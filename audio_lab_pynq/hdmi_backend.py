"""Minimal HDMI framebuffer back end for the Phase 4 integrated AudioLab
overlay.

Single-purpose role: take an RGB888 ``numpy.ndarray`` from
``GUI.pynq_multi_fx_gui.render_frame_800x480_compact_v2`` (or the native
1280x720 path used by the diagnostic scripts) and scan it out to HDMI
through the integrated ``axi_vdma_hdmi`` / ``v_tc_hdmi`` /
``v_axi4s_vid_out_hdmi`` / ``rgb2dvi_hdmi`` block in ``audio_lab.bit``.
The DDR framebuffer is 24-bit packed GBR888 because Digilent ``rgb2dvi``
maps ``vid_pData`` as ``[23:16]=R``, ``[15:8]=B``, ``[7:0]=G``.

The back end intentionally does NOT:

- load ``base.bit`` or any second overlay
- depend on ``pynq.lib.video`` (PYNQ base overlay assumptions don't fit
  here; the AudioLab BD names IPs ``axi_vdma_hdmi`` / ``v_tc_hdmi`` /
  ``rgb2dvi_hdmi`` and does not provide a ``video.hdmi_out`` accessor)
- depend on the unused ``axi_dma_0`` audio capture path
- write to any audio-side AXI GPIO

Public API:

    backend = AudioLabHdmiBackend(overlay)
    backend.start(rgb_frame)        # one-shot static frame
    backend.write_frame(rgb_frame)  # overwrite the framebuffer
    backend.write_frame(rgb_frame, fit_mode="fit-90")
    backend.write_frame(rgb_800x480, placement="center")
    backend.write_frame(rgb_800x480, placement="manual", offset_x=0, offset_y=0)
    backend.status()                # debug dict
    backend.stop()
"""
from __future__ import print_function

import os
import time

import numpy as np


# AXI VDMA (Xilinx PG020 v6.3) MM2S register offsets, used inside this
# instance only. Audio-side VDMA is a different cell and is not touched.
VDMA_MM2S_DMACR              = 0x00
VDMA_MM2S_DMASR              = 0x04
VDMA_PARK_PTR_REG            = 0x28
VDMA_VERSION                 = 0x2C
VDMA_MM2S_VSIZE              = 0x50
VDMA_MM2S_HSIZE              = 0x54
VDMA_MM2S_FRMDLY_STRIDE      = 0x58
VDMA_MM2S_START_ADDRESS1     = 0x5C
VDMA_MM2S_START_ADDRESS2     = 0x60
VDMA_MM2S_START_ADDRESS3     = 0x64

# VDMA MM2S_VDMACR bit field meanings used here. See PG020 Table 2-2.
VDMACR_RS                    = 1 << 0
VDMACR_RESET                 = 1 << 2
VDMACR_GENLOCK_EN            = 1 << 3
VDMACR_INTERNAL_GENLOCK      = 1 << 7
VDMACR_CIRCULAR_PARK         = 1 << 1   # 1 = circular, 0 = park
VDMACR_FRMCNT_EN             = 1 << 4
# DMASR error bits we care about
VDMASR_HALTED                = 1 << 0
VDMASR_IDLE                  = 1 << 1
VDMASR_DMAINTERR             = 1 << 4
VDMASR_DMASLVERR             = 1 << 5
VDMASR_DMADECERR             = 1 << 6
VDMASR_SOFINTERR             = 1 << 7   # not used in our mode but checked
VDMASR_ERR_MASK = (VDMASR_DMAINTERR | VDMASR_DMASLVERR | VDMASR_DMADECERR)

# Xilinx v_tc (PG016 v6.1) register offsets
VTC_CTL                      = 0x000
VTC_GLOBAL_INTR_ENABLE       = 0x00C
VTC_GEN_HACTIVE_SIZE         = 0x064  # legacy alias, see notes below
VTC_GEN_HSYNC                = 0x078  # bits[12:0]=HSYNC_HSTART, [28:16]=HSYNC_HEND

# v_tc CTL bits (PG016 v6.1 Table 2-4)
VTC_CTL_SW_RESET             = 1 << 31
VTC_CTL_FSYNC_ENABLE_GEN     = 1 << 0
VTC_CTL_REG_UPDATE           = 1 << 1
VTC_CTL_GENERATION_ENABLE    = 1 << 2
VTC_CTL_DETECTION_ENABLE     = 1 << 3
# Bit 5 = FSync enable, bit 6 = SyncEnable. We do not use FSync inputs.

# Phase 6G: live-patch the VTC HSync position to compensate the 5-inch
# LCD's 150 px right-shift. The IP-baked 1280x720@60 timing has HSync
# at 1390..1429 (40-cycle sync, 220-cycle back porch). The LCD samples
# active video 150 cycles later than expected, which puts source x=0
# at LCD x=150 and cuts the right ~150 px of an 800x480 logical frame
# off the LCD. Moving HSync 150 cycles later (1540..1579) shrinks the
# back porch to 70 and shifts the visible source region 150 cycles
# left, aligning source x=0 with LCD x=0. The shift can be disabled at
# runtime by setting environment variable ``AUDIOLAB_HDMI_HSYNC_SHIFT``
# to ``0`` or by passing ``hsync_shift=0`` to
# ``AudioLabHdmiBackend(...)``.
VTC_HSYNC_SHIFT_DEFAULT      = 150

DEFAULT_WIDTH                = 1280
DEFAULT_HEIGHT               = 720
DEFAULT_BYTES_PER_PIXEL      = 3
DEFAULT_NUM_FSTORES          = 3

FIT_MODE_SCALES = {
    "native": 1.00,
    "fit-97": 0.97,
    "fit-95": 0.95,
    "fit-90": 0.90,
    "fit-85": 0.85,
    "fit-80": 0.80,
}


class HdmiNotIntegratedError(RuntimeError):
    """Raised when the running overlay does not contain the HDMI subsystem.

    Phase 4A integrated the HDMI path into ``audio_lab.bit``. If a board
    boots an older bit, ``axi_vdma_hdmi`` / ``v_tc_hdmi`` / ``rgb2dvi_hdmi``
    will be missing and this back end refuses to fake them.
    """


def _mmio_from_ip_dict(overlay, name):
    """Create a bare ``pynq.MMIO`` for an AXI-lite IP by HWH name.

    PYNQ binds ``axi_vdma`` to ``pynq.lib.video.dma.AxiVDMA`` by default.
    That driver expects the base-overlay interrupt wiring and fails during
    attribute access for this MM2S-only AudioLab instance. Phase 4B needs only
    a handful of registers, so direct MMIO is the least coupled path.
    """
    try:
        desc = overlay.ip_dict[name]
    except KeyError:
        raise HdmiNotIntegratedError(
            "AudioLabOverlay ip_dict is missing {}; the running bit/HWH was "
            "not built with Phase 4 HDMI integration.".format(name))

    try:
        from pynq import MMIO
        mmio = MMIO(int(desc["phys_addr"]), int(desc["addr_range"]))
    except Exception as exc:
        raise HdmiNotIntegratedError(
            "failed to create MMIO for {} from ip_dict: {}".format(name, exc))
    return mmio, desc


def _allocate_framebuffer(width=DEFAULT_WIDTH, height=DEFAULT_HEIGHT,
                          bytes_per_pixel=DEFAULT_BYTES_PER_PIXEL):
    """Allocate a contiguous PS DDR buffer for one VDMA frame.

    Prefers ``pynq.allocate`` (PYNQ 2.5+); falls back to ``pynq.Xlnk``
    when that helper is not available (older PYNQ images).
    """
    if bytes_per_pixel != 3:
        raise ValueError("Only RGB888 (3 bytes/pixel) is supported in Phase 4B")
    try:
        from pynq import allocate
        buf = allocate(shape=(height, width, 3), dtype=np.uint8,
                       cacheable=False)
        return buf
    except Exception:
        from pynq import Xlnk  # noqa: F401
        xlnk = Xlnk()
        return xlnk.cma_array(shape=(height, width, 3), dtype=np.uint8,
                              cacheable=False)


def fit_mode_scale(fit_mode="native", scale=None):
    """Resolve a named HDMI LCD fit mode to a numeric scale."""
    if scale is not None:
        value = float(scale)
    else:
        try:
            value = FIT_MODE_SCALES[str(fit_mode)]
        except KeyError:
            raise ValueError(
                "unknown fit_mode {!r}; expected one of {}".format(
                    fit_mode, sorted(FIT_MODE_SCALES)))
    if value <= 0.0 or value > 1.0:
        raise ValueError("HDMI fit scale must be > 0.0 and <= 1.0; got {}".format(value))
    return value


def compose_fit_frame(rgb_frame, fit_mode="native", scale=None,
                      width=DEFAULT_WIDTH, height=DEFAULT_HEIGHT,
                      background=(0, 0, 0)):
    """Return a 1280x720 RGB frame after optional LCD overscan fitting.

    ``native`` returns the input ndarray and records zero offset. Other modes
    resize the input with Pillow's old-version-compatible constants and paste
    it onto a black RGB888 canvas. The framebuffer dimensions and VDMA
    programming stay unchanged.
    """
    arr = np.asarray(rgb_frame)
    if arr.shape != (int(height), int(width), 3) or arr.dtype != np.uint8:
        raise ValueError(
            "rgb_frame must be ({},{},3) uint8 RGB; got shape={}, dtype={}"
            .format(int(height), int(width), arr.shape, arr.dtype))

    requested_mode = str(fit_mode)
    resolved_scale = fit_mode_scale(requested_mode, scale=scale)
    scaled_w = max(1, int(round(int(width) * resolved_scale)))
    scaled_h = max(1, int(round(int(height) * resolved_scale)))
    offset_x = (int(width) - scaled_w) // 2
    offset_y = (int(height) - scaled_h) // 2
    meta = {
        "fit_mode": requested_mode,
        "scale": resolved_scale,
        "input_width": int(width),
        "input_height": int(height),
        "scaled_width": scaled_w,
        "scaled_height": scaled_h,
        "offset_x": offset_x,
        "offset_y": offset_y,
        "background_rgb": tuple(int(v) for v in background),
        "resize_compose_s": 0.0,
        "native_passthrough": bool(resolved_scale == 1.0),
    }
    if resolved_scale == 1.0:
        return arr, meta

    t0 = time.time()
    try:
        from PIL import Image
    except Exception as exc:
        raise RuntimeError("Pillow is required for HDMI fit modes: {}".format(exc))

    canvas = np.empty((int(height), int(width), 3), dtype=np.uint8)
    canvas[:, :, 0] = int(background[0]) & 0xFF
    canvas[:, :, 1] = int(background[1]) & 0xFF
    canvas[:, :, 2] = int(background[2]) & 0xFF

    pil = Image.fromarray(arr, "RGB")
    resized = pil.resize((scaled_w, scaled_h), Image.BILINEAR)
    canvas[offset_y:offset_y + scaled_h,
           offset_x:offset_x + scaled_w, :] = np.asarray(resized, dtype=np.uint8)
    meta["resize_compose_s"] = time.time() - t0
    return canvas, meta


def compose_logical_frame(rgb_frame, width=DEFAULT_WIDTH, height=DEFAULT_HEIGHT,
                          placement="center", offset_x=None, offset_y=None,
                          background=(0, 0, 0)):
    """Place a smaller logical RGB frame inside the fixed HDMI framebuffer.

    ``placement="manual"`` accepts negative ``offset_x`` / ``offset_y``. The
    requested rectangle is clipped against the framebuffer on every side, and
    the corresponding source region is shifted so that any negative offset
    crops the logical frame instead of indexing into a previous row. The
    returned meta records the requested destination region, the clipped
    destination region, and the source crop, so a user-facing log can
    distinguish a clipped placement from a fully-visible one.
    """
    arr = np.asarray(rgb_frame)
    if arr.ndim != 3 or arr.shape[2] != 3 or arr.dtype != np.uint8:
        raise ValueError(
            "logical rgb_frame must be (h,w,3) uint8 RGB; got shape={}, dtype={}"
            .format(arr.shape, arr.dtype))
    in_h, in_w = int(arr.shape[0]), int(arr.shape[1])
    out_w, out_h = int(width), int(height)
    placement = str(placement)
    if placement == "center":
        ox = (out_w - in_w) // 2
        oy = (out_h - in_h) // 2
    elif placement == "manual":
        ox = int(offset_x) if offset_x is not None else 0
        oy = int(offset_y) if offset_y is not None else 0
    else:
        raise ValueError(
            "unknown placement {!r}; expected center or manual".format(placement))

    req_x0, req_y0 = int(ox), int(oy)
    req_x1, req_y1 = req_x0 + in_w, req_y0 + in_h

    t0 = time.time()
    canvas = np.empty((out_h, out_w, 3), dtype=np.uint8)
    canvas[:, :, 0] = int(background[0]) & 0xFF
    canvas[:, :, 1] = int(background[1]) & 0xFF
    canvas[:, :, 2] = int(background[2]) & 0xFF

    dst_x0 = min(max(0, req_x0), out_w)
    dst_y0 = min(max(0, req_y0), out_h)
    dst_x1 = max(0, min(out_w, req_x1))
    dst_y1 = max(0, min(out_h, req_y1))
    src_x0 = max(0, -req_x0)
    src_y0 = max(0, -req_y0)
    copied_w = max(0, dst_x1 - dst_x0)
    copied_h = max(0, dst_y1 - dst_y0)
    src_x1 = src_x0 + copied_w
    src_y1 = src_y0 + copied_h
    if copied_w > 0 and copied_h > 0:
        canvas[dst_y0:dst_y1, dst_x0:dst_x1, :] = \
            arr[src_y0:src_y1, src_x0:src_x1, :]

    compose_s = time.time() - t0
    clipped = (req_x0 < 0 or req_y0 < 0
               or req_x1 > out_w or req_y1 > out_h)
    fully_offscreen = (copied_w <= 0 or copied_h <= 0)
    meta = {
        "fit_mode": "logical",
        "scale": 1.0,
        "input_width": in_w,
        "input_height": in_h,
        "input_shape": [in_h, in_w, 3],
        "output_width": out_w,
        "output_height": out_h,
        "scaled_width": in_w,
        "scaled_height": in_h,
        "offset_x": req_x0,
        "offset_y": req_y0,
        "placement": placement,
        "background_rgb": tuple(int(v) for v in background),
        "resize_compose_s": compose_s,
        "compose_s": compose_s,
        "native_passthrough": False,
        "logical_placement": True,
        "negative_offset": bool(req_x0 < 0 or req_y0 < 0),
        "clipped": bool(clipped),
        "fully_offscreen": bool(fully_offscreen),
        "requested_destination_region": {
            "x0": req_x0, "y0": req_y0, "x1": req_x1, "y1": req_y1,
            "width": in_w, "height": in_h,
        },
        "source_visible_region": {
            "x0": src_x0, "y0": src_y0, "x1": src_x1, "y1": src_y1,
            "width": copied_w, "height": copied_h,
        },
        "framebuffer_copied_region": {
            "x0": dst_x0, "y0": dst_y0, "x1": dst_x1, "y1": dst_y1,
            "width": copied_w, "height": copied_h,
        },
        "copied_pixels": int(copied_w * copied_h),
    }
    return canvas, meta


class AudioLabHdmiBackend(object):
    """Direct-MMIO VDMA + VTC driver for the integrated AudioLab HDMI path."""

    REQUIRED_MMIO_IPS = ("axi_vdma_hdmi", "v_tc_hdmi")

    def __init__(self, overlay, width=DEFAULT_WIDTH, height=DEFAULT_HEIGHT,
                 num_fstores=DEFAULT_NUM_FSTORES, hsync_shift=None):
        self.overlay = overlay
        self.width = int(width)
        self.height = int(height)
        self.bytes_per_pixel = DEFAULT_BYTES_PER_PIXEL
        self.num_fstores = int(num_fstores)
        self.hsize_bytes = self.width * self.bytes_per_pixel
        self.stride_bytes = self.hsize_bytes
        self.vdma_mmio, self._vdma_ip_desc = _mmio_from_ip_dict(
            overlay, "axi_vdma_hdmi")
        self.vtc_mmio, self._vtc_ip_desc = _mmio_from_ip_dict(
            overlay, "v_tc_hdmi")
        self._framebuffer = None
        self._started = False
        self._last_vdma_start = {}
        self._last_frame_write = {}
        # Phase 6G: VTC HSync shift compensates the LCD's 150 px right
        # offset. Constructor arg overrides the env-var default; pass
        # 0 to disable.
        if hsync_shift is None:
            env = os.environ.get("AUDIOLAB_HDMI_HSYNC_SHIFT")
            if env is not None:
                try:
                    hsync_shift = int(env)
                except ValueError:
                    hsync_shift = VTC_HSYNC_SHIFT_DEFAULT
            else:
                hsync_shift = VTC_HSYNC_SHIFT_DEFAULT
        self.hsync_shift = int(hsync_shift)
        self._original_hsync = None
        self._patched_hsync = None

    # ---- MMIO helpers --------------------------------------------------
    def _vdma_read(self, offset):
        return int(self.vdma_mmio.read(offset))

    def _vdma_write(self, offset, value):
        self.vdma_mmio.write(offset, int(value) & 0xFFFFFFFF)

    def _vtc_read(self, offset):
        return int(self.vtc_mmio.read(offset))

    def _vtc_write(self, offset, value):
        self.vtc_mmio.write(offset, int(value) & 0xFFFFFFFF)

    @staticmethod
    def _hex32(value):
        return "0x{:08x}".format(int(value) & 0xFFFFFFFF)

    def _snapshot_vdma_regs(self):
        return {
            "dmacr": self._hex32(self._vdma_read(VDMA_MM2S_DMACR)),
            "dmasr": self._hex32(self._vdma_read(VDMA_MM2S_DMASR)),
        }

    # ---- VDMA bring-up --------------------------------------------------
    def _vdma_reset(self, timeout_s=0.5):
        self._vdma_write(VDMA_MM2S_DMACR,
                         self._vdma_read(VDMA_MM2S_DMACR) | VDMACR_RESET)
        t_end = time.time() + timeout_s
        while time.time() < t_end:
            if (self._vdma_read(VDMA_MM2S_DMACR) & VDMACR_RESET) == 0:
                return
        raise RuntimeError("axi_vdma_hdmi MM2S reset did not clear")

    def _program_vdma(self, phys_addr):
        # MM2S register sequence, PG020 Section 2-4 "Start MM2S Operation".
        debug = {
            "before_reset": self._snapshot_vdma_regs(),
            "framebuffer_phys_address": self._hex32(phys_addr),
            "framebuffer_format": "GBR888 packed in DDR from RGB888 input",
            "bytes_per_pixel": self.bytes_per_pixel,
            "hsize_bytes": self.hsize_bytes,
            "vsize_lines": self.height,
            "stride_bytes": self.stride_bytes,
            "frame_delay": 0,
            "mode": "parked frame 0, internal genlock",
        }
        # 1. Issue soft reset and wait for clear.
        self._vdma_reset()
        debug["after_reset"] = self._snapshot_vdma_regs()
        # 2. Disable interrupts; we are polling.
        # 3. Program frame buffer addresses. Use the same physical address
        #    for every frame store so a single static buffer scans out.
        for offset in (VDMA_MM2S_START_ADDRESS1,
                       VDMA_MM2S_START_ADDRESS2,
                       VDMA_MM2S_START_ADDRESS3):
            self._vdma_write(offset, phys_addr)
        # 4. Park the engine on frame 0 (so it never advances frame index).
        self._vdma_write(VDMA_PARK_PTR_REG, 0)
        # 5. Frame delay 0, stride = hsize_bytes (no padding).
        self._vdma_write(VDMA_MM2S_FRMDLY_STRIDE,
                         self.stride_bytes & 0xFFFF)
        # 6. HSIZE in bytes per line.
        self._vdma_write(VDMA_MM2S_HSIZE, self.hsize_bytes)
        # 7. Start MM2S: RS=1, park mode (Circular_Park=0), internal genlock.
        dmacr = VDMACR_RS | VDMACR_INTERNAL_GENLOCK
        self._vdma_write(VDMA_MM2S_DMACR, dmacr)
        debug["after_dmacr_start"] = self._snapshot_vdma_regs()
        # 8. Writing VSIZE kicks off the channel.
        self._vdma_write(VDMA_MM2S_VSIZE, self.height)
        debug["after_vsize"] = self._snapshot_vdma_regs()
        self._last_vdma_start = debug

    # ---- VTC bring-up ---------------------------------------------------
    def _start_vtc(self):
        # Soft reset, then enable generator + register update. The 1280x720@60
        # timing was baked in at IP gen time, so this just turns it on.
        self._vtc_write(VTC_CTL, VTC_CTL_SW_RESET)
        time.sleep(0.001)
        # Clear pending interrupt latches.
        self._vtc_write(0x004, 0xFFFFFFFF)
        # Phase 6G: shift HSync later in each line so the LCD viewport
        # aligns source x=0 with LCD x=0. Capture the original value
        # before patching so callers / diagnostics can revert.
        try:
            self._original_hsync = int(self._vtc_read(VTC_GEN_HSYNC))
        except Exception:
            self._original_hsync = None
        if self.hsync_shift and self._original_hsync is not None:
            hstart = self._original_hsync & 0x1FFF
            hend = (self._original_hsync >> 16) & 0x1FFF
            new_hstart = (hstart + int(self.hsync_shift)) & 0x1FFF
            new_hend = (hend + int(self.hsync_shift)) & 0x1FFF
            patched = ((new_hend & 0x1FFF) << 16) | (new_hstart & 0x1FFF)
            self._vtc_write(VTC_GEN_HSYNC, patched)
            self._patched_hsync = patched
        # Enable generator and REG_UPDATE.
        self._vtc_write(VTC_CTL,
                        VTC_CTL_GENERATION_ENABLE | VTC_CTL_REG_UPDATE)

    # ---- public API -----------------------------------------------------
    def start(self, rgb_frame=None, fit_mode="native", scale=None,
              background=(0, 0, 0), placement="center",
              offset_x=None, offset_y=None):
        """Allocate a framebuffer, fill it from ``rgb_frame`` (or black if
        None), program VDMA and VTC, and return the framebuffer ndarray.
        """
        if self._started:
            return self._framebuffer

        if self._framebuffer is None:
            self._framebuffer = _allocate_framebuffer(
                self.width, self.height, self.bytes_per_pixel)
        # Fill with content
        if rgb_frame is None:
            self._framebuffer[...] = 0
            self._last_frame_write = {
                "fit_mode": str(fit_mode),
                "scale": fit_mode_scale(fit_mode, scale=scale),
                "input_width": self.width,
                "input_height": self.height,
                "scaled_width": self.width,
                "scaled_height": self.height,
                "offset_x": 0,
                "offset_y": 0,
                "placement": str(placement),
                "background_rgb": tuple(int(v) for v in background),
                "resize_compose_s": 0.0,
                "compose_s": 0.0,
                "framebuffer_copy_s": 0.0,
                "native_passthrough": True,
                "logical_placement": False,
            }
        else:
            self.write_frame(rgb_frame, fit_mode=fit_mode, scale=scale,
                             background=background, placement=placement,
                             offset_x=offset_x, offset_y=offset_y)

        phys = int(self._framebuffer.physical_address)
        self._program_vdma(phys)
        self._start_vtc()
        self._started = True
        return self._framebuffer

    def write_frame(self, rgb_frame, fit_mode="native", scale=None,
                    background=(0, 0, 0), placement="center",
                    offset_x=None, offset_y=None):
        """Overwrite the framebuffer in place with a new RGB888 ndarray."""
        if self._framebuffer is None:
            raise RuntimeError("HDMI back end has not been started yet")
        arr = np.asarray(rgb_frame)
        if arr.shape == (self.height, self.width, 3):
            fitted, meta = compose_fit_frame(
                arr, fit_mode=fit_mode, scale=scale, width=self.width,
                height=self.height, background=background)
            meta["placement"] = str(placement)
            meta["compose_s"] = meta.get("resize_compose_s", 0.0)
            meta["logical_placement"] = False
        else:
            if str(fit_mode) != "native" or scale is not None:
                raise ValueError(
                    "fit_mode/scale are only for native 1280x720 frames; "
                    "logical frames use placement")
            fitted, meta = compose_logical_frame(
                arr, width=self.width, height=self.height,
                placement=placement, offset_x=offset_x, offset_y=offset_y,
                background=background)
        t0 = time.time()
        self._copy_rgb(fitted)
        meta["framebuffer_copy_s"] = time.time() - t0
        self._last_frame_write = meta
        return dict(meta)

    def write_logical_frame(self, rgb_frame, placement="center",
                            offset_x=None, offset_y=None,
                            background=(0, 0, 0)):
        """Overwrite the framebuffer with a smaller logical RGB frame."""
        return self.write_frame(
            rgb_frame, placement=placement, offset_x=offset_x,
            offset_y=offset_y, background=background)

    def _copy_rgb(self, rgb_frame):
        arr = np.asarray(rgb_frame)
        if arr.shape != (self.height, self.width, 3) or arr.dtype != np.uint8:
            raise ValueError(
                "rgb_frame must be ({},{},3) uint8 RGB; got shape={}, dtype={}"
                .format(self.height, self.width, arr.shape, arr.dtype))
        # The renderer gives RGB byte order. The VDMA emits byte 0 on
        # TDATA[7:0], byte 1 on TDATA[15:8], and byte 2 on TDATA[23:16].
        # Digilent rgb2dvi expects that bus as G, B, R respectively.
        # Three direct slice copies avoid a temporary 720p swizzle buffer.
        self._framebuffer[:, :, 0] = arr[:, :, 1]  # G -> vid_pData[7:0]
        self._framebuffer[:, :, 1] = arr[:, :, 2]  # B -> vid_pData[15:8]
        self._framebuffer[:, :, 2] = arr[:, :, 0]  # R -> vid_pData[23:16]

    def status(self):
        """Return a small dict with VDMA and VTC state for tests / docs."""
        return {
            "vdma_dmacr": self._hex32(self._vdma_read(VDMA_MM2S_DMACR)),
            "vdma_dmasr": self._hex32(self._vdma_read(VDMA_MM2S_DMASR)),
            "vdma_hsize": int(self._vdma_read(VDMA_MM2S_HSIZE)),
            "vdma_vsize": int(self._vdma_read(VDMA_MM2S_VSIZE)),
            "vdma_stride": int(self._vdma_read(VDMA_MM2S_FRMDLY_STRIDE)) & 0xFFFF,
            "vdma_start1": self._hex32(self._vdma_read(VDMA_MM2S_START_ADDRESS1)),
            "vdma_version": self._hex32(self._vdma_read(VDMA_VERSION)),
            "vdma_ip_phys_addr": self._hex32(self._vdma_ip_desc["phys_addr"]),
            "vdma_ip_addr_range": int(self._vdma_ip_desc["addr_range"]),
            "vtc_ctl": self._hex32(self._vtc_read(VTC_CTL)),
            "vtc_ip_phys_addr": self._hex32(self._vtc_ip_desc["phys_addr"]),
            "vtc_ip_addr_range": int(self._vtc_ip_desc["addr_range"]),
            "vtc_gen_hsync": self._hex32(self._vtc_read(VTC_GEN_HSYNC)),
            "vtc_hsync_shift": int(self.hsync_shift),
            "vtc_original_hsync": (
                self._hex32(self._original_hsync)
                if self._original_hsync is not None else None),
            "vtc_patched_hsync": (
                self._hex32(self._patched_hsync)
                if self._patched_hsync is not None else None),
            "framebuffer_phys_address": (
                self._hex32(int(self._framebuffer.physical_address))
                if self._framebuffer is not None else None),
            "framebuffer_size_bytes": (
                int(self._framebuffer.nbytes)
                if self._framebuffer is not None else None),
            "hsize_bytes": self.hsize_bytes,
            "vsize_lines": self.height,
            "stride_bytes": self.stride_bytes,
            "bytes_per_pixel": self.bytes_per_pixel,
            "input_format": "RGB888 ndarray",
            "memory_format": (
                "GBR888 packed in DDR: byte0=G, byte1=B, byte2=R"),
            "axis_stream_format": (
                "24-bit vid_pData: [23:16]=R, [15:8]=B, [7:0]=G"),
            "non_mmio_hdmi_note": (
                "rgb2dvi_hdmi and v_axi4s_vid_out_hdmi are HWH-only video "
                "pipeline IPs; they are not exposed as PYNQ MMIO attributes"),
            "last_vdma_start": self._last_vdma_start,
            "last_frame_write": self._last_frame_write,
            "started": self._started,
        }

    def stop(self):
        """Stop VDMA MM2S and VTC generator. Framebuffer stays allocated."""
        try:
            self._vdma_write(VDMA_MM2S_DMACR,
                             self._vdma_read(VDMA_MM2S_DMACR) & ~VDMACR_RS)
        except Exception:
            pass
        try:
            self._vtc_write(VTC_CTL, 0)
        except Exception:
            pass
        self._started = False

    def errors(self):
        """Return the set of VDMA error bits currently asserted (post-start)."""
        sr = self._vdma_read(VDMA_MM2S_DMASR)
        return {
            "halted": bool(sr & VDMASR_HALTED),
            "idle": bool(sr & VDMASR_IDLE),
            "dmainterr": bool(sr & VDMASR_DMAINTERR),
            "dmaslverr": bool(sr & VDMASR_DMASLVERR),
            "dmadecerr": bool(sr & VDMASR_DMADECERR),
            "raw": self._hex32(sr),
        }


__all__ = [
    "AudioLabHdmiBackend",
    "HdmiNotIntegratedError",
    "DEFAULT_WIDTH",
    "DEFAULT_HEIGHT",
    "DEFAULT_BYTES_PER_PIXEL",
    "FIT_MODE_SCALES",
    "fit_mode_scale",
    "compose_fit_frame",
    "compose_logical_frame",
]

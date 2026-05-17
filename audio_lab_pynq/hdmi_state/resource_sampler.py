"""Phase 6C: /proc-based system metrics for the HDMI GUI resource
monitor.

The PYNQ-Z2 image does not ship ``psutil``, so the sampler reads
``/proc/stat``, ``/proc/self/stat``, ``/proc/meminfo``,
``/proc/self/status`` and ``/sys/class/thermal/thermal_zone0/temp``
directly. First-call ``sample()`` returns ``None`` for the CPU
percentages so the caller can ignore the bootstrap delta.
"""

import os
import time


def _parse_proc_meminfo_text(text):
    """Phase 6C: parse a /proc/meminfo blob into a {key: kB int} dict."""
    info = {}
    for raw in str(text or "").splitlines():
        if ":" not in raw:
            continue
        key, _, rest = raw.partition(":")
        parts = rest.strip().split()
        if not parts:
            continue
        try:
            info[key.strip()] = int(parts[0])
        except (TypeError, ValueError):
            continue
    return info


def _parse_proc_status_text(text):
    """Phase 6C: parse a /proc/self/status blob into a {key: value} dict."""
    out = {}
    for raw in str(text or "").splitlines():
        if ":" not in raw:
            continue
        key, _, rest = raw.partition(":")
        out[key.strip()] = rest.strip()
    return out


def _parse_proc_stat_cpu_line(line):
    """Phase 6C: parse the aggregate CPU line of /proc/stat.

    Returns ``(total_jiffies, idle_jiffies)`` or ``None`` if the line is
    malformed. ``idle_jiffies`` includes iowait (field 4) so the
    derived %CPU includes both run-time-blocked and on-CPU work.
    """
    parts = str(line or "").split()
    if len(parts) < 5 or parts[0] != "cpu":
        return None
    try:
        nums = [int(x) for x in parts[1:]]
    except ValueError:
        return None
    idle = nums[3] + (nums[4] if len(nums) > 4 else 0)
    total = sum(nums)
    return total, idle


def _parse_proc_self_stat_times(text):
    """Phase 6C: parse utime + stime jiffies out of /proc/self/stat.

    The ``comm`` field is enclosed in parens and may itself contain
    spaces, so split off the last ``)`` before tokenising. Returns
    ``None`` when fields cannot be parsed.
    """
    data = str(text or "")
    rparen = data.rfind(")")
    if rparen < 0:
        return None
    rest = data[rparen + 1:].split()
    try:
        utime = int(rest[11])
        stime = int(rest[12])
    except (IndexError, ValueError):
        return None
    return utime + stime


class ResourceSampler(object):
    """Phase 6C: tiny /proc-based CPU / memory sampler.

    No ``psutil`` dependency; older PYNQ images do not ship it. The
    sampler returns ``None`` for percentages on the first call so the
    caller can ignore the bootstrap delta. Subsequent ``sample()`` calls
    return absolute deltas against the previous call.
    """

    def __init__(self):
        self._prev_proc_cpu = None
        self._prev_sys_cpu = None
        self._prev_t = None
        try:
            self.ticks_per_sec = float(os.sysconf("SC_CLK_TCK"))
        except (AttributeError, OSError, ValueError):
            self.ticks_per_sec = 100.0
        try:
            self.cpu_count = int(os.sysconf("SC_NPROCESSORS_ONLN"))
        except (AttributeError, OSError, ValueError):
            self.cpu_count = 1

    @staticmethod
    def _read_text(path):
        try:
            with open(path, "r") as fp:
                return fp.read()
        except (IOError, OSError):
            return ""

    def _read_sys_cpu(self):
        text = self._read_text("/proc/stat")
        first = text.split("\n", 1)[0] if text else ""
        return _parse_proc_stat_cpu_line(first)

    def _read_proc_cpu(self):
        return _parse_proc_self_stat_times(self._read_text("/proc/self/stat"))

    def _read_meminfo(self):
        return _parse_proc_meminfo_text(self._read_text("/proc/meminfo"))

    def _read_status(self):
        return _parse_proc_status_text(self._read_text("/proc/self/status"))

    def _temperature_c(self):
        path = "/sys/class/thermal/thermal_zone0/temp"
        try:
            with open(path, "r") as fp:
                raw = fp.read().strip()
        except (IOError, OSError):
            return None
        try:
            return float(raw) / 1000.0
        except (TypeError, ValueError):
            return None

    def sample(self):
        """Return a snapshot dict. First call's CPU% fields are ``None``."""
        t_now = time.time()
        sys_cpu = self._read_sys_cpu()
        proc_cpu = self._read_proc_cpu()
        meminfo = self._read_meminfo()
        status = self._read_status()

        sys_cpu_pct = None
        if sys_cpu is not None and self._prev_sys_cpu is not None:
            total_now, idle_now = sys_cpu
            total_prev, idle_prev = self._prev_sys_cpu
            d_total = total_now - total_prev
            d_idle = idle_now - idle_prev
            if d_total > 0:
                sys_cpu_pct = 100.0 * (1.0 - (float(d_idle) / float(d_total)))

        proc_cpu_pct = None
        if (proc_cpu is not None and self._prev_proc_cpu is not None
                and self._prev_t is not None):
            dt = t_now - self._prev_t
            d_ticks = proc_cpu - self._prev_proc_cpu
            if dt > 0 and self.ticks_per_sec > 0:
                proc_cpu_pct = 100.0 * (
                    (float(d_ticks) / self.ticks_per_sec) / dt)

        self._prev_sys_cpu = sys_cpu
        self._prev_proc_cpu = proc_cpu
        self._prev_t = t_now

        def _kb(field):
            try:
                return int(status.get(field, "0 kB").split()[0])
            except (IndexError, ValueError):
                return 0

        return {
            "time_s": t_now,
            "proc_rss_kb": _kb("VmRSS"),
            "proc_vmsize_kb": _kb("VmSize"),
            "mem_total_kb": int(meminfo.get("MemTotal", 0)),
            "mem_avail_kb": int(meminfo.get("MemAvailable", 0)),
            "mem_free_kb": int(meminfo.get("MemFree", 0)),
            "sys_cpu_pct": sys_cpu_pct,
            "proc_cpu_pct": proc_cpu_pct,
            "cpu_count": int(self.cpu_count),
            "temperature_c": self._temperature_c(),
        }


# Phase 6C: static PL utilization snapshot. Read from the latest Vivado
# implementation report; updated only when bit/hwh is rebuilt.
STATIC_PL_UTILIZATION = {
    "source": "Vivado utilization_placed (latest deployed audio_lab.bit)",
    "lut": 18619,
    "registers": 20846,
    "bram_36k": 9,
    "dsp48": 83,
    "ioob": 60,
}

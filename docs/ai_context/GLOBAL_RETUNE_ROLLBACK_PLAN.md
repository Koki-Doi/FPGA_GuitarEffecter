# Global Retune Rollback Plan

This plan belongs to the one-branch experiment
`feature/global-amp-dist-od-real-pedal-retune-20260525-192457`.

## Baseline

- Baseline commit:
  `882a1cfe928a0aabdd02aefa4a8c6c80b0fd7e36`
  (`Retune JCM800 amp model constants only`)
- Baseline branch at start: `feature/global-amp-dist-od-real-pedal-retune`
  pointing at the same commit as `main`
- Experiment branch:
  `feature/global-amp-dist-od-real-pedal-retune-20260525-192457`
- Baseline local bit md5:
  `70b5dc7d972510c26fbb3b1014aa06eb`
- Baseline local hwh md5:
  `dc42290dc7fb46d7486068cc1d11032a`
- Baseline PYNQ bit/hwh md5 matched local at experiment start.
- Baseline runtime at start:
  - `PL.timestamp`: `2026/5/25 8:51:8 +789698`
  - `VERSION`: `0x00480001`
  - `ADC HPF`: `True`, `R19_ADC_CONTROL = 0x23`
  - Pmod I2S2 `MODE_REG`: `3 (mute)`
  - `FRAME_COUNT`: `269403330`
  - `CLIP_COUNT`: `0`

## Files To Restore On Reject

Restore these tracked paths exactly from the baseline commit:

- `hw/ip/clash/src/AudioLab/Effects/Amp.hs`
- `hw/ip/clash/src/AudioLab/Effects/Distortion.hs`
- `hw/ip/clash/src/AudioLab/Effects/Overdrive.hs`
- `hw/ip/clash/vhdl/LowPassFir/`
- `hw/Pynq-Z2/bitstreams/audio_lab.bit`
- `hw/Pynq-Z2/bitstreams/audio_lab.hwh`

Do not delete untracked files. Do not use `git reset --hard`,
`git clean`, or `git add .`.

## Local Rollback Commands

From the repository root:

```sh
BASELINE=882a1cfe928a0aabdd02aefa4a8c6c80b0fd7e36

git restore --source "$BASELINE" -- \
  hw/ip/clash/src/AudioLab/Effects/Amp.hs \
  hw/ip/clash/src/AudioLab/Effects/Distortion.hs \
  hw/ip/clash/src/AudioLab/Effects/Overdrive.hs \
  hw/ip/clash/vhdl/LowPassFir \
  hw/Pynq-Z2/bitstreams/audio_lab.bit \
  hw/Pynq-Z2/bitstreams/audio_lab.hwh

md5sum hw/Pynq-Z2/bitstreams/audio_lab.bit \
       hw/Pynq-Z2/bitstreams/audio_lab.hwh
```

Expected md5 after local rollback:

```text
70b5dc7d972510c26fbb3b1014aa06eb  hw/Pynq-Z2/bitstreams/audio_lab.bit
dc42290dc7fb46d7486068cc1d11032a  hw/Pynq-Z2/bitstreams/audio_lab.hwh
```

If research docs should be retained after a rejected experiment, leave
only docs staged explicitly by path. Do not commit the rejected
implementation, regenerated VHDL, bit, or hwh.

## PYNQ Rollback Deploy

After local files match the baseline md5:

```sh
PYNQ_HOST=192.168.1.9 bash scripts/deploy_to_pynq.sh
```

Then force a fresh PL program and return the board to mute:

```sh
ssh xilinx@192.168.1.9 '
  cd /home/xilinx/Audio-Lab-PYNQ &&
  sudo env PYTHONPATH=/home/xilinx/Audio-Lab-PYNQ python3 - <<PY
from audio_lab_pynq.AudioLabOverlay import AudioLabOverlay
from pynq import PL
ov = AudioLabOverlay(download=True)
print("PL.timestamp:", PL.timestamp)
print("ADC HPF:", ov.codec.get_adc_hpf_state())
print("R19_ADC_CONTROL: 0x{0:02x}".format(
    int(ov.codec.R19_ADC_CONTROL[0]) & 0xff))
PY
  sudo env PYTHONPATH=/home/xilinx/Audio-Lab-PYNQ \
    python3 scripts/pmod_i2s2_mode.py --mode mute
'
```

Confirm all board bit/hwh copies match the baseline md5, then run the
safe structural smoke:

```sh
ssh xilinx@192.168.1.9 '
  md5sum \
    /usr/local/lib/python3.6/dist-packages/audio_lab_pynq/bitstreams/audio_lab.bit \
    /usr/local/lib/python3.6/dist-packages/audio_lab_pynq/bitstreams/audio_lab.hwh
'

ssh xilinx@192.168.1.9 '
  cd /home/xilinx/Audio-Lab-PYNQ &&
  sudo env PYTHONPATH=/home/xilinx/Audio-Lab-PYNQ \
    python3 scripts/diagnose_pmod_loopback.py
'
```

Rollback is complete only when:

- board bit/hwh md5 match the baseline md5 above
- `AudioLabOverlay(download=True)` succeeds
- `ADC HPF` is `True`
- `VERSION` is `0x00480001`
- Pmod I2S2 `MODE_REG` is `3 (mute)`
- self-loopback smoke has no `QUANT!` / `STAIR!` flags
- `CLIP_COUNT` is not increasing abnormally

## Acceptance Record

The D68 global retune was accepted after deploy, self-loopback smoke, and
user-reported external bench checks for all_off bypass plus all existing
Amp / Distortion / Overdrive models. Accepted deployed md5:

```text
cabb9bca3fbcc41f06f8b9fe8301cff1  hw/Pynq-Z2/bitstreams/audio_lab.bit
299485480dcc46aa0c679cef8f1a048a  hw/Pynq-Z2/bitstreams/audio_lab.hwh
```

This document remains the rollback procedure for returning from D68 to
the D67 baseline if the accepted build is later rejected in use.

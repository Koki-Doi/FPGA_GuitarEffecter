# Realism measurement inputs (work order step 2)

Status: **fixed measurement inputs + generator, no DSP change** (2026-06-14).
`REALISM_IMPROVEMENT_WORK_ORDER.md` 結論順 **2. 測定入力を固定** / phase 分割
**1. docs / measurement harness only** に対応。step 1 の
`REALISM_REFERENCE_PRESETS.md` と対で使う。

目的は、以後の realism retune 候補をすべて同じ stimulus で replay でき、入力 level が
記録されていて「音が大きいだけ」を「良い音」と誤認しないようにすること。

## 生成器

`tools/dsp_sim/signals.py`（決定論的、RNG 無し）。各生成器は 24-bit mono int64
（FS24 full-scale、`run_sim` / `measure` と同一規約）を返し、`run_sim.run_dsp` へ
そのまま渡せる。bypass で out==in bit-exact を確認済み（offline knife-edge）。

- WAV 一括書き出し: `python3 tools/dsp_sim/signals.py --dump`
- catalogue 確認: `python3 tools/dsp_sim/signals.py --list`

## 2 つの canonical level（peak / full-scale 比）

実ギターの ADC 入力は ~0.1-0.2。0.85 は clip 段を brick-wall するだけなので使わない。

- `LINEAR = 0.05`: small-signal magnitude probe。Cab / tone-stack / filter の
  シェイプを clip させずに測る。
- `DRIVE = 0.20`: harmonic / clipping probe。OD / Distortion / Amp の transfer
  curve を現実的な入力で測る。

## work order 入力 -> 生成器マップ

| work order の入力 | catalogue 名 | 生成器 | 固定 param | level | 用途 |
| --- | --- | --- | --- | --- | --- |
| 1 kHz sine | `sine_1k` | `sine` | f=1000, 0.25 s | 0.20 | harmonic distortion / transfer curve / gain / clipping |
| 100 Hz sine | `sine_100` | `sine` | f=100, 0.25 s | 0.20 | low-freq tightness / bass clipping / blocking |
| 5 kHz sine | `sine_5k` | `sine` | f=5000, 0.25 s | 0.20 | alias / fizz / HF harshness |
| logarithmic sweep | `sweep_lin` | `log_sweep` | 20 Hz->20 kHz, 2.0 s | 0.05 | Cab / tone-stack / filter magnitude |
| two-tone | `two_tone` | `two_tone` | 1000+1100 Hz, 0.5 s | 0.20 | intermodulation / non-harmonic |
| impulse / click | `impulse` | `impulse` | 1 sample @0.05 s, 0.5 s window | 0.50 | reverb tail / cab ring / echo density |
| decaying sine / plucked | `decay_220` | `decaying_sine` | f=220, tau=0.30 s, 1.5 s | 0.20 | comp release / NS close |

### 生成器で作らない入力（外部 WAV）

faithful に合成できないので固定録音 WAV を `run_sim.py --wav-in <file>` で使い、
ファイル名と level を regression anchor として記録する。

| work order の入力 | 取得方法 | 用途 |
| --- | --- | --- |
| palm-mute phrase | 固定録音 WAV | gate chatter / high-gain low-end tightness |
| short DI guitar phrase | 固定録音 WAV | musical sanity check |

DI phrase に含める要素（work order）: low/high single note、open chord、barred
chord、palm mute、soft pick、hard pick、sustained decay into silence。
合成 fallback が要るなら `run_sim.py::synth_guitar`（plucked harmonic tone、
level 0.12）を使うが、本物の phrase の代用にはしない。

### Wah position sweep（signal ではなく control sweep）

audio 入力は sustained tone（`sine_1k` などの長め版、または `synth_guitar`）を
固定し、Wah の `POSITION` control word を `0/32/64/96/128/160/192/224/255` で
振って各点の出力を測る。POSITION は audio 信号ではなく control 語なので
`signals.py` には含めない（work order step 7 / Wah metrics 参照）。

## 既存 harness との関係

- `measure.py::multitone`（log 26-tone, level 0.05）は bypass 差分の**net 周波数
  シェイピング**専用。Cab / tone-stack の overall shape はこちらが手軽。
  単体 tone の harmonic / IMD / tail を見るときに `signals.py` を使う。
- `run_sim.py` は WAV / synth 入力 + metrics（peak/rms/crest/centroid/clip_count/
  level_stability）。`signals.py` の WAV を `--wav-in` で食わせれば metrics も出る。

## acceptance（step 2）

- 後続候補を全て同じ input で replay できる: catalogue は固定 param。
- board 無しで offline 比較できる: 生成器は numpy のみ、`run_dsp` で完結。
- input level が記録されている: 各入力に LINEAR/DRIVE/0.50 を明記。

## 次工程への申し送り

- step 3（target metrics）: 各 effect family で見る指標を、上記入力ごとに
  どの計算（`measure.py::tone_levels` / `net_curve`、`run_sim.py::metrics`）で
  出すか対応付ける。
- step 4（Cab）前提（step 1 から継続）: `measure.py::build_config("cab")` の
  cab model override 小改修が未実装（Open/Closed を測れない）。

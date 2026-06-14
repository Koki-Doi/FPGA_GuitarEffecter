# Realism Cab measurement + target (work order step 4 / phase 2)

Status: **D121 Cab measured, target gaps documented, NO DSP change**
(2026-06-14). `REALISM_IMPROVEMENT_WORK_ORDER.md` 結論順 **4. Cab を最優先で
詰める** の phase 2（measurement + target documentation）。phase 3（Cab constant /
biquad pass = 実 DSP 変更）は別 turn・rebuild + bench 必須なのでここでは行わない。

step 1 `REALISM_REFERENCE_PRESETS.md` / step 2 `REALISM_MEASUREMENT_INPUTS.md` /
step 3 `REALISM_TARGET_METRICS.md` を使用。

## harness blocker 解消（phase 1 残件）

`tools/dsp_sim/measure.py::build_config` に `cab0` / `cab1` / `cab2` を追加（suffix =
cab model）。従来の `cab` は model 1(British) の alias。これで Open(0) / British(1) /
Closed(2) を個別に測れる（step 1 から継続の blocker を解消）。

再現コマンド（sweep linear 0.05 + multitone net + band readout）は
`docs/ai_context/REALISM_CAB_MEASUREMENT.md` のこの測定スクリプト（コミット履歴参照）。

## D121 実測（変更前 baseline）

bypass 差分。net peak/dip は median 除去の相対 shape（`net_curve`）、
low/presence/rolloff/fizz は bypass 比の band 絶対値（`harmonics.band_energy_db`）、
rms は bypass 比（`run_sim.metrics`）。fs=96 kHz、sweep 20 Hz->20 kHz @0.05。

| model | net peak | net dip | low 20-150 | pres 2-4k | rolloff 5k+ | fizz 8-12k | rms |
| --- | --- | --- | --- | --- | --- | --- | --- |
| Open (1x12) | +3.4 @2806 Hz | -8.5 @9000 Hz | +0.6 | +2.9 | -2.9 | -7.0 | +0.3 |
| British (2x12) | +3.2 @2806 Hz | -10.3 @9000 Hz | +4.3 | +6.5 | -3.7 | -5.0 | +4.0 |
| Closed (4x12) | +3.2 @2806 Hz | -10.3 @9000 Hz | +3.3 | +5.5 | -3.6 | -5.9 | +3.0 |

## target との差分（actionable gaps）

target は `REALISM_REFERENCE_PRESETS.md` Cab 節 / work order step 4。

1. **model separation が弱い（最重要）**: 3 model とも presence peak が同一の
   2806 Hz、peak gain も +3.2..+3.4 でほぼ同じ。差は band tilt（low / presence の
   量）だけ。work order「Open/British/Closed の model separation を強める」に対し、
   peak 中心が共通なので model 差が出ていない。
   - 方向: model ごとに presence center を変える（例 Open やや高め・抜け重視、
     British mid-presence identity、Closed は low-mid body + presence 別位置）。

2. **Closed の fizz 抑制が target と逆**: work order は Closed が 8-12 kHz fizz を
   最も抑える想定だが、実測は Open -7.0 が最強で Closed -5.9 / British -5.0 と
   弱い。Closed の高域 rolloff / fizz cut を強める方向が必要。

3. **高域 rolloff が band edge 止まり**: net dip が 3 model とも 9000 Hz
   （測定上限）= 単調 high cut で distinct notch なし。speaker らしい >5 kHz の
   明確な rolloff は Open -2.9 / British -3.7 / Closed -3.6 と緩め。work order
   「>5 kHz guitar-speaker rolloff を明確に」に対しやや不足。

4. **model 間の loudness 不一致**: British +4.0 / Closed +3.0 / Open +0.3 dB。
   unity preset での output gain（step 4 acceptance）が揃っておらず A/B が
   不公平。phase 3 で level / mix 既存定数で揃える、または step 11 で吸収。

5. **good な点（過剰修正しない）**: presence peak 2806 Hz は 2-4 kHz target 帯域内
   （D121 の cone-breakup presence ~2.8 kHz 設計通り）。low end は Open 緩め
   (+0.6) / British・Closed body あり（+4.3 / +3.3）で方向は合っている。

## phase 3（DSP 変更）= D123 実施: per-model presence biquad

最優先 gap（model separation 弱 = 3 model とも presence peak が共通 2806 Hz）の
**根本原因は cone-breakup presence biquad の係数が全 model 共通だったこと**。
`AudioLab/Effects/Cab.hs` の `cabPresenceFeedforwardFrame` /
`cabPresenceRecursiveFrame` が固定係数（2800 Hz, Q1.0, +3.5 dB）を全 model に適用
していた。これを **per-model 化**（coeff-only mux、既存 biquad 構造内、D122 amp
scoop と同方式）:

| model | RBJ peaking (96 kHz, Q14) | 狙い |
| --- | --- | --- |
| Open 1x12 | 3400 Hz, Q 0.8, +3.0 dB | 明るく/airy、高め・緩い presence |
| British 2x12 | 2800 Hz, Q 1.0, +3.5 dB（**不変**） | mid-forward identity 保持 |
| Closed 4x12 | 2300 Hz, Q 1.2, +4.0 dB | 低く/太い presence honk |

新 helper `cabPresenceFFCoeff` / `cabPresenceFBCoeff`（model = `ctrlC>>6`）。
b1==a1（RBJ peaking）なので na1=-b1。bit-exact bypass 維持（cab off path 不変）。
loudness 不一致・rolloff・Closed fizz は今回 scope 外（work order「1 bitstream に
Cab だけ」方針、step 11 / 後続 pass）。ただし presence center 低下の副次で Closed
rolloff -3.6->-4.2 / fizz -5.9->-6.1 も target 方向へ改善。

### before/after（sweep linear、bypass 差分、`measure.py cab0/1/2`）

| model | net peak (before -> after) | pres 2-4k | 効果 |
| --- | --- | --- | --- |
| Open | +3.4@2806 -> +2.7@2806(実 3400 broad) | +2.9 -> +2.3 | 明るく/緩く |
| British | +3.2@2806 -> +3.2@2806 | +6.5 -> +6.5 | 不変 |
| Closed | +3.2@2806 -> **+3.4@2310** | +5.5 -> +5.8 | **peak 分離・太く** |

offline bypass bit-exact 確認。3 model が peak 周波数/presence 量で識別可能に。

### build / deploy（D123、bench PENDING）

- Clash regen PASS（`make regen` 相当、mtime trap 回避: vhdl + component.xml が M、
  新係数 30865/28637/17087/16837/12274/14834 が VHDL に存在を確認）。
- full Vivado build PASS、route error 0、`write_bitstream completed`。
- timing 完全 MET: **WNS +0.595 / TNS 0 / 0 failing、WHS +0.017 / THS 0**、
  island clk_fpga_1 +2.677、D109 CDC pair clk_fpga_0<->clk +5.610 / +6.508
  （knife-edge bound 健在）。accepted baseline 帯（D112 +0.564 / D122 +0.614）内。
- bit/hwh md5 `7efd41ef6d0b7a88ecd8c54217ad9c23` / `06611bce8a69b5409ff91ba54c531b76`。
- deploy 完了、board 3 site md5 一致、PL smoke PASS（新 bit ロード、ADC HPF True）。
- **bench-ACCEPTED（合格）。`--no-ff` で main にマージ（"Merge D123"）。
  D123（`62d0610`、bit `7efd41ef`）が新 canonical baseline（D122 を supersede）。**

bench checklist（Cab 中心）: Safe Bypass clean、Cab only で Open/British/Closed の
presence 差が聞こえるか、Closed が低めの太い presence、Open が明るい、high-gain
through Cab の fizz、他 effect 不変。rollback は `git checkout d07c8e9 --
hw/Pynq-Z2/bitstreams/`（D122 `1a295b8b`）+ redeploy。

## acceptance（step 4）

- phase 2: D121/D122 Cab 3 model が変更前 baseline として数値固定。
- phase 3（D123）: per-model presence biquad で model separation を作成、sim A/B +
  timing-clean build + deploy + PL-smoke 済み。**ear-bench 待ち**。

## 次工程

- ユーザ ear-bench → accepted なら `CURRENT_STATE.md` / `DECISIONS.md` を D123 で更新、
  rejected なら上記 rollback。
- bench 後、Cab の残 gap（loudness unity・rolloff・Closed fizz）を別 pass にするか、
  step 5（Overdrive measurement）へ進む。

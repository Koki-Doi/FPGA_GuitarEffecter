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

## phase 3（DSP 変更）候補メモ — 未実施

`hw/ip/clash/src/LowPassFir.hs`（cab biquad / presence / body / air / softClip
定数）を触る pass。次が候補だが、**rebuild + timing + bench acceptance が必須**で
本 turn では行わない:

- model 別 presence center をずらして separation を作る（biquad coeff、model mux）。
- Closed の 8-12 kHz fizz cut を強める（air / HF shelf 定数）。
- >5 kHz rolloff を全 model でやや急に。
- 3 model の rms を unity 付近へ（level / mix 既存定数のみで）。

修正タイプ分類（work order step 4-3）: 1/2/4 は peak/notch/shelf = biquad、
3 は既存 air/shelf 定数、broad speaker texture が要るなら FIR/IR（license 明確な
もののみ）。1 bitstream に Cab だけ載せ、drive/dynamics/amp と混ぜない。

## acceptance（step 4 phase 2）

- D121 Cab 3 model が変更前 baseline として数値固定された。
- target との差分（separation 弱・Closed fizz 逆・rolloff 緩・loudness 不一致）が
  明文化され、phase 3 の修正対象が biquad / 定数 / FIR に分類された。
- phase 3（実 DSP 変更）は未着手。rebuild + bench はユーザ判断で別 turn。

## 次工程

- phase 3 に進むなら: 上記候補を 1 つずつ `tools/dsp_sim` で A/B → 良ければ
  Vivado rebuild → timing → deploy → bench。ユーザ承認が前提。
- phase 3 を保留して step 5（Overdrive measurement）へ進むのも可（DSP 非変更で
  継続できる measurement 工程）。

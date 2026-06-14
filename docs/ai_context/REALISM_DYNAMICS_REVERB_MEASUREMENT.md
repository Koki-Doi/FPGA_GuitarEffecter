# Realism Wah / Compressor / NS / Reverb / loudness survey (work order steps 7-11)

Status: **measurement survey on the D124 baseline; only Compressor needs a DSP
fix, no DSP change yet** (2026-06-14). `REALISM_IMPROVEMENT_WORK_ORDER.md`
結論順 7 (Wah) / 8 (Compressor) / 9 (Noise Suppressor) / 10 (Reverb) /
11 (preset loudness)。step 1-3 scaffold + `tools/dsp_sim` を使用。

## サマリ

| step | family | 測定結論 | アクション |
| --- | --- | --- | --- |
| 7 | Wah | on-target | 変更不要 |
| 8 | Compressor | **RATIO knob ほぼ無効 + 圧縮が浅い** | **DSP 修正候補（次の bench cycle）** |
| 9 | Noise Suppressor | on-target（close する / chatter なし） | 変更不要 |
| 10 | Reverb | offline 測定不適（timeout / impulse 過小）→ 耳判断 | dedicated bench pass |
| 11 | preset loudness | 全 effect 確定後の最終工程 | 保留 |

## step 7 Wah — on-target

`POSITION` sweep（Q50/VOL50/BIAS50）、multitone net 曲線の resonant peak:

| POS | peak freq | peak gain | Q |
| --- | --- | --- | --- |
| 0 (heel) | 466 Hz | +8.0 dB | 2.2 |
| 25 | 738 Hz | +8.5 | 3.2 |
| 50 | 1170 Hz | +9.2 | 3.2 |
| 75 | 1591 Hz | +10.0 | 3.2 |
| 100 (toe) | 2164 Hz | +11.1 | 4.2 |

sweep 466->2164 Hz は実機 Cry Baby（~450 Hz->~2.2 kHz）とほぼ一致、Q~3（vocal）、
taper は滑らかな指数的、gain 変動 3 dB のみ。target どおりで変更不要。

## step 8 Compressor — RATIO 無効（要修正）

1 kHz sine の input level sweep、in->out RMS（th40/ra70/re50/mk50）:

| in dBFS | out dBFS | gain change |
| --- | --- | --- |
| -29 | -29.0 | 0.0 |
| -23 | -23.1 | -0.1（閾値付近） |
| -17 | -17.4 | -0.5 |
| -11 | -12.2 | -1.2 |
| -6 | -8.7 | -2.6 |

閾値 ~-23 dBFS、gain reduction は level とともに増える（方向は正しい）が **最大でも
~2.6 dB と非常に浅い**。RATIO 比較（in=-17, th40）:

| ratio | 10 | 25 | 45 | 70 | 90 |
| --- | --- | --- | --- | --- | --- |
| GR | -0.1 | -0.2 | -0.3 | -0.5 | -0.6 |

**RATIO を全域振っても GR が -0.1〜-0.6 dB しか変わらない = ほぼ無効。** work order
step 8「RATIO の変化が分かりやすいか」が失敗。guitar comp（Dyna/Ross sustain）
としても squash/sustain が不足。

**修正方針（DSP、`AudioLab/Effects/Compressor.hs`、未実施）**: gain computer で
RATIO が実効的に gain reduction の傾きを決めるようにし、より深い圧縮レンジを許す。
まず target identity（Dyna/Ross sustain か transparent leveler か）を決める。
rebuild + bench が必要 → 次の bench cycle。release / pumping は time-domain
analyzer を足して別途確認。

## step 9 Noise Suppressor — on-target

decaying note（220 Hz, tau 0.30）に NS High-Gain-Tight（th55/de20/da90, gate on）:

- bypass tail end 1.48 s → NS tail end **0.84 s**（gate が tail を truncate）。
- chatter（-50 dB 交差数）: bypass 1 / NS 1 = **chatter なし**。

close する・tail を切る・chatter しない = 健全な gate 動作。変更不要。
（より詳細な open/close hysteresis / hold time は必要時に gate-timing analyzer 追加。）

## step 10 Reverb — offline 測定不適、耳判断

2 s impulse 経由は long-decay 設定で sim timeout（192k サンプル × feedback taps）、
かつ single-sample impulse は energy 過小（peak -47 dBFS、-60 まで 0.07 s しか
測れない）。reverb の realism 項目（initial reflection / echo density / metallic
ringing / boingy / HF damping）は本質的に **耳判断**が適切。offline harness を使うなら
短い tone burst + Schroeder EDC 専用 analyzer が要るが、優先度は bench での
subjective 評価。work order でも Reverb は dry chain 安定後の後工程。

## step 11 preset loudness — 保留

`Safe Bypass / Clean / Crunch / High Gain / Ambient / Solo` の RMS/peak/crest を
揃える最終工程。全 effect（特に Compressor / Reverb）が確定してから。先に揃えても
やり直しになる（work order step 11 の前提）。

## acceptance（steps 7-11 survey）

- Wah / NS は実機どおり on-target = 過剰修正しない。
- Compressor の RATIO 無効 = 唯一の明確な offline-measurable 修正候補。
- Reverb / loudness は耳 / 全chain依存で後工程。

## 次工程

- 次の bench cycle 候補: **Compressor RATIO を実効化**（`Compressor.hs`、rebuild + bench）。
- その後 Reverb を耳ベースで dedicated pass、最後に preset loudness。
- user メモ: 完成度はまだ低く、反復修正前提。

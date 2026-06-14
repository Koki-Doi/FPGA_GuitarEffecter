# Realism OD / Distortion measurement + RAT fix (work order steps 5 & 6)

Status: **measured all OD + Dist models; only RAT was off (fixed = D124, bench
PENDING)** (2026-06-14). `REALISM_IMPROVEMENT_WORK_ORDER.md` 結論順 **5. Overdrive**
+ **6. Distortion / Fuzz**。step 1-3 の scaffold（`REALISM_REFERENCE_PRESETS.md` /
`REALISM_MEASUREMENT_INPUTS.md` / `REALISM_TARGET_METRICS.md` +
`tools/dsp_sim/{signals,harmonics}.py`）を使用。

## 測定方法

`sine_1k` @ DRIVE(0.20) を各モデルの固定 drive point で入れ、`harmonic_profile`
（THD / odd-even / h2/h3/h5 / alias）+ `metrics`（rms / clip）。周波数シェイプは
`measure.py` の multitone net 曲線（peak/dip/tilt）。

## 結果（D123 baseline、変更前）

### Overdrive（step 5）— 全 on-target、変更不要

| model | drive | THD | odd/even | net peak | target | 判定 |
| --- | --- | --- | --- | --- | --- | --- |
| TS9 | 60 | 24.3% | +18.9 | +5.3@720 | mid hump ~720, low-cut | OK |
| OD-1 | 60 | 20.9% | +6.8 | flat | asym (even harm), mild | OK（even 多め=asym） |
| BD-2 | 60 | 22.9% | +9.9 | +3.0@2310 | brighter, dynamic | OK（D121） |
| Jan Ray | 45 | 0.0%→11.7%@max | - | flat | transparent, flat-ish | OK（低 gain、drive で歪む） |
| OCD | 65 | 19.5% | +6.8 | +3.7@1290 | harder knee, upper-mid honk | OK（D121） |
| Centaur/Klon | 60 | 3.1% | +10.3 | flat | clean-blend, transparent | OK（透明） |

Jan Ray は drive 45 で THD 0% だが、drive を上げると 4.6%(70) / 9.8%(90) /
11.7%(max) と歪む = 低 gain transparent OD で **仕様どおり**（RAT のような
「max でも 0%」のバグではない）。Klon も全 drive ~3% で透明（仕様どおり）。

### Distortion / Fuzz（step 6）— RAT 以外 on-target

| model | drive | THD | net | target | 判定 |
| --- | --- | --- | --- | --- | --- |
| clean_boost | 50 | 0.0% | flat | mostly flat boost | OK（設計上 clean） |
| TubeScreamer | 60 | 19.6% | +6.9@720, low-cut | mid hump, low-cut | OK |
| DS-1 | 65 | 21.9% | bright + HPF | scooped-ish, aggressive | OK |
| Big Muff | 70 | 55.9% | scoop@720 + bass | deep mid scoop | OK |
| Fuzz Face | 70 | 23.7% | warm/dark | warm, rounded, dynamic | OK |
| Metal | 70 | 59.5% | +8.2@2806, scoop | scooped, very bright | OK（D121） |
| **RAT** | 55 | **0.0%（最大 drive でも 0%）** | +8.5@4138, tilt +24.6 | mid-forward, filter rolloff, gritty | **NG → D124 で修正** |

## RAT のバグと修正（D124）

### 根本原因

`ratHighpassFrame` の `onePoleHighpass 511 9` は precedence で
`prevOut * (511>>9) = prevOut*0` となり帰還極が死ぬ → **first-difference
(x − prevIn)**。これは 1 kHz を約 −24 dB 減衰（|H|=2·sin(π·1000/96000)≈0.065）させ、
drive + hard clip に届く信号が極小。結果、**RAT は drive 55〜127 のどこでも THD
0.0% = 全く歪まない**（net 曲線の +24.6 tilt は clean 信号を EQ してるだけ）。
memory `project_amp_rat_hp_dead_pole` の RAT dead-pole 事象。

### 修正

`ratHighpassFrame` 局所に live one-pole highpass をインライン展開（正しい
precedence `(prevOut*507)>>9`、coef 507/512 = 0.9902 ≈ 150 Hz）。**共有
`onePoleHighpass` とその他（意図的 dead-pole）caller は不変** — RAT の極だけ live 化。

### 効果（sim A/B、drive 55）

| 指標 | 修正前 | 修正後 |
| --- | --- | --- |
| THD | 0.0%（max でも 0） | 17%(drv30) → 24%(55) → 26%(85) |
| odd/even | -1.0 | +77（強 odd-dominant = op-amp+diode hard clip） |
| rms | -28.4（最低） | -12.2（他 dist と同水準） |
| net peak | +8.5@4138（harsh bright） | +1.8@**720Hz**（mid-forward） |
| FILTER 0/50/100 tilt | - | -5.3 / -10.0 / -39.3（FILTER が treble rolloff として機能） |

修正後は target "mid-forward, filter rolloff, gritty" に合致。FILTER=0 で明るさも
保持（work order「RAT の明るさは潰しすぎない」充足）。bypass bit-exact。

### build / deploy（D124、bench PENDING）

- Rat.hs のみ変更（他 effect 不変）。Clash regen PASS（mtime trap 回避、coef 507
  が VHDL に存在）。full Vivado build PASS、route error 0、`write_bitstream completed`。
- timing 完全 MET: **WNS +0.619 / 0 failing、WHS +0.008**、island clk_fpga_1 +2.449、
  D109 CDC pair clk_fpga_0<->clk +5.683/+6.359（knife-edge bound 健在）。
  accepted 帯（D122 +0.614）内。
- bit/hwh md5 `3367d0e3f86fdb5d8b5d501be1c71995` / `3b24f3f2fa4e8aa2ffc1530e80c4484d`。
- deploy 完了、board 2 site md5 一致、PL smoke PASS（bit ロード、ADC HPF True）。
- **ear-bench 未。RAT は音色変更なので実機確認が必須。D123 `7efd41ef` が bench-approved
  まで canonical baseline。** branch `feature/rat-highpass-fix`。rollback は
  `git checkout <D123> -- hw/Pynq-Z2/bitstreams/` + redeploy。

bench checklist: Safe Bypass clean、**RAT を選んで実際に歪む/gritty か**（従来は
clean だった）、FILTER knob で treble が変わるか、mid-forward か、明るさが残るか、
他 dist/OD/amp/cab 不変。

## acceptance（steps 5 & 6）

- OD 6 + Dist 7 全モデルを測定し target と照合。
- 唯一の破綻（RAT が全く歪まない dead-pole HP）を特定し D124 で局所修正。
- 他は実機性格どおり on-target = 過剰修正せず（work order 方針）。
- D124 は build/deploy/PL-smoke 済み、**ear-bench 待ち**。

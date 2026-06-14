# Realism target metrics (work order step 3)

Status: **metrics fixed to computations; harmonic analyzer added, no DSP change**
(2026-06-14). `REALISM_IMPROVEMENT_WORK_ORDER.md` 結論順 **3. target metrics を
先に決める** / phase 分割 **1. docs / measurement harness only**。step 1
`REALISM_REFERENCE_PRESETS.md` / step 2 `REALISM_MEASUREMENT_INPUTS.md` と対。

目的は、各 effect family で見る指標を**先に**固定し、どの harness 計算で出すかを
紐づけること。耳だけで係数を触ると後から判断が揺れる。各 retune は明確な target と
before/after measurement を持つ。

## 計算の在処（measurement primitives）

| primitive | 出力 | 入力 |
| --- | --- | --- |
| `measure.py::net_curve` / `--batch` | bypass 差分の net 周波数シェイピング、peak/dip@freq、tilt | multitone（log 26-tone, 0.05） |
| `measure.py::tone_levels` | 指定周波数の FFT bin 振幅 | 任意 |
| `run_sim.py::metrics` | peak_dBFS / rms_dBFS / crest_dB / level_stability_std_dB（pumping proxy）/ centroid_Hz / clip_count | 任意出力 |
| `harmonics.py::harmonic_profile` | fundamental_dBFS / h2..h8(dB rel fund) / thd_pct / odd_even_ratio_dB / harmonic_energy_dBFS / nonharmonic_dBFS（alias・IMD proxy） | `signals.sine` 単音 |
| `harmonics.py::band_energy_db(lo,hi)` | 帯域積分エネルギー dBFS | 任意出力 |

`harmonics.py` は step 3 で追加した（OD/Dist の harmonic 指標が既存 harness に
無かったため）。純 numpy 解析で sim 非依存に検証済み: clean=THD~0、hardclip=
odd 支配、asym=even 出現。sim 経由で TS9=odd soft clip / DS-1 aggressive /
Big Muff THD 55.9% odd-dominant を確認。

## family 別 metric -> 計算マップ

### Cab（step 4、計算は全て既存）

| metric | 計算 | 入力 |
| --- | --- | --- |
| low bump 量 / 中心帯域 | `net_curve` peak + `band_energy_db(20,150)` | sweep_lin / multitone |
| 2-4 kHz presence peak | `band_energy_db(2000,4000)`、`net_curve` peak | sweep_lin |
| >5 kHz rolloff | `band_energy_db(5000,9000)` vs `(800,1200)` | sweep_lin |
| 8-12 kHz fizz suppression | `band_energy_db(8000,12000)` | sweep_lin |
| unity preset output gain | `metrics.rms_dBFS` vs bypass | sweep_lin / sine_1k |

### OD / Distortion（step 5/6、計算は全て既存）

固定 drive point（`REALISM_REFERENCE_PRESETS.md`）で `sine_1k` を入れる:

| metric | 計算 |
| --- | --- |
| fundamental gain | `harmonic_profile.fundamental_dBFS` |
| 2nd / 3rd / 5th harmonic | `harmonic_profile.h2_dB / h3_dB / h5_dB` |
| odd / even ratio | `harmonic_profile.odd_even_ratio_dB` |
| RMS / peak | `metrics.rms_dBFS / peak_dBFS` |
| clip_count / saturation | `metrics.clip_count` |
| alias / non-harmonic energy | `harmonic_profile.nonharmonic_dBFS`（+ `sine_5k` で高域 alias） |

sweep（`net_curve`）で: low cut / bass tightness、mid hump/scoop center freq、
tone-knob range、HF rolloff。

### Wah（step 7、**要追加**）

| metric | 計算 | 状態 |
| --- | --- | --- |
| peak frequency / gain | POSITION ごとの sweep_lin の `net_curve` peak | net_curve で可 |
| Q / bandwidth | -3 dB 幅推定（peak 周辺） | **gap: peak/Q estimator 未実装** |
| output RMS | `metrics.rms_dBFS` | 既存 |
| toe harshness / heel dullness | toe/heel position の `band_energy_db` 高域/低域 | band で可 |
| pedal taper smoothness | peak-freq vs POSITION の連続性（1 階差分） | **gap: estimator 後** |

入力は sustained tone を固定し POSITION control word を `0/32/.../255` で振る
（`REALISM_MEASUREMENT_INPUTS.md` Wah sweep 節）。

### Compressor（step 8、**要追加**）

| metric | 計算 | 状態 |
| --- | --- | --- |
| input-output gain curve | 複数入力 level の `metrics.rms_dBFS` | **gap: level-sweep helper 未実装** |
| threshold / ratio | gain curve からの推定 | gap（curve 後） |
| peak reduction / RMS change | `metrics` diff vs bypass | 既存 |
| transient preservation | `metrics.crest_dB` diff | 既存 |
| release recovery time | `decay_220` の envelope follower | **gap: envelope/release estimator 未実装** |
| pumping on sustained chords | `metrics.level_stability_std_dB` | 既存 |

### Noise Suppressor（step 9、**要追加**）

| metric | 計算 | 状態 |
| --- | --- | --- |
| open / close threshold、hysteresis | `decay_220` の振幅 vs gate 出力 | **gap: gate-timing analysis 未実装** |
| close time / tail truncation | decay envelope の閾値到達点 | gap |
| chatter count | near-threshold 出力の on/off エッジ数 | gap |
| high-gain hiss reduction | silence 区間の `metrics.rms_dBFS` | 既存 |

### Reverb（step 10、**要追加**）

| metric | 計算 | 状態 |
| --- | --- | --- |
| initial reflection / echo density | `impulse` 出力の早期エネルギー分布 | **gap: EDC / Schroeder 未実装** |
| decay time（DECAY 別） | Schroeder energy-decay curve（RT60 推定） | gap |
| HF damping | `impulse` 出力の帯域別 decay（`band_energy_db` を時間窓で） | gap |
| metallic ringing / LF buildup | spectrum の sharp peak / 低域積分 | 一部既存（band） |
| wet/dry law（MIX 別） | MIX sweep の wet/dry `metrics.rms_dBFS` | 既存（sweep 運用） |

### Preset loudness（step 11、ほぼ既存）

| metric | 計算 |
| --- | --- |
| RMS / loudness proxy | `metrics.rms_dBFS`（必要なら A-weight 近似を後付け） |
| peak / crest factor | `metrics.peak_dBFS / crest_dB` |
| required output trim | preset 間 rms 差から導出 |

## acceptance（step 3）

- 後続 retune に明確な target（family 別 metric）と before/after 計算がある。
- 「大きいから良い」と「実機らしさが増した」を分離: harmonic / band / net 曲線で
  level と shape を分けて読む。

## 即着手可能 / 要追加の切り分け

- **即着手可（計算済み）**: Cab(step4)、OD(step5)、Distortion(step6)、
  preset loudness(step11) は既存 + `harmonics.py` で全 metric が出る。
- **当該 phase で要追加**: Wah peak/Q estimator(step7)、Compressor gain-curve +
  release estimator(step8)、NS gate-timing analysis(step9)、Reverb EDC/RT60(step10)。
  各 phase 着手時に小 helper を足す（前倒し実装しない）。

## 次工程への申し送り

- step 4（Cab）: 上記計算で D121 Cab 3 model を測れるが、
  `measure.py::build_config("cab")` が model=1 固定で Open(0)/Closed(2) を選べない
  小改修が未実装（step 1 から継続の blocker）。Cab phase 着手時に cab model 引数を足す。

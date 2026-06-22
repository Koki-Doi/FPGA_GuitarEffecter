# Realism reference presets (work order step 1)

Status: **fixed reference presets, no DSP change** (2026-06-14).
`REALISM_IMPROVEMENT_WORK_ORDER.md` の結論順 **1. 比較用の基準プリセットを固定** /
phase 分割 **1. docs / measurement harness only** に対応する成果物。

目的は、以後の realism retune を replay できる固定基準を 1 か所に置くこと。
測定しながら knob を動かすと、DSP 変更の影響か設定変更の影響か分からなくなる。
ここで category ごとに基準を固定し、offline harness の config 名と on-board の
model index / pedal mask / knob 値を紐づける。

権威ある値の所在:

- 単体 effect 測定設定: `tools/dsp_sim/measure.py`（`BATCH` の drive point と
  `build_config` の tone/level=50/50）。`net_curve` は bypass 差分の周波数
  シェイピングを返す。
- full-chain preset の knob 値: `audio_lab_pynq/effect_presets.py` の
  `CHAIN_PRESETS`（`apply_chain_preset` がそのまま適用）。
- GUI knob デフォルト / model 表: `GUI/compact_v2/knobs.py`。

このドキュメントは値を複製せず、上記を **pin**（名前・index で固定参照）する。
数値を直接書くのは、harness にまだ config が無い単体基準だけ。

## 共通の測定条件（reference preset 作成時 baseline は D121、現行 baseline は D155）

- reference preset は D121 作成時に固定した anchor だが、現行 canonical deployed
  voicing baseline は **D155**（`09c8a95`、D153 を supersede）。値の pin は比較
  条件として維持し、実装状態は `CURRENT_STATE.md` / `BASELINES.md` を見る。
- 単体 effect 基準は対象 effect 以外を bypass し、`build_config` の `_base`
  （gate off、他段 neutral）を起点にする。
- 単体 net 曲線は `tone=50 / level=50` 固定、drive は下表（`BATCH` 由来）。
- offline replay コマンド:
  - 全体サマリ: `python3 tools/dsp_sim/measure.py --batch`
  - 単体曲線: `python3 tools/dsp_sim/measure.py --config <config> --drive <n>`
- fs = 96 kHz（D98）。harness 既定の `--fs 96000`、`gap=32` を変えない。

## Cab 基準（最優先カテゴリ / 3 model）

model index は `knobs.py::CAB_MODELS`。単体基準は `mix=100 / level=100 / air=50`
（`build_config("cab")` と同じ）、cab 以外 off。

| 基準名 | model idx | offline config | on-board (cab section) | target curve（要約） |
| --- | --- | --- | --- | --- |
| Cab Open | 0 = 1x12 OPEN BACK | `cab`（要 model override, 下記） | `model=0, mix=100, level=100, air=50` | low 緩め / low-mid 過多にしない / 高域 rolloff 滑らか |
| Cab British | 1 = 2x12 BRITISH | `cab`（現状そのまま）| `model=1, mix=100, level=100, air=50` | mid / presence identity 強め / top 制御 |
| Cab Closed | 2 = 4x12 CLOSED | `cab`（要 model override, 下記） | `model=2, mix=100, level=100, air=50` | low-mid body 強め / 3-4 kHz presence / 8-12 kHz fizz 抑制 |

**harness gap（Cab phase の前提）**: `measure.py::build_config("cab")` は
`model=1`（British）固定で、Open(0) / Closed(2) を測れない。Cab を詰める
phase（work order step 4）に入る前に、`build_config` へ cab model 引数を
追加する小改修が必要。step 1 では実装しない。flag のみ。

## Overdrive 基準（4+2 model）

model index は `knobs.py::OVERDRIVE_MODELS`。単体 net は `tone=50 / level=50`、
drive は `BATCH` の point。od 以外 off。

| 基準名 | model idx | offline config | drive | target shape（measure.py 記載） |
| --- | --- | --- | --- | --- |
| TS9 | 0 = Ibanez / TS9 | `od_0` | 60 | mid hump ~720 Hz, input low-cut |
| BD-2 | 2 = BOSS / BD-2 | `od_2` | 60 | brighter, dynamic（D121 で約 2.31 kHz peak へ補正済み） |
| OCD | 4 = Fulltone / OCD | `od_4` | 65 | harder knee, upper-mid honk ~1.3 kHz（D121 追加） |
| Centaur | 5 = CENTAUR | `od_5` | 60 | clean-blend, transparent |
| （副）OD-1 | 1 = BOSS / OD-1 | `od_1` | 60 | asym (even harm), mild |
| （副）Jan Ray | 3 = Vemuram / Jan Ray | `od_3` | 45 | transparent, flat-ish, low-mid warmth |

## Distortion / Fuzz 基準（5 model）

pedal bit は `measure.py::PEDAL_BIT`（GUI 名は `knobs.py::DIST_MODELS`）。
RAT は pedalboard slot が DSP no-op、実体は専用 RAT 段（config `rat_fx`）。
単体 net は `tone=50 / level=50`、drive は `BATCH` point。distortion / rat 以外 off。

| 基準名 | pedal / stage | offline config | drive | target shape |
| --- | --- | --- | --- | --- |
| RAT | 専用 RAT 段 | `rat_fx` | 55 | mid-forward, filter rolloff, gritty（明るさ＝RAT らしさ、潰さない） |
| DS-1 | pedal bit 3 = ds1 | `ds1` | 65 | scooped-ish, aggressive, HPF in |
| Big Muff | pedal bit 4 = big_muff | `big_muff` | 70 | deep mid scoop, bass+treble |
| Metal | pedal bit 6 = metal | `metal` | 70 | scooped mids, very bright, high gain（D121 で Big Muff scoop path 共有） |
| Fuzz Face | pedal bit 5 = fuzz_face | `fuzz_face` | 70 | warm, rounded, dynamic bias |

## Amp 基準（6 model、reassessment 順）

model index は `knobs.py::AMP_MODELS`。単体は clean 測定＝drive 0、
`build_config("amp_*")` が `input_gain=18 / master=60 / presence=45 / resonance=35`、
tone-stack `50/50/50`、`drive_mode=0`。amp 以外 off。

| 基準名 | model idx | offline config | target shape |
| --- | --- | --- | --- |
| JC-120 | 0 | `amp_0` | clean SS, flat-ish（power-sag exempt） |
| JCM800 | 4 | `amp_4` | mid push ~650 Hz, bite |
| AC30 | 2 | `amp_2` | chime peak ~2-3 kHz, upper-mid |
| Twin | 1 | `amp_1` | glassy clean, slight scoop |
| Rockerverb | 3 | `amp_3` | thick low-mid, dark |
| TriAmp | 5 | `amp_5` | modern scoop ~750 Hz, tight |

Amp は work order step 12（最後）。bench rejection 履歴が重く、programmatic smoke
だけで accepted にしない。step 1 では基準を固定するだけ。

## Full-chain 基準（6 preset）

権威ある knob 値は `effect_presets.py::CHAIN_PRESETS`。work order の総称 ->
実 preset key を pin する（値は複製しない / drift 防止）。

| 総称（work order） | CHAIN_PRESETS key | 備考 |
| --- | --- | --- |
| Safe Bypass | `"Safe Bypass"` | 全 effect off、各 param neutral。panic 基準 |
| Clean | `"Basic Clean"` | comp 弱 + amp clean + cab Open + 軽 reverb |
| Crunch | `"Light Crunch"` | OD on(drive 41) + amp crunch + cab Open |
| High Gain | `"Noise Controlled High Gain"` | metal + NS + cab Closed |
| Ambient | `"Ambient Clean"` | clean + EQ + reverb mix 55 |
| Solo | `"Solo Boost"` | TS + comp sustain + reverb（意図的に大きめ可） |

full-chain は board 上で `apply_chain_preset(<key>)` を適用、または GUI/encoder/
footswitch から同名 preset を呼ぶ。offline では各段の control word を
`effect_presets.py` の値から組んで `run_sim.py` に渡す（preset 一括 replay は
未実装、必要なら別途）。

## acceptance（step 1）

- 後で同じ measurement run を再現できる: 単体は `measure.py --config/--drive`、
  full-chain は `CHAIN_PRESETS` key で固定済み。
- preset 名 / model index / pedal bit / knob 値が regression anchor として
  この 1 ファイルから辿れる。
- chat history を読まずに測定条件が分かる。

## 次工程への申し送り

- step 2（測定入力固定）: `measure.py` は multitone net 曲線、`run_sim.py` は
  WAV / synth。work order の入力一覧（1k/100/5k sine、log sweep、two-tone、
  impulse、decay、palm-mute、DI phrase、Wah sweep）をどの harness 入口で
  出すか、次ターンで対応付ける。
- step 4（Cab）前提: 上記 `build_config("cab")` の model override 小改修が必須。
- DSP に触れる phase は build / deploy / bench を都度分け、Cab/drive/dynamics/
  ambience/Amp を 1 bitstream にまとめない（work order 末尾の保守ルール）。

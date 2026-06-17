# Audio-Lab-PYNQ 技術詳細 (5/5) — リファレンス

> [PORTFOLIO.md](../PORTFOLIO.md) の深掘り技術付録。リポジトリ構成・用語集・現状を扱う。

## 20. リポジトリ構成

```
Audio-Lab-PYNQ/
├── hw/                         FPGA ハードウェア
│   ├── Pynq-Z2/                ブロックデザイン + 加算式 integration.tcl 群 + XDC
│   │   ├── block_design.tcl        ★編集禁止のベース BD
│   │   ├── *_integration.tcl       pmod / wah / xadc / footswitch / island / hdmi / encoder
│   │   ├── audio_lab.xdc            制約（D109 の CDC ハードニングを含む）
│   │   └── bitstreams/             .bit / .hwh
│   └── ip/
│       ├── clash/src/              ★ DSP の唯一の真実（Clash/Haskell）
│       │   ├── LowPassFir.hs           Vivado 可視の薄い top module
│       │   └── AudioLab/
│       │       ├── Types / FixedPoint / Control / Axis / Pipeline.hs
│       │       └── Effects/            Amp / Cab / Compressor / Distortion /
│       │                               Eq / NoiseSuppressor / Overdrive / Reverb / Wah.hs
│       └── pmod_i2s2/src/          pmod_i2s2_master.v / axi_pmod_i2s2_status.v
├── audio_lab_pynq/             Python / PYNQ 制御層（19 モジュール）
│   ├── (AudioLabOverlay, encoder_effect_apply, hdmi_backend, footswitch_*, ...)
│   ├── hdmi_state/             エフェクト別ステートミラー
│   └── notebooks/              実機ランタイム Notebook（15 種）
├── GUI/                        コンパクト v2 800×480 レンダラ
│   └── compact_v2/             knobs / state / layout / renderer / hit_test.py
├── scripts/                    デプロイ / スモーク / テスト（29 本）
├── tests/                      pytest
├── tools/
│   └── dsp_sim/                Clash topEntity offline sim / measure.py / golden 測定
└── docs/                       本書 + docs/ai_context/（設計・決定記録）
```

中核の Clash ソースが「DSP 挙動の唯一の真実」、`docs/ai_context/` が「設計・決定の唯一の真実」
という二本柱で、セッションをまたいでも一貫した開発ができる構成にしています。実機ランタイムは
用途別に Notebook（`PmodI2S2EffectControlOneCell` / `HdmiGui` / `EncoderGuiSmoke` など）として
提供します。D104/D115 以降は `Amp` / `Distortion` / overlay writer / GUI renderer も小さな
submodule へ分割されており、ポートフォリオで見るべき top-level は「shim」ではなく、その下の
所有 module です。

## 21. 用語集

| 用語 | 意味 |
| --- | --- |
| **PL / PS** | Programmable Logic（FPGA ファブリック）/ Processing System（ARM コア） |
| **Clash** | Haskell ベースの関数型 HDL。型安全な回路記述から VHDL を生成 |
| **WNS / WHS / TNS** | Worst Negative Slack（最悪セットアップ余裕）/ Worst Hold Slack / Total NS。タイミング指標 |
| **CDC** | Clock Domain Crossing。異クロック間の信号渡り。未タイミングだと配置依存で壊れる |
| **アイランド** | DSP コアだけを隔離した低速クロックドメイン（FCLK_CLK1） |
| **safe-bypass / all_off** | 全エフェクト OFF のバイパス経路。ビット完全一致でなければ「壊れている」 |
| **ear-bench** | 実機試聴による受け入れ判定（合格＝採用ベースライン昇格） |
| **offline DSP sim** | `tools/dsp_sim` で Clash `topEntity` を host CPU 上で実行する検証経路。Vivado 前に tone-curve / golden / bypass を見る |
| **golden regression** | 代表設定の出力を保存し、意図しない DSP 変更でズレないかを見る回帰検査 |
| **net tone-curve** | effect ON と bypass の周波数応答差。D121-D131 の測定駆動 voicing で使用 |
| **ペダルマスク** | ディストーション段を mux ではなくビットマスクで選択する方式 |
| **知見（knee）** | クリップ関数が効き始める振幅しきい値。`Sample` の絶対値（例 2,850,000） |
| **RBJ** | Robert Bristow-Johnson のオーディオ EQ Cookbook。バイカッド係数設計の標準 |
| **SVF** | State Variable Filter。Wah のレゾナントバンドパスに使用 |
| **Pmod I2S2** | Digilent の I2S オーディオモジュール（CS5343 ADC + CS4344 DAC） |
| **複数コピー先同期** | bit/hwh をボード上の必要コピー場所すべてに md5 一致させるデプロイ規律 |
| **ナイフエッジ** | 「DSP 再ビルドのたびにバイパスが壊れる」未タイミング CDC 由来の現象（D109 で解決） |
| **D99** | D120 rollback 後にユーザーが選んだ Amp character の基準。D121 はこの Amp を触らず非 Amp だけ補正 |
| **D121** | 最初の measured non-Amp voicing baseline。bit md5 `9a57c50a...`、D99 Amp untouched + non-Amp measured voicing |
| **D131** | 現行 canonical deployed baseline。bit md5 `fdab62d5...`、DIST low-end + saturation/sustain + offline distortion-eval tooling |

## 22. 現状

採用済みデプロイベースラインは **D131**（merge commit `37114b9`、bit md5
`fdab62d5ef229ec64dc60fe9395cbf06`、hwh md5 `d852ec4e737460ad016b41f0a3f71de2`）。
2026-06-15 に build / timing / deploy / PL smoke / user bench を通過し、main へ `--no-ff`
merge されています。

D131 の位置づけ：

- D109 の CDC hardening により、DSP 再ビルド時の safe-bypass 破壊リスクを根本対策済み。
- D120 の Amp sag/static-trim 路線は bench rejected され、D121 で D99 系 Amp character へ rollback
  したあと、D122/D128/D130 の table/coeff 限定 Amp pass だけを accepted line として採用。
- D131 は DS-1 / Big Muff / Fuzz Face / Metal の low-end、saturation、sustain を補正し、
  `dist_eval.py` / `targets.py` で distortion-character と real-hardware target を自動評価。
- Vivado routed timing は WNS `+0.631 ns`、WHS `+0.019 ns`、route errors `0`。
- D109 CDC pair は `clk_fpga_0 -> clk = +3.353 ns` / `clk -> clk_fpga_0 = +6.286 ns`。

D113-D120 の amp-retune / sag-disable / static-trim 系は、履歴上の候補または rejected branch として
扱い、現行値としては語りません。後で問題が出た場合の直近 rollback は D130 bitstreams を
`fffa2b1` から復元（bit md5 `33af82f131cfff260871599e5142ef59`）して deploy します。

最新の正確な状態は `docs/ai_context/CURRENT_STATE.md` / `DECISIONS.md`（D109-D131）/
`TIMING_AND_FPGA_NOTES.md` を参照してください。

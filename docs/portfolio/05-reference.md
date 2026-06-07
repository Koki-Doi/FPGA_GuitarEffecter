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
├── tools/                      revoice.py 等の係数生成
└── docs/                       本書 + docs/ai_context/（設計・決定記録）
```

中核の Clash ソースが「DSP 挙動の唯一の真実」、`docs/ai_context/` が「設計・決定の唯一の真実」
という二本柱で、セッションをまたいでも一貫した開発ができる構成にしています。実機ランタイムは
用途別に Notebook（`PmodI2S2EffectControlOneCell` / `HdmiGui` / `EncoderGuiSmoke` など）として
提供します。

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
| **ペダルマスク** | ディストーション段を mux ではなくビットマスクで選択する方式 |
| **知見（knee）** | クリップ関数が効き始める振幅しきい値。`Sample` の絶対値（例 2,850,000） |
| **RBJ** | Robert Bristow-Johnson のオーディオ EQ Cookbook。バイカッド係数設計の標準 |
| **SVF** | State Variable Filter。Wah のレゾナントバンドパスに使用 |
| **Pmod I2S2** | Digilent の I2S オーディオモジュール（CS5343 ADC + CS4344 DAC） |
| **5 サイト同期** | bit/hwh をボード上の複数コピー場所すべてに md5 一致させるデプロイ規律 |
| **ナイフエッジ** | 「DSP 再ビルドのたびにバイパスが壊れる」未タイミング CDC 由来の現象（D109 で解決） |

## 22. 現状

採用済みデプロイベースラインは **D112**（`c1e3de50`、D109 の CDC 修正の上にアンプを
全面リボイス、実機試聴で合格、2026-06-07）。これに続く **D113**（アンプのモデル個性
リチューン、bit `ed76421f`）と **D114**（アンプ以外のエフェクト定数リチューン、
bit `31c768eb`）はタイミングクリーンでビルド済みですが、実機試聴での承認は保留中です
（D114 は PL ロードがタイムアウトしボードがオフラインになったため、FPGA へのロード自体が
未確認）。

最新の正確な状態は `docs/ai_context/CURRENT_STATE.md` / `DECISIONS.md`（D109-D114）/
`TIMING_AND_FPGA_NOTES.md` を参照してください。

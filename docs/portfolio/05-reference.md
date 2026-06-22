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
| **ナイフエッジ** | DSP 出力→DAC の placement-sensitive CDC。D109 で timing-bound したが D136-D144 で残存リスクを再確認 |
| **D99** | D120 rollback 後にユーザーが選んだ Amp character の基準。D121 はこの Amp を触らず非 Amp だけ補正 |
| **D121** | 最初の measured non-Amp voicing baseline。bit md5 `9a57c50a...`、D99 Amp untouched + non-Amp measured voicing |
| **D131** | DIST low-end + saturation/sustain + offline distortion-eval tooling を確立した accepted baseline |
| **D135** | Fuzz Face mid-hump + Amp/Cab character。bit md5 `533d5869...` |
| **D146-D148** | audio-output CDC hard pblock（`SLICE_X100Y116:SLICE_X113Y137`）+ amp sag-attack slew + JC/Twin clean-headroom fix。`96ef899` |
| **D149** | cab real-IR step B1 = 31-tap rolloff-only speaker FIR（Option Y）。`1468e93` |
| **D150-D153** | OD/DS 対称クリップ（和音 IMD）+ amp 高音増強（HF シェルフ + cab presence）+ 和音高音 cab 修正 + JC/Twin 音割れ修正。`b86c88a` |
| **D154** | ゲイン機の和音 IMD（multiband 含め非改善）= 未採用 |
| **D155** | 現行 canonical deployed baseline。bit md5 `8d875cc8...`、cab speaker FIR を 31→47 タップへ拡張、D153 を supersede |

## 22. 現状

採用済みデプロイベースラインは **D155**（merge commit `09c8a95`、bit md5
`8d875cc8a0154a86673ab22e5b142d27`、hwh md5
`e0469cf593e97d582c14bb09ea98d3d3`）。2026-06-22 に build / timing /
deploy / PL smoke / user bench を通過し、main へ `--no-ff` merge されています。

D155 とそこへ至る 2026-06 の D150-D155 voicing アークの位置づけ：

- ベースは D109 CDC hardening + D146 hard pblock（audio-output CDC を
  `SLICE_X100Y116:SLICE_X113Y137` で物理固定）+ D147 sag slew + D148 clean-headroom
  + D149 cab real-IR 31-tap rolloff FIR。
- D150：OD/DS の和音 IMD（非対称クリップの偶数次差音）を対称クリップ
  （`symSoftClipMed`）で偶数次→奇数次へ。
- D151：amp 高音増強 = post-amp HF シェルフ + cab presence +3 dB。**rig の高域は cab が
  支配し、amp の TREBLE/PRESENCE はほぼ効かない**と実測で確定したのが設計上の学び。
- D152/D153：和音高音の "汚い/ブツブツ" = 帯域内 IMD（**オーバーサンプリングは無効と実証**、
  エイリアスではない）。cab ヘッドルーム + presence 戻し → 出力ホット化分の
  `cabSpeakerKnee` peak-limit 復帰 + JC/Twin master -1.3 dB トリム（音割れ修正）。
- D154：ゲイン機の和音 IMD は multiband 含め非改善（AC30 悪化）＝未採用、Drive つまみが制御。
- D155：cab speaker FIR を 31→47 タップへ拡張（Option-Y 折返し、real-4x12 寄りロールオフ、
  128-tap BRAM "B2" は不採用）。Vivado routed timing は WNS `+0.319 ns`、WHS `+0.013 ns`、
  route errors `0`、D109 CDC fwd `+0.989`（bench-clean）、DSP `206/220`。

D113-D120 の amp-retune / sag 系、D136-D144、D152 単独、D154 multiband は履歴上の
rejected / 非改善候補として扱い、現行値としては語りません。直近 accepted rollback は
D153 bitstreams を `b86c88a` から復元して deploy します。

最新の正確な状態は `docs/ai_context/CURRENT_STATE.md` / `DECISIONS.md`（D109-D155）/
`TIMING_AND_FPGA_NOTES.md` を参照してください。

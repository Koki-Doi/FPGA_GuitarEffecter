# Realism improvement work order

Status: **planning only, no implementation** (2026-06-14). D121 以降で
AudioLab を実機らしい方向へ寄せるための、実装前の作業順と測定方針をまとめる。
このドキュメントは Clash / Python / Vivado の実装手順ではなく、何から評価し、
どの順番で詰めるべきかを固定するための計画書。

関連ドキュメント:

- `REALISM_REFERENCE_PRESETS.md`: 結論順 step 1 の成果物。category ごとの基準
  preset を offline harness config 名 / model index / pedal mask / knob 値で固定。
- `REALISM_MEASUREMENT_INPUTS.md`: 結論順 step 2 の成果物。canonical 測定入力を
  `tools/dsp_sim/signals.py` の決定論生成器 + 固定 param + 記録済み level で固定。
- `REALISM_TARGET_METRICS.md`: 結論順 step 3 の成果物。family 別 metric を harness
  計算へ対応付け（`tools/dsp_sim/harmonics.py` を追加）。Cab/OD/Dist は即着手可、
  Wah/Comp/NS/Reverb は当該 phase で helper 追加。
- `REALISM_CAB_MEASUREMENT.md`: step 4 phase 2 の成果物。D121 Cab 3 model 実測 +
  target 差分（separation 弱・Closed fizz 逆・rolloff 緩・loudness 不一致）。
  phase 3（DSP 変更）は未着手・rebuild + bench 必須。
- `MODEL_REALISM_GAP_ANALYSIS.md`: OD / Distortion / Amp / Cab の旧ギャップ分析。
- `MODEL_REALISM_IMPLEMENTATION_GUIDE.md`: 将来実装する場合の具体案。
- `REAL_HARDWARE_FIDELITY_ROADMAP.md`: real-hardware fidelity 作業の履歴。
- `CURRENT_STATE.md` / `DECISIONS.md`: 現在の accepted baseline と rebuild / bench 制約。

## 前提

- 現在の canonical deployed voicing baseline は **D121**。
- D121 は D99 の accepted Amp character を維持したまま、測定で外れていた非 Amp 系を
  先に補正した。
  - BD-2: pre-clip biquad を明るい方向へ寄せ、測定 peak は約 2.31 kHz。
  - OCD: 約 1.3 kHz の upper-mid honk を追加。
  - Metal: 既存 Big Muff mid-scoop notch を Metal にも適用。
  - Cab: 約 2.8 kHz の cone-breakup presence peak を追加。
- 実機 reference pedal / amp / cab を継続的に用意するのは困難。
- 入力はすでに buffer を噛ませている。今回の順序では Hi-Z input、pickup loading、
  analog front-end impedance は優先しない。
- 目標は **category-level realism**。特定個体の完全 clone ではなく、transfer curve、
  tone shape、dynamic response、speaker rolloff、control feel、preset loudness を
  現実的な範囲に寄せる。
- GPL DSP code、license 不明の commercial IR、proprietary coefficient table は使わない。
  公開グラフ、schematic-level reasoning、自前で設計した target curve は参照可能。
- `hw/ip/clash/src/LowPassFir.hs` または `hw/ip/clash/src/AudioLab/` 配下を変更する
  後続作業は、Clash VHDL regeneration、IP repackage、Vivado bit/hwh rebuild、
  timing summary、deploy、programmatic smoke、user bench acceptance が必須。

## 結論の順番

堅い順番は次の通り。

1. 比較用の基準プリセットを固定。
2. 測定入力を固定。
3. target metrics を先に決める。
4. Cab を詰める。
5. Overdrive を詰める。
6. Distortion / Fuzz を詰める。
7. Wah を詰める。
8. Compressor を詰める。
9. Noise Suppressor を詰める。
10. Reverb を詰める。
11. preset 間の loudness を揃える。
12. Amp は最後に、必要なら 1 model ずつ見る。
13. 最後に integrated board bench を行う。

これは live DSP の信号順ではなく、**作業順**。後ろの工程ほど前の工程の安定度に
依存する。

- Cab は guitar amp らしさを最も大きく決める。Drive の印象も Cab で変わる。
- OD / Distortion を先に安定させないと、Wah into dirt の評価がぶれる。
- Compressor は pick attack と後段 clipping を変えるので、core drive voicing 後に調整する。
- Noise Suppressor は Compressor の makeup / tail / noise floor の影響を受ける。
- Reverb は dry chain、dynamics、gate が安定してからでないと final mix / damping / decay を判断しにくい。
- Amp は bench rejection 履歴が重いので最後。まず Cab / OD / Distortion / Wah /
  Compressor / Noise Suppressor / Reverb を詰めてもなお Amp が足を引っ張るかを見る。

## 1. 比較用の基準プリセットを固定

測定前に、各カテゴリで 1-2 個だけ基準設定を決める。測定しながら knob position を
動かすと、DSP 変更の影響なのか設定変更の影響なのか分からなくなる。

最低限の基準プリセット:

| Category | Reference presets |
| --- | --- |
| Cab | `Cab Open`, `Cab British`, `Cab Closed` |
| Overdrive | `TS9`, `BD-2`, `OCD`, `Centaur` |
| Distortion / Fuzz | `RAT`, `DS-1`, `Big Muff`, `Metal`, `Fuzz Face` |
| Amp | `JC-120`, `JCM800`, `AC30`, `Twin`, `Rockerverb`, `TriAmp` |
| Full-chain | `Safe Bypass`, `Clean`, `Crunch`, `High Gain`, `Ambient`, `Solo` |

各プリセットで固定しておく値:

- effect enable state
- model index / pedal mask
- `DRIVE`
- `TONE`
- `LEVEL`
- `MIX`
- Amp `GAIN`, `BASS`, `MID`, `TREBLE`, `PRESENCE`, `MASTER`, `DRV MODE`
- Cab `AIR`, `LEVEL`, `MIX`
- Wah `POSITION`, `Q`, `VOLUME`, `BIAS`
- Compressor `THRESHOLD`, `RATIO`, `RESPONSE`, `MAKEUP`
- Noise Suppressor `THRESHOLD`, `DECAY`, `DAMP`
- Reverb `DECAY`, `TONE`, `MIX`

この段階の acceptance:

- 後で同じ measurement run を再現できる。
- preset 名と knob 値が regression anchor として使える。
- chat history を読まなくても測定条件が分かる。

## 2. 測定入力を固定

実機がなくても、offline input を固定すれば周波数、倍音、潰れ方、tail、gate、reverb の
比較軸は作れる。`tools/dsp_sim` または隣接する measurement harness で使う入力を先に
決める。

推奨入力:

| Input | Purpose |
| --- | --- |
| `1 kHz sine` | harmonic distortion、transfer curve、gain、clipping |
| `100 Hz sine` | low-frequency tightness、bass clipping、blocking 感 |
| `5 kHz sine` | alias / fizz、高域 harshness |
| `logarithmic sweep` | Cab / tone-stack / filter magnitude response |
| `two-tone` | intermodulation、non-harmonic products |
| `impulse` or short click | Reverb tail、Cab impulse behaviour、ringing |
| decaying sine or plucked-note envelope | Compressor release、Noise Suppressor close behaviour |
| palm-mute phrase | gate chatter、high-gain low-end tightness |
| short DI guitar phrase | musical sanity check |
| sustained tone with Wah position sweep | Wah peak tracking、heel / toe behaviour |

DI guitar phrase に入れる要素:

- low string / high string の single note
- open chord
- barred chord
- palm mute
- soft pick
- hard pick
- sustained decay into silence

この段階の acceptance:

- 後続の候補変更をすべて同じ input で replay できる。
- PYNQ board が手元になくても offline で比較できる。
- input level が記録され、音が大きいだけの候補を良い音と誤認しない。

## 3. target metrics を先に決める

耳だけで係数を触ると、後から判断が揺れる。各 effect family で見る指標を先に固定する。

### Cab metrics

`Open`, `British`, `Closed` それぞれについて、文章と簡単な数値で target curve を決める。

- low bump の量と中心帯域。
- 2-4 kHz presence peak の量。
- 5 kHz 以降の rolloff。
- 8-12 kHz fizz suppression。
- unity preset での output gain。

target の書き方例:

- Open: low end は緩め、low-mid は箱鳴り過多にしない、高域 rolloff は滑らか。
- British: mid / presence identity を強め、top は制御する。
- Closed: low-mid body を強め、3-4 kHz speaker presence を出し、8-12 kHz fizz は抑える。

### OD / Distortion metrics

`1 kHz sine` を固定 drive point で入れて見るもの:

- fundamental gain
- 2nd harmonic
- 3rd harmonic
- 5th harmonic
- odd / even ratio
- RMS
- peak
- `clip_count` または saturation count
- alias bins / non-harmonic energy

sweep で見るもの:

- low cut / bass tightness
- mid hump / scoop center frequency
- tone-knob range
- high-frequency rolloff

### Wah metrics

`POSITION = 0 / 32 / 64 / 96 / 128 / 160 / 192 / 224 / 255` で見るもの:

- peak frequency
- peak gain
- Q / bandwidth
- output RMS
- toe harshness
- heel dullness
- pedal taper smoothness

### Compressor metrics

level step と transient input で見るもの:

- input-output gain curve
- estimated threshold point
- effective ratio
- peak reduction
- RMS change
- transient preservation
- release recovery time
- pumping on sustained chords
- makeup gain headroom

### Noise Suppressor metrics

silence、decay、high-gain phrase で見るもの:

- open threshold
- close threshold
- hysteresis width
- close time
- tail truncation
- chatter count
- palm-mute recovery
- high-gain hiss reduction

### Reverb metrics

impulse / click と DI phrase で見るもの:

- initial reflection strength
- echo density
- decay time by `DECAY`
- high-frequency damping
- metallic ringing
- low-frequency buildup
- wet/dry law by `MIX`

### Preset loudness metrics

final reference preset ごとに見るもの:

- RMS または integrated loudness proxy
- peak
- crest factor
- subjective loudness note
- required output trim

この段階の acceptance:

- 後続 retune に明確な target と before / after measurement がある。
- 「大きいから良い」と「実機らしさが増した」を分離できる。

## 4. Cab を最優先で詰める

Cab は最初に詰める。理由は、Cab が guitar speaker らしさを決定し、Drive / Distortion の
fizz、presence、low-mid body の聞こえ方まで変えるから。

作業順:

1. D121 の Cab 3 種を変更せず測る。
2. `Open`, `British`, `Closed` を target curve と比較する。
3. 修正タイプを分類する。
   - broad speaker shape、comb、cone-breakup texture が不足しているなら FIR / IR。
   - 明確な peak / notch / shelf が 1 箇所足りないなら biquad。
   - 方向は合っていて強さだけ違うなら既存 `softClip`, `presence`, `body`, `air` の定数。
4. Cab-only で確認する。
5. clean curve が成立してから high-gain through Cab を確認する。

改善候補:

- Open / British / Closed の model separation を強める。
- 5 kHz 以降の guitar-speaker rolloff を明確にする。
- 2-4 kHz presence identity を意図的に作る。
- 8-12 kHz fizz suppression を強める。
- 単なる EQ ではなく speaker box らしい挙動に寄せる。

避けること:

- Cab の不足を Amp retune で隠さない。
- Cab なしの high-gain fizz だけで判断しない。
- license が明確でない external IR を入れない。

この段階の acceptance:

- Cab-only の response が target curve に近い。
- high-gain fizz が Cab engaged で自然に収まる。
- 3 model の役割差が測定と耳の両方で分かる。

## 5. Overdrive を次に詰める

Overdrive は Distortion より先。破綻しにくく、control feel と harmonic balance を
測りやすい。

推奨順:

1. `TS9`
2. `BD-2`
3. `OCD`
4. `Centaur`
5. `OD-1`
6. `Jan Ray`

理由:

- TS9 は mid-hump / low-cut の基準になる。
- BD-2 / OCD は D121 で改善済みなので、まず自然な sweep かを確認する。
- Centaur は clean blend 期待が強く、現構造で表現できない差があれば先に記録する。
- OD-1 / Jan Ray は明確な問題が出てからでよい。

見る点:

- `DRIVE` sweep が自然か。
- `TONE` sweep が model identity を壊さないか。
- `LEVEL` が unity を作れるか。
- 2nd / 3rd harmonic balance が model ごとに違うか。
- BD-2 が bright / dynamic のままか。
- OCD が upper-mid character を持ちつつ harsh になっていないか。

この段階の acceptance:

- OD-only presets が fair A/B できる程度に level matched。
- 6 model が generic soft clip の gain 違いに聞こえない。
- D121 の BD-2 / OCD 改善を、測定上の理由なしに過剰修正しない。

## 6. Distortion / Fuzz を詰める

Distortion / Fuzz は Cab と OD の後。high-gain は Cab rolloff の影響が大きく、alias /
fizz の判断も Cab target が固まってからの方が正確。

推奨順:

1. `RAT`
2. `DS-1`
3. `Big Muff`
4. `Metal`
5. `Fuzz Face`

理由:

- RAT は hard clip reference として比較しやすい。明るさは RAT らしさなので潰しすぎない。
- DS-1 は hard-edged distortion と scooped tone identity を確認する。
- Big Muff は sustain と mid-scoop の balance が主戦場。
- Metal は D121 で Big Muff scoop path を共有したので、post EQ / scoop strength /
  fizz / unity level を見る。
- Fuzz Face は pickup / volume interaction が本質だが、実 passive pickup 前提ではないので
  実用上の cleanup / sputter target を先に決める。

見る点:

- `5 kHz sine`、high drive、high notes での alias / fizz。
- `100 Hz sine` と palm mute での low-end tightness。
- tone-stack center frequency と scoop / hump depth。
- sustain と mush の境目。
- pedal 間の unity level。
- 4x oversampled path の効果が維持されているか。

この段階の acceptance:

- Cab engaged の high-gain fizz が制御されている。
- Metal / Big Muff が単に大きいから良く聞こえる状態ではない。
- Fuzz Face の cleanup / gating target が明文化されている。

## 7. Wah を詰める

Wah は OD / Distortion の後。単体 curve も重要だが、実際に気になるのは Wah into TS9、
Wah into RAT、Wah into high gain。

見る点:

- `POSITION` ごとの peak frequency。
- sweep 全体の Q。
- toe position の harshness。
- heel position の mud / volume loss。
- output volume consistency。
- `Q` knob の usable range。
- `BIAS` の効き方。
- `xadc_wiz_a0` から入る expression-pedal taper。

改善候補:

- position-to-frequency taper を linear ではなく pedal-like に寄せる。
- toe range の高域を Distortion 前提で抑える。
- heel range が消えすぎないよう low-mid presence を残す。
- `Q` maximum は dramatic だが whistling / unstable にならない範囲にする。
- `VOLUME` で sweep 中の perceived level loss を補正する。

この段階の acceptance:

- TS9 / high gain へ入れた slow sweep が連続的で vocal。
- どの position でも uncontrolled clipping や極端な volume drop がない。
- `position_raw` writer は pedal のみ。GUI / encoder は `Q`, `VOLUME`, `BIAS` を維持。

## 8. Compressor を詰める

Compressor は drive voices の後。Compressor が先だと、後で OD / Distortion を触った時に
compression の感じがまた変わる。

現状の見方:

- 現在の Compressor は feed-forward peak compressor に近い。
- attack は速く、response smoothing がある。
- makeup gain は conservative。
- 便利ではあるが、Dyna Comp / Ross 系 sustain なのか transparent leveler なのかは
  まだ明確に定義されていない。

見る点:

- input-output curve。
- `THRESHOLD` が musical な位置に来ているか。
- `RATIO` の変化が分かりやすいか。
- `RESPONSE` が attack / release control として自然か。
- `MAKEUP` で後段を clip させず level を戻せるか。
- clean picking の transient loss。
- sustained chord の pumping。
- Noise Suppressor へ入る sustain / noise tail。

改善候補:

- まず target identity を選ぶ。
  - Dyna / Ross sustain: 分かりやすく潰す、速く掴む、sustain を伸ばす。
  - Transparent leveler: 色付けを抑え、level control を滑らかにする。
- release が不自然なら release curve を見直す。
- makeup gain が preset ごとに暴れるなら level-aware にする。
- gain reduction 後の明るさ / 暗さを確認する。

この段階の acceptance:

- Clean / OD の両方で benefit があり、意図しない level jump がない。
- high-gain noise management を壊さない。
- generic compressor のままにせず、狙う compressor identity が記録されている。

## 9. Noise Suppressor を詰める

Noise Suppressor は Compressor の後。Compressor は tail と noise floor を持ち上げるので、
先に suppressor を調整すると後で chatter や note cut が再発しやすい。

現状の見方:

- 現在の suppressor は threshold / decay / damp based。
- hysteresis 的な挙動はある。
- 課題は単に noise を減らすことではなく、note decay を残しながら high-gain hiss を抑えること。

見る点:

- high-gain silence の close 動作。
- decaying note tail length。
- palm-mute gaps。
- near-threshold input の chatter。
- `DAMP` が hard mute ではなく attenuation として聞こえるか。
- `DECAY` range が tight gate から natural fade まで使えるか。
- OD / Distortion / Compressor の組み合わせで default が破綻しないか。

改善候補:

- close 前の hold time。
- smoother close curve。
- hysteresis width の見直し。
- sidechain filtering で low-end thump による誤 open を減らす。
- 将来 UI workflow が許すなら noise-floor learn。

この段階の acceptance:

- high-gain idle hiss が落ちる。
- normal note release を不自然に切らない。
- palm mute は tight だが click しない。
- slow decay で threshold 付近の chatter が出ない。

## 10. Reverb を詰める

Reverb は改善余地が大きいが、順番としては後ろ。dry chain の問題を隠しやすく、final mix /
damping / decay は Cab、drive、dynamics、gate が安定してから判断した方がよい。

現状の見方:

- 現在の Reverb は比較的 simple な comb / feedback tail と damping / diffuser 要素。
- ambience は作れるが、sparse echo、metallic ringing、boingy な感じが出やすい可能性がある。
- 最初の target を 1 つ選ぶなら guitar 向けの spring-ish target が現実的。

見る点:

- impulse response density。
- early echo spacing。
- metallic resonance。
- decay smoothness。
- high-frequency damping。
- low-frequency buildup。
- wet/dry mix law。
- Noise Suppressor の tail behaviour との相互作用。

改善候補:

- diffuser stage の追加または見直し。
- damping filter の調整。
- static mode を減らす subtle modulation。
- wet path low cut。
- wet path high cut。
- 小さい wet setting が使いやすい `MIX` curve。

この段階の acceptance:

- Clean / Ambient preset を支え、attack を潰さない。
- High Gain + Reverb で fizz / hiss を過度に増やさない。
- 通常使用で Noise Suppressor が Reverb tail を不自然に切らない。

## 11. preset 間の loudness を揃える

これは個別 effect が安定してから行う。先に loudness を揃えても、Cab / drive /
dynamics / Reverb を触るたびにやり直しになる。

基準 preset:

- `Safe Bypass`
- `Clean`
- `Crunch`
- `High Gain`
- `Ambient`
- `Solo`

見る点:

- RMS または loudness proxy。
- peak。
- crest factor。
- perceived loudness note。
- unity へ戻すための output trim。

ルール:

- すべての preset を数値上完全一致にしなくてよい。`Solo` は意図的に大きくてよい。
- ただし意図しない volume jump は潰す。
- clipping を loud preset の代償として許容しない。
- bypass と Cab-only が sane なままか確認する。

この段階の acceptance:

- preset switching で accidental volume jump がない。
- intentional boost の量が記録されている。
- wet tail と gate behaviour も含めて perceived loudness が揃っている。

## 12. Amp は最後

Amp は最後に回す。D119 / D120 で、build が clean でも bench で reject されることが分かっている。
現在の実務ルールは、非 Amp chain を測定してもなお Amp 固有の問題が残る場合だけ触る、というもの。

最初にやること:

1. Cab / OD / Distortion / Wah / Compressor / Noise Suppressor / Reverb の target が
   安定した状態で D121 Amp behaviour を測る。
2. Amp が本当に limiting factor か判断する。
3. 必要なら 1 model、1 problem だけ選ぶ。
4. 1 model ずつ retune する。

推奨 reassessment order:

1. `JC-120`: clean headroom / true-clean feel。
2. `JCM800`: crunch identity。
3. `AC30`: chime / early breakup。
4. `Twin`: blackface clean / scoop。
5. `Rockerverb`: thick high-gain body。
6. `TriAmp`: tight modern high gain。

避けること:

- rejected された sag / static-trim route を明示指示なしで復活させない。
- Cab target の不足を Amp EQ で隠さない。
- shared bug fix 以外で複数 Amp model をまとめて触らない。

この段階の acceptance:

- Amp 固有の問題が edit 前に記録されている。
- 変更対象が 1 model または明確な shared bug に絞られている。
- Amp tone は programmatic smoke だけで accepted にしない。最終判断は bench。

## 13. 最後に integrated board bench

offline measurement は候補を絞るためのもの。最終 acceptance は board と耳で行う。

最低限の bench checklist:

- `Safe Bypass`
- `Cab only`
- `OD only`
- `Wah into OD`
- `Compressor into OD`
- `High Gain + Noise Suppressor`
- `Reverb after full chain`
- `Clean` / `Crunch` / `High Gain` / `Ambient` / `Solo` preset switching
- footswitch toggle and preset stepping
- encoder / GUI live apply

bench note として残すもの:

- clipping / crackle
- unexpected level jump
- gate chatter
- reverb tail cutoff
- Wah harsh spot
- high-gain fizz
- bypass cleanliness
- accepted / rejected / provisionally kept の判断

この段階の acceptance:

- programmatic smoke が通る。
- user bench で sound が確認される。
- bitstream / behaviour が accepted なら `CURRENT_STATE.md` と `DECISIONS.md` を更新する。

## 後で実装する場合の phase 分割

後続ターンで明示的に実装する場合も、まとめて大きく触らない。保守的な分割は次。

1. docs / measurement harness only。
2. Cab measurement and target documentation。
3. Cab constant / biquad pass。
4. OD measurement and small retune pass。
5. Distortion / Fuzz measurement and small retune pass。
6. Wah taper / response pass。
7. Compressor response pass。
8. Noise Suppressor gate-behaviour pass。
9. Reverb structure / damping pass。
10. Preset loudness pass。
11. Amp reassessment only if still necessary。

DSP に触れる phase は、それぞれ別の build / deploy / bench decision にする。Cab、drive、
dynamics、ambience、Amp を 1 つの bitstream にまとめるのは高リスクなので、ユーザーが明示的に
選ばない限り避ける。

## 一行まとめ

順番は **基準 preset -> 測定入力 -> target metrics -> Cab -> OD -> Distortion / Fuzz ->
Wah -> Compressor -> Noise Suppressor -> Reverb -> preset loudness -> Amp -> final bench**。

実機 reference が用意しにくく、入力 buffer はすでに解決済みなので、この順番で offline
measurement と category-level target を先に固めるのが最も堅い。

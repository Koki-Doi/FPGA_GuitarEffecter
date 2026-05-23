# AMP_MODEL_RESEARCH_D55

D55 で Amp Sim の旧 4 モデル (jc_clean / clean_combo / british_crunch /
high_gain_stack) を、実機を意識した 6 voicing へ置き換える。本ドキュメ
ントは各モデルの音響特徴と、それを Clash `Amp.hs` の係数 (clip knee /
preLPF alpha / second-stage gain / treble trim / presence trim /
drive-mode delta) に落とすための根拠を残す。実装側の数値はここでの
"Reason" を裏付けとして決定する。

参照優先順位:
1. メーカー公式ページ / オーナーズマニュアル
2. 信頼できる回路解説 (ampbooks / robrobinette など)
3. 商品レビュー (Premier Guitar / MusicRadar / Guitar.com / Sweetwater
   official store / Vintage Guitar / Reverb News)
4. メーカーフォーラム投稿は補助。係数決定の主根拠にはしない。

商標は全て各社所有。本実装は inspired-by の DSP voicing であり、
回路 / IR / 係数の複製ではない (`DECISIONS.md` D7)。

---

## 0. JC-120 (Roland Jazz Chorus 120)

### Source notes
- Source: Roland (manufacturer page)
  - URL: https://www.roland.com/us/products/jc-120/
- Source: Wikipedia — Roland JC-120 Jazz Chorus
  - URL: https://en.wikipedia.org/wiki/Roland_JC-120_Jazz_Chorus_Guitar_Amplifier
- Source: MusicRadar — In praise of the Roland JC-120 Jazz Chorus
  - URL: https://www.musicradar.com/news/guitars/in-praise-of-the-roland-jc-120-jazz-chorus-520494
- Source: Guitar Player — Pioneering Chorus: How the Roland JC-120 Jazz
  Chorus Amp and Boss CE-1 Set Industry Standards
  - URL: https://www.guitarplayer.com/gear/pioneering-chorus-how-the-roland-jc-120-jazz-chorus-amp-and-boss-ce-1-chorus-ensemble-pedal-set-industry-standards
- Notes:
  - 2 × 60 W (8 Ω) / 160 W total (4 Ω), pure solid-state, 2 × 12" speakers.
  - "high-fidelity solid-state preamp" + "high-quality dual 60 W stereo
    solid-state output stage" (Wikipedia, Roland official).
  - "pristine clean tones" / "warm, pristine cleans with impressive
    headroom" / used heavily as a pedal platform (MusicRadar, Guitar
    Player).
  - 1975 から実質仕様変更が少なく、ペダルプラットフォームの基準として
    多用される。

### Tone target
- Clean headroom: very high. 6L6 二発のフェンダー系より硬くて
  fast attack。
- Breakup: ほぼ無し。SS の hard clipping を 8 以上で踏まないと出ない。
- Low: tight。tube amp 的なふくらみは少ない。
- Mid: フラット〜やや控えめ。"high-fidelity preamp" の表現どおり EQ
  色付け弱め。
- High: bright、harsh 寄り。
- Presence: 高め。SS 直結感。
- Compression / sag: ほぼ無し。SS 電源で sag しない。
- Attack: 非常に速い。pick attack がそのまま出る。
- Bright / chime: bright だが chime とは違う、硬い "transparent" 系。
- High-gain suitability: 低い。歪ませ用ではなくペダル受けの clean
  platform。

### DSP mapping
- preGain: low。歪まないことが目的。
- clipKnee: very high (= `intensity` を低く保つ)。Clean mode で
  knee に触らせない。
- asymmetry: low。SS の対称 hard clip 寄り。
- preLPF: bright (`modelDarken = 0`)。SS 直結感を残す。
- low / mid / high / presence: 後段 tone stack 側の挙動。voicing
  としてはフラット寄りに据え置く。
- sag / compression: なし (output trim はほぼ unity)。
- output trim: near unity。
- Clean Mode: ほぼ素通り。`ampAsymClip` の knee に届かない領域で
  動かす。
- Drive Mode: 軽い hard clip だけを付与する。`driveBonus` を非常に
  小さく、`drive negDelta` も小さく抑える。SS amp の overdrive
  channel のような硬い軽歪み程度に留める。
- Reason:
  - 公式 / Wikipedia がはっきり "solid-state, clean" を強調しており、
    drive 用途で売られた amp ではない。
  - Drive Mode で重く歪ませると JC-120 の本質 (touch sensitive な
    bright clean) を壊す。
  - clip plateau を緩めにし、shift も 1 段浅くしないことで "tube
    の柔らかい sag" を入れないように meaning-difference を作る。

---

## 1. Twin Reverb (Fender 1965 Twin Reverb Blackface / AB763)

### Source notes
- Source: Wikipedia — Fender Twin
  - URL: https://en.wikipedia.org/wiki/Fender_Twin
- Source: Fenderguru.com — BF/SF Twin Reverb
  - URL: https://fenderguru.com/amps/twin-reverb/
- Source: Sweetwater — Fender '65 Twin Reverb 2x12 85 W Tube Combo
  - URL: https://www.sweetwater.com/store/detail/65TwinRev--fender-65-twin-reverb-85-watt-2x12-inch-tube-combo-amp
- Source: Reverb News — A Guide to Blackface Era Fender Amps
  - URL: https://reverb.com/news/a-guide-to-blackface-era-fender-amps
- Source: Mojotone / Ampwares — Fender Blackface Twin Reverb
  - URL: https://ampwares.com/amplifiers/fender-blackface-twin-reverb/
- Notes:
  - 4 × 6L6GC、AB763 回路、diode rectifier、大型 OT/PT。85 W RMS。
  - "tons of clean headroom and volume", "stays clean up to almost 6 on
    the volume knob"(fenderguru.com)。
  - ペダル受けの代表機。Fender tone stack (mid notch ~400 Hz) で
    "scooped" 寄り。
  - "sparkly, articulate cleans, warm bottom end" / "spring reverb"
    (Sweetwater)。

### Tone target
- Clean headroom: very high。tube だが diode rectifier + 大 OT で
  sag 少なめ、JC-120 の次に硬い clean が出る。
- Breakup: 軽い。MV 無しの単段ゲインなので 6 以上で軽く割れる。
- Low: full、太い。Fender 6L6 + 2x12 の代表的な厚い低域。
- Mid: scooped 寄り。tone stack mid notch。
- High: bright、sparkly、JC-120 より少し丸い。
- Presence: bright cap で十分立つ。ただし TriAmp / JCM800 系の
  hard presence ではなく "open"。
- Compression / sag: 低。diode rectifier。
- Attack: 速い。
- Bright / chime: bright + warm。
- High-gain suitability: 非常に低い。歪ませると "ばたつき" になる
  ので、Drive mode は edge-of-breakup までで止める。

### DSP mapping
- preGain: low to medium。clean 用なので入力ゲインは控えめ。
- clipKnee: high。clean を死守する。
- asymmetry: low to medium。tube らしさを少しだけ。
- preLPF: ほぼ bright (`modelDarken = 2`)。JC-120 の生硬さよりは
  ほんの少し丸める。
- low: 厚め (post-amp tone stack 側で BASS を効かせやすい voicing)。
- mid: 軽く scoop。`presenceTrim` を少しだけ持つ。
- high: bright。
- sag / compression: low。
- output trim: near unity。
- Clean Mode: 大きく clean。pedal in front 想定。
- Drive Mode: edge-of-breakup。`driveBonus` 小、`drive negDelta` 小。
  fizz を増やさない。
- Reason:
  - 文献全般が "huge clean headroom" を強調しているため、Drive Mode
    でも JC-120 の次に歪ませない band に置く。
  - mid scoop と low fullness の対比は preLPF だけでなく後段の
    presenceTrim を弱めに据えて作る。
  - clip plateau を JC-120 とほんの少しだけ変えて touch sensitive
    な breakup を生む (`negShift` は drive mode で 2 に変える)。

---

## 2. AC30 (Vox AC30 Top Boost)

### Source notes
- Source: Vox Showroom — Vox Top Boost Circuit: A Look Under the Hood
  - URL: https://voxshowroom.com/uk/amp/ac30_tb_hood.html
- Source: voxac30.org.uk — The Vox AC30 Top Boost Circuit
  - URL: https://www.voxac30.org.uk/vox_ac30_top_boost_circuit.html
- Source: Ampbooks — Circuit Analysis of the Vox AC30 Silver Jubilee
  - URL: https://www.ampbooks.com/mobile/classic-circuits/vox-ac30/
- Source: Steve's Amps — Voxiness: what makes the Vox AC30 sound that way?
  - URL: https://www.stevesamps.co.uk/?page_id=287
- Source: Premier Guitar — VOX Introduces Hand-Wired AC15 and AC30
  Greenback Combos
  - URL: https://www.premierguitar.com/news/vox
- Notes:
  - 4 × EL84 (cathode bias, Class A), ~30 W。GZ34 rectifier。
  - Top Boost 回路は ECC83 で treble / bass を boost してから
    cathode follower で出力 inpedance を下げる構造。
  - "subtle harmonic bloom generated as the phase inverter is driven
    harder" (premierguitar)。
  - "treble has a distinctive upper midrange 'chime' and cut that
    sounds magical from clean to heavily overdriven" (voxshowroom)。
  - "cathode bias … maximises gain, sweet compression contributes to
    breakup" (steves amps)。

### Tone target
- Clean headroom: medium。Fender / JC-120 より早く割れる。
- Breakup: 早い。volume 4〜5 で chime + edge-of-breakup。
- Low: 抑えめ。低域ふくらまない (2x12 alnico Blue / Greenback で
  低域は出るが mid-low は緩い)。
- Mid: upper-mid / high-mid (約 2-4 kHz) が強い。"chime" の本体。
- High: 明るいが Fender ほど sparkle ではなく "ring" の方向。
- Presence: 中。Top Boost が brightness を作る。
- Compression / sag: 中。cathode bias で sweet compression。
- Attack: ほどよく速いが pickup attack より harmonic bloom が乗る。
- Bright / chime: 非常に強い。
- High-gain suitability: 中。Brian May / The Edge のように edge-of-
  breakup が定番、heavy modern gain には行かない。

### DSP mapping
- preGain: medium。`intensity` band を中。
- clipKnee: medium。tube knee。
- asymmetry: medium。AC30 は対称ではない (cathode bias 単段)。
- preLPF: 暗くしすぎない (`modelDarken = 4`)。upper-mid を残す。
- low: 控えめ。`presenceTrim` を bass 側に効かせない。
- mid / high-mid: 強め。`ampToneGain` の mid / treble byte 経由で
  自然に効かせる (これは tone stack の knob 反応なので係数側は
  base のみ)。
- high: chime を残すため preLPF を抑えめ。
- sag / compression: medium。output trim を unity からほんの少し下げる。
- output trim: near unity。
- Clean Mode: edge-of-breakup。`driveBonus = 0` で knee は触らない
  が、preGain 段で character byte は中 band を選ぶ。
- Drive Mode: jangly crunch。`driveBonus` を中、`negShift = 2`、
  `posDriveDelta` を中。chime を残すために preLPF darken は
  Drive 側でも控えめにする。
- Reason:
  - "magical from clean to heavily overdriven" の chime は preLPF
    を切りすぎないこと、second-stage gain に少しだけ harmonic
    bloom (driveBonus) を入れることで近似する。
  - cathode bias の sweet compression は output trim をほんの少し
    下げて簡易表現する。
  - Drive Mode で fizz が暴れないよう、preLPF darken を Drive 側で
    +4〜+8 と JCM800 / TriAmp より浅めにする。

---

## 3. Rockerverb (Orange Rockerverb MKIII Dirty Channel)

### Source notes
- Source: Orange Amps — The Rockerverb Series: A Retrospective
  - URL: https://orangeamps.com/articles/the-rockerverb-series-a-retrospective/
- Source: Premier Guitar — Orange Rockerverb 50 MKIII Review
  - URL: https://www.premierguitar.com/gear/orange-rockerverb-50-mkiii-review
- Source: Full Compass — Orange RK50HTC-MKIII Rockerverb 50 MKIII Head
  - URL: https://www.fullcompass.com/prod/282827-orange-rk50htc-mkiii-rockerverb-50-mkiii-head-50w-2-channel-guitar-tube-amplifier-head-with-2x-el34-valves
- Source: ProSoundGear — Orange Rockerverb 50 MKIII review
  - URL: https://www.prosoundgear.com/shop/pro-audio/guitar-amplifiers/orange-rockerverb-50-mkiii-50-watt-2-channel-tube-head-orange/
- Source: el34world — Orange Rockerverb 50 W schematic
  - URL: https://el34world.com/charts/Schematics/Files/Orange/Orange_rockreverb_50w.pdf
- Notes:
  - 2 × EL34 (50 W) / 4 × EL34 (100 W)。Dirty channel + Clean channel。
  - "Dirty channel goes anywhere from classic British crunch to the
    very heaviest modern genres, and always maintains outstanding
    clarity. The distortion sounds spacious, with little of the
    compression you get from fuzz-based gain. Touch sensitivity is
    excellent." (premierguitar)
  - Bass / Mid / Treble + Gain で広いペイント帯。output power switch
    (50W/25W) で sag 量を変えられる。
  - Orange らしい mid-rich / low-rich の voicing。
  - El34world の schematic で Orange MKIII Dirty が cascaded gain
    stages を持つことが確認できる。

### Tone target
- Clean headroom: medium。dirty channel は gain を絞っても色付け
  が乗る。
- Breakup: 中。gain noon でクラシック crunch。
- Low: thick。低域が厚い。
- Mid: rich、low-mid が押し出してくる。
- High: 丸い方向。fizz は少ない。
- Presence: 中。treble は出るが Marshall ほど刺さらない。
- Compression / sag: 中〜やや高。EL34 + sag knob 系で粘る。
- Attack: 中。"touch sensitive" だが Marshall ほど fast ではない。
- Bright / chime: 弱い。
- High-gain suitability: 高。modern metal までいける。

### DSP mapping
- preGain: medium to high。
- clipKnee: low-medium。Drive Mode で深く食わせる。
- asymmetry: medium-high。EL34 saturation。
- preLPF: 中暗 (`modelDarken = 12`)。high-mid fizz を抑える。
- low-mid: thick (`presenceTrim` を強めに、`ampToneGain` の bass
  反応がある分は tone knob 任せ)。
- high: rounded。
- sag / compression: medium-high。`softClipK` を据え置きにして
  暴走を抑え、`driveBonus` を高めに振って "粘る" 感を作る。
- output trim: 据え置き (`softClipK 3_300_000 / 3_400_000`)。
- Clean Mode: 太い clean / crunch。`character byte` 中で受ける。
- Drive Mode: thick overdrive。`driveBonus = 32`、`posDriveDelta`
  を中、`negDriveDelta` を中。preLPF Drive darken は強め (+16)。
- Reason:
  - "spacious distortion, little compression of fuzz-based gain, touch
    sensitivity excellent" は asymmetry を中強、negShift を Drive 側
    で 2、posShift 据え置きで近似。
  - "rounded high" は preLPF darken を強めにして fizz を切る。
  - "thick low-mid" は presenceTrim を Marshall より弱くして低域
    が残るようにする。

---

## 4. JCM800 (Marshall JCM800 2203 Master Volume)

### Source notes
- Source: Vintage Guitar — Marshall JCM800 2203
  - URL: https://www.vintageguitar.com/19826/marshall-jcm800-2203/
- Source: robrobinette.com — How the Marshall Plexi, 2204 and JCM800
  Amplifiers Work
  - URL: https://robrobinette.com/How_the_Marshall_JCM800_Works.htm
- Source: Sweetwater InSync — The History of the Legendary Marshall
  JCM800 2203
  - URL: https://www.sweetwater.com/insync/the-history-of-the-legendary-marshall-jcm800-2203/
- Source: Synergy Amps — Marshall JCM 800 Preamp Module
  - URL: https://www.synergyamps.com/shop/modules/marshall-jcm-800-preamp-module/
- Source: Marshall — Support for Marshall JCM800 Synergy Preamp Module
  - URL: https://www.marshall.com/us/en/support/amps/support-for-marshall-jcm800-synergy-preamp-module/settings-controls
- Notes:
  - 2 × EL34 (50W 2204) / 4 × EL34 (100W 2203)。Master volume single-
    channel。
  - "cascaded two gain stages in the preamp" / "cascaded amps have a
    bit more bite and bark, less squish, and tighter and punchier in
    the bottom end" (robrobinette, synergyamps)。
  - "the resultant maelstrom needed some reining-in" → bright cap +
    cathode follower tone stack で締める設計。
  - "signature midrange roar … authority and articulation"
    (vintageguitar)。
  - 3-position bright cap (Synergy module の解説より)。

### Tone target
- Clean headroom: medium-low。MV を絞っても少し色付き。
- Breakup: 中。gain knob 半分で hard rock crunch。
- Low: tight。cathode follower tone stack + bright cap で締まる。
- Mid: upper-mid (~ 1-2 kHz) が強い。Marshall の "honk"。
- High: aggressive。bright cap で attack が立つ。
- Presence: 強い。
- Compression / sag: 中。MV cascaded で sag は plexi より少なめ。
- Attack: fast、bark。
- Bright / chime: bright だが chime ではなく bark。
- High-gain suitability: 高。classic hard rock の代表。

### DSP mapping
- preGain: high。
- clipKnee: low。Drive Mode で knee に食い込む。
- asymmetry: medium-high。EL34 cascaded。
- preLPF: 中 (`modelDarken = 10`)。high-mid を残す。
- low: tight (`presenceTrim` を強めにして低域を削る)。
- mid / high-mid: 強。`ampToneGain` の mid/treble byte が効きやすい
  voicing なので係数は中。
- high: bark。
- presence: 強い (`presenceTrim` の case 値を上げる)。
- sag / compression: medium。
- output trim: 据え置き。
- Clean Mode: crunch 寄り。低 gain でも色付きあり。
- Drive Mode: aggressive classic rock。`driveBonus = 36`、`posDriveDelta`
  を強、`negDriveDelta` を強。preLPF darken は +12 で fizz を切る。
- Reason:
  - "tighter and punchier in the bottom end" は presenceTrim を強める
    + preLPF を中で実装する。
  - "midrange roar" は preLPF / presenceTrim の組み合わせで自然に
    high-mid が残る voicing にする。
  - Drive Mode 側で knee を深く食わせる (`negShift = 2`) ことで
    EL34 cascaded gain の sustain を近似。

---

## 5. TriAmp Mk3 (Hughes & Kettner TriAmp Mark 3 — Mode 3B Modern High Gain)

### Source notes
- Source: Hughes & Kettner — TriAmp Mark 3 product page
  - URL: https://hughes-and-kettner.com/?product=triamp-mark-3
- Source: Sweetwater — Hughes & Kettner TriAmp Mark 3 150 W Dual 3-channel
  - URL: https://www.sweetwater.com/store/detail/TRIAMPMKIII--hughes-and-kettner-triamp-mkiii-150-watt-dual-3-channel-programmable-tube-head
- Source: Guitar.com — Hughes & Kettner TriAmp Mark 3 review
  - URL: https://guitar.com/reviews/hughes-kettner-triamp-mark-3-review/
- Source: MusicRadar — Hughes & Kettner TriAmp Mark 3 review
  - URL: https://www.musicradar.com/reviews/guitars/hughes-kettner-triamp-mark-3-628353
- Source: MusicPlayers — Hughes & Kettner TriAmp Mark 3
  - URL: https://musicplayers.com/2017/01/hughes-kettner-triamp-mark-3/
- Notes:
  - 6 channels: 1A 50s Californian clean, 1B 60s British clean, 2A 70s
    British lead, 2B 80s brown sound, 3A 90s Californian high-gain,
    3B modern high-gain and beyond。
  - "trio of independent power amp sections that can be used
    independently or combined" / 最大 150 W (4 x 6L6 + 2 x EL34
    構成時)。
  - "modern high-gain and beyond" モード = メタル / モダンプログ
    ターゲット。built-in noise gate 同梱。
  - "tight low end with great tonal precision without any interference
    or noise" (Hughes & Kettner公式)。
  - D55 ではこの 3B mode (modern high-gain) を Drive Mode の頂点
    として近似する。Clean Mode は 1A (Californian clean)〜 1B
    (British clean) の混血として整える。

### Tone target
- Clean headroom: 中。1A / 1B は clean を作れる。Drive Mode では
  最も低い。
- Breakup: 早い (Drive Mode で)。Clean Mode は medium。
- Low: tight、modern。低域がふくらまず締まる。
- Mid: programmable だが modern high-gain らしい mid scoop。
- High: 制御された明るさ。fizz を抑え、attack だけ立てる。
- Presence: 高い (resonance 系統)。
- Compression / sag: 高 (3B mode は sustain 重視)。
- Attack: tight、fast。
- Bright / chime: chime ではなく precision。
- High-gain suitability: 最高。modern metal / 7-string まで。

### DSP mapping
- preGain: 最高。
- clipKnee: 最低。Drive Mode で深い hard clip。
- asymmetry: 強。
- preLPF: 最暗 (`modelDarken = 28`)。modern high-gain の fizz を
  徹底的に切る。
- low: tight (`presenceTrim` を最強)。
- high: controlled。
- presence / resonance: modern。
- sag / compression: 強 (`output trim` で `clip_count` 暴走を防止)。
- output trim: ほんの少し下げる方向。
- Clean Mode: modern clean / 軽 crunch。`driveBonus = 0` でも
  character byte と modelDarken が効くので既に modern voicing。
- Drive Mode: 最大歪み。`driveBonus = 44`、`posDriveDelta` 最強、
  `negDriveDelta` 最強。preLPF darken Drive 側 +20。
- Reason:
  - 公式の "tight low end, great tonal precision, no interference" を
    preLPF darken と presenceTrim 強で再現。
  - clip_count 暴走対策として、Drive Mode + TriAmp Mk3 の組み合わせ
    が最も大きい削り量になるよう、preLPF が一番暗いこと + softClipK
    が据え置きであることを意図的に組み合わせる。
  - 2x12 / 4x12 large speaker からの "controlled high" は preLPF
    にすべて吸収させ、`ampTrebleGain` の case 値を最大の trim に
    することで二重に保険をかける。
  - clean mode でも既に圧縮感があってよい (Mark 3 1A/1B clean は
    modern clean なので completely transparent ではない)。

---

## 6. モデル別 DSP 係数サマリ (Amp.hs 反映の指針)

### D55 (初期 commit)

| idx | name | modelDarken | trebleTrim | presenceTrim case | drivePosDelta | driveNegDelta | preLPF drive darken | secondStage driveBonus |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| 0 | JC-120 | 0 | 0 | 0 | 1_200 | 1_000 | 4 | 8 |
| 1 | Twin Reverb | 2 | 1 | byte >> 6 | 1_500 | 1_300 | 6 | 12 |
| 2 | AC30 | 4 | 3 | byte >> 5 | 1_900 | 1_700 | 8 | 20 |
| 3 | Rockerverb | 12 | 6 | byte >> 4 | 2_400 | 2_100 | 14 | 32 |
| 4 | JCM800 | 10 | 8 | byte >> 4 | 2_700 | 2_400 | 12 | 36 |
| 5 | TriAmp Mk3 | 28 | 12 | byte >> 3 | 3_200 | 2_900 | 20 | 44 |

### D58.2 (現行 / fixed-scalar 版 Balanced Drive — D58 ロールバック後)

D58 (`ch * factor`) は DSP 数を 83→87 に増やしてしまい、Vivado P&R が
ADC→DAC bypass 経路に高音域飽和ノイズを乗せたため不採用。D58.2 は
**per-model fixed scalar** で同等の Drive 強度をターゲットしつつ DSP 数を
D55 と同じ 83 に揃える。Clean Mode は完全に D55 と同一。

| idx | name | modelDarken | trebleTrim | presenceTrim case | drivePosDelta | driveNegDelta | preLPF drive darken | secondStage driveBonus |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| 0 | JC-120 | 0 | 0 | 0 | 13_000 | 11_000 | 5 | 14 |
| 1 | Twin Reverb | 2 | 1 | byte >> 6 | 58_000 | 50_000 | 7 | 18 |
| 2 | AC30 | 4 | 3 | byte >> 5 | 130_000 | 113_000 | 10 | 28 |
| 3 | Rockerverb | 12 | 6 | byte >> 4 | 210_000 | 180_000 | 16 | 42 |
| 4 | JCM800 | 10 | 8 | byte >> 4 | 264_000 | 231_000 | 16 | 48 |
| 5 | TriAmp Mk3 | 28 | 12 | byte >> 3 | 336_000 | 300_000 | 24 | 56 |

D58.2 の数値根拠:
- `drivePosDelta` 値は **D58 の `ch * factor` を各モデルの
  `ampCharForModel` peak 値で評価した結果に丸めた値** を採用
  (例 TriAmp Mk3: `ch=240 * 1400 = 336_000`)。
  これにより first stage (`ampWaveshapeFrame`, `intensity = ch`)
  での Drive 効きは D58 とほぼ一致。
- second stage (`ampSecondStageFrame`, `intensity = ch >> 1`) では
  D58 だと `ch * factor` が自動的に半減するが、D58.2 の fixed scalar
  では同じ値が再利用される。結果 second stage の posKnee は D58 よりも
  `~ delta/2` だけ tight になる (例 TriAmp Mk3 second stage posKnee:
  D58 = `3_892_000` → D58.2 = `3_724_000`)。第二段は元々 `softClipK
  3_300_000` safety から距離があるので `clip_count` 暴走には至らない
  (PYNQ 上 3 秒測定で TriAmp Mk3 + Drive の CLIP_COUNT delta = 0 を
  確認)。
- `preLPF drive darken` と `secondStage driveBonus` は D58 と同じ値
  (`5..24` / `14..56`)。どちらも単純な per-model adder/subtractor
  なので DSP コストはゼロ。

D58 / D57 から採用しなかった項目 (audible regression 回避のため):

- D58 の `ch * factor` 比例型 delta (DSP+4 で P&R が ADC→DAC bypass
  経路に高音域飽和ノイズを乗せた)。
- D57 の `ch * 5_000..7_000` 多項係数 (Drive 過剰、breakup)。
- D57 の `ampInputDriveGainBonus` (pre-clip push)。
- D57 の second clip stage を `intensity = ampCharForModel idx`
  (full intensity) に変える変更。D58.2 は D55 の `>> 1` を維持。
- `ampSecondStageDriveBonus` を 80 を超える領域まで持ち上げる
  変更。D58.2 max = 56。

注:
- `presenceTrim` の右シフト幅が小さいほど high band から削る量が
  増える → JC-120 / Twin が一番 bright、TriAmp Mk3 が一番 dark。
- `drivePosDelta` / `driveNegDelta` は `ampAsymClip` の knee 引き量
  (Signed 25 / per-model `character` ではなく、固定値で per-model
  に独立)。これにより Drive Mode の歪み深さがモデルごとに段階的に
  変わる。
- `preLPF drive darken` は `ampPreLowpassFrame` の Drive 時に
  base alpha から差し引く値。高ゲイン modeling 側で大きくして fizz
  を切る。
- `secondStage driveBonus` は `ampSecondStageMultiplyFrame` の
  Drive 時に追加する Q9 ゲイン。

旧 D54 から削減 / 維持される項目:
- `softClipK 3_300_000` / `3_400_000` の output safety は維持。
  6 モデルすべてで `clip_count` が暴走しないよう据え置く。
- `ampMasterFrame` / `ampPowerFrame` の structure は据え置き。
  voicing 差は前段 (`ampAsymClip` / `ampPreLowpassFrame` /
  `ampSecondStageMultiplyFrame` / `ampTrebleGain` /
  `ampResPresenceProductsFrame`) に集約する。

DSP 側で 6 / 7 が来た場合の扱い:
- 安全側で 0 = JC-120 にフォールバックする。
- 理由: TriAmp Mk3 に倒すと、誤書き込みが modern high-gain Drive
  に直結し `clip_count` が暴走するリスクがある。JC-120 にフォール
  バックすれば、Drive Mode 1 でも歪み深さが最弱の voicing 上で
  動くため、想定外の挙動を audible regression のしきい値以下に
  抑えられる。
- Python 側では `AMP_MODEL_IDX_MASK = 0x07` だが
  `AMP_MODEL_IDX_MAX = 5` で clamp してから書くため、通常経路で
  6 / 7 が書かれることはない。

---

## 7. 検証計画 (PYNQ 実機)

- 6 モデルすべてで `Pmod I2S2 mode 2` 経由 (ADC → DSP → DAC) の
  実音で Clean / Drive の差が出ること。
- `JC-120` Clean Mode と `TriAmp Mk3` Drive Mode で `clip_count`
  が暴走しないこと (`scripts/pmod_i2s2_mode.py --read` または
  `scripts/test_pmod_i2s2.py` で確認)。
- 同一モデル内で Drive Mode = 1 が Drive Mode = 0 より明確に歪む
  こと (耳での A/B)。
- 異モデル間で voicing 差があること (低域厚み / 高域明るさ / 歪み
  深さ)。
- Encoder 1 hold + rotate で 6 モデルを循環できること、Encoder 2
  で DRV MODE 0/1 が切替できること。

参考: 本ドキュメントの数値はあくまで初期目標。bench で耳合わせの
結果、係数を更新する場合は本 md の `DSP mapping` を上書きし、
`Reason` に "bench tuning (date)" を追記する。

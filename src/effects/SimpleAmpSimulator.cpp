#include "SimpleAmpSimulator.h"

#include <cmath>

namespace {
constexpr float kPi = 3.14159265358979323846f;
constexpr float kInternalLimit = 16.0f;
constexpr float kDenormalLimit = 1.0e-20f;
constexpr float kInputHighpassHz = 45.0f;
constexpr float kPreampLowpassHz = 6800.0f;
constexpr float kToneLowpassHz = 260.0f;
constexpr float kToneHighSplitHz = 2400.0f;
constexpr float kResonanceHz = 130.0f;
constexpr float kPresenceHz = 4200.0f;
} // namespace

SimpleAmpSimulator::SimpleAmpSimulator()
{
    prepare(sampleRate_);
}

void SimpleAmpSimulator::prepare(float sampleRate)
{
    if (!std::isfinite(sampleRate) || sampleRate < 1000.0f) {
        sampleRate_ = 48000.0f;
    } else {
        sampleRate_ = sampleRate;
    }

    smoothedInputGain_.prepare(sampleRate_, 0.010f);
    smoothedBass_.prepare(sampleRate_, 0.010f);
    smoothedMiddle_.prepare(sampleRate_, 0.010f);
    smoothedTreble_.prepare(sampleRate_, 0.010f);
    smoothedPresence_.prepare(sampleRate_, 0.010f);
    smoothedResonance_.prepare(sampleRate_, 0.010f);
    smoothedMaster_.prepare(sampleRate_, 0.010f);
    smoothedCharacter_.prepare(sampleRate_, 0.010f);

    const float preampLowpass = lowpassCoefficient(kPreampLowpassHz);
    const float toneLowpass = lowpassCoefficient(kToneLowpassHz);
    const float toneHighSplit = lowpassCoefficient(kToneHighSplitHz);
    const float resonanceLowpass = lowpassCoefficient(kResonanceHz);
    const float presenceLowpass = lowpassCoefficient(kPresenceHz);

    for (auto& channel : channels_) {
        channel.inputHighpass.setCutoff(kInputHighpassHz, sampleRate_);
        channel.preampLowpass.setCoefficient(preampLowpass);
        channel.toneLowpass.setCoefficient(toneLowpass);
        channel.toneHighLowpass.setCoefficient(toneHighSplit);
        channel.resonanceLowpass.setCoefficient(resonanceLowpass);
        channel.presenceLowpass.setCoefficient(presenceLowpass);
    }

    updateTargets(true);
    reset();
}

void SimpleAmpSimulator::reset()
{
    for (auto& channel : channels_) {
        channel.reset();
    }

    smoothedInputGain_.setImmediate(smoothedInputGain_.target);
    smoothedBass_.setImmediate(smoothedBass_.target);
    smoothedMiddle_.setImmediate(smoothedMiddle_.target);
    smoothedTreble_.setImmediate(smoothedTreble_.target);
    smoothedPresence_.setImmediate(smoothedPresence_.target);
    smoothedResonance_.setImmediate(smoothedResonance_.target);
    smoothedMaster_.setImmediate(smoothedMaster_.target);
    smoothedCharacter_.setImmediate(smoothedCharacter_.target);
}

void SimpleAmpSimulator::setInputGain(float value)
{
    inputGain_ = clamp(value, 0.0f, 1.0f);
    updateTargets(false);
}

void SimpleAmpSimulator::setBass(float value)
{
    bass_ = clamp(value, 0.0f, 1.0f);
    updateTargets(false);
}

void SimpleAmpSimulator::setMiddle(float value)
{
    middle_ = clamp(value, 0.0f, 1.0f);
    updateTargets(false);
}

void SimpleAmpSimulator::setTreble(float value)
{
    treble_ = clamp(value, 0.0f, 1.0f);
    updateTargets(false);
}

void SimpleAmpSimulator::setPresence(float value)
{
    presence_ = clamp(value, 0.0f, 1.0f);
    updateTargets(false);
}

void SimpleAmpSimulator::setResonance(float value)
{
    resonance_ = clamp(value, 0.0f, 1.0f);
    updateTargets(false);
}

void SimpleAmpSimulator::setMaster(float value)
{
    master_ = clamp(value, 0.0f, 1.5f);
    updateTargets(false);
}

void SimpleAmpSimulator::setCharacter(float value)
{
    character_ = clamp(value, 0.0f, 1.0f);
    updateTargets(false);
}

void SimpleAmpSimulator::setEnabled(bool enabled)
{
    enabled_ = enabled;
}

float SimpleAmpSimulator::processSample(float input)
{
    return processSample(input, 0);
}

float SimpleAmpSimulator::processSample(float input, std::size_t channel)
{
    const float dry = sanitize(input);
    if (!enabled_) {
        return clamp(dry, -1.0f, 1.0f);
    }

    return processChannel(dry,
                          channel,
                          smoothedInputGain_.next(),
                          smoothedBass_.next(),
                          smoothedMiddle_.next(),
                          smoothedTreble_.next(),
                          smoothedPresence_.next(),
                          smoothedResonance_.next(),
                          smoothedMaster_.next(),
                          smoothedCharacter_.next());
}

void SimpleAmpSimulator::processStereo(float& left, float& right)
{
    const float dryLeft = sanitize(left);
    const float dryRight = sanitize(right);
    if (!enabled_) {
        left = clamp(dryLeft, -1.0f, 1.0f);
        right = clamp(dryRight, -1.0f, 1.0f);
        return;
    }

    const float inputGain = smoothedInputGain_.next();
    const float bass = smoothedBass_.next();
    const float middle = smoothedMiddle_.next();
    const float treble = smoothedTreble_.next();
    const float presence = smoothedPresence_.next();
    const float resonance = smoothedResonance_.next();
    const float master = smoothedMaster_.next();
    const float character = smoothedCharacter_.next();

    left = processChannel(dryLeft, 0, inputGain, bass, middle, treble, presence, resonance, master, character);
    right = processChannel(dryRight, 1, inputGain, bass, middle, treble, presence, resonance, master, character);
}

void SimpleAmpSimulator::processBlock(const float* input, float* output, std::size_t sampleCount)
{
    if (output == nullptr) {
        return;
    }

    for (std::size_t i = 0; i < sampleCount; ++i) {
        output[i] = processSample(input == nullptr ? 0.0f : input[i], 0);
    }
}

void SimpleAmpSimulator::processBlock(const float* inputLeft,
                                      const float* inputRight,
                                      float* outputLeft,
                                      float* outputRight,
                                      std::size_t sampleCount)
{
    if (outputLeft == nullptr || outputRight == nullptr) {
        return;
    }

    for (std::size_t i = 0; i < sampleCount; ++i) {
        float left = inputLeft == nullptr ? 0.0f : inputLeft[i];
        float right = inputRight == nullptr ? 0.0f : inputRight[i];
        processStereo(left, right);
        outputLeft[i] = left;
        outputRight[i] = right;
    }
}

void SimpleAmpSimulator::SmoothValue::prepare(float sampleRate, float timeSeconds)
{
    if (!std::isfinite(sampleRate) || sampleRate <= 0.0f || timeSeconds <= 0.0f) {
        amount = 1.0f;
        return;
    }

    amount = 1.0f - std::exp(-1.0f / (sampleRate * timeSeconds));
}

void SimpleAmpSimulator::SmoothValue::setImmediate(float value)
{
    current = value;
    target = value;
}

void SimpleAmpSimulator::SmoothValue::setTarget(float value)
{
    target = value;
}

float SimpleAmpSimulator::SmoothValue::next()
{
    current += (target - current) * amount;
    if (std::fabs(current - target) < 1.0e-6f) {
        current = target;
    }
    return current;
}

void SimpleAmpSimulator::DcBlocker::setCutoff(float cutoffHz, float sampleRate)
{
    if (!std::isfinite(cutoffHz) || !std::isfinite(sampleRate) || sampleRate <= 0.0f) {
        coefficient = 0.995f;
        return;
    }

    const float maxCutoff = sampleRate * 0.45f;
    const float safeCutoff = SimpleAmpSimulator::clamp(cutoffHz, 1.0f, maxCutoff);
    coefficient = std::exp(-2.0f * kPi * safeCutoff / sampleRate);
}

void SimpleAmpSimulator::DcBlocker::reset()
{
    previousInput = 0.0f;
    previousOutput = 0.0f;
}

float SimpleAmpSimulator::DcBlocker::process(float input)
{
    const float output = SimpleAmpSimulator::removeDenormal(
        input - previousInput + coefficient * previousOutput);
    previousInput = input;
    previousOutput = output;
    return output;
}

void SimpleAmpSimulator::OnePoleLowpass::setCoefficient(float value)
{
    coefficient = SimpleAmpSimulator::clamp(value, 0.0f, 1.0f);
}

void SimpleAmpSimulator::OnePoleLowpass::reset()
{
    state = 0.0f;
}

float SimpleAmpSimulator::OnePoleLowpass::process(float input)
{
    state = SimpleAmpSimulator::removeDenormal(state + coefficient * (input - state));
    return state;
}

void SimpleAmpSimulator::ChannelState::reset()
{
    inputHighpass.reset();
    preampLowpass.reset();
    toneLowpass.reset();
    toneHighLowpass.reset();
    resonanceLowpass.reset();
    presenceLowpass.reset();
}

float SimpleAmpSimulator::clamp(float value, float minimum, float maximum)
{
    if (!std::isfinite(value)) {
        return minimum;
    }
    if (value < minimum) {
        return minimum;
    }
    if (value > maximum) {
        return maximum;
    }
    return value;
}

float SimpleAmpSimulator::sanitize(float value)
{
    if (!std::isfinite(value)) {
        return 0.0f;
    }
    return clamp(value, -kInternalLimit, kInternalLimit);
}

float SimpleAmpSimulator::removeDenormal(float value)
{
    return std::fabs(value) < kDenormalLimit ? 0.0f : value;
}

float SimpleAmpSimulator::cubicSoftClip(float value, float threshold)
{
    const float safeThreshold = clamp(threshold, 0.05f, 4.0f);
    const float x = clamp(value / safeThreshold, -1.0f, 1.0f);
    return (1.5f * x - 0.5f * x * x * x) * safeThreshold;
}

float SimpleAmpSimulator::asymmetricWaveshape(float value, float character)
{
    const float x = clamp(value, -8.0f, 8.0f);
    const float grit = clamp(character, 0.0f, 1.0f);

    if (x >= 0.0f) {
        const float atanStage = (2.0f / kPi) * std::atan(x * (1.20f + 0.80f * grit));
        return cubicSoftClip(atanStage * (1.05f + 0.25f * grit), 1.0f);
    }

    const float folded = -x;
    const float soft = std::tanh(folded * (1.05f + 0.95f * grit));
    const float clipped = cubicSoftClip(soft * (0.95f + 0.25f * grit), 1.0f);
    return -clipped * (0.90f + 0.06f * grit);
}

float SimpleAmpSimulator::powerAmpSaturate(float value, float character)
{
    const float drive = 1.0f + 0.35f * clamp(character, 0.0f, 1.0f);
    return cubicSoftClip(value * drive, 1.15f);
}

float SimpleAmpSimulator::softLimit(float value)
{
    const float x = clamp(value, -4.0f, 4.0f);
    const float absX = std::fabs(x);
    if (absX <= 0.95f) {
        return x;
    }

    // Continuous knee from 0.95 toward 1.0 keeps protection from adding a
    // sudden level drop at the limiter threshold.
    const float sign = x < 0.0f ? -1.0f : 1.0f;
    const float knee = absX - 0.95f;
    const float limited = 0.95f + 0.05f * std::tanh(knee * 20.0f);
    return sign * limited;
}

float SimpleAmpSimulator::lowpassCoefficient(float cutoffHz) const
{
    const float maxCutoff = sampleRate_ * 0.45f;
    const float safeCutoff = clamp(cutoffHz, 10.0f, maxCutoff);
    return 1.0f - std::exp(-2.0f * kPi * safeCutoff / sampleRate_);
}

float SimpleAmpSimulator::processChannel(float input,
                                         std::size_t channel,
                                         float inputGain,
                                         float bass,
                                         float middle,
                                         float treble,
                                         float presence,
                                         float resonance,
                                         float master,
                                         float character)
{
    ChannelState& state = channels_[channel % kChannelCount];

    const float gain = 1.0f + 39.0f * inputGain * inputGain;
    float wet = state.inputHighpass.process(input);
    wet = sanitize(wet * gain);
    wet = asymmetricWaveshape(wet, character);
    wet = state.preampLowpass.process(wet);
    wet = toneStack(state, wet, bass, middle, treble);
    wet = powerAmpSaturate(wet, character);

    // Resonance is a controlled low-frequency feedback impression around cabinet thump range.
    const float lowBody = state.resonanceLowpass.process(wet);
    wet = sanitize(wet + lowBody * (0.34f * resonance));

    // Presence adds a high-passed component instead of just raising all treble.
    const float dark = state.presenceLowpass.process(wet);
    wet = sanitize(wet + (wet - dark) * (0.45f * presence));
    wet = sanitize(wet * master);

    return removeDenormal(sanitize(softLimit(wet)));
}

float SimpleAmpSimulator::toneStack(ChannelState& state, float input, float bass, float middle, float treble) const
{
    const float low = state.toneLowpass.process(input);
    const float highLowpass = state.toneHighLowpass.process(input);
    const float mid = highLowpass - low;
    const float high = input - highLowpass;

    const float bassGain = 1.0f + (bass - 0.5f) * 1.25f;
    const float midGain = 1.0f + (middle - 0.5f) * 1.10f;
    const float trebleGain = 1.0f + (treble - 0.5f) * 1.30f;

    return sanitize((low * bassGain + mid * midGain + high * trebleGain) * 0.82f);
}

void SimpleAmpSimulator::updateTargets(bool immediate)
{
    if (immediate) {
        smoothedInputGain_.setImmediate(inputGain_);
        smoothedBass_.setImmediate(bass_);
        smoothedMiddle_.setImmediate(middle_);
        smoothedTreble_.setImmediate(treble_);
        smoothedPresence_.setImmediate(presence_);
        smoothedResonance_.setImmediate(resonance_);
        smoothedMaster_.setImmediate(master_);
        smoothedCharacter_.setImmediate(character_);
        return;
    }

    smoothedInputGain_.setTarget(inputGain_);
    smoothedBass_.setTarget(bass_);
    smoothedMiddle_.setTarget(middle_);
    smoothedTreble_.setTarget(treble_);
    smoothedPresence_.setTarget(presence_);
    smoothedResonance_.setTarget(resonance_);
    smoothedMaster_.setTarget(master_);
    smoothedCharacter_.setTarget(character_);
}

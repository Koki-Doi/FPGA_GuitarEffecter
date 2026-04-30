#include "RatStyleDistortion.h"

#include <cmath>

namespace {
constexpr float kPi = 3.14159265358979323846f;
constexpr float kInternalLimit = 16.0f;
constexpr float kDenormalLimit = 1.0e-20f;
constexpr float kInputHighpassHz = 55.0f;
constexpr float kPostClipLowpassHz = 12000.0f;
} // namespace

RatStyleDistortion::RatStyleDistortion()
{
    prepare(sampleRate_);
}

void RatStyleDistortion::prepare(float sampleRate)
{
    if (!std::isfinite(sampleRate) || sampleRate < 1000.0f) {
        sampleRate_ = 48000.0f;
    } else {
        sampleRate_ = sampleRate;
    }

    preGain_.prepare(sampleRate_, 0.010f);
    clipThreshold_.prepare(sampleRate_, 0.010f);
    opAmpLowpassCoefficient_.prepare(sampleRate_, 0.010f);
    toneLowpassCoefficient_.prepare(sampleRate_, 0.010f);
    outputLevel_.prepare(sampleRate_, 0.010f);
    wetMix_.prepare(sampleRate_, 0.010f);

    const float postClipCoefficient = lowpassCoefficient(kPostClipLowpassHz);
    for (auto& channel : channels_) {
        channel.inputHighpass.setCutoff(kInputHighpassHz, sampleRate_);
        channel.postClipLowpass.setCoefficient(postClipCoefficient);
    }

    updateDriveTargets(true);
    updateFilterTargets(true);
    updateLevelTarget(true);
    updateMixTarget(true);
    reset();
}

void RatStyleDistortion::reset()
{
    for (auto& channel : channels_) {
        channel.reset();
    }

    preGain_.setImmediate(preGain_.target);
    clipThreshold_.setImmediate(clipThreshold_.target);
    opAmpLowpassCoefficient_.setImmediate(opAmpLowpassCoefficient_.target);
    toneLowpassCoefficient_.setImmediate(toneLowpassCoefficient_.target);
    outputLevel_.setImmediate(outputLevel_.target);
    wetMix_.setImmediate(wetMix_.target);
}

void RatStyleDistortion::setDrive(float value)
{
    drive_ = clamp(value, 0.0f, 1.0f);
    updateDriveTargets(false);
}

void RatStyleDistortion::setFilter(float value)
{
    filter_ = clamp(value, 0.0f, 1.0f);
    updateFilterTargets(false);
}

void RatStyleDistortion::setLevel(float value)
{
    level_ = clamp(value, 0.0f, 1.5f);
    updateLevelTarget(false);
}

void RatStyleDistortion::setMix(float value)
{
    mix_ = clamp(value, 0.0f, 1.0f);
    updateMixTarget(false);
}

void RatStyleDistortion::setEnabled(bool enabled)
{
    enabled_ = enabled;
}

float RatStyleDistortion::processSample(float input)
{
    return processSample(input, 0);
}

float RatStyleDistortion::processSample(float input, std::size_t channel)
{
    const float dry = sanitize(input);
    if (!enabled_) {
        return clamp(dry, -1.0f, 1.0f);
    }

    const float preGain = preGain_.next();
    const float clipThreshold = clipThreshold_.next();
    const float opAmpLowpassCoefficient = opAmpLowpassCoefficient_.next();
    const float toneLowpassCoefficient = toneLowpassCoefficient_.next();
    const float outputLevel = outputLevel_.next();
    const float wetMix = wetMix_.next();

    return processChannel(dry,
                          channel,
                          preGain,
                          clipThreshold,
                          opAmpLowpassCoefficient,
                          toneLowpassCoefficient,
                          outputLevel,
                          wetMix);
}

void RatStyleDistortion::processStereo(float& left, float& right)
{
    const float dryLeft = sanitize(left);
    const float dryRight = sanitize(right);

    if (!enabled_) {
        left = clamp(dryLeft, -1.0f, 1.0f);
        right = clamp(dryRight, -1.0f, 1.0f);
        return;
    }

    const float preGain = preGain_.next();
    const float clipThreshold = clipThreshold_.next();
    const float opAmpLowpassCoefficient = opAmpLowpassCoefficient_.next();
    const float toneLowpassCoefficient = toneLowpassCoefficient_.next();
    const float outputLevel = outputLevel_.next();
    const float wetMix = wetMix_.next();

    left = processChannel(dryLeft,
                          0,
                          preGain,
                          clipThreshold,
                          opAmpLowpassCoefficient,
                          toneLowpassCoefficient,
                          outputLevel,
                          wetMix);
    right = processChannel(dryRight,
                           1,
                           preGain,
                           clipThreshold,
                           opAmpLowpassCoefficient,
                           toneLowpassCoefficient,
                           outputLevel,
                           wetMix);
}

void RatStyleDistortion::processBlock(const float* input, float* output, std::size_t sampleCount)
{
    if (output == nullptr) {
        return;
    }

    for (std::size_t i = 0; i < sampleCount; ++i) {
        const float sample = input == nullptr ? 0.0f : input[i];
        output[i] = processSample(sample, 0);
    }
}

void RatStyleDistortion::processBlock(const float* inputLeft,
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

void RatStyleDistortion::SmoothValue::prepare(float sampleRate, float timeSeconds)
{
    if (!std::isfinite(sampleRate) || sampleRate <= 0.0f || timeSeconds <= 0.0f) {
        amount = 1.0f;
        return;
    }

    amount = 1.0f - std::exp(-1.0f / (sampleRate * timeSeconds));
}

void RatStyleDistortion::SmoothValue::setImmediate(float value)
{
    current = value;
    target = value;
}

void RatStyleDistortion::SmoothValue::setTarget(float value)
{
    target = value;
}

float RatStyleDistortion::SmoothValue::next()
{
    current += (target - current) * amount;
    if (std::fabs(current - target) < 1.0e-6f) {
        current = target;
    }
    return current;
}

void RatStyleDistortion::DcBlocker::setCutoff(float cutoffHz, float sampleRate)
{
    if (!std::isfinite(cutoffHz) || !std::isfinite(sampleRate) || sampleRate <= 0.0f) {
        coefficient = 0.995f;
        return;
    }

    const float maxCutoff = sampleRate * 0.45f;
    const float safeCutoff = RatStyleDistortion::clamp(cutoffHz, 1.0f, maxCutoff);
    coefficient = std::exp(-2.0f * kPi * safeCutoff / sampleRate);
}

void RatStyleDistortion::DcBlocker::reset()
{
    previousInput = 0.0f;
    previousOutput = 0.0f;
}

float RatStyleDistortion::DcBlocker::process(float input)
{
    const float output = RatStyleDistortion::removeDenormal(
        input - previousInput + coefficient * previousOutput);
    previousInput = input;
    previousOutput = output;
    return output;
}

void RatStyleDistortion::OnePoleLowpass::setCoefficient(float value)
{
    coefficient = RatStyleDistortion::clamp(value, 0.0f, 1.0f);
}

void RatStyleDistortion::OnePoleLowpass::reset()
{
    state = 0.0f;
}

float RatStyleDistortion::OnePoleLowpass::process(float input)
{
    state = RatStyleDistortion::removeDenormal(state + coefficient * (input - state));
    return state;
}

void RatStyleDistortion::ChannelState::reset()
{
    inputHighpass.reset();
    opAmpLowpass.reset();
    postClipLowpass.reset();
    toneLowpass.reset();
}

float RatStyleDistortion::clamp(float value, float minimum, float maximum)
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

float RatStyleDistortion::sanitize(float value)
{
    if (!std::isfinite(value)) {
        return 0.0f;
    }
    return clamp(value, -kInternalLimit, kInternalLimit);
}

float RatStyleDistortion::removeDenormal(float value)
{
    return std::fabs(value) < kDenormalLimit ? 0.0f : value;
}

float RatStyleDistortion::hardClip(float value, float threshold)
{
    const float safeThreshold = clamp(threshold, 0.05f, 1.0f);
    return clamp(value, -safeThreshold, safeThreshold) / safeThreshold;
}

float RatStyleDistortion::softLimit(float value)
{
    return std::tanh(clamp(value, -4.0f, 4.0f));
}

float RatStyleDistortion::lowpassCoefficient(float cutoffHz) const
{
    const float maxCutoff = sampleRate_ * 0.45f;
    const float safeCutoff = clamp(cutoffHz, 10.0f, maxCutoff);
    return 1.0f - std::exp(-2.0f * kPi * safeCutoff / sampleRate_);
}

float RatStyleDistortion::processChannel(float input,
                                         std::size_t channel,
                                         float preGain,
                                         float clipThreshold,
                                         float opAmpLowpassCoefficient,
                                         float toneLowpassCoefficient,
                                         float outputLevel,
                                         float wetMix)
{
    ChannelState& state = channels_[channel % kChannelCount];
    state.opAmpLowpass.setCoefficient(opAmpLowpassCoefficient);
    state.toneLowpass.setCoefficient(toneLowpassCoefficient);

    const float dry = input;
    float wet = state.inputHighpass.process(input);
    wet = sanitize(wet * preGain);
    wet = state.opAmpLowpass.process(wet);
    wet = hardClip(wet, clipThreshold);
    wet = state.postClipLowpass.process(wet);
    wet = state.toneLowpass.process(wet);
    wet = sanitize(wet * outputLevel);

    const float mixed = dry + (wet - dry) * wetMix;
    return removeDenormal(sanitize(softLimit(mixed)));
}

void RatStyleDistortion::updateDriveTargets(bool immediate)
{
    const float driveCubed = drive_ * drive_ * drive_;

    // RAT-style high gain range: modest drive stays touch-sensitive, max drive pushes fuzz-like clipping.
    const float gain = 2.0f + 98.0f * driveCubed;
    const float threshold = 0.75f - 0.30f * drive_;

    // A reduced bandwidth at high drive approximates the slow op-amp feel without circuit modelling.
    const float opAmpCutoffHz = 8000.0f - 3500.0f * drive_;
    const float opAmpCoefficient = lowpassCoefficient(opAmpCutoffHz);

    if (immediate) {
        preGain_.setImmediate(gain);
        clipThreshold_.setImmediate(threshold);
        opAmpLowpassCoefficient_.setImmediate(opAmpCoefficient);
    } else {
        preGain_.setTarget(gain);
        clipThreshold_.setTarget(threshold);
        opAmpLowpassCoefficient_.setTarget(opAmpCoefficient);
    }
}

void RatStyleDistortion::updateFilterTargets(bool immediate)
{
    // RAT FILTER is reverse-feeling: higher values remove more high frequencies.
    const float cutoffHz = 6500.0f - 5600.0f * filter_;
    const float coefficient = lowpassCoefficient(cutoffHz);

    if (immediate) {
        toneLowpassCoefficient_.setImmediate(coefficient);
    } else {
        toneLowpassCoefficient_.setTarget(coefficient);
    }
}

void RatStyleDistortion::updateLevelTarget(bool immediate)
{
    if (immediate) {
        outputLevel_.setImmediate(level_);
    } else {
        outputLevel_.setTarget(level_);
    }
}

void RatStyleDistortion::updateMixTarget(bool immediate)
{
    if (immediate) {
        wetMix_.setImmediate(mix_);
    } else {
        wetMix_.setTarget(mix_);
    }
}

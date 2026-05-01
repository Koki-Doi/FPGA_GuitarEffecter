#include "CabIRSimulator.h"

#include <cmath>

namespace {
constexpr float kDenormalLimit = 1.0e-20f;
constexpr float kInternalLimit = 16.0f;
constexpr float kSilenceThreshold = 1.0e-5f;
} // namespace

CabIRSimulator::CabIRSimulator()
{
    prepare(sampleRate_);
}

void CabIRSimulator::prepare(float sampleRate)
{
    if (!std::isfinite(sampleRate) || sampleRate < 1000.0f) {
        sampleRate_ = 48000.0f;
    } else {
        sampleRate_ = sampleRate;
    }

    smoothedMix_.prepare(sampleRate_, 0.010f);
    smoothedLevel_.prepare(sampleRate_, 0.010f);
    updateTargets(true);
    reset();
}

void CabIRSimulator::reset()
{
    for (auto& channel : channels_) {
        channel.reset();
    }

    smoothedMix_.setImmediate(smoothedMix_.target);
    smoothedLevel_.setImmediate(smoothedLevel_.target);
}

bool CabIRSimulator::setIR(const float* data, int length)
{
    clearIR();
    if (data == nullptr || length <= 0) {
        return false;
    }

    int start = 0;
    while (start < length && std::fabs(data[start]) < kSilenceThreshold) {
        ++start;
    }
    if (start >= length) {
        return false;
    }

    const int available = length - start;
    irLength_ = available > MaxIRLength ? MaxIRLength : available;

    float peak = 0.0f;
    for (int i = 0; i < irLength_; ++i) {
        const float sample = sanitize(data[start + i]);
        ir_[static_cast<std::size_t>(i)] = sample;
        peak = std::fmax(peak, std::fabs(sample));
    }

    if (peak < kSilenceThreshold) {
        clearIR();
        return false;
    }

    // Keep normal IRs unchanged. Only tame clearly over-hot data to avoid surprise jumps.
    if (peak > 1.0f) {
        const float scale = 0.95f / peak;
        for (int i = 0; i < irLength_; ++i) {
            ir_[static_cast<std::size_t>(i)] *= scale;
        }
    }

    hasIR_ = true;
    reset();
    return true;
}

void CabIRSimulator::clearIR()
{
    ir_.fill(0.0f);
    irLength_ = 0;
    hasIR_ = false;
    reset();
}

void CabIRSimulator::setMix(float value)
{
    mix_ = clamp(value, 0.0f, 1.0f);
    updateTargets(false);
}

void CabIRSimulator::setLevel(float value)
{
    level_ = clamp(value, 0.0f, 1.5f);
    updateTargets(false);
}

void CabIRSimulator::setEnabled(bool enabled)
{
    enabled_ = enabled;
}

float CabIRSimulator::processSample(float input)
{
    return processSample(input, 0);
}

float CabIRSimulator::processSample(float input, std::size_t channel)
{
    const float dry = sanitize(input);
    if (!enabled_ || !hasIR_) {
        return clamp(dry, -1.0f, 1.0f);
    }

    return processChannel(dry, channel, smoothedMix_.next(), smoothedLevel_.next());
}

void CabIRSimulator::processStereo(float& left, float& right)
{
    const float dryLeft = sanitize(left);
    const float dryRight = sanitize(right);
    if (!enabled_ || !hasIR_) {
        left = clamp(dryLeft, -1.0f, 1.0f);
        right = clamp(dryRight, -1.0f, 1.0f);
        return;
    }

    const float mix = smoothedMix_.next();
    const float level = smoothedLevel_.next();
    left = processChannel(dryLeft, 0, mix, level);
    right = processChannel(dryRight, 1, mix, level);
}

void CabIRSimulator::processBlock(const float* input, float* output, std::size_t sampleCount)
{
    if (output == nullptr) {
        return;
    }

    for (std::size_t i = 0; i < sampleCount; ++i) {
        output[i] = processSample(input == nullptr ? 0.0f : input[i], 0);
    }
}

void CabIRSimulator::processBlock(const float* inputLeft,
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

void CabIRSimulator::SmoothValue::prepare(float sampleRate, float timeSeconds)
{
    if (!std::isfinite(sampleRate) || sampleRate <= 0.0f || timeSeconds <= 0.0f) {
        amount = 1.0f;
        return;
    }

    amount = 1.0f - std::exp(-1.0f / (sampleRate * timeSeconds));
}

void CabIRSimulator::SmoothValue::setImmediate(float value)
{
    current = value;
    target = value;
}

void CabIRSimulator::SmoothValue::setTarget(float value)
{
    target = value;
}

float CabIRSimulator::SmoothValue::next()
{
    current += (target - current) * amount;
    if (std::fabs(current - target) < 1.0e-6f) {
        current = target;
    }
    return current;
}

void CabIRSimulator::ChannelState::reset()
{
    delay.fill(0.0f);
    writeIndex = 0;
}

float CabIRSimulator::clamp(float value, float minimum, float maximum)
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

float CabIRSimulator::sanitize(float value)
{
    if (!std::isfinite(value)) {
        return 0.0f;
    }
    return clamp(value, -kInternalLimit, kInternalLimit);
}

float CabIRSimulator::removeDenormal(float value)
{
    return std::fabs(value) < kDenormalLimit ? 0.0f : value;
}

float CabIRSimulator::safetyLimit(float value)
{
    const float x = sanitize(value);
    const float absX = std::fabs(x);
    if (absX <= 0.95f) {
        return x;
    }

    const float sign = x < 0.0f ? -1.0f : 1.0f;
    const float knee = std::min(absX, 4.0f) - 0.95f;
    const float limited = 0.95f + 0.05f * std::tanh(knee * 20.0f);
    return sign * limited;
}

float CabIRSimulator::processChannel(float input, std::size_t channel, float mix, float level)
{
    ChannelState& state = channels_[channel % kChannelCount];
    state.delay[static_cast<std::size_t>(state.writeIndex)] = input;

    float wet = 0.0f;
    int readIndex = state.writeIndex;
    for (int i = 0; i < irLength_; ++i) {
        wet += state.delay[static_cast<std::size_t>(readIndex)] * ir_[static_cast<std::size_t>(i)];
        --readIndex;
        if (readIndex < 0) {
            readIndex = MaxIRLength - 1;
        }
    }

    ++state.writeIndex;
    if (state.writeIndex >= MaxIRLength) {
        state.writeIndex = 0;
    }

    wet = safetyLimit(wet * level);
    const float mixed = input + (wet - input) * mix;
    return removeDenormal(safetyLimit(mixed));
}

void CabIRSimulator::updateTargets(bool immediate)
{
    if (immediate) {
        smoothedMix_.setImmediate(mix_);
        smoothedLevel_.setImmediate(level_);
    } else {
        smoothedMix_.setTarget(mix_);
        smoothedLevel_.setTarget(level_);
    }
}

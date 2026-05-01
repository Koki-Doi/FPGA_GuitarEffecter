#ifndef AUDIO_LAB_SIMPLE_AMP_SIMULATOR_H
#define AUDIO_LAB_SIMPLE_AMP_SIMULATOR_H

#include <array>
#include <cstddef>

class SimpleAmpSimulator {
public:
    SimpleAmpSimulator();

    void prepare(float sampleRate);
    void reset();

    void setInputGain(float value);
    void setBass(float value);
    void setMiddle(float value);
    void setTreble(float value);
    void setPresence(float value);
    void setResonance(float value);
    void setMaster(float value);
    void setCharacter(float value);
    void setEnabled(bool enabled);

    float processSample(float input);
    float processSample(float input, std::size_t channel);
    void processStereo(float& left, float& right);
    void processBlock(const float* input, float* output, std::size_t sampleCount);
    void processBlock(const float* inputLeft,
                      const float* inputRight,
                      float* outputLeft,
                      float* outputRight,
                      std::size_t sampleCount);

private:
    static constexpr std::size_t kChannelCount = 2;

    struct SmoothValue {
        float current = 0.0f;
        float target = 0.0f;
        float amount = 1.0f;

        void prepare(float sampleRate, float timeSeconds);
        void setImmediate(float value);
        void setTarget(float value);
        float next();
    };

    struct DcBlocker {
        float coefficient = 0.995f;
        float previousInput = 0.0f;
        float previousOutput = 0.0f;

        void setCutoff(float cutoffHz, float sampleRate);
        void reset();
        float process(float input);
    };

    struct OnePoleLowpass {
        float coefficient = 0.5f;
        float state = 0.0f;

        void setCoefficient(float value);
        void reset();
        float process(float input);
    };

    struct ChannelState {
        DcBlocker inputHighpass;
        OnePoleLowpass preampLowpass;
        OnePoleLowpass toneLowpass;
        OnePoleLowpass toneHighLowpass;
        OnePoleLowpass resonanceLowpass;
        OnePoleLowpass presenceLowpass;

        void reset();
    };

    static float clamp(float value, float minimum, float maximum);
    static float sanitize(float value);
    static float removeDenormal(float value);
    static float cubicSoftClip(float value, float threshold);
    static float asymmetricWaveshape(float value, float character);
    static float secondPreampStage(float value, float inputGain, float character);
    static float powerAmpSaturate(float value, float character);
    static float softLimit(float value);

    float lowpassCoefficient(float cutoffHz) const;
    float processChannel(float input,
                         std::size_t channel,
                         float inputGain,
                         float bass,
                         float middle,
                         float treble,
                         float presence,
                         float resonance,
                         float master,
                         float character);
    float toneStack(ChannelState& state, float input, float bass, float middle, float treble) const;
    void updateTargets(bool immediate);

    float sampleRate_ = 48000.0f;
    bool enabled_ = false;
    float inputGain_ = 0.35f;
    float bass_ = 0.5f;
    float middle_ = 0.5f;
    float treble_ = 0.5f;
    float presence_ = 0.45f;
    float resonance_ = 0.35f;
    float master_ = 0.8f;
    float character_ = 0.35f;

    SmoothValue smoothedInputGain_;
    SmoothValue smoothedBass_;
    SmoothValue smoothedMiddle_;
    SmoothValue smoothedTreble_;
    SmoothValue smoothedPresence_;
    SmoothValue smoothedResonance_;
    SmoothValue smoothedMaster_;
    SmoothValue smoothedCharacter_;
    std::array<ChannelState, kChannelCount> channels_;
};

#endif

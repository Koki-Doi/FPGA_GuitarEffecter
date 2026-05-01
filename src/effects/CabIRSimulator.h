#ifndef AUDIO_LAB_CAB_IR_SIMULATOR_H
#define AUDIO_LAB_CAB_IR_SIMULATOR_H

#include <array>
#include <cstddef>

class CabIRSimulator {
public:
    static constexpr int MaxIRLength = 512;

    enum class Preset {
        OpenBack1x12 = 0,
        British2x12 = 1,
        ClosedBack4x12 = 2,
    };

    CabIRSimulator();

    void prepare(float sampleRate);
    void reset();

    bool setIR(const float* data, int length);
    bool setPreset(Preset preset);
    void clearIR();

    void setMix(float value);
    void setLevel(float value);
    void setAir(float value);
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

    struct ChannelState {
        std::array<float, MaxIRLength> delay {};
        float toneLowpass = 0.0f;
        int writeIndex = 0;

        void reset();
    };

    static float clamp(float value, float minimum, float maximum);
    static float sanitize(float value);
    static float removeDenormal(float value);
    static float safetyLimit(float value);

    float processChannel(float input, std::size_t channel, float mix, float level, float air);
    void updateTargets(bool immediate);

    float sampleRate_ = 48000.0f;
    bool enabled_ = false;
    bool hasIR_ = false;
    int irLength_ = 0;
    float mix_ = 1.0f;
    float level_ = 1.0f;
    float air_ = 1.0f;

    SmoothValue smoothedMix_;
    SmoothValue smoothedLevel_;
    SmoothValue smoothedAir_;
    std::array<float, MaxIRLength> ir_ {};
    std::array<ChannelState, kChannelCount> channels_;
};

#endif

#ifndef AUDIO_LAB_RAT_STYLE_DISTORTION_H
#define AUDIO_LAB_RAT_STYLE_DISTORTION_H

#include <array>
#include <cstddef>

class RatStyleDistortion {
public:
    RatStyleDistortion();

    void prepare(float sampleRate);
    void reset();

    void setDrive(float value);
    void setFilter(float value);
    void setLevel(float value);
    void setMix(float value);
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
        OnePoleLowpass opAmpLowpass;
        OnePoleLowpass postClipLowpass;
        OnePoleLowpass toneLowpass;

        void reset();
    };

    static float clamp(float value, float minimum, float maximum);
    static float sanitize(float value);
    static float removeDenormal(float value);
    static float hardClip(float value, float threshold);
    static float softLimit(float value);

    float lowpassCoefficient(float cutoffHz) const;
    float processChannel(float input,
                         std::size_t channel,
                         float preGain,
                         float clipThreshold,
                         float opAmpLowpassCoefficient,
                         float toneLowpassCoefficient,
                         float outputLevel,
                         float wetMix);
    void updateDriveTargets(bool immediate);
    void updateFilterTargets(bool immediate);
    void updateLevelTarget(bool immediate);
    void updateMixTarget(bool immediate);

    float sampleRate_ = 48000.0f;
    bool enabled_ = false;
    float drive_ = 0.5f;
    float filter_ = 0.35f;
    float level_ = 0.8f;
    float mix_ = 1.0f;

    SmoothValue preGain_;
    SmoothValue clipThreshold_;
    SmoothValue opAmpLowpassCoefficient_;
    SmoothValue toneLowpassCoefficient_;
    SmoothValue outputLevel_;
    SmoothValue wetMix_;
    std::array<ChannelState, kChannelCount> channels_;
};

#endif

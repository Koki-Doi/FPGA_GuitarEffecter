#include "src/effects/RatStyleDistortion.h"

#include <cassert>
#include <atomic>
#include <cmath>
#include <cstdlib>
#include <iostream>
#include <new>

namespace {
constexpr float kPi = 3.14159265358979323846f;
constexpr float kSampleRate = 48000.0f;
constexpr std::size_t kSampleCount = 2048;

std::atomic<unsigned long long> gAllocations { 0 };

float sineSample(std::size_t index, float frequency)
{
    return 0.25f * std::sin(2.0f * kPi * frequency * static_cast<float>(index) / kSampleRate);
}

void assertFinite(float value)
{
    assert(std::isfinite(value));
}

void runSilenceTest()
{
    RatStyleDistortion effect;
    effect.prepare(kSampleRate);
    effect.setEnabled(true);
    effect.setDrive(1.0f);
    effect.setFilter(1.0f);
    effect.setLevel(1.5f);
    effect.setMix(1.0f);

    for (std::size_t i = 0; i < kSampleCount; ++i) {
        const float output = effect.processSample(0.0f);
        assertFinite(output);
        assert(std::fabs(output) < 1.0e-4f);
    }
}

void runSineTest()
{
    RatStyleDistortion effect;
    effect.prepare(kSampleRate);
    effect.setEnabled(true);
    effect.setDrive(0.7f);
    effect.setFilter(0.35f);
    effect.setLevel(1.0f);
    effect.setMix(1.0f);

    float peak = 0.0f;
    for (std::size_t i = 0; i < kSampleCount; ++i) {
        const float output = effect.processSample(sineSample(i, 1000.0f));
        assertFinite(output);
        peak = std::fmax(peak, std::fabs(output));
    }

    assert(peak <= 1.001f);
}

void runParameterSweepTest()
{
    const float values[] = { 0.0f, 0.5f, 1.0f };

    for (float drive : values) {
        for (float filter : values) {
            for (float level : values) {
                for (float mix : values) {
                    RatStyleDistortion effect;
                    effect.prepare(kSampleRate);
                    effect.setEnabled(true);
                    effect.setDrive(drive);
                    effect.setFilter(filter);
                    effect.setLevel(level * 1.5f);
                    effect.setMix(mix);

                    for (std::size_t i = 0; i < 512; ++i) {
                        assertFinite(effect.processSample(sineSample(i, 1000.0f)));
                    }
                }
            }
        }
    }
}

void runSampleRateTest()
{
    const float sampleRates[] = { 44100.0f, 48000.0f, 96000.0f };

    for (float sampleRate : sampleRates) {
        RatStyleDistortion effect;
        effect.prepare(sampleRate);
        effect.setEnabled(true);
        effect.setDrive(1.0f);
        effect.setFilter(0.5f);
        effect.setLevel(1.0f);

        for (std::size_t i = 0; i < 512; ++i) {
            assertFinite(effect.processSample(0.2f));
        }
    }
}

void runInvalidInputTest()
{
    RatStyleDistortion effect;
    effect.prepare(kSampleRate);
    effect.setEnabled(true);

    assertFinite(effect.processSample(NAN));
    assertFinite(effect.processSample(INFINITY));
    assertFinite(effect.processSample(-INFINITY));

    effect.setEnabled(false);
    assertFinite(effect.processSample(NAN));
    assertFinite(effect.processSample(INFINITY));
    assertFinite(effect.processSample(-INFINITY));
}

void runStereoTest()
{
    RatStyleDistortion effect;
    effect.prepare(kSampleRate);
    effect.setEnabled(true);
    effect.setDrive(0.8f);
    effect.setFilter(0.2f);
    effect.setLevel(1.0f);

    for (std::size_t i = 0; i < 512; ++i) {
        float left = sineSample(i, 440.0f);
        float right = sineSample(i, 1320.0f);
        effect.processStereo(left, right);
        assertFinite(left);
        assertFinite(right);
    }
}

void runAllocationTest()
{
    RatStyleDistortion effect;
    effect.prepare(kSampleRate);
    effect.setEnabled(true);
    effect.setDrive(0.9f);
    effect.setFilter(0.6f);
    effect.setLevel(1.0f);

    const unsigned long long before = gAllocations.load();
    for (std::size_t i = 0; i < kSampleCount; ++i) {
        static_cast<void>(effect.processSample(sineSample(i, 1000.0f)));
    }
    const unsigned long long after = gAllocations.load();
    assert(before == after);
}

void printDemoPeaks()
{
    const float drives[] = { 0.2f, 0.6f, 1.0f };
    const float filters[] = { 0.0f, 0.5f, 1.0f };

    for (float drive : drives) {
        for (float filter : filters) {
            RatStyleDistortion effect;
            effect.prepare(kSampleRate);
            effect.setEnabled(true);
            effect.setDrive(drive);
            effect.setFilter(filter);
            effect.setLevel(1.0f);
            effect.setMix(1.0f);
            effect.reset();

            float peak = 0.0f;
            for (std::size_t i = 0; i < kSampleCount; ++i) {
                const float output = effect.processSample(sineSample(i, 1000.0f));
                assertFinite(output);
                peak = std::fmax(peak, std::fabs(output));
            }

            std::cout << "drive=" << drive << " filter=" << filter << " peak=" << peak << '\n';
        }
    }
}
} // namespace

void* operator new(std::size_t size)
{
    gAllocations.fetch_add(1, std::memory_order_relaxed);
    if (void* pointer = std::malloc(size)) {
        return pointer;
    }
    throw std::bad_alloc();
}

void* operator new[](std::size_t size)
{
    gAllocations.fetch_add(1, std::memory_order_relaxed);
    if (void* pointer = std::malloc(size)) {
        return pointer;
    }
    throw std::bad_alloc();
}

void operator delete(void* pointer) noexcept
{
    std::free(pointer);
}

void operator delete(void* pointer, std::size_t) noexcept
{
    std::free(pointer);
}

void operator delete[](void* pointer) noexcept
{
    std::free(pointer);
}

void operator delete[](void* pointer, std::size_t) noexcept
{
    std::free(pointer);
}

int main()
{
    runSilenceTest();
    runSineTest();
    runParameterSweepTest();
    runSampleRateTest();
    runInvalidInputTest();
    runStereoTest();
    runAllocationTest();
    printDemoPeaks();

    std::cout << "RatStyleDistortion tests passed\n";
    return 0;
}

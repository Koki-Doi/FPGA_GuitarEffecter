#include "src/effects/CabIRSimulator.h"
#include "src/effects/SimpleAmpSimulator.h"

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

void runAmpSilenceTest()
{
    SimpleAmpSimulator amp;
    amp.prepare(kSampleRate);
    amp.setEnabled(true);
    amp.setInputGain(1.0f);
    amp.setBass(1.0f);
    amp.setMiddle(1.0f);
    amp.setTreble(1.0f);
    amp.setPresence(1.0f);
    amp.setResonance(1.0f);
    amp.setMaster(1.5f);
    amp.setCharacter(1.0f);
    amp.reset();

    for (std::size_t i = 0; i < kSampleCount; ++i) {
        const float output = amp.processSample(0.0f);
        assertFinite(output);
        assert(std::fabs(output) < 1.0e-4f);
    }
}

void runAmpSineTest()
{
    SimpleAmpSimulator amp;
    amp.prepare(kSampleRate);
    amp.setEnabled(true);
    amp.setInputGain(0.65f);
    amp.setBass(0.5f);
    amp.setMiddle(0.6f);
    amp.setTreble(0.55f);
    amp.setPresence(0.5f);
    amp.setResonance(0.5f);
    amp.setMaster(0.9f);
    amp.setCharacter(0.55f);
    amp.reset();

    float peak = 0.0f;
    for (std::size_t i = 0; i < kSampleCount; ++i) {
        const float output = amp.processSample(sineSample(i, 1000.0f));
        assertFinite(output);
        peak = std::fmax(peak, std::fabs(output));
    }

    assert(peak <= 1.001f);
}

void runAmpParameterSweepTest()
{
    const float values[] = { 0.0f, 0.5f, 1.0f };

    for (float inputGain : values) {
        for (float bass : values) {
            for (float middle : values) {
                for (float treble : values) {
                    for (float presence : values) {
                        for (float resonance : values) {
                            for (float master : values) {
                                SimpleAmpSimulator amp;
                                amp.prepare(kSampleRate);
                                amp.setEnabled(true);
                                amp.setInputGain(inputGain);
                                amp.setBass(bass);
                                amp.setMiddle(middle);
                                amp.setTreble(treble);
                                amp.setPresence(presence);
                                amp.setResonance(resonance);
                                amp.setMaster(master * 1.5f);
                                amp.setCharacter(inputGain);
                                amp.reset();

                                for (std::size_t i = 0; i < 128; ++i) {
                                    const float output = amp.processSample(sineSample(i, 1000.0f));
                                    assertFinite(output);
                                    assert(std::fabs(output) <= 1.001f);
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}

void runAmpResetAndInvalidInputTest()
{
    SimpleAmpSimulator amp;
    amp.prepare(44100.0f);
    amp.setEnabled(true);
    amp.setInputGain(0.8f);
    amp.setMaster(1.0f);
    amp.reset();

    assertFinite(amp.processSample(NAN));
    assertFinite(amp.processSample(INFINITY));
    assertFinite(amp.processSample(-INFINITY));
    amp.reset();
    assertFinite(amp.processSample(0.25f));
}

void runCabDryWhenUnsetTest()
{
    CabIRSimulator cab;
    cab.prepare(kSampleRate);
    cab.setEnabled(true);
    cab.setMix(1.0f);
    cab.setLevel(1.0f);
    cab.reset();

    const float output = cab.processSample(0.25f);
    assertFinite(output);
    assert(std::fabs(output - 0.25f) < 1.0e-6f);
}

void runCabImpulseTest()
{
    const float ir[] = { 1.0f, 0.0f, 0.0f, 0.0f };

    CabIRSimulator cab;
    cab.prepare(kSampleRate);
    assert(cab.setIR(ir, 4));
    cab.setEnabled(true);
    cab.setMix(1.0f);
    cab.setLevel(1.0f);
    cab.reset();

    for (std::size_t i = 0; i < 64; ++i) {
        const float input = sineSample(i, 1000.0f);
        const float output = cab.processSample(input);
        assertFinite(output);
        assert(std::fabs(output - input) < 1.0e-6f);
    }
}

void runCabConvolutionTest()
{
    const float ir[] = { 0.5f, 0.25f, 0.125f };

    CabIRSimulator cab;
    cab.prepare(kSampleRate);
    assert(cab.setIR(ir, 3));
    cab.setEnabled(true);
    cab.setMix(1.0f);
    cab.setLevel(1.0f);
    cab.reset();

    const float y0 = cab.processSample(1.0f);
    const float y1 = cab.processSample(0.0f);
    const float y2 = cab.processSample(0.0f);
    const float y3 = cab.processSample(0.0f);

    assert(std::fabs(y0 - 0.5f) < 1.0e-6f);
    assert(std::fabs(y1 - 0.25f) < 1.0e-6f);
    assert(std::fabs(y2 - 0.125f) < 1.0e-6f);
    assert(std::fabs(y3) < 1.0e-6f);
}

void runCabLongIrAndMixTest()
{
    float ir[CabIRSimulator::MaxIRLength + 32] = {};
    ir[0] = 0.0f;
    ir[1] = 0.0f;
    ir[2] = 1.0f;
    for (int i = 3; i < CabIRSimulator::MaxIRLength + 32; ++i) {
        ir[i] = 0.001f;
    }

    CabIRSimulator cab;
    cab.prepare(kSampleRate);
    assert(cab.setIR(ir, CabIRSimulator::MaxIRLength + 32));
    cab.setEnabled(true);
    cab.setMix(0.0f);
    cab.setLevel(1.0f);
    cab.reset();
    assert(std::fabs(cab.processSample(0.25f) - 0.25f) < 1.0e-6f);

    cab.setMix(1.0f);
    cab.reset();
    const float wet = cab.processSample(0.25f);
    assertFinite(wet);
    assert(std::fabs(wet - 0.25f) < 1.0e-6f);
}

void runCabPresetAndAirTest()
{
    for (CabIRSimulator::Preset preset : {
             CabIRSimulator::Preset::OpenBack1x12,
             CabIRSimulator::Preset::British2x12,
             CabIRSimulator::Preset::ClosedBack4x12,
         }) {
        CabIRSimulator cab;
        cab.prepare(kSampleRate);
        assert(cab.setPreset(preset));
        cab.setEnabled(true);
        cab.setMix(1.0f);
        cab.setLevel(0.9f);
        cab.setAir(0.45f);
        cab.reset();

        float peak = 0.0f;
        for (std::size_t i = 0; i < kSampleCount; ++i) {
            const float output = cab.processSample(sineSample(i, 1000.0f));
            assertFinite(output);
            peak = std::fmax(peak, std::fabs(output));
        }
        assert(peak <= 1.001f);
    }
}

void runIntegratedAmpCabTest()
{
    const float ir[] = { 0.8f, 0.4f, 0.2f, 0.1f };

    SimpleAmpSimulator amp;
    amp.prepare(kSampleRate);
    amp.setEnabled(true);
    amp.setInputGain(0.6f);
    amp.setBass(0.5f);
    amp.setMiddle(0.5f);
    amp.setTreble(0.5f);
    amp.setPresence(0.5f);
    amp.setResonance(0.5f);
    amp.setMaster(0.8f);
    amp.setCharacter(0.5f);
    amp.reset();

    CabIRSimulator cab;
    cab.prepare(kSampleRate);
    assert(cab.setIR(ir, 4));
    cab.setEnabled(true);
    cab.setMix(1.0f);
    cab.setLevel(0.9f);
    cab.reset();

    float peak = 0.0f;
    for (std::size_t i = 0; i < kSampleCount; ++i) {
        const float ampOut = amp.processSample(sineSample(i, 1000.0f));
        const float cabOut = cab.processSample(ampOut);
        assertFinite(cabOut);
        peak = std::fmax(peak, std::fabs(cabOut));
    }

    assert(peak <= 1.001f);
    std::cout << "amp+cab integrated peak=" << peak << '\n';
}

void runAllocationTest()
{
    const float ir[] = { 0.8f, 0.4f, 0.2f, 0.1f };

    SimpleAmpSimulator amp;
    amp.prepare(kSampleRate);
    amp.setEnabled(true);
    amp.setInputGain(0.7f);
    amp.setMaster(0.8f);
    amp.reset();

    CabIRSimulator cab;
    cab.prepare(kSampleRate);
    assert(cab.setIR(ir, 4));
    cab.setEnabled(true);
    cab.setMix(1.0f);
    cab.reset();

    const unsigned long long before = gAllocations.load();
    for (std::size_t i = 0; i < kSampleCount; ++i) {
        static_cast<void>(cab.processSample(amp.processSample(sineSample(i, 1000.0f))));
    }
    const unsigned long long after = gAllocations.load();
    assert(before == after);
}

void printDemoPeaks()
{
    const float gains[] = { 0.2f, 0.6f, 1.0f };
    const float ir[] = { 0.8f, 0.4f, 0.2f, 0.1f };

    for (float inputGain : gains) {
        SimpleAmpSimulator amp;
        amp.prepare(kSampleRate);
        amp.setEnabled(true);
        amp.setInputGain(inputGain);
        amp.setBass(0.5f);
        amp.setMiddle(0.5f);
        amp.setTreble(0.5f);
        amp.setPresence(0.5f);
        amp.setResonance(0.5f);
        amp.setMaster(0.8f);
        amp.setCharacter(inputGain);
        amp.reset();

        CabIRSimulator cab;
        cab.prepare(kSampleRate);
        assert(cab.setIR(ir, 4));
        cab.setEnabled(true);
        cab.setMix(1.0f);
        cab.setLevel(0.9f);
        cab.reset();

        float peak = 0.0f;
        for (std::size_t i = 0; i < kSampleCount; ++i) {
            const float output = cab.processSample(amp.processSample(sineSample(i, 1000.0f)));
            assertFinite(output);
            peak = std::fmax(peak, std::fabs(output));
        }

        std::cout << "inputGain=" << inputGain << " amp+cab peak=" << peak << '\n';
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
    runAmpSilenceTest();
    runAmpSineTest();
    runAmpParameterSweepTest();
    runAmpResetAndInvalidInputTest();
    runCabDryWhenUnsetTest();
    runCabImpulseTest();
    runCabConvolutionTest();
    runCabLongIrAndMixTest();
    runCabPresetAndAirTest();
    runIntegratedAmpCabTest();
    runAllocationTest();
    printDemoPeaks();

    std::cout << "SimpleAmpSimulator and CabIRSimulator tests passed\n";
    return 0;
}

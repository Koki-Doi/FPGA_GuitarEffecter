#!/usr/bin/env python3
"""Generate compact analysis plots for effect recording comparisons.

The script expects one WAV per effect in a directory. File names are matched
case-insensitively against effect labels such as "Bypass", "Overdrive", or
"DS-1"; unmatched WAVs are still included under their stem name. A Bypass WAV
is required for the difference plots.
"""

import argparse
import json
import math
import wave
from pathlib import Path
from typing import Dict, List, Tuple

import matplotlib

matplotlib.use("Agg")
import matplotlib.pyplot as plt
import numpy as np


EFFECT_ORDER = (
    "Bypass",
    "NoiseSuppressor",
    "Compressor",
    "Overdrive",
    "DS-1",
    "AmpSim",
    "Cabinet",
    "Reverb",
)

MATCH_KEYS = (
    ("NoiseSuppressor", ("noisesuppressor", "noise_suppressor", "noise-suppressor", "ns")),
    ("Compressor", ("compressor", "comp")),
    ("Overdrive", ("overdrive", "od")),
    ("DS-1", ("ds-1", "ds1")),
    ("AmpSim", ("ampsim", "amp_sim", "amp-sim", "amp")),
    ("Cabinet", ("cabinet", "cab", "cabir", "cab_ir")),
    ("Reverb", ("reverb", "rev")),
    ("Bypass", ("bypass", "safe_bypass", "dry")),
)


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Analyze effect WAV recordings and generate comparison plots."
    )
    parser.add_argument("wav_dir", type=Path, help="Directory containing WAV recordings.")
    parser.add_argument("output_dir", type=Path, help="Directory for generated PNG/JSON files.")
    parser.add_argument(
        "--analysis-sr",
        type=int,
        default=16000,
        help="Downsample target for plotting/FFT. Use 0 to keep original rate.",
    )
    parser.add_argument(
        "--high-band-low",
        type=float,
        default=5000.0,
        help="Low edge of the high-frequency energy band in Hz.",
    )
    parser.add_argument(
        "--high-band-high",
        type=float,
        default=7500.0,
        help="High edge of the high-frequency energy band in Hz.",
    )
    parser.add_argument(
        "--max-seconds",
        type=float,
        default=0.0,
        help="Optional maximum duration to analyze per file. 0 means full file.",
    )
    parser.add_argument(
        "--rms-window-ms",
        type=float,
        default=46.0,
        help="Short-time RMS window in milliseconds.",
    )
    return parser.parse_args()


def pcm24_to_int32(raw: bytes) -> np.ndarray:
    data = np.frombuffer(raw, dtype=np.uint8)
    if len(data) % 3:
        data = data[: len(data) - (len(data) % 3)]
    triples = data.reshape(-1, 3).astype(np.int32)
    values = triples[:, 0] | (triples[:, 1] << 8) | (triples[:, 2] << 16)
    sign = values & 0x800000
    return values - (sign << 1)


def read_wav(path: Path) -> Tuple[int, np.ndarray]:
    with wave.open(str(path), "rb") as wav:
        channels = wav.getnchannels()
        sample_width = wav.getsampwidth()
        sample_rate = wav.getframerate()
        frames = wav.readframes(wav.getnframes())

    if sample_width == 1:
        data = np.frombuffer(frames, dtype=np.uint8).astype(np.float32)
        data = (data - 128.0) / 128.0
    elif sample_width == 2:
        data = np.frombuffer(frames, dtype="<i2").astype(np.float32) / 32768.0
    elif sample_width == 3:
        data = pcm24_to_int32(frames).astype(np.float32) / 8388608.0
    elif sample_width == 4:
        data = np.frombuffer(frames, dtype="<i4").astype(np.float32) / 2147483648.0
    else:
        raise ValueError("unsupported WAV sample width {} in {}".format(sample_width, path))

    if channels > 1:
        data = data.reshape(-1, channels).mean(axis=1)
    return sample_rate, np.clip(data, -1.0, 1.0)


def canonical_name(path: Path) -> str:
    stem = path.stem.lower().replace(" ", "_")
    for label, keys in MATCH_KEYS:
        if any(key in stem for key in keys):
            return label
    return path.stem


def load_recordings(wav_dir: Path, analysis_sr: int, max_seconds: float) -> Dict[str, Tuple[int, np.ndarray]]:
    recordings = {}  # type: Dict[str, Tuple[int, np.ndarray]]
    for path in sorted(wav_dir.glob("*.wav")):
        sample_rate, data = read_wav(path)
        if max_seconds > 0:
            data = data[: int(sample_rate * max_seconds)]
        if analysis_sr and sample_rate > analysis_sr:
            step = max(1, int(round(float(sample_rate) / float(analysis_sr))))
            data = data[::step]
            sample_rate = int(round(float(sample_rate) / float(step)))
        recordings[canonical_name(path)] = (sample_rate, data)
    return recordings


def ordered_items(recordings: Dict[str, Tuple[int, np.ndarray]]) -> List[Tuple[str, int, np.ndarray]]:
    labels = [label for label in EFFECT_ORDER if label in recordings]
    labels.extend(sorted(label for label in recordings if label not in labels))
    return [(label, recordings[label][0], recordings[label][1]) for label in labels]


def st_rms(data: np.ndarray, sample_rate: int, window_ms: float) -> Tuple[np.ndarray, np.ndarray]:
    win = max(16, int(sample_rate * window_ms / 1000.0))
    hop = max(1, win // 4)
    if len(data) < win:
        rms = np.array([math.sqrt(float(np.mean(data * data)))], dtype=np.float32)
        return np.array([0.0]), rms
    values = []
    times = []
    for start in range(0, len(data) - win + 1, hop):
        chunk = data[start : start + win]
        values.append(math.sqrt(float(np.mean(chunk * chunk))))
        times.append((start + win / 2.0) / sample_rate)
    return np.asarray(times), np.asarray(values)


def mean_spectrum(data: np.ndarray, sample_rate: int) -> Tuple[np.ndarray, np.ndarray]:
    n = min(max(2048, 1 << int(math.floor(math.log(max(len(data), 2), 2)))), 16384)
    if len(data) < n:
        padded = np.zeros(n, dtype=np.float32)
        padded[: len(data)] = data
        data = padded
    hop = n // 2
    window = np.hanning(n)
    specs = []
    for start in range(0, len(data) - n + 1, hop):
        frame = data[start : start + n] * window
        specs.append(np.abs(np.fft.rfft(frame)))
    if not specs:
        specs = [np.abs(np.fft.rfft(data[:n] * window))]
    mag = np.mean(np.vstack(specs), axis=0)
    freqs = np.fft.rfftfreq(n, 1.0 / sample_rate)
    return freqs, mag


def db(x: np.ndarray, floor: float = 1.0e-12) -> np.ndarray:
    return 20.0 * np.log10(np.maximum(x, floor))


def high_band_energy(data: np.ndarray, sample_rate: int, low_hz: float, high_hz: float) -> float:
    freqs, mag = mean_spectrum(data, sample_rate)
    high_hz = min(high_hz, sample_rate / 2.0)
    mask = (freqs >= low_hz) & (freqs <= high_hz)
    if not np.any(mask):
        return 0.0
    return float(np.mean(np.square(mag[mask])))


def first_attack_window(data: np.ndarray, sample_rate: int, before_ms: float = 10.0, after_ms: float = 90.0) -> Tuple[np.ndarray, np.ndarray]:
    peak = float(np.max(np.abs(data))) if len(data) else 0.0
    if peak <= 0.0:
        start = 0
    else:
        threshold = peak * 0.12
        above = np.flatnonzero(np.abs(data) >= threshold)
        start = int(above[0]) if len(above) else 0
    first = max(0, start - int(sample_rate * before_ms / 1000.0))
    last = min(len(data), start + int(sample_rate * after_ms / 1000.0))
    chunk = data[first:last]
    times = (np.arange(first, last) - start) / float(sample_rate) * 1000.0
    return times, chunk


def align_to_bypass(label: str, recordings: Dict[str, Tuple[int, np.ndarray]]) -> Tuple[int, np.ndarray, np.ndarray]:
    bypass_sr, bypass = recordings["Bypass"]
    sample_rate, data = recordings[label]
    if sample_rate != bypass_sr:
        raise ValueError("sample-rate mismatch for {} vs Bypass".format(label))
    n = min(len(bypass), len(data))
    return sample_rate, data[:n], bypass[:n]


def save_rms_plot(items: List[Tuple[str, int, np.ndarray]], output_dir: Path, window_ms: float) -> None:
    plt.figure(figsize=(11, 6))
    for label, sample_rate, data in items:
        times, rms = st_rms(data, sample_rate, window_ms)
        plt.plot(times, db(rms), label=label, linewidth=1.2)
    plt.xlabel("Time (s)")
    plt.ylabel("Short-time RMS (dBFS)")
    plt.title("Short-time RMS")
    plt.legend(fontsize=8)
    plt.grid(True, alpha=0.3)
    plt.tight_layout()
    plt.savefig(output_dir / "01_short_time_rms.png", dpi=150)
    plt.close()


def save_mean_spectrum_plot(items: List[Tuple[str, int, np.ndarray]], output_dir: Path) -> None:
    plt.figure(figsize=(11, 6))
    for label, sample_rate, data in items:
        freqs, mag = mean_spectrum(data, sample_rate)
        plt.plot(freqs, db(mag), label=label, linewidth=1.0)
    plt.xlabel("Frequency (Hz)")
    plt.ylabel("Mean magnitude (dB)")
    plt.title("Mean frequency spectrum")
    plt.xlim(20, max(item[1] for item in items) / 2.0)
    plt.xscale("log")
    plt.legend(fontsize=8)
    plt.grid(True, which="both", alpha=0.3)
    plt.tight_layout()
    plt.savefig(output_dir / "02_mean_spectrum.png", dpi=150)
    plt.close()


def save_bar(labels: List[str], values: List[float], ylabel: str, title: str, path: Path) -> None:
    plt.figure(figsize=(10, 5))
    x = np.arange(len(labels))
    plt.bar(x, values)
    plt.xticks(x, labels, rotation=30, ha="right")
    plt.ylabel(ylabel)
    plt.title(title)
    plt.grid(True, axis="y", alpha=0.3)
    plt.tight_layout()
    plt.savefig(path, dpi=150)
    plt.close()


def save_noise_floor_plot(items: List[Tuple[str, int, np.ndarray]], output_dir: Path) -> None:
    labels = []
    values = []
    for label, sample_rate, data in items:
        first = data[: int(sample_rate * 5.0)]
        labels.append(label)
        values.append(float(db(np.array([math.sqrt(float(np.mean(first * first))) if len(first) else 0.0]))[0]))
    save_bar(labels, values, "First 5s RMS (dBFS)", "First 5s noise floor", output_dir / "04_noise_floor_first5s.png")


def save_attack_plot(items: List[Tuple[str, int, np.ndarray]], output_dir: Path) -> None:
    plt.figure(figsize=(11, 6))
    for label, sample_rate, data in items:
        times, attack = first_attack_window(data, sample_rate)
        plt.plot(times, attack, label=label, linewidth=1.0)
    plt.xlabel("Time around attack (ms)")
    plt.ylabel("Amplitude")
    plt.title("Attack waveform")
    plt.legend(fontsize=8)
    plt.grid(True, alpha=0.3)
    plt.tight_layout()
    plt.savefig(output_dir / "05_attack_waveforms.png", dpi=150)
    plt.close()


def save_diff_waveforms(recordings: Dict[str, Tuple[int, np.ndarray]], output_dir: Path) -> None:
    if "Bypass" not in recordings:
        return
    plt.figure(figsize=(11, 6))
    for label in [label for label in EFFECT_ORDER if label in recordings and label != "Bypass"]:
        sample_rate, data, bypass = align_to_bypass(label, recordings)
        n = min(len(data), int(sample_rate * 1.0))
        times = np.arange(n) / float(sample_rate)
        plt.plot(times, data[:n] - bypass[:n], label=label, linewidth=0.9)
    plt.xlabel("Time (s)")
    plt.ylabel("Effect - Bypass")
    plt.title("Difference waveform vs Bypass (first 1s)")
    plt.legend(fontsize=8)
    plt.grid(True, alpha=0.3)
    plt.tight_layout()
    plt.savefig(output_dir / "06_difference_waveforms_vs_bypass.png", dpi=150)
    plt.close()


def save_diff_spectra(recordings: Dict[str, Tuple[int, np.ndarray]], output_dir: Path) -> None:
    if "Bypass" not in recordings:
        return
    plt.figure(figsize=(11, 6))
    for label in [label for label in EFFECT_ORDER if label in recordings and label != "Bypass"]:
        sample_rate, data, bypass = align_to_bypass(label, recordings)
        freqs, mag = mean_spectrum(data - bypass, sample_rate)
        plt.plot(freqs, db(mag), label=label, linewidth=1.0)
    plt.xlabel("Frequency (Hz)")
    plt.ylabel("Difference magnitude (dB)")
    plt.title("Difference spectrum vs Bypass")
    plt.xscale("log")
    plt.legend(fontsize=8)
    plt.grid(True, which="both", alpha=0.3)
    plt.tight_layout()
    plt.savefig(output_dir / "07_difference_spectrum_vs_bypass.png", dpi=150)
    plt.close()


def save_spectrograms(items: List[Tuple[str, int, np.ndarray]], output_dir: Path) -> None:
    count = len(items)
    cols = 2
    rows = int(math.ceil(count / float(cols)))
    fig, axes = plt.subplots(rows, cols, figsize=(12, 3.2 * rows), squeeze=False)
    for ax in axes.ravel():
        ax.axis("off")
    for ax, (label, sample_rate, data) in zip(axes.ravel(), items):
        ax.axis("on")
        ax.specgram(data, NFFT=1024, Fs=sample_rate, noverlap=768, cmap="magma")
        ax.set_title(label)
        ax.set_xlabel("Time (s)")
        ax.set_ylabel("Frequency (Hz)")
        ax.set_ylim(0, min(sample_rate / 2.0, 8000.0))
    fig.tight_layout()
    fig.savefig(output_dir / "09_spectrograms.png", dpi=150)
    plt.close(fig)


def main() -> int:
    args = parse_args()
    args.output_dir.mkdir(parents=True, exist_ok=True)
    recordings = load_recordings(args.wav_dir, args.analysis_sr, args.max_seconds)
    if not recordings:
        raise SystemExit("no WAV files found in {}".format(args.wav_dir))
    items = ordered_items(recordings)

    save_rms_plot(items, args.output_dir, args.rms_window_ms)
    save_mean_spectrum_plot(items, args.output_dir)

    labels = [label for label, _sr, _data in items]
    high_values = [
        high_band_energy(data, sample_rate, args.high_band_low, args.high_band_high)
        for label, sample_rate, data in items
    ]
    save_bar(labels, high_values, "Mean squared magnitude", "High-frequency energy", args.output_dir / "03_high_frequency_energy.png")
    save_noise_floor_plot(items, args.output_dir)
    save_attack_plot(items, args.output_dir)
    save_diff_waveforms(recordings, args.output_dir)
    save_diff_spectra(recordings, args.output_dir)

    if "Bypass" in recordings:
        bypass_energy = high_band_energy(
            recordings["Bypass"][1],
            recordings["Bypass"][0],
            args.high_band_low,
            args.high_band_high,
        )
        delta_labels = []
        delta_values = []
        for label, sample_rate, data in items:
            if label == "Bypass":
                continue
            delta_labels.append(label)
            delta_values.append(
                high_band_energy(data, sample_rate, args.high_band_low, args.high_band_high)
                - bypass_energy
            )
        save_bar(delta_labels, delta_values, "Energy delta", "High-frequency energy change vs Bypass", args.output_dir / "08_high_energy_delta_vs_bypass.png")

    save_spectrograms(items, args.output_dir)

    summary = {
        "effects": labels,
        "analysis_sr": args.analysis_sr,
        "high_band_hz": [args.high_band_low, args.high_band_high],
        "high_frequency_energy": dict(zip(labels, high_values)),
        "notes": [
            "Plots may use simple decimation for speed when --analysis-sr is below the WAV sample rate.",
            "High-frequency assessment defaults to 5 kHz through 7.5 kHz for comparability with the lightweight visualization pass.",
        ],
    }
    (args.output_dir / "analysis_summary.json").write_text(json.dumps(summary, indent=2), encoding="utf-8")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

#!/usr/bin/env python3
"""Render a short Sound Lab WAV using only the Python standard library."""

import argparse
from array import array
from datetime import datetime
from math import cos, exp, pi, sin, sqrt, tanh
from pathlib import Path
import os
import shutil
import sys
import tempfile
import wave


def read_wav(path: Path):
    with wave.open(str(path), "rb") as wav:
        channels = wav.getnchannels()
        rate = wav.getframerate()
        if channels not in (1, 2) or wav.getsampwidth() != 2 or wav.getcomptype() != "NONE":
            raise ValueError("Sound Lab currently edits mono or stereo 16-bit PCM WAVs.")
        data = array("h")
        data.frombytes(wav.readframes(wav.getnframes()))
        if sys.byteorder != "little":
            data.byteswap()
    return rate, [[sample / 32768.0 for sample in data[c::channels]] for c in range(channels)]


def change_pitch(samples, factor):
    if abs(factor - 1.0) < 0.0001:
        return samples[:]
    count = max(1, int(len(samples) / factor))
    result = []
    for index in range(count):
        position = index * factor
        left = min(int(position), len(samples) - 1)
        right = min(left + 1, len(samples) - 1)
        fraction = position - left
        result.append(samples[left] * (1 - fraction) + samples[right] * fraction)
    return result


def change_tempo(samples, stretch, rate):
    """Overlap-add short Hann-windowed grains, preserving approximate pitch."""
    if abs(stretch - 1.0) < 0.005 or len(samples) < 256:
        return samples[:]
    window = 512 if rate <= 24000 else 1024
    source_hop = window // 4
    length = max(1, round(len(samples) * stretch))
    output = [0.0] * (length + window)
    weights = [0.0] * (length + window)
    shape = [0.5 - 0.5 * cos(2 * pi * i / (window - 1)) for i in range(window)]
    for start in range(-window // 2, len(samples), source_hop):
        dest = round((start + window // 2) * stretch) - window // 2
        for i in range(window):
            src = start + i
            dst = dest + i
            if 0 <= src < len(samples) and 0 <= dst < length:
                weight = shape[i]
                output[dst] += samples[src] * weight
                weights[dst] += weight
    return [output[i] / weights[i] if weights[i] > 0.001 else 0.0 for i in range(length)]


def process_channel(samples, rate, pitch, tempo, lowpass, highpass, grit):
    # Resampling changes pitch and duration. Grain stretching compensates so
    # tempo can be adjusted separately from the new pitch.
    result = change_pitch(samples, pitch)
    result = change_tempo(result, pitch / tempo, rate)
    if lowpass < min(12000, rate * 0.45):
        coefficient = 1.0 - exp(-2 * pi * lowpass / rate)
        previous = 0.0
        for i, value in enumerate(result):
            previous += coefficient * (value - previous)
            result[i] = previous
    if highpass > 20:
        coefficient = 1.0 - exp(-2 * pi * highpass / rate)
        previous = 0.0
        for i, value in enumerate(result):
            previous += coefficient * (value - previous)
            result[i] = value - previous
    if grit > 0:
        rms = sqrt(sum(value * value for value in result) / len(result))
        if rms > 0.000001:
            input_gain = min(12.0, 0.24 / rms)
            drive = 1.0 + grit * 22.0
            wet = [tanh(value * input_gain * drive) for value in result]
            # At stronger settings, sample holding and fewer amplitude steps
            # make the roughness audible on quiet, short cues too.
            crush = max(0.0, (grit - 0.15) / 0.85)
            if crush > 0:
                hold = max(1, round(1 + crush * rate / 5500))
                steps = max(16, round(256 - 240 * crush))
                wet = [round(wet[index - index % hold] * steps) / steps
                       for index in range(len(wet))]
            wet_rms = sqrt(sum(value * value for value in wet) / len(wet))
            wet_gain = rms / max(wet_rms, 0.000001)
            result = [dry * (1 - grit) + changed * wet_gain * grit
                      for dry, changed in zip(result, wet)]
    return result


def add_room_reverb(samples, rate, amount, channel_index):
    """Dark early reflections with a short, decaying tail; dry signal stays clear."""
    if amount <= 0:
        return samples
    duration = 0.20 + 0.50 * amount
    tail = round(duration * rate)
    wet = [0.0] * (len(samples) + tail)
    taps = (0.027, 0.035, 0.046, 0.061, 0.077, 0.098, 0.124,
            0.159, 0.204, 0.263, 0.337, 0.431, 0.551, 0.691)
    for tap in taps:
        if tap >= duration:
            break
        delay = round((tap + channel_index * 0.003) * rate)
        strength = 0.34 * exp(-2.0 * tap / duration)
        for index, value in enumerate(samples):
            wet[index + delay] += value * strength
    # Soften high frequencies only in the reflections, like a stone room.
    coefficient = 1.0 - exp(-2 * pi * 3200 / rate)
    previous = 0.0
    for index, value in enumerate(wet):
        previous += coefficient * (value - previous)
        wet[index] = previous
    result = [0.0] * len(wet)
    for index in range(len(wet)):
        dry = samples[index] if index < len(samples) else 0.0
        result[index] = dry + amount * wet[index]
    fade = min(round(rate * 0.04), tail)
    for index in range(len(result) - fade, len(result)):
        result[index] *= (len(result) - index - 1) / max(1, fade - 1)
    return result


def render(source, output, volume, pitch, tempo, lowpass, highpass, sine_hz,
           sine_mix, grit, reverb, trim_start, trim_end, fade_out, backup):
    rate, channels = read_wav(source)
    if max(len(channel) for channel in channels) > rate * 30:
        raise ValueError("Trim source recordings to 30 seconds before using Sound Lab.")
    start = round(len(channels[0]) * trim_start)
    end = round(len(channels[0]) * trim_end)
    if end - start < 32:
        raise ValueError("Trim end must be later than trim start.")
    channels = [channel[start:end] for channel in channels]
    processed = [process_channel(channel, rate, pitch, tempo, lowpass, highpass, grit)
                 for channel in channels]
    if reverb > 0:
        processed = [add_room_reverb(channel, rate, reverb, index)
                     for index, channel in enumerate(processed)]
    count = min(map(len, processed))
    fade_frames = min(count, round(rate * fade_out / 1000))
    smoothed = 0.0
    pcm = array("h")
    for index in range(count):
        frame = [channel[index] for channel in processed]
        smoothed += 0.01 * (sum(abs(x) for x in frame) / len(frame) - smoothed)
        sine = sine_mix * min(1.0, smoothed * 8.0) * sin(2 * pi * sine_hz * index / rate)
        for sample in frame:
            value = (sample + sine) * volume
            if fade_frames > 0 and index >= count - fade_frames:
                value *= (count - 1 - index) / max(1, fade_frames - 1)
            # Soft limiting prevents clipped PCM when layers are combined.
            value = tanh(value * 1.3) / tanh(1.3) if abs(value) > 0.7 else value
            pcm.append(round(max(-1, min(1, value)) * 32767))
    if sys.byteorder != "little":
        pcm.byteswap()
    output.parent.mkdir(parents=True, exist_ok=True)
    if backup and output.exists():
        backup.mkdir(parents=True, exist_ok=True)
        stamp = datetime.now().strftime("%Y%m%d-%H%M%S-%f")
        shutil.copy2(output, backup / f"{output.stem}-{stamp}.wav")
    descriptor, temporary = tempfile.mkstemp(suffix=".wav", dir=output.parent)
    os.close(descriptor)
    try:
        with wave.open(temporary, "wb") as wav:
            wav.setnchannels(len(channels))
            wav.setsampwidth(2)
            wav.setframerate(rate)
            wav.writeframes(pcm.tobytes())
        os.replace(temporary, output)
    finally:
        if os.path.exists(temporary):
            os.unlink(temporary)
    print(f"Rendered {count / rate:.2f}s to {output}")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--source", required=True, type=Path)
    parser.add_argument("--output", required=True, type=Path)
    parser.add_argument("--backup", type=Path)
    parser.add_argument("--volume", type=float, default=0.5)
    parser.add_argument("--pitch", type=float, default=1.0)
    parser.add_argument("--tempo", type=float, default=1.0)
    parser.add_argument("--lowpass", type=float, default=12000.0)
    parser.add_argument("--highpass", type=float, default=20.0)
    parser.add_argument("--sine-hz", type=float, default=90.0)
    parser.add_argument("--sine-mix", type=float, default=0.0)
    parser.add_argument("--grit", type=float, default=0.0)
    parser.add_argument("--reverb", type=float, default=0.0)
    parser.add_argument("--trim-start", type=float, default=0.0)
    parser.add_argument("--trim-end", type=float, default=1.0)
    parser.add_argument("--fade-out", type=float, default=0.0)
    args = parser.parse_args()
    if not 0 <= args.volume <= 2 or not 0.5 <= args.pitch <= 2 or not 0.5 <= args.tempo <= 2:
        parser.error("Volume, pitch or tempo is outside the Sound Lab range.")
    if not 0 <= args.sine_mix <= 0.5 or not 0 <= args.grit <= 1 or not 0 <= args.reverb <= 1:
        parser.error("Sine, distortion or reverb is outside the Sound Lab range.")
    if not 0 <= args.trim_start <= 0.8 or not 0.2 <= args.trim_end <= 1:
        parser.error("Trim range is outside the Sound Lab limits.")
    render(args.source, args.output, args.volume, args.pitch, args.tempo,
           args.lowpass, args.highpass, args.sine_hz, args.sine_mix,
           args.grit, args.reverb, args.trim_start, args.trim_end, args.fade_out, args.backup)


if __name__ == "__main__":
    try:
        main()
    except (OSError, ValueError, wave.Error) as error:
        sys.exit(str(error))

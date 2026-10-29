#!/usr/bin/env python3
"""Generate STARFALL's original score and sound effects (Python standard library).

No samples, soundfonts, external programs, or third-party music are used.
Output is deterministic, mono, 22050 Hz, signed 16-bit PCM WAV.
"""
from __future__ import annotations

import array
import math
from pathlib import Path
import random
import struct
import sys
import wave

RATE = 22050
TAU = math.tau
ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "assets" / "audio"


def hz(midi: int) -> float:
    return 440.0 * 2.0 ** ((midi - 69) / 12.0)


def envelope(t: float, duration: float, attack: float = 0.012, release: float = 0.07) -> float:
    return min(1.0, t / max(attack, 0.001)) * min(1.0, max(0.0, duration - t) / max(release, 0.001))


def note(buffer: list[float], start: float, duration: float, midi: int,
         volume: float, voice: str = "soft", wrap: bool = False) -> None:
    offset = round(start * RATE)
    count = round(duration * RATE)
    f = hz(midi)
    for i in range(count):
        t = i / RATE
        p = TAU * f * t
        if voice == "bass":
            s = math.sin(p) + 0.16 * math.sin(p * 2) + 0.06 * math.sin(p * 3)
            env = envelope(t, duration, 0.008, 0.055)
        elif voice == "bell":
            s = math.sin(p) + 0.22 * math.sin(p * 2) + 0.07 * math.sin(p * 3)
            env = envelope(t, duration, 0.006, 0.05) * math.exp(-4.0 * t)
        elif voice == "pad":
            s = math.sin(p) + 0.12 * math.sin(p * 2)
            env = envelope(t, duration, 0.11, 0.24)
        else:
            s = math.sin(p) - 0.11 * math.sin(p * 3) + 0.035 * math.sin(p * 5)
            env = envelope(t, duration, 0.018, 0.08)
        index = offset + i
        if wrap:
            index %= len(buffer)
        elif index >= len(buffer):
            break
        buffer[index] += volume * env * s


def drum(buffer: list[float], start: float, kind: str, volume: float,
         rng: random.Random, wrap: bool = False) -> None:
    duration = {"kick": 0.23, "snare": 0.15, "hat": 0.045}[kind]
    previous = 0.0
    for i in range(round(duration * RATE)):
        t = i / RATE
        noise = rng.uniform(-1, 1)
        if kind == "kick":
            phase = TAU * (45 * t + 5.3 * (1 - math.exp(-32 * t)))
            s = math.sin(phase) * math.exp(-20 * t)
        elif kind == "snare":
            s = (0.68 * noise + 0.32 * math.sin(TAU * 165 * t)) * math.exp(-30 * t)
        else:
            s = (noise - previous) * 0.45 * math.exp(-90 * t)
        previous = noise
        s *= min(1.0, t / 0.002) * min(1.0, (duration - t) / 0.008)
        index = round(start * RATE) + i
        if wrap:
            index %= len(buffer)
        elif index >= len(buffer):
            break
        buffer[index] += volume * s


def write(name: str, samples: list[float], peak: float) -> None:
    # A single linear gain preserves dynamics and guarantees clipping-free PCM.
    raw_peak = max(abs(x) for x in samples) or 1.0
    gain = peak / raw_peak
    data = array.array("h", (round(max(-1.0, min(1.0, x * gain)) * 32767) for x in samples))
    if sys.byteorder != "little":
        data.byteswap()
    with wave.open(str(OUT / name), "wb") as out:
        out.setnchannels(1)
        out.setsampwidth(2)
        out.setframerate(RATE)
        out.writeframes(data.tobytes())


def make_music() -> None:
    # 24 bars, 4/4, 120 BPM = exactly 48 seconds. The eight-bar harmony is
    # developed through three instrumental phrases. Every tail wraps across
    # the loop boundary, rather than being chopped or faded to silence.
    beat = 0.5
    bar = 4 * beat
    buffer = [0.0] * (RATE * 48)
    rng = random.Random(20261029)
    chords = [
        (45, [57, 60, 64, 67]), (41, [57, 60, 65, 69]),
        (48, [55, 60, 64, 67]), (43, [55, 59, 62, 67]),
        (45, [57, 60, 64, 69]), (41, [53, 57, 60, 65]),
        (38, [57, 62, 65, 69]), (43, [55, 59, 62, 67]),
    ]
    melody_shapes = [[0, 2, 1, 3], [2, 3, 2, 1], [1, 0, 2, 1]]
    for n in range(24):
        start = n * bar
        root, chord = chords[n % 8]
        phrase = n // 8
        for pitch in chord:
            note(buffer, start, 2.18, pitch, 0.025, "pad", True)
        for tick in [0, 1.5, 2, 3.25]:
            bass_pitch = root if tick != 3.25 else root + 12
            note(buffer, start + tick * beat, 0.19 if tick == 3.25 else 0.25,
                 bass_pitch, 0.20, "bass", True)
        for tick in range(8):
            note(buffer, start + tick * beat / 2, 0.21,
                 chord[[0, 2, 1, 3, 2, 1, 3, 2][tick]] + 12,
                 0.040 if phrase == 0 else 0.053, "bell", True)
        if phrase != 0:
            shape = melody_shapes[phrase]
            for tick in range(4):
                # Pauses make the repeating motif less fatiguing.
                if (n + tick) % 7 == 0:
                    continue
                note(buffer, start + (tick + 0.5) * beat, 0.32,
                     chord[shape[tick]] + 12, 0.065, "soft", True)
        for tick in range(4):
            drum(buffer, start + tick * beat, "kick", 0.26 if tick % 2 == 0 else 0.18, rng, True)
            if tick % 2 == 1:
                drum(buffer, start + tick * beat, "snare", 0.11, rng, True)
        for tick in range(8):
            drum(buffer, start + tick * beat / 2, "hat", 0.032 if tick % 2 == 0 else 0.018, rng, True)
    write("bgm.wav", buffer, 0.78)


def swept(name: str, duration: float, start_hz: float, end_hz: float,
          peak: float, noise_amount: float = 0.0, seed: int = 1) -> None:
    rng = random.Random(seed)
    buffer = []
    phase = 0.0
    low_noise = 0.0
    for i in range(round(duration * RATE)):
        t = i / RATE
        ratio = t / duration
        f = start_hz * (end_hz / start_hz) ** ratio
        phase += TAU * f / RATE
        low_noise = 0.45 * low_noise + 0.55 * rng.uniform(-1, 1)
        s = math.sin(phase) * (1 - noise_amount) + low_noise * noise_amount
        env = envelope(t, duration, 0.004, duration * 0.35) * math.exp(-3.1 * ratio)
        buffer.append(s * env)
    write(name, buffer, peak)


def make_sfx() -> None:
    swept("shot.wav", 0.085, 1150, 520, 0.46)
    swept("enemy_shot.wav", 0.13, 420, 210, 0.30)
    swept("explosion.wav", 0.50, 140, 32, 0.72, 0.84, 17)
    swept("hit.wav", 0.26, 180, 70, 0.68, 0.50, 19)
    power = [0.0] * round(0.54 * RATE)
    for i, pitch in enumerate([72, 76, 79, 84]):
        note(power, i * 0.075, 0.27, pitch, 0.24, "bell")
    write("powerup.wav", power, 0.58)
    victory = [0.0] * round(2.5 * RATE)
    for i, pitch in enumerate([69, 72, 76, 79, 81]):
        note(victory, i * 0.16, 0.35, pitch, 0.15, "soft")
    for pitch in [57, 64, 69, 72, 76]:
        note(victory, 0.90, 1.4, pitch, 0.09, "pad")
    write("victory.wav", victory, 0.66)
    menu = [0.0] * round(0.2 * RATE)
    note(menu, 0.0, 0.11, 72, 0.25, "bell")
    note(menu, 0.065, 0.13, 79, 0.2, "bell")
    write("menu.wav", menu, 0.46)


def validate() -> None:
    print("file              duration   peak     RMS      clipped   boundary jump")
    total = 0
    for path in sorted(OUT.glob("*.wav")):
        with wave.open(str(path), "rb") as wav:
            assert wav.getnchannels() == 1
            assert wav.getsampwidth() == 2
            assert wav.getframerate() == RATE
            raw = wav.readframes(wav.getnframes())
            samples = struct.unpack("<" + "h" * (len(raw) // 2), raw)
            peak = max(abs(x) for x in samples) / 32767
            rms = math.sqrt(sum((x / 32767) ** 2 for x in samples) / len(samples))
            clipped = sum(abs(x) >= 32767 for x in samples)
            jump = abs(samples[0] - samples[-1]) / 32767
            assert not clipped, path
            assert peak <= 0.80, path
            if path.name == "bgm.wav":
                assert len(samples) == 48 * RATE
                assert jump < 0.02, (path, jump)
            print(f"{path.name:17} {len(samples)/RATE:7.3f}s {peak:7.4f} {rms:8.4f} {clipped:8d} {jump:15.6f}")
        total += path.stat().st_size
    print(f"Total WAV bytes: {total:,}")


if __name__ == "__main__":
    OUT.mkdir(parents=True, exist_ok=True)
    if "--validate-only" not in sys.argv:
        make_music()
        make_sfx()
    validate()

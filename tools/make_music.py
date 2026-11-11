#!/usr/bin/env python3
"""Writes the game's background music to assets/music/ as looping Ogg files.

Every track is composed and synthesised here, note by note, so there are no
samples to license. Rendering the music once, ahead of time, keeps the game
from spending a phone's battery making it while you play.

    python3 tools/make_music.py            # needs numpy and ffmpeg

Tracks: title (warm, hopeful), hospital (calm daytime), theatre (tense,
with a heartbeat), night (sparse, for the night on call) and fanfare (a
short flourish for a promotion; it does not loop).
"""

import os
import subprocess
import sys
import tempfile
import wave

import numpy as np

RATE = 32000
OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "assets", "music")

NOTES = {"C": 0, "C#": 1, "Db": 1, "D": 2, "D#": 3, "Eb": 3, "E": 4, "F": 5, "F#": 6, "Gb": 6,
         "G": 7, "G#": 8, "Ab": 8, "A": 9, "A#": 10, "Bb": 10, "B": 11}


def freq(name):
    """'A4' -> 440.0"""
    pitch, octave = name[:-1], int(name[-1])
    return 440.0 * 2 ** ((NOTES[pitch] + 12 * (octave + 1) - 69) / 12)


def envelope(n, attack, release, rate=RATE):
    env = np.ones(n)
    a = max(1, int(attack * rate))
    r = max(1, int(release * rate))
    env[:a] = np.linspace(0, 1, a) if a < n else np.linspace(0, 1, n)[:a]
    if r < n:
        env[-r:] *= np.linspace(1, 0, r)
    return env


def pad(f, seconds):
    t = np.arange(int(seconds * RATE)) / RATE
    wave_ = (np.sin(2 * np.pi * f * t) + 0.8 * np.sin(2 * np.pi * f * 1.004 * t + 1.3)
             + 0.28 * np.sin(2 * np.pi * f * 2 * t) + 0.1 * np.sin(2 * np.pi * f * 3 * t))
    wave_ *= 1 + 0.08 * np.sin(2 * np.pi * 0.35 * t)
    return wave_ * envelope(len(t), 0.7, 0.9) * 0.18


def pluck(f, seconds=1.6, bright=1.0):
    t = np.arange(int(seconds * RATE)) / RATE
    out = np.zeros_like(t)
    for harmonic, level in ((1, 1.0), (2, 0.45 * bright), (3, 0.22 * bright), (4, 0.1 * bright)):
        out += level * np.sin(2 * np.pi * f * harmonic * t) * np.exp(-t * (3.2 + harmonic * 1.6))
    return out * envelope(len(t), 0.004, 0.05) * 0.32


def bell(f, seconds=3.0):
    t = np.arange(int(seconds * RATE)) / RATE
    out = np.zeros_like(t)
    for ratio, level, decay in ((1.0, 1.0, 1.4), (2.76, 0.35, 2.6), (5.4, 0.16, 4.5), (2.0, 0.25, 2.0)):
        out += level * np.sin(2 * np.pi * f * ratio * t) * np.exp(-t * decay)
    return out * envelope(len(t), 0.003, 0.2) * 0.22


def bass(f, seconds):
    t = np.arange(int(seconds * RATE)) / RATE
    out = np.sin(2 * np.pi * f * t) + 0.3 * np.sin(2 * np.pi * f * 2 * t)
    return out * envelope(len(t), 0.02, 0.25) * np.exp(-t * 0.6) * 0.32


def thump(seconds=0.35, low=46.0, high=82.0):
    t = np.arange(int(seconds * RATE)) / RATE
    sweep = low + (high - low) * np.exp(-t * 22)
    phase = 2 * np.pi * np.cumsum(sweep) / RATE
    return np.sin(phase) * np.exp(-t * 11) * 0.55


def tick(seconds=0.05, seed=1):
    rng = np.random.default_rng(seed)
    noise = rng.uniform(-1, 1, int(seconds * RATE))
    noise = noise - np.concatenate(([0.0], noise[:-1])) * 0.9  # brighten
    return noise * np.exp(-np.arange(len(noise)) / RATE * 70) * 0.05


def brass(f, seconds):
    t = np.arange(int(seconds * RATE)) / RATE
    out = np.zeros_like(t)
    for harmonic in range(1, 9):
        out += np.sin(2 * np.pi * f * harmonic * t) / harmonic ** 1.4
    return out * envelope(len(t), 0.05, 0.35) * 0.16


class Track:
    """A loop of a given length; notes that run past the end wrap round to
    the start, so the loop joins without a click."""

    def __init__(self, bpm, bars, beats_per_bar=4, loop=True, tail=0.0):
        self.beat = 60.0 / bpm
        self.length = int(round(bars * beats_per_bar * self.beat * RATE))
        self.loop = loop
        self.buffer = np.zeros(self.length + (0 if loop else int(tail * RATE)))

    def add(self, sound, at_beat):
        start = int(round(at_beat * self.beat * RATE))
        for offset in range(0, len(sound), self.length if self.loop else len(sound)):
            chunk = sound[offset:offset + (self.length if self.loop else len(sound))]
            begin = (start + offset) % self.length if self.loop else start + offset
            end = begin + len(chunk)
            if end <= len(self.buffer):
                self.buffer[begin:end] += chunk
            else:
                first = len(self.buffer) - begin
                self.buffer[begin:] += chunk[:first]
                if self.loop:
                    self.buffer[:len(chunk) - first] += chunk[first:]

    def chord(self, names, at_beat, beats, voice=pad):
        for name in names:
            self.add(voice(freq(name), beats * self.beat + 0.9), at_beat)

    def finished(self, peak=0.5):
        top = np.max(np.abs(self.buffer)) or 1.0
        return self.buffer / top * peak


def title():
    track = Track(84, 8)
    chords = [("D3", "F#3", "A3"), ("B2", "D3", "F#3"), ("G2", "B2", "D3"), ("A2", "C#3", "E3")]
    roots = ["D2", "B1", "G1", "A1"]
    melody = [("F#5", 0), ("E5", 1.5), ("D5", 2), ("A4", 3), ("B4", 4.5), ("D5", 5), ("F#5", 6),
              ("G5", 8), ("F#5", 9.5), ("E5", 10), ("D5", 11), ("E5", 12), ("C#5", 13.5), ("A4", 14)]
    for index in range(4):
        at = index * 8
        track.chord(chords[index], at, 8)
        track.add(bass(freq(roots[index]), 3.6), at)
        track.add(bass(freq(roots[index]), 3.6), at + 4)
        tones = [chords[index][0], chords[index][1], chords[index][2], chords[index][1]]
        for step in range(16):
            name = tones[step % 4]
            higher = name[:-1] + str(int(name[-1]) + 1)
            track.add(pluck(freq(higher), 1.4, 0.7), at + step * 0.5)
    for name, beat in melody:
        track.add(bell(freq(name), 3.0), beat)
        track.add(bell(freq(name), 3.0), beat + 16)
    return track.finished(0.5)


def hospital():
    track = Track(92, 8)
    chords = [("F3", "A3", "C4"), ("A2", "C3", "E3"), ("D3", "F3", "A3"), ("C3", "E3", "G3")]
    roots = ["F2", "A1", "D2", "C2"]
    pattern = [0, 2, 1, 2, 0, 2, 1, 2]
    for index in range(4):
        at = index * 8
        track.chord(chords[index], at, 8)
        for beat in (0, 3, 4, 7):
            track.add(bass(freq(roots[index]), 1.2), at + beat)
        for step in range(16):
            name = chords[index][pattern[step % 8]]
            higher = name[:-1] + str(int(name[-1]) + 1)
            track.add(pluck(freq(higher), 1.0, 0.5) * (0.9 if step % 2 == 0 else 0.6), at + step * 0.5)
        track.add(tick(seed=index), at + 2)
        track.add(tick(seed=index + 9), at + 6)
    for name, beat in [("A5", 1), ("G5", 3), ("C6", 9), ("A5", 11), ("F5", 17), ("E5", 19), ("G5", 25), ("E5", 27)]:
        track.add(bell(freq(name), 2.5) * 0.7, beat)
    return track.finished(0.45)


def theatre():
    track = Track(70, 8)
    chords = [("A2", "E3", "C4"), ("F2", "C3", "A3"), ("D2", "A2", "F3"), ("E2", "B2", "G#3")]
    for index in range(4):
        at = index * 8
        track.chord(chords[index], at, 8)
        track.add(pad(freq(chords[index][0][:-1] + "1"), 8 * track.beat + 0.9) * 0.8, at)
        for beat in range(8):
            # A heartbeat: lub-dub on every beat.
            track.add(thump(), at + beat)
            track.add(thump(0.25, 44, 70) * 0.6, at + beat + 0.3)
            track.add(tick(0.03, seed=beat) * 0.6, at + beat + 0.5)
    for name, beat in [("E5", 4), ("F5", 12), ("D5", 20), ("E5", 28), ("G#5", 30)]:
        track.add(bell(freq(name), 3.5) * 0.45, beat)
    return track.finished(0.45)


def night():
    track = Track(66, 8)
    chords = [("E3", "G3", "B3", "D4"), ("C3", "E3", "G3", "B3"), ("A2", "C3", "E3", "G3"), ("B2", "E3", "F#3", "A3")]
    for index in range(4):
        at = index * 8
        track.chord(chords[index], at, 8)
        track.add(bass(freq(chords[index][0][:-1] + "2"), 6.0) * 0.7, at)
    for name, beat in [("B5", 0), ("G5", 1.5), ("E5", 3), ("D6", 6), ("B5", 9), ("G5", 10.5), ("E5", 13),
                       ("C6", 17), ("B5", 18.5), ("E5", 21), ("F#5", 25), ("A5", 27), ("B5", 29.5)]:
        track.add(bell(freq(name), 4.0) * 0.6, beat)
    return track.finished(0.4)


def fanfare():
    track = Track(120, 2, loop=False, tail=2.5)
    for index, name in enumerate(["C4", "E4", "G4", "C5"]):
        track.add(brass(freq(name), 0.45), index * 0.5)
    for name in ["C4", "E4", "G4", "C5", "E5"]:
        track.add(brass(freq(name), 2.4), 2.2)
    track.add(bass(freq("C2"), 2.5), 2.2)
    for name, at in [("G5", 2.2), ("C6", 2.5), ("E6", 2.8)]:
        track.add(bell(freq(name), 2.5) * 0.8, at)
    return track.finished(0.6)


def write_ogg(name, samples):
    os.makedirs(OUT, exist_ok=True)
    pcm = (np.clip(samples, -1, 1) * 32767).astype(np.int16)
    with tempfile.TemporaryDirectory() as folder:
        wav_path = os.path.join(folder, name + ".wav")
        with wave.open(wav_path, "wb") as file:
            file.setnchannels(1)
            file.setsampwidth(2)
            file.setframerate(RATE)
            file.writeframes(pcm.tobytes())
        target = os.path.join(OUT, name + ".ogg")
        subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", wav_path, "-c:a", "libvorbis", "-q:a", "3",
                        "-map_metadata", "-1", "-fflags", "+bitexact", "-flags:a", "+bitexact", target], check=True)
    print("%s: %.1f s, %d KB" % (name, len(samples) / RATE, os.path.getsize(target) // 1024))


def main():
    for name, make in (("title", title), ("hospital", hospital), ("theatre", theatre), ("night", night),
                       ("fanfare", fanfare)):
        write_ogg(name, make())
    return 0


if __name__ == "__main__":
    sys.exit(main())

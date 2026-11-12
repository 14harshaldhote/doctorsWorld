#!/usr/bin/env python3
"""Writes the game's background music to assets/music/ as looping Ogg files.

Every track is composed and synthesised here, note by note, so there are no
samples to license. Rendering the music once, ahead of time, keeps the game
from spending a phone's battery making it while you play.

    python3 tools/make_music.py            # needs numpy and ffmpeg
    python3 tools/make_music.py night sad  # only some tracks

The tracks are stereo loops of a minute or more with a room around them
(a reverb), so they do not tire the ear the way short loops do. Everything
that rings past the end of a loop (notes, echoes, the reverb) wraps round to
its start, so the loops join without a seam. The loops sit quietly under
the dialogue and leave the middle of the sound free for voices.

Tracks:
  title      warm and hopeful (D major)
  hospital   calm daytime on the ward (F major)
  theatre    focused, tense, no drums: the monitor keeps the beat (A minor)
  night      sparse piano for nights on call (E minor)
  emergency  urgent strings and drums for a crash call (D minor)
  sad        slow piano and strings for bad news (A minor)
  fanfare    a short flourish for a promotion; it does not loop
"""

import os
import subprocess
import sys
import tempfile
import wave

import numpy as np

RATE = 32000
OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "assets", "music")
## How loud a loop is, measured the way a phone speaker plays it (RMS of
## the mix above about 250 Hz, dBFS), and the highest peak allowed. The
## loops sit a little under the old ones so voices stay clear over them.
LOOP_LOUDNESS = -27.5
PEAK = 0.8

NOTES = {"C": 0, "C#": 1, "Db": 1, "D": 2, "D#": 3, "Eb": 3, "E": 4, "F": 5, "F#": 6, "Gb": 6,
         "G": 7, "G#": 8, "Ab": 8, "A": 9, "A#": 10, "Bb": 10, "B": 11}


# --- Pitches -------------------------------------------------------------

def midi(name):
    """'A4' -> 69"""
    pitch, octave = name[:-1], int(name[-1])
    return NOTES[pitch] + 12 * (octave + 1)


def hz(note):
    """A MIDI number or a name -> frequency."""
    number = midi(note) if isinstance(note, str) else note
    return 440.0 * 2 ** ((number - 69) / 12)


def voicing(text):
    """'D3 A3 D4 F#4' -> [50, 57, 62, 66]"""
    return [midi(name) for name in text.split()]


def phrase(text, start=0.0):
    """'F#5:2 A5:1 r:1' -> [(beat, midi, beats), ...]; r is a rest."""
    notes = []
    at = start
    for token in text.split():
        name, length = token.split(":")
        length = float(length)
        if name != "r":
            notes.append((at, midi(name), length))
        at += length
    return notes


def bars(*lines):
    """One phrase string per 4/4 bar -> notes."""
    notes = []
    for index, line in enumerate(lines):
        notes += phrase(line, index * 4)
    return notes


def bass_note(note):
    """Folds a bass note into the octave a phone speaker can still carry."""
    number = midi(note) if isinstance(note, str) else note
    while number < 36:
        number += 12
    while number > 50:
        number -= 12
    return number


# --- Filters and the room --------------------------------------------------

def _freqs(n):
    return np.fft.rfftfreq(n, 1.0 / RATE)


def lowpass(x, cutoff, order=2):
    """Zero-phase Butterworth-shaped low-pass, circular (loops stay seamless)."""
    n = x.shape[-1]
    response = 1.0 / np.sqrt(1.0 + (_freqs(n) / cutoff) ** (2 * order))
    return np.fft.irfft(np.fft.rfft(x, axis=-1) * response, n=n, axis=-1)


def highpass(x, cutoff, order=1):
    n = x.shape[-1]
    f = np.maximum(_freqs(n), 1e-3)
    response = 1.0 / np.sqrt(1.0 + (cutoff / f) ** (2 * order))
    return np.fft.irfft(np.fft.rfft(x, axis=-1) * response, n=n, axis=-1)


def phone_loudness(x):
    """RMS of the mid signal above about 250 Hz: roughly what a phone's
    small speaker lets through."""
    mid = (x[0] + x[1]) / 2
    n = len(mid)
    response = 1.0 / np.sqrt(1.0 + (250.0 / np.maximum(_freqs(n), 1.0)) ** 4)
    return float(np.sqrt(np.mean(np.fft.irfft(np.fft.rfft(mid) * response, n) ** 2))) or 1.0


def room(seconds=3.2, rt60=2.3, seed=11, predelay=0.024):
    """A stereo impulse response: early reflections, then a diffuse tail
    whose highs die away faster than its lows, like a real hall."""
    rng = np.random.default_rng(seed)
    n = int(seconds * RATE)
    t = np.arange(n) / RATE
    channels = []
    for side in range(2):
        noise = rng.standard_normal(n)
        low = lowpass(noise, 600)
        mid = lowpass(noise, 3200) - low
        high = noise - low - mid
        tail = (low * np.exp(-6.9 * t / rt60) + mid * np.exp(-6.9 * t / (rt60 * 0.7))
                + 0.5 * high * np.exp(-6.9 * t / (rt60 * 0.3)))
        tail *= np.minimum(1.0, t / 0.03)
        response = np.zeros(n)
        start = int(predelay * RATE)
        response[start:] = tail[:n - start] * 0.6
        for index, (ms, gain) in enumerate(((11, 0.7), (17, 0.5), (23, 0.45), (31, 0.35), (43, 0.28), (59, 0.2))):
            if index % 2 == side:
                response[int((ms + 3 * side) / 1000 * RATE)] += gain * 6.0
        channels.append(response / np.sqrt(np.sum(response ** 2)))
    return np.array(channels)


def convolve(x, response, loop):
    """Stereo convolution; circular for loops so the tail wraps to the start."""
    n = x.shape[-1]
    size = n if loop else n + response.shape[-1]
    out = np.zeros_like(x)
    for side in range(2):
        spectrum = np.fft.rfft(x[side], size) * np.fft.rfft(response[side], size)
        out[side] = np.fft.irfft(spectrum, size)[:n]
    return out


# --- Envelopes and oscillators ---------------------------------------------

def _time(seconds):
    return np.arange(max(1, int(seconds * RATE))) / RATE


def _gate(t, hold, attack, release):
    """Rises over attack, holds until hold, then falls away over release."""
    env = np.minimum(1.0, t / max(attack, 1e-4))
    after = t > hold
    env[after] *= np.exp(-(t[after] - hold) * (6.9 / max(release, 1e-3)))
    return env


_TABLES = {}


def _saw_table(harmonics, size=4096):
    if harmonics not in _TABLES:
        phase = np.arange(size) / size
        table = np.zeros(size)
        for k in range(1, harmonics + 1):
            table += np.sin(2 * np.pi * k * phase) / k
        _TABLES[harmonics] = table / np.max(np.abs(table))
    return _TABLES[harmonics]


def saw(freq_curve, phase0=0.0, ceiling=7000.0):
    """A band-limited sawtooth that follows a frequency curve (for vibrato)."""
    harmonics = int(max(1, min(48, ceiling / max(float(np.max(freq_curve)), 20.0))))
    table = _saw_table(harmonics)
    phase = (phase0 + np.cumsum(freq_curve) / RATE) % 1.0
    position = phase * len(table)
    index = position.astype(int)
    frac = position - index
    return table[index] * (1 - frac) + table[(index + 1) % len(table)] * frac


# --- Instruments (each returns a mono note) --------------------------------

def epiano(note, hold, vel=0.7):
    """An electric piano (two-operator FM): bell-like when struck, mellow after."""
    f = hz(note)
    t = _time(hold + 1.2)
    index = vel * (2.0 * np.exp(-t * 5.0) + 0.35)
    body = np.sin(2 * np.pi * f * t + index * np.sin(2 * np.pi * f * t))
    tine = 0.12 * vel * np.sin(2 * np.pi * f * 7.0 * t) * np.exp(-t * 30.0)
    amp = np.exp(-t * (0.7 + f / 1100.0)) * _gate(t, hold, 0.002, 0.35)
    return (body + tine) * amp * (0.25 + 0.2 * vel)


def piano(note, hold, vel=0.6):
    """A soft acoustic piano: slightly stretched partials, two strings per
    note beating gently, highs dying first."""
    f = hz(note)
    t = _time(min(hold + 1.4, 6.0))
    out = np.zeros_like(t)
    rng = np.random.default_rng(int(f * 10) % 9973)
    for k in range(1, 13):
        fk = k * f * np.sqrt(1 + 0.00028 * k * k)
        if fk > 9000:
            break
        level = k ** -1.0 * np.exp(-(k - 1) * (1.0 - 0.6 * vel) * 0.35)
        decay = 0.45 + 0.22 * k + f / 900.0
        for detune in (-0.00045, 0.00045):
            out += level * np.sin(2 * np.pi * fk * (1 + detune) * t + rng.uniform(0, 6.28)) * np.exp(-t * decay)
    hammer = rng.standard_normal(len(t)) * np.exp(-t * 400.0) * 0.04 * vel
    return (out * 0.5 + hammer) * _gate(t, hold, 0.0015, 0.3) * (0.18 + 0.22 * vel)


def kalimba(note, hold, vel=0.6):
    f = hz(note)
    t = _time(min(hold, 1.0) + 1.6)
    out = (np.sin(2 * np.pi * f * t) * np.exp(-t * 3.0)
           + 0.22 * np.sin(2 * np.pi * f * 5.4 * t) * np.exp(-t * 16.0)
           + 0.12 * np.sin(2 * np.pi * f * 2.0 * t) * np.exp(-t * 6.0))
    return out * np.minimum(1.0, t / 0.001) * (0.2 + 0.25 * vel)


def bell(note, hold=0.0, vel=0.5):
    """A soft glassy bell (FM, inharmonic)."""
    f = hz(note)
    t = _time(3.5)
    index = 1.4 * np.exp(-t * 2.5)
    out = np.sin(2 * np.pi * f * t + index * np.sin(2 * np.pi * f * 3.5 * t))
    return out * np.exp(-t * 1.2) * np.minimum(1.0, t / 0.002) * (0.12 + 0.18 * vel)


def pad(note, hold, vel=0.6, attack=1.4, release=1.8, seed=0):
    """A warm pad: detuned saws (the bus filter rounds them) and a sine body."""
    f = hz(note)
    t = _time(hold + release + 0.2)
    rng = np.random.default_rng(seed + note)
    out = np.zeros_like(t)
    for cents in (-9.0, 0.0, 9.0):
        drift = 1 + 0.0012 * np.sin(2 * np.pi * rng.uniform(0.1, 0.3) * t + rng.uniform(0, 6.28))
        out += saw(np.full_like(t, f * 2 ** (cents / 1200)) * drift, rng.uniform())
    out = out / 3 + 0.6 * np.sin(2 * np.pi * f * t)
    swell = 1 + 0.1 * np.sin(2 * np.pi * 0.21 * t + rng.uniform(0, 6.28))
    return out * swell * _gate(t, hold, attack, release) * 0.12 * vel


def strings(note, hold, vel=0.6, attack=0.6, release=1.1, seed=0):
    """A small string section: three players slightly apart, vibrato that
    grows in after the bow settles."""
    f = hz(note)
    t = _time(hold + release + 0.2)
    rng = np.random.default_rng(seed + 7 * note)
    out = np.zeros_like(t)
    depth = 0.0035 * np.minimum(1.0, np.maximum(0.0, t - 0.35) / 0.6)
    for cents in (-6.0, 1.0, 7.0):
        vibrato = 1 + depth * np.sin(2 * np.pi * rng.uniform(4.8, 5.8) * t + rng.uniform(0, 6.28))
        out += saw(np.full_like(t, f * 2 ** (cents / 1200)) * vibrato, rng.uniform())
    return out / 3 * _gate(t, hold, attack, release) * 0.16 * vel


def spiccato(note, hold, vel=0.7, seed=0):
    """Short bowed notes for driving ostinatos."""
    f = hz(note)
    t = _time(0.35)
    rng = np.random.default_rng(seed + note)
    out = saw(np.full_like(t, f), rng.uniform()) + saw(np.full_like(t, f * 1.004), rng.uniform())
    env = np.minimum(1.0, t / 0.006) * np.exp(-t * 11.0)
    return out * env * 0.14 * vel


def brass(note, hold, vel=0.8):
    """A warm brass section: the tone brightens as the note swells."""
    f = hz(note)
    t = _time(hold + 0.6)
    bright = 0.35 + 0.65 * np.minimum(1.0, t / 0.09) * (0.75 + 0.25 * np.exp(-t * 2.0))
    vibrato = 1 + 0.003 * np.minimum(1.0, np.maximum(0.0, t - 0.3) / 0.4) * np.sin(2 * np.pi * 5.2 * t)
    phase = 2 * np.pi * f * np.cumsum(vibrato) / RATE
    out = np.zeros_like(t)
    for k in range(1, 14):
        if k * f > 8000:
            break
        out += np.sin(k * phase) / k * np.exp(-(k - 1) * (1.15 - 0.8 * bright) * 0.9)
    return out * _gate(t, hold, 0.04, 0.3) * 0.15 * vel


def bass(note, hold, vel=0.7):
    """A round bass with enough overtones to be heard on a phone."""
    f = hz(note)
    t = _time(hold + 0.4)
    out = (np.sin(2 * np.pi * f * t) + 0.45 * np.sin(4 * np.pi * f * t)
           + 0.18 * np.sin(6 * np.pi * f * t) + 0.06 * np.sin(8 * np.pi * f * t))
    amp = (0.65 + 0.35 * np.exp(-t * 2.5)) * _gate(t, hold, 0.01, 0.12)
    return out * amp * 0.3 * vel


def hat(vel=0.5, seed=0, length=0.06):
    rng = np.random.default_rng(seed)
    t = _time(length)
    noise = highpass(rng.standard_normal(len(t)), 6000, 2)
    return noise * np.exp(-t * 70.0) * 0.07 * vel


def shaker(vel=0.5, seed=0):
    rng = np.random.default_rng(seed + 100)
    t = _time(0.09)
    noise = lowpass(highpass(rng.standard_normal(len(t)), 3500, 2), 9000)
    return noise * np.minimum(1.0, t / 0.012) * np.exp(-t * 45.0) * 0.06 * vel


def drum(low=62.0, high=150.0, vel=0.7, decay=7.0, seed=0):
    """A soft low drum (tom or a gentle kick): a falling sine and a little
    skin noise."""
    rng = np.random.default_rng(seed + 300)
    t = _time(0.9)
    sweep = low + (high - low) * np.exp(-t * 30.0)
    body = np.sin(2 * np.pi * np.cumsum(sweep) / RATE) * np.exp(-t * decay)
    skin = lowpass(rng.standard_normal(len(t)), 1500) * np.exp(-t * 40.0) * 0.25
    return (body + skin) * 0.45 * vel


def swell(seconds, vel=0.5, seed=0, peak_at=1.0):
    """Filtered noise that rises (a riser, or a cymbal swell)."""
    rng = np.random.default_rng(seed + 500)
    t = _time(seconds)
    noise = lowpass(highpass(rng.standard_normal(len(t)), 1800, 2), 8000)
    shape = (t / seconds) ** 2.2
    shape[t > seconds * peak_at] = 1.0
    return noise * shape * np.minimum(1.0, (seconds - t) / 0.02) * 0.05 * vel


def crash(vel=0.6, seed=0):
    rng = np.random.default_rng(seed + 700)
    t = _time(3.0)
    noise = highpass(rng.standard_normal(len(t)), 3000, 2)
    return noise * np.exp(-t * 1.6) * np.minimum(1.0, t / 0.004) * 0.06 * vel


def air(seconds, seed=0):
    """A faint night-time hush, like a ventilation hum far down the corridor."""
    rng = np.random.default_rng(seed + 900)
    t = _time(seconds)
    noise = lowpass(highpass(rng.standard_normal(len(t)), 120), 500, 2)
    return noise * (1 + 0.4 * np.sin(2 * np.pi * t / 9.0)) * 0.05


# --- A piece of music --------------------------------------------------------

class Song:
    """A loop (or a one-off with a tail) built on named buses. Notes that run
    past the end of a loop wrap round to its start."""

    def __init__(self, bpm, bar_count, loop=True, tail=0.0, seed=1):
        self.beat = 60.0 / bpm
        self.loop = loop
        self.length = int(round(bar_count * 4 * self.beat * RATE))
        self.size = self.length if loop else self.length + int(tail * RATE)
        self.buses = {}
        self.rng = np.random.default_rng(seed)

    def bus(self, name):
        if name not in self.buses:
            self.buses[name] = np.zeros((2, self.size))
        return self.buses[name]

    def put(self, bus_name, sound, beat, pan=0.0, gain=1.0, human=0.005):
        """Adds a mono sound at a beat, panned (-1 left .. 1 right), with a
        touch of human timing and loudness."""
        buffer = self.bus(bus_name)
        jitter = float(np.clip(self.rng.normal(0, human), -2.5 * human, 2.5 * human)) if human > 0 else 0.0
        start = int(round((beat * self.beat + jitter) * RATE))
        gain *= 1 + (self.rng.uniform(-0.06, 0.06) if human > 0 else 0.0)
        angle = (np.clip(pan, -1, 1) + 1) * np.pi / 4
        for side, weight in enumerate((np.cos(angle), np.sin(angle))):
            self._place(buffer[side], sound * (weight * gain * np.sqrt(2)), start)

    def _place(self, channel, sound, start):
        if self.loop:
            start %= self.size
            offset = 0
            while offset < len(sound):
                begin = (start + offset) % self.size
                count = min(len(sound) - offset, self.size - begin)
                channel[begin:begin + count] += sound[offset:offset + count]
                offset += count
        else:
            if start < 0:
                sound = sound[-start:]
                start = 0
            end = min(self.size, start + len(sound))
            channel[start:end] += sound[:end - start]

    def notes(self, bus_name, instrument, notes, pan=0.0, gain=1.0, vel=0.6, offset=0.0, **options):
        for beat, number, length in notes:
            self.put(bus_name, instrument(number, length * self.beat, vel, **options), beat + offset, pan, gain)

    def chord(self, bus_name, instrument, numbers, beat, length, spread=0.5, gain=1.0, vel=0.6, **options):
        """A chord, its notes spread across the stereo field."""
        for index, number in enumerate(numbers):
            pan = (index / max(1, len(numbers) - 1) * 2 - 1) * spread
            self.put(bus_name, instrument(number, length * self.beat, vel, **options), beat, pan, gain)

    def echo(self, bus_name, beats, feedback=0.35, repeats=3, pan_swap=True):
        """A tempo-synced echo on a bus (circular, so it wraps)."""
        source = self.bus(bus_name)
        out = source.copy()
        step = int(round(beats * self.beat * RATE))
        level = 1.0
        current = source
        for index in range(repeats):
            level *= feedback
            current = lowpass(current, 3500, 1)
            shifted = np.roll(current, step * (index + 1), axis=-1) if self.loop else np.pad(current, ((0, 0), (step * (index + 1), 0)))[:, :self.size]
            if pan_swap and index % 2 == 0:
                shifted = shifted[::-1]
            out += shifted * level
            current = source
        self.buses[bus_name] = out

    def mix(self, settings, reverb=0.3, loudness=LOOP_LOUDNESS, room_seconds=3.2, rt60=2.3):
        """Filters each bus, sends some of it to the room and sets the loudness."""
        dry = np.zeros((2, self.size))
        send = np.zeros((2, self.size))
        for name, buffer in self.buses.items():
            setting = settings.get(name, {})
            signal = buffer
            if "lp" in setting:
                signal = lowpass(signal, setting["lp"], setting.get("order", 2))
            if "hp" in setting:
                signal = highpass(signal, setting["hp"], 1)
            gain = setting.get("gain", 1.0)
            dry += signal * gain
            send += signal * gain * setting.get("send", 0.3)
        wet = convolve(highpass(send, 180, 1), room(room_seconds, rt60), self.loop)
        out = highpass(dry + wet * reverb * 3.0, 35, 2)
        out *= 10 ** (loudness / 20) / phone_loudness(out)
        # Soft limit the few peaks above the ceiling.
        over = np.abs(out) > PEAK * 0.7
        knee = PEAK * 0.7
        out[over] = np.sign(out[over]) * (knee + (PEAK - knee) * np.tanh((np.abs(out[over]) - knee) / (PEAK - knee)))
        if not self.loop:
            fade = int(0.3 * RATE)
            out[:, -fade:] *= np.linspace(1, 0, fade)
        return out


# --- Shared figures ------------------------------------------------------------

def arpeggio(song, bus, chord, bar, pattern, instrument=epiano, step=0.5, vel=0.5, pan_range=0.45, gain=1.0,
             octave=0, beats=4, hold=None):
    """Plays chord tones in a pattern (indexes into the voicing; +10 means the
    same note an octave up)."""
    for index in range(int(beats / step)):
        slot = pattern[index % len(pattern)]
        number = chord[slot % 10] + 12 * (slot // 10) + 12 * octave
        pan = pan_range * np.sin(index * 1.3)
        accent = 1.0 if index % 2 == 0 else 0.82
        song.put(bus, instrument(number, (hold or step * 1.6) * song.beat, vel * accent), bar * 4 + index * step, pan, gain)


# --- The tracks --------------------------------------------------------------

def title():
    song = Song(76, 24, seed=3)
    a = [("D3 A3 D4 F#4", "D2"), ("E3 A3 C#4 E4", "C#2"), ("D3 F#3 B3 D4", "B1"), ("D3 G3 B3 D4", "G1"),
         ("D3 F#3 A3 D4", "F#2"), ("D3 G3 B3 D4", "G2"), ("E3 G3 B3 E4", "E2"), ("E3 A3 C#4 E4", "A1")]
    b = [("D3 G3 B3 D4", "G1"), ("E3 A3 C#4 E4", "A1"), ("C#3 F#3 A3 C#4", "F#2"), ("D3 F#3 B3 D4", "B1"),
         ("E3 G3 B3 E4", "E2"), ("E3 A3 C#4 E4", "A1"), ("D3 F#3 A3 D4", "D2"), ("E3 A3 C#4 E4", "A1")]
    progression = a + b + a
    for bar, (chord_text, root) in enumerate(progression):
        chord = voicing(chord_text)
        song.chord("pad", pad, chord, bar * 4, 4, vel=0.55 if bar < 8 else 0.7)
        low = bass_note(root)
        if 8 <= bar < 16:
            for beat, number in ((0, low), (1.5, low), (2, low + 7), (3, low)):
                song.put("bass", bass(number, 0.9 * song.beat, 0.7), bar * 4 + beat)
            song.put("perc", drum(55, 120, 0.45, 9.0, bar), bar * 4)
            song.put("perc", drum(55, 120, 0.3, 9.0, bar + 50), bar * 4 + 2.5)
            for step in range(8):
                song.put("perc", shaker(0.6 if step % 2 else 0.35, bar * 8 + step), bar * 4 + step * 0.5,
                         pan=0.35)
        else:
            song.put("bass", bass(low, 1.9 * song.beat, 0.65), bar * 4)
            song.put("bass", bass(low, 1.9 * song.beat, 0.55), bar * 4 + 2)
        if bar < 16:
            arpeggio(song, "keys", chord, bar, [0, 1, 2, 3, 11, 3, 2, 1], vel=0.42)
        else:
            arpeggio(song, "keys", chord, bar, [0, 2, 3, 12], instrument=piano, step=1.0, vel=0.38, hold=2.5)
    melody_a = bars("F#5:2 A5:1 G5:1", "F#5:1.5 E5:0.5 E5:2", "D5:1.5 E5:0.5 F#5:1 D5:1", "B4:3 r:1",
                    "A4:1 D5:1 F#5:1 A5:1", "B5:2 A5:1 G5:1", "G5:1.5 F#5:0.5 E5:1 G5:1", "E5:2 C#5:1 A4:1")
    melody_b = bars("D5:1 G5:1 B5:2", "A5:1.5 G5:0.5 E5:2", "F#5:1 A5:1 C#6:2", "B5:3 A5:1",
                    "G5:2 B5:1 A5:1", "A5:2 G5:1 E5:1", "F#5:3 E5:1", "E5:2 r:2")
    melody_c = bars("A5:2 F#5:2", "E5:3 r:1", "D5:2 F#5:2", "B4:4",
                    "A4:1 D5:1 F#5:1 E5:1", "D5:2 B4:2", "E5:2 G5:1 F#5:1", "A4:2 C#5:1 E5:1")
    song.notes("lead", piano, melody_a, pan=0.1, vel=0.62)
    song.notes("lead", piano, melody_b, pan=0.1, vel=0.7, offset=32)
    song.notes("lead", bell, [(beat, n + 12, length) for beat, n, length in melody_b], pan=-0.3, gain=0.35, offset=32)
    song.notes("lead", piano, melody_c, pan=0.1, vel=0.55, offset=64)
    line = bars("B3:4", "C#4:4", "C#4:4", "D4:4", "B3:4", "C#4:4", "D4:4", "C#4:2 E4:2")
    song.notes("strings", strings, line, pan=-0.35, vel=0.75, offset=32)
    song.notes("strings", strings, [(b, n + 12, l) for b, n, l in line], pan=0.35, vel=0.45, offset=32)
    return song.mix({
        "pad": {"lp": 2000, "gain": 0.8, "send": 0.5},
        "keys": {"lp": 7000, "gain": 0.7, "send": 0.35},
        "lead": {"gain": 1.0, "send": 0.45},
        "strings": {"lp": 4200, "gain": 0.7, "send": 0.55},
        "bass": {"lp": 900, "gain": 0.8, "send": 0.05},
        "perc": {"gain": 0.6, "send": 0.15},
    }, reverb=0.32)


def hospital():
    song = Song(84, 24, seed=5)
    chords = {"F": ("F3 A3 C4 E4", "F2"), "Am": ("E3 G3 A3 C4", "A2"), "Dm": ("F3 A3 C4 D4", "D2"),
              "Bb": ("F3 A3 Bb3 D4", "Bb2"), "Gm": ("F3 G3 Bb3 D4", "G2"), "Csus": ("F3 G3 Bb3 C4", "C3"),
              "C": ("E3 G3 C4 E4", "C3")}
    a = ["F", "Am", "Dm", "Bb", "F", "Am", "Gm", "Csus"]
    b = ["Bb", "C", "Am", "Dm", "Gm", "C", "F", "Csus"]
    for bar, name in enumerate(a + b + a):
        chord_text, root = chords[name]
        chord = voicing(chord_text)
        song.chord("pad", pad, chord, bar * 4, 4, vel=0.45)
        # Comping: a held chord on the one and a push on the "and" of two.
        song.chord("keys", epiano, chord, bar * 4, 1.4, spread=0.6, vel=0.42)
        song.chord("keys", epiano, chord, bar * 4 + 2.5, 1.3, spread=0.6, vel=0.34)
        low = bass_note(root)
        song.put("bass", bass(low, 1.4 * song.beat, 0.7), bar * 4)
        song.put("bass", bass(low, 0.9 * song.beat, 0.55), bar * 4 + 2.5)
        song.put("bass", bass(low + 7, 0.4 * song.beat, 0.45), bar * 4 + 3.5)
        if bar >= 4:
            for step in range(4):
                song.put("perc", hat(0.55, bar * 4 + step), bar * 4 + step + 0.5, pan=0.3)
        if 8 <= bar < 20:
            song.put("perc", drum(52, 110, 0.4, 10.0, bar), bar * 4)
            song.put("perc", drum(52, 110, 0.28, 10.0, bar + 40), bar * 4 + 2)
            for step in range(8):
                song.put("perc", shaker(0.55 if step % 2 else 0.3, bar * 8 + step), bar * 4 + step * 0.5, pan=-0.35)
    melody_a = bars("C5:1 A4:1 G4:0.5 A4:1.5", "E4:2 G4:1 A4:1", "F4:1 A4:1 C5:2", "D5:1.5 C5:0.5 A4:2",
                    "C5:1 A4:1 G4:0.5 A4:1.5", "E4:1 G4:1 C5:2", "Bb4:1.5 A4:0.5 G4:1 F4:1", "G4:4")
    melody_b = bars("D5:1 F5:1 A5:2", "G5:1.5 E5:0.5 C5:2", "E5:1 G5:1 C6:1.5 A5:0.5", "A5:2 F5:2",
                    "Bb5:1 A5:1 G5:1 D5:1", "E5:2 G5:2", "A5:3 r:1", "r:4")
    song.notes("lead", kalimba, melody_a, pan=0.2, vel=0.7)
    song.notes("lead", kalimba, [(b, n + 12, l) for b, n, l in melody_a], pan=-0.25, gain=0.25)
    song.notes("lead", piano, melody_b, pan=0.1, vel=0.55, offset=32)
    song.notes("lead", kalimba, melody_a[:9], pan=0.2, vel=0.6, offset=64)
    return song.mix({
        "pad": {"lp": 1800, "gain": 0.7, "send": 0.45},
        "keys": {"lp": 6500, "gain": 0.75, "send": 0.3},
        "lead": {"gain": 0.9, "send": 0.4},
        "bass": {"lp": 900, "gain": 0.75, "send": 0.04},
        "perc": {"gain": 0.55, "send": 0.12},
    }, reverb=0.26, rt60=1.9)


def theatre():
    song = Song(72, 24, seed=7)
    chords = {"Am": ("E3 A3 C4 E4", "A2"), "F": ("C3 F3 A3 C4", "F2"), "Dm": ("D3 F3 A3 D4", "D2"),
              "E": ("E3 G#3 B3 E4", "E2"), "G": ("D3 G3 B3 D4", "G2")}
    plan = ["Am", "F", "Dm", "E"] * 2 + ["F", "G", "Am", "E"]
    for index, name in enumerate(plan):
        chord_text, root = chords[name]
        chord = voicing(chord_text)
        at = index * 8
        song.chord("pad", pad, chord, at, 8, vel=0.6, attack=2.2, release=2.5)
        song.put("bass", pad(bass_note(root) - 12, 8 * song.beat, 0.9, attack=1.5, release=2.0), at)
        song.put("bass", bass(bass_note(root), 7.5 * song.beat, 0.35), at)
        # A soft, dark ostinato with an echo: motion without a beat to fight
        # the heart monitor.
        pattern = [1, 2, 3, 2] if index < 8 else [0, 3, 2, 3]
        for step in range(16):
            slot = pattern[step % 4]
            song.put("ostinato", epiano(chord[slot] + 12, 0.45 * song.beat, 0.3 + 0.08 * (step % 4 == 0)),
                     at + step * 0.5, pan=0.3 * np.sin(step * 0.8))
    song.echo("ostinato", 0.75, 0.32, 3)
    song.put("drone", pad(midi("A2"), 96 * song.beat, 0.5, attack=6.0, release=4.0), 0)
    song.put("drone", pad(midi("E3"), 96 * song.beat, 0.35, attack=6.0, release=4.0), 0, pan=0.4)
    line_2 = bars("E5:4", "C5:4", "A4:4", "C5:4", "D5:4", "F5:4", "E5:4", "G#4:4")
    line_3 = bars("A4:4", "C5:4", "B4:4", "D5:4", "C5:4", "E5:4", "B4:4", "G#4:2 B4:2")
    song.notes("strings", strings, line_2, pan=-0.3, vel=0.7, offset=32, attack=1.2, release=1.6)
    song.notes("strings", strings, line_3, pan=-0.3, vel=0.75, offset=64, attack=1.2, release=1.6)
    song.notes("strings", strings, [(b, n - 12, l) for b, n, l in line_3], pan=0.3, vel=0.5, offset=64,
               attack=1.2, release=1.6)
    for beat, name in ((32, "A5"), (40, "C6"), (48, "D6"), (56, "B5"), (64, "C6"), (72, "D6"), (80, "E6"), (88, "B5")):
        song.put("keys", piano(midi(name), 3.5 * song.beat, 0.35), beat, pan=0.25)
    return song.mix({
        "pad": {"lp": 1100, "gain": 0.75, "send": 0.5},
        "drone": {"lp": 700, "gain": 0.6, "send": 0.4},
        "bass": {"lp": 400, "gain": 0.8, "send": 0.05},
        "ostinato": {"lp": 2400, "gain": 0.75, "send": 0.35},
        "strings": {"lp": 2800, "gain": 0.75, "send": 0.55},
        "keys": {"gain": 0.8, "send": 0.6},
    }, reverb=0.34, rt60=2.6)


def night():
    song = Song(60, 20, seed=9)
    chords = {"Em9": ("E3 G3 B3 D4 F#4", "E2"), "Cmaj7": ("C3 G3 B3 E4", "C3"), "Am9": ("C3 E3 G3 B3", "A2"),
              "Bsus": ("B2 E3 F#3 A3", "B2"), "B7": ("B2 D#3 F#3 A3", "B2")}
    plan = []
    for _ in range(2):
        plan += [("Em9", 8), ("Cmaj7", 8), ("Am9", 8), ("Bsus", 4), ("B7", 4)]
    plan += [("Cmaj7", 4), ("Am9", 4), ("Bsus", 4), ("B7", 4)]
    at = 0
    for name, beats in plan:
        chord_text, root = chords[name]
        chord = voicing(chord_text)
        song.chord("pad", pad, chord, at, beats, vel=0.5, attack=2.0, release=2.4)
        low = bass_note(root)
        for bar_start in range(0, beats, 4):
            song.put("piano", piano(low, 3.6 * song.beat, 0.4), at + bar_start, pan=-0.2)
            for step, slot in enumerate((1, 2, 3)):
                song.put("piano", piano(chord[slot] + 12 * (slot == 1), 2.8 * song.beat, 0.3),
                         at + bar_start + 1 + step, pan=0.15 * step)
        at += beats
    melody = bars("B4:2 D5:1 F#5:1", "G5:3 F#5:1", "E5:2 G5:2", "B5:4",
                  "A5:2 G5:1 E5:1", "C5:2 B4:2", "E5:2 F#5:2", "D#5:4")
    song.notes("lead", piano, melody, pan=0.1, vel=0.5, offset=32)
    for beat, name in ((0, "B5"), (9, "G5"), (17, "E6"), (26, "F#5"), (64, "G5"), (68, "E5"), (72, "F#5"), (76, "D#5")):
        song.put("bells", bell(midi(name), 0, 0.45), beat, pan=-0.4 + 0.2 * (beat % 3))
    song.put("air", air(80.0), 0)
    return song.mix({
        "pad": {"lp": 1000, "gain": 0.65, "send": 0.5},
        "piano": {"gain": 0.85, "send": 0.45},
        "lead": {"gain": 0.95, "send": 0.5},
        "bells": {"gain": 0.6, "send": 0.8},
        "air": {"gain": 0.35, "send": 0.0},
    }, reverb=0.38, rt60=2.8, loudness=-28.5)


def emergency():
    song = Song(116, 24, seed=13)
    chords = {"Dm": ("D3 F3 A3 D4", "D2"), "Bb": ("D3 F3 Bb3 D4", "Bb2"), "Gm": ("D3 G3 Bb3 D4", "G2"),
              "A": ("E3 A3 C#4 E4", "A2"), "C": ("E3 G3 C4 E4", "C3"), "A7": ("E3 G3 C#4 E4", "A2")}
    one = ["Dm", "Dm", "Bb", "Bb", "Gm", "Gm", "A", "A"]
    two = ["Dm", "C", "Bb", "A", "Gm", "Bb", "A", "A7"]
    for bar, name in enumerate(one + two + one):
        chord_text, root = chords[name]
        chord = voicing(chord_text)
        low = bass_note(root)
        song.chord("pad", pad, chord, bar * 4, 4, vel=0.5, attack=0.6, release=1.2)
        for step, offset in enumerate((0, 0, 12, 0, 7, 0, 12, 7)):
            song.put("ostinato", spiccato(low + 12 + offset, 0, 0.75 if step % 2 == 0 else 0.55, bar),
                     bar * 4 + step * 0.5, pan=-0.25 if step % 2 else 0.25)
        song.put("bass", bass(low, 1.4 * song.beat, 0.6), bar * 4)
        song.put("bass", bass(low, 0.9 * song.beat, 0.5), bar * 4 + 2.5)
        for beat, level in ((0, 0.8), (1.5, 0.5), (2.5, 0.65)):
            song.put("drums", drum(60, 140, level, 6.0, bar * 3 + int(beat * 2)), bar * 4 + beat)
        if bar >= 8:
            for step in range(8):
                song.put("drums", hat(0.6 if step % 2 else 0.35, bar * 8 + step, 0.04), bar * 4 + step * 0.5, pan=0.3)
        if bar >= 16 and bar % 2 == 0:
            song.chord("brass", brass, [n + 12 for n in chord[1:]], bar * 4, 0.5, vel=0.8)
            song.chord("brass", brass, [n + 12 for n in chord[1:]], bar * 4 + 1.5, 0.9, vel=0.7)
    for bar in (6, 14, 22):
        song.put("drums", swell(8 * song.beat, 0.6, bar), bar * 4)
    high_1 = phrase("A4:8 Bb4:8 Bb4:8 A4:4 C#5:4")
    high_2 = phrase("A5:4 G5:4 F5:4 E5:4 D5:4 F5:4 E5:8")
    song.notes("strings", strings, high_1, pan=-0.3, vel=0.6, attack=0.4, release=0.8)
    song.notes("strings", strings, high_2, pan=0.2, vel=0.75, offset=32, attack=0.3, release=0.8)
    song.notes("strings", strings, [(b, n - 12, l) for b, n, l in high_2], pan=-0.3, vel=0.55, offset=32,
               attack=0.3, release=0.8)
    song.notes("strings", strings, high_1, pan=-0.3, vel=0.7, offset=64, attack=0.4, release=0.8)
    song.notes("strings", strings, [(b, n + 12, l) for b, n, l in high_1], pan=0.3, vel=0.45, offset=64,
               attack=0.4, release=0.8)
    return song.mix({
        "pad": {"lp": 900, "gain": 0.6, "send": 0.4},
        "ostinato": {"lp": 2600, "gain": 0.8, "send": 0.25},
        "bass": {"lp": 700, "gain": 0.75, "send": 0.03},
        "drums": {"hp": 70, "gain": 0.6, "send": 0.2},
        "strings": {"lp": 3400, "gain": 0.8, "send": 0.45},
        "brass": {"lp": 3800, "gain": 0.7, "send": 0.4},
    }, reverb=0.26, rt60=1.8, loudness=-27.0)


def sad():
    song = Song(64, 16, seed=17)
    chords = {"Am": ("A2 E3 A3 C4", "A2"), "F": ("F2 C3 F3 A3", "F2"), "C": ("C3 G3 C4 E4", "C3"),
              "G": ("G2 D3 G3 B3", "G2"), "Dm": ("D3 A3 D4 F4", "D3"), "Esus": ("E2 B2 E3 A3", "E2"),
              "E": ("E2 B2 E3 G#3", "E2"), "Em": ("E2 B2 E3 G3", "E2")}
    plan = ["Am", "F", "C", "G", "Am", "F", "Dm", "Esus", "F", "G", "Em", "Am", "Dm", "Am", "F", "E"]
    for bar, name in enumerate(plan):
        chord_text, root = chords[name]
        chord = voicing(chord_text)
        song.chord("pad", pad, chord[1:], bar * 4, 4, vel=0.45, attack=1.8, release=2.2)
        if name == "Esus":
            arpeggio(song, "piano", chord, bar, [0, 1, 2, 13, 12, 2, 1, 2], instrument=piano, vel=0.38, beats=2,
                     hold=1.4)
            e_chord = voicing(chords["E"][0])
            for index, slot in enumerate([0, 1, 2, 13]):
                number = e_chord[slot % 10] + 12 * (slot // 10)
                song.put("piano", piano(number, 1.4 * song.beat, 0.36), bar * 4 + 2 + index * 0.5)
        else:
            arpeggio(song, "piano", chord, bar, [0, 1, 2, 13, 12, 2, 1, 2], instrument=piano, vel=0.38, hold=1.4)
        if bar >= 8:
            song.put("cello", strings(bass_note(root), 3.8 * song.beat, 0.55, attack=0.8, release=1.2), bar * 4,
                     pan=-0.2)
    melody = bars("A4:1.5 B4:0.5 C5:2", "C5:1.5 D5:0.5 A4:2", "F5:1.5 E5:0.5 D5:2", "B4:2 G#4:2",
                  "A4:1 C5:1 F5:2", "G5:2 F5:1 D5:1", "E5:2 G5:2", "A5:2 E5:2",
                  "F5:2 D5:1 F5:1", "E5:2 C5:2", "A4:1 C5:1 D5:1 C5:1", "B4:3 G#4:1")
    song.notes("lead", piano, melody, pan=0.12, vel=0.55, offset=16)
    line = bars("C4:4", "B3:4", "B3:4", "C4:4", "D4:4", "C4:4", "C4:4", "B3:4")
    song.notes("strings", strings, line, pan=-0.35, vel=0.6, offset=32, attack=1.0, release=1.5)
    song.notes("strings", strings, bars("A4:4", "A4:4", "A4:4", "G#4:4"), pan=0.35, vel=0.45, offset=48,
               attack=1.2, release=1.5)
    return song.mix({
        "pad": {"lp": 1000, "gain": 0.6, "send": 0.5},
        "piano": {"gain": 0.8, "send": 0.45},
        "lead": {"gain": 1.0, "send": 0.5},
        "cello": {"lp": 2000, "gain": 0.6, "send": 0.45},
        "strings": {"lp": 3000, "gain": 0.7, "send": 0.55},
    }, reverb=0.36, rt60=2.6, loudness=-28.5)


def fanfare():
    song = Song(120, 2, loop=False, tail=3.5, seed=19)
    for index, name in enumerate(["G4", "C5", "E5"]):
        song.put("brass", brass(midi(name), 0.4, 0.75), index * 0.5, pan=0.15, human=0)
    for index, name in enumerate(["C4", "E4", "G4", "C5", "E5"]):
        song.put("brass", brass(midi(name), 2.6, 0.85), 2, pan=(index - 2) * 0.25, human=0)
    song.put("strings", strings(midi("C3"), 2.6, 0.6), 2, human=0)
    song.put("strings", strings(midi("G3"), 2.6, 0.5), 2, pan=0.3, human=0)
    song.put("bass", bass(midi("C2"), 2.6, 0.8), 2, human=0)
    song.put("perc", swell(1.0, 0.7), 0, human=0)
    song.put("perc", drum(55, 130, 0.9, 5.0), 2, human=0)
    song.put("perc", crash(0.7), 2, human=0)
    for name, beat in (("G5", 2.0), ("C6", 2.33), ("E6", 2.66), ("G6", 3.0)):
        song.put("bells", bell(midi(name), 0, 0.6), beat, pan=0.4, human=0)
    return song.mix({
        "brass": {"lp": 4500, "gain": 1.0, "send": 0.35},
        "strings": {"lp": 2500, "gain": 0.6, "send": 0.4},
        "bass": {"lp": 800, "gain": 0.7, "send": 0.05},
        "perc": {"gain": 0.6, "send": 0.25},
        "bells": {"gain": 0.6, "send": 0.6},
    }, reverb=0.3, loudness=-21.0)


TRACKS = (("title", title), ("hospital", hospital), ("theatre", theatre), ("night", night),
          ("emergency", emergency), ("sad", sad), ("fanfare", fanfare))


def write_ogg(name, samples):
    os.makedirs(OUT, exist_ok=True)
    pcm = (np.clip(samples.T, -1, 1) * 32767).astype("<i2")
    with tempfile.TemporaryDirectory() as folder:
        wav_path = os.path.join(folder, name + ".wav")
        with wave.open(wav_path, "wb") as file:
            file.setnchannels(2)
            file.setsampwidth(2)
            file.setframerate(RATE)
            file.writeframes(pcm.tobytes())
        target = os.path.join(OUT, name + ".ogg")
        subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", wav_path, "-c:a", "libvorbis", "-q:a", "2",
                        "-map_metadata", "-1", "-fflags", "+bitexact", "-flags:a", "+bitexact", target], check=True)
    rms = 20 * np.log10(np.sqrt(np.mean(samples ** 2)) + 1e-9)
    print("%s: %.1f s, %d KB, RMS %.1f dB, peak %.2f" % (name, samples.shape[1] / RATE,
                                                         os.path.getsize(target) // 1024, rms, np.max(np.abs(samples))))


def main(names):
    for name, make in TRACKS:
        if not names or name in names:
            write_ogg(name, make())
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))

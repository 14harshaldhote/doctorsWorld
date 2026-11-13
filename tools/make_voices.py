#!/usr/bin/env python3
"""Makes the game's recorded voices (assets/voices) with Kokoro, a free and
open voice model (Apache 2.0) that runs on an ordinary computer, offline.

Every line gets its own clip in the voice of whoever says it, so people in
the game sound like people instead of the phone's reading voice:

  * the story's lines and replies, read straight from story/*.json;
  * the coaching in the skills lab and theatre, and the patients' answers,
    listed by tools/voice_lines.gd (which runs the game) in
    tools/voice_lines.json, plus every answer in story/cases.json.

Each character has their own voice, made by blending Kokoro's voices (so
nobody else's game sounds like this). A line's mood sets its pace, calls
come through a phone, children sound like children. The player's own
doctor is never voiced, so their lines and replies get no clips.

The player's name in a line ({called}) is said as "Doctor". Lines with
numbers in them (a pulse, a swab count) are kept as the words around the
numbers plus each number said on its own, and the game joins them up
(VoiceBank). Clips are named by what they say, so a second run only makes
the clips that changed and removes the ones no longer used.

Needs Python 3.10+, ffmpeg, and:  pip install kokoro-onnx scipy
and Kokoro's two model files (kokoro-v1.0.onnx and voices-v1.0.bin) from
https://github.com/thewh1teagle/kokoro-onnx/releases (model-files-v1.0).

  python3 tools/make_voices.py --model DIR [--jobs 4] [--only iyer,grace]
  python3 tools/make_voices.py --model DIR --sample iyer "A line to try."

Then open the project in Godot (or run godot --headless --import) so the new
clips are imported.
"""

import argparse
import hashlib
import json
import multiprocessing
import os
import re
import subprocess
import sys

import numpy as np

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "assets", "voices")
RATE = 24000

# --- The cast's voices -------------------------------------------------------
# Kokoro voice blends: Indian voices (hf_*, hm_*) give the accent, the others
# give each person their own colour. speed is the person's own pace.
VOICES = {
    "iyer": {"mix": {"hf_alpha": 0.6, "bf_emma": 0.4}, "speed": 0.98},
    "grace": {"mix": {"hf_beta": 0.6, "bf_alice": 0.4}, "speed": 0.97},
    "priya": {"mix": {"hf_beta": 0.55, "af_nova": 0.45}, "speed": 1.04},
    "khan": {"mix": {"hf_alpha": 0.55, "bf_isabella": 0.45}, "speed": 0.98},
    "sunita": {"mix": {"hf_beta": 0.6, "af_sarah": 0.4}, "speed": 1.0},
    "lakshmi": {"mix": {"hf_alpha": 0.5, "bf_lily": 0.5}, "speed": 0.95},
    "leela": {"mix": {"hf_beta": 0.5, "af_kore": 0.5}, "speed": 1.0},
    "mum": {"mix": {"hf_alpha": 0.5, "af_heart": 0.5}, "speed": 1.0},
    "family": {"mix": {"hf_alpha": 0.5, "af_heart": 0.5}, "speed": 1.0},
    "maria": {"mix": {"hf_beta": 0.55, "af_jessica": 0.45}, "speed": 1.0},
    "banerjee": {"mix": {"hf_alpha": 0.6, "bf_lily": 0.4}, "speed": 0.88},
    "deepa": {"mix": {"hf_beta": 0.65, "af_river": 0.35}, "speed": 1.03},
    "farida": {"mix": {"hf_alpha": 0.55, "af_aoede": 0.45}, "speed": 1.0},
    "mehra": {"mix": {"hf_alpha": 0.5, "bf_isabella": 0.3, "bf_emma": 0.2}, "speed": 0.93},
    "anu": {"mix": {"hf_beta": 0.5, "af_sky": 0.5}, "speed": 1.05, "child": True},
    "pooja": {"mix": {"af_sky": 0.5, "hf_beta": 0.5}, "speed": 1.05, "child": True, "phone": True},
    "aarav": {"mix": {"af_sky": 0.6, "hf_beta": 0.4}, "speed": 1.05, "child": True},
    "rao": {"mix": {"hm_omega": 0.6, "bm_george": 0.4}, "speed": 0.95},
    "malhotra": {"mix": {"hm_psi": 0.5, "am_onyx": 0.5}, "speed": 1.0},
    "sethi": {"mix": {"hm_psi": 0.6, "am_liam": 0.4}, "speed": 1.02},
    "tom": {"mix": {"hm_omega": 0.5, "bm_daniel": 0.5}, "speed": 1.0},
    "rohit": {"mix": {"hm_psi": 0.5, "am_puck": 0.5}, "speed": 1.05},
    "nair": {"mix": {"hm_omega": 0.6, "bm_fable": 0.4}, "speed": 0.92},
    "dean": {"mix": {"hm_omega": 0.55, "bm_george": 0.45}, "speed": 0.93},
    "dad": {"mix": {"hm_psi": 0.55, "am_eric": 0.45}, "speed": 1.0},
    "arjun": {"mix": {"hm_psi": 0.55, "am_echo": 0.45}, "speed": 1.06, "phone": True},
    "kunal": {"mix": {"hm_psi": 0.5, "am_fenrir": 0.5}, "speed": 1.06},
    "rider": {"mix": {"hm_omega": 0.6, "am_adam": 0.4}, "speed": 0.9},
    "salim": {"mix": {"hm_omega": 0.5, "am_liam": 0.5}, "speed": 1.0},
    "joseph": {"mix": {"hm_omega": 0.5, "bm_fable": 0.5}, "speed": 0.88},
    "peter": {"mix": {"hm_psi": 0.5, "bm_daniel": 0.5}, "speed": 1.0},
    "bansal": {"mix": {"hm_omega": 0.6, "bm_lewis": 0.4}, "speed": 0.92},
    "raju": {"mix": {"hm_omega": 0.7, "am_echo": 0.3}, "speed": 1.0},
    # A year later: the Senior Resident's intern, patients and colleagues.
    "zoya": {"mix": {"hf_beta": 0.55, "af_bella": 0.45}, "speed": 1.06},
    "gomes": {"mix": {"hf_alpha": 0.5, "bf_lily": 0.3, "bf_emma": 0.2}, "speed": 0.9},
    "rubina": {"mix": {"hf_beta": 0.6, "af_alloy": 0.4}, "speed": 1.04},
    "bhatt": {"mix": {"hm_omega": 0.55, "am_michael": 0.45}, "speed": 1.0},
    "francis": {"mix": {"hm_psi": 0.55, "bm_lewis": 0.45}, "speed": 1.0},
    "nanda": {"mix": {"hm_omega": 0.55, "am_eric": 0.45}, "speed": 0.94},
    "imran": {"mix": {"hm_psi": 0.6, "am_adam": 0.4}, "speed": 0.95},
    # Three months later: the Surgeon's patient, team and board chair.
    "kurup": {"mix": {"hf_alpha": 0.55, "bf_emma": 0.25, "af_heart": 0.2}, "speed": 0.94},
    "venu": {"mix": {"hm_omega": 0.6, "bm_fable": 0.4}, "speed": 0.94},
    "neha": {"mix": {"hf_beta": 0.6, "af_nicole": 0.4}, "speed": 1.03},
    "bose": {"mix": {"hm_psi": 0.55, "bm_daniel": 0.45}, "speed": 1.04},
    "rajan": {"mix": {"hf_alpha": 0.6, "bf_isabella": 0.4}, "speed": 0.93},
}
# The player's doctor: never voiced.
PLAYER = "you"

# A line's mood changes its pace a little.
MOOD_SPEED = {"calm": 0.97, "happy": 1.04, "focused": 1.02, "worried": 1.05, "angry": 1.06,
              "tired": 0.9, "shocked": 1.03}

# Names the voice says wrongly as written, spelt the way they are said.
RESPELL = {
    "Iyer": "Eye-yer", "Nambiar": "Nambiyaar", "Kulkarni": "Coolkarni", "Bhatia": "Bhaatiya",
    "Sethi": "Saythee", "Yadav": "Yaadav", "Sunita": "Soo-neetha", "Kunal": "Koonal", "Priya": "Preeya",
    "Farida": "Fareeda", "Prakash": "Prakaash", "Ramesh": "Raamesh", "Kabir": "Kabeer", "Rawat": "Raawat",
    "Dubai": "Doo-bye", "Asha": "Aasha", "ji": "jee", "Arre": "Arey", "arre": "arey", "Achha": "Achcha",
    "achha": "achcha", "Bhaiya": "Bhaiyya", "Menon": "Maynon", "Fernandes": "Fernandez", "D'Souza": "D Souza",
    "Qureshi": "Koo-ray-shee", "Gomes": "Gomez", "Philomena": "Fillo-meena", "Bhatt": "Bhutt", "Nanda": "Nunda",
    "Imran": "Imraan", "Rubina": "Roo-beena", "Margao": "Mar-gow", "Nagpur": "Naag-poor", "Pune": "Poona",
    "idli": "idlee", "Harish": "Hareesh", "Vivek": "Viveyk", "Zoya": "Zoyaa",
    "co-amoxiclav": "co-amoxi-clav", "Co-amoxiclav": "Co-amoxi-clav", "eGFR": "e G F R",
    "Kurup": "Koo-roop", "Shanta": "Shaanta", "Venu": "Vay-noo", "Neha": "Nay-ha", "Arindam": "Ah-rin-dum",
    "Bose": "Bohs", "Nirmala": "Nir-mala", "Rajan": "Raajan", "Ernakulam": "Er-naa-kulam", "Rehan": "Ray-haan",
    "Joshi": "Joe-shee", "Anand": "Aanand",
}
TITLES = {"Dr.": "Doctor", "Mr.": "Mister", "Mrs.": "Missus", "Ms.": "Miz"}
ACRONYMS = ["ICU", "VIP", "MBBS", "ECG", "CPR", "OPD", "MRI", "HIV", "IVF", "DNA", "CCTV", "ENT", "NICU", "HR", "INR", "CT", "MDT"]
# Test players' names, which turn back into {called} in the catalogue. (Not
# "Rao" or "Joseph": the cast has a Dr. Rao and a Mr. Joseph.)
TEST_NAMES = ["Verma", "Asha", "Kiran", "Mei", "Lin", "Kofi", "Mensah", "Ravi", "Das", "Nila"]
# Numbers get clips around the values heard in each kind of line (a pulse
# of 88 gives 52 to 126), never past this.
LARGEST_NUMBER = 250


def normalize(text):
    """As VoiceBank.normalize(): lower case, letters, digits, {names}."""
    return re.sub(r"[^a-z0-9{}]+", " ", text.lower()).strip()


# --- What is said ------------------------------------------------------------

def story_lines():
    """(who, text, mood) for every story line and reply."""
    found = []

    def walk(item, phone_call):
        if isinstance(item, list):
            for step in item:
                walk(step, phone_call)
        elif isinstance(item, dict):
            if "say" in item and "text" in item:
                found.append((str(item["say"]), str(item["text"]), str(item.get("mood", ""))))
            for key, value in item.items():
                if key == "choose" and isinstance(value, list):
                    for option in value:
                        if isinstance(option, dict) and "text" in option:
                            found.append(("you", str(option["text"]), ""))
                        walk(option, phone_call)
                elif isinstance(value, (list, dict)):
                    walk(value, phone_call)

    for name in sorted(os.listdir(os.path.join(ROOT, "story"))):
        if name.endswith(".json") and name not in ("cast.json", "cases.json"):
            with open(os.path.join(ROOT, "story", name)) as file:
                walk(json.load(file), False)
    return found


def case_lines(heard):
    """Every patient's answer and every finding in story/cases.json, by who
    says it (the patient's actor, or whoever introduces the case)."""
    with open(os.path.join(ROOT, "story", "cases.json")) as file:
        cases = json.load(file)
    said_by = {}
    for who, text in heard:
        said_by.setdefault(normalize(text), who)
    found = []
    for case in cases.values():
        actor = str(case.get("actor", ""))
        host = said_by.get(normalize(str(case.get("opening", ""))), actor or "iyer")
        if case.get("questions"):
            for question in case["questions"]:
                found.append((actor or host, question["answer"]))
            found.append((actor or host, case.get("opening", "")))
            continue
        if case.get("kind") == "chart":
            # The intern who wrote the chart answers for it; Dr. Iyer gives hints.
            for text in list(case.get("brief", {}).values()) + list(case.get("signed", {}).values()):
                found.append((actor, text))
            found.append((actor, case.get("half", "")))
            found.append(("iyer", case.get("no_more", "")))
            for line in case.get("lines", []):
                found.append((actor, line.get("ok", {}).get("defend", "")))
                found.append((actor, line.get("wrong", {}).get("found", "")))
                found.append(("iyer", line.get("wrong", {}).get("hint", "")))
            continue
        if case.get("kind") == "triage":
            # The nurse running the line says everything: what each casualty
            # looks like, what a check finds, and each tag as it's given.
            for text in list(case.get("brief", {}).values()) + list(case.get("sent", {}).values()):
                found.append((actor, text))
            for casualty in case.get("casualties", []):
                for key in ("looks", "walks", "stays"):
                    found.append((actor, casualty.get(key, "")))
                for text in case.get("tagged", {}).values():
                    found.append((actor, text.replace("{who}", casualty.get("short", "them"))))
            continue
        found.append((host, case.get("opening", "")))
        for spot in case.get("spots", []):
            if spot.get("says"):
                found.append((actor or host, spot["says"]))
            if spot.get("finding"):
                found.append((host, spot["finding"]))
        lines = case.get("lines", {})
        for text in (lines.values() if isinstance(lines, dict) else lines):
            if isinstance(text, str):
                found.append((host, text))
    return [(who, text) for who, text in found if who and text]


def catalogue_lines(story):
    """The lines the running game asked for (tools/voice_lines.json) that are
    not story lines, with the test players' names put back as {called}."""
    path = os.path.join(ROOT, "tools", "voice_lines.json")
    if not os.path.exists(path):
        return []
    with open(path) as file:
        heard = [(entry["who"], entry["text"]) for entry in json.load(file)]
    tests = ""
    for name in ("test_speech.gd", "test_recorded_voices.gd"):
        with open(os.path.join(ROOT, "tests", "unit", name)) as file:
            tests += file.read()
    exact = {(who, normalize(text)) for who, text, _mood in story}
    patterns = [(who, re.compile("^" + re.sub(r"\\\{[a-z]+\\\}", "(.+?)", re.escape(normalize(text))) + "$"))
                for who, text, _mood in story if "{" in text]
    names = re.compile(r"\bDr\. (?:%s)\b" % "|".join(TEST_NAMES))
    kept = {}
    for who, text in heard:
        if '"%s"' % text in tests:
            continue  # a line only the tests say
        plain = normalize(text)
        if (who, plain) in exact or any(w == who and p.match(plain) for w, p in patterns):
            continue
        text = names.sub("{called}", text)
        kept[(who, normalize(text))] = (who, text)
    # A line also heard with the cast's names as the player's ("Dr. Rao?").
    for (who, plain), (_, text) in list(kept.items()):
        for cast_name in ("Rao", "Joseph"):
            swapped = text.replace("Dr. %s" % cast_name, "{called}")
            if swapped != text and (who, normalize(swapped)) in kept:
                kept.pop((who, plain), None)
    return list(kept.values()) + case_lines(heard)


def spoken(text):
    """What the voice is given for a shown line."""
    text = text.replace("{called}", "Doctor")
    for title, said in TITLES.items():
        text = re.sub(r"\b" + re.escape(title), said, text)
    for word, said in RESPELL.items():
        text = re.sub(r"(?<![\w'])" + re.escape(word) + r"(?![\w'])", said, text)
    for word in ACRONYMS:
        text = re.sub(r"\b%s\b" % word, " ".join(word), text)
    text = re.sub(r"[·—–]", ", ", text).replace("*", "").replace("_", " ").replace("~", "")
    return re.sub(r"\s+", " ", text).strip()


def number_parts(text):
    """For a line with numbers in it: the key with # for each number, and its
    parts: words to say, or {"number": index}. None when it can't be split."""
    if re.search(r"\d[A-Za-z]|[A-Za-z]\d|\d:\d", text):
        return None
    if any(int(value) > LARGEST_NUMBER for value in re.findall(r"\d+", text)):
        return None  # a year, a phone number: said as it is
    runs = list(re.finditer(r"\d+", text))
    plain = normalize(text)
    if len(runs) != sum(1 for token in plain.split(" ") if token.isdigit()):
        return None
    key = " ".join("#" if token.isdigit() else token for token in plain.split(" "))
    parts = []
    at = 0
    for index, run in enumerate(runs):
        between = text[at:run.start()]
        if index > 0:
            stripped = between.strip()
            if stripped == "/":
                between = " over "
            elif stripped == ".":
                between = " point "
            elif between.startswith("%"):
                between = " percent" + between[1:]
        if re.search(r"[A-Za-z]", between):
            parts.append(between.strip())
        parts.append({"number": index})
        at = run.end()
    tail = text[at:]
    if tail.startswith("%"):
        tail = " percent" + tail[1:]
    if re.search(r"[A-Za-z]", tail):
        parts.append(tail.strip())
    return key, parts


# --- Making a clip -------------------------------------------------------------

_kokoro = None
_styles = {}


def kokoro(model_dir):
    global _kokoro
    if _kokoro is None:
        import onnxruntime
        from kokoro_onnx import Kokoro
        # One thread each: --jobs workers side by side use the cores better.
        options = onnxruntime.SessionOptions()
        options.intra_op_num_threads = 1
        options.inter_op_num_threads = 1
        session = onnxruntime.InferenceSession(os.path.join(model_dir, "kokoro-v1.0.onnx"), options,
                                               providers=["CPUExecutionProvider"])
        _kokoro = Kokoro.from_session(session, os.path.join(model_dir, "voices-v1.0.bin"))
    return _kokoro


def style(model_dir, who):
    if who not in _styles:
        mix = VOICES[who]["mix"]
        total = sum(mix.values())
        _styles[who] = sum(kokoro(model_dir).get_voice_style(name) * (weight / total) for name, weight in mix.items())
    return _styles[who]


def band(samples, low, high):
    from scipy.signal import butter, sosfilt
    sos = butter(4, [low, high], btype="band", fs=RATE, output="sos")
    return sosfilt(sos, samples).astype(np.float32)


def trim(samples, keep=0.04):
    """Cuts the silence at both ends, leaving a little."""
    loud = np.abs(samples) > max(0.01, np.max(np.abs(samples)) * 0.03)
    if not loud.any():
        return samples
    first = max(0, int(np.argmax(loud)) - int(RATE * keep))
    last = min(len(samples), len(samples) - int(np.argmax(loud[::-1])) + int(RATE * keep))
    return samples[first:last]


def room(samples):
    """A small hard room: a short faint tail, so voices aren't bone dry."""
    from scipy.signal import fftconvolve
    rng = np.random.default_rng(7)
    size = int(RATE * 0.18)
    tail = rng.standard_normal(size).astype(np.float32) * np.exp(-np.linspace(0, 8, size)).astype(np.float32)
    tail = band(tail, 400, 5000)
    tail /= np.sqrt(np.sum(tail ** 2)) + 1e-9
    wet = fftconvolve(samples, tail)[:len(samples)]
    return (samples + 0.07 * wet).astype(np.float32)


def phone(samples):
    """Through a phone: a narrow band and a little crunch."""
    narrow = band(samples, 330, 3400)
    return (np.tanh(narrow * 2.4) / np.tanh(2.4)).astype(np.float32)


def child(samples):
    """Higher and a little quicker, like a child."""
    raise_by = 1.12
    positions = np.arange(0, len(samples) - 1, raise_by)
    return np.interp(positions, np.arange(len(samples)), samples).astype(np.float32)


def level(samples, target_db=-19.0, peak=0.89):
    """Even loudness across the cast (speech-weighted RMS), no clipping."""
    weighted = band(samples, 200, 5000)
    rms = np.sqrt(np.mean(weighted ** 2)) + 1e-9
    gain = 10 ** (target_db / 20) / rms
    out = samples * gain
    top = np.max(np.abs(out)) + 1e-9
    if top > peak:
        out *= peak / top
    return out.astype(np.float32)


def word_times(text, length):
    """When each word ends (seconds): spread over the clip by letters, with
    a pause's worth after commas and full stops."""
    words = text.split()
    if not words:
        return []
    weights = []
    for word in words:
        weight = max(1, len(re.sub(r"[^\w]", "", word)))
        if word[-1] in ",;:":
            weight += 3
        elif word[-1] in ".?!":
            weight += 5
        weights.append(weight)
    total = float(sum(weights))
    lead = min(0.08, length * 0.1)
    span = max(0.01, length - lead * 2)
    times = []
    done = 0.0
    for weight in weights:
        done += weight
        times.append(round(lead + span * done / total, 3))
    return times


def render(model_dir, who, text, speed, ending="."):
    """The clip for one piece of speech: float samples."""
    voice = VOICES[who]
    said = spoken(text)
    if said and said[-1] not in ".?!,;:":
        said += ending
    samples, rate = kokoro(model_dir).create(said, voice=style(model_dir, who), speed=speed * voice["speed"],
                                             lang="en-gb")
    assert rate == RATE
    samples = trim(np.asarray(samples, dtype=np.float32))
    if voice.get("child"):
        samples = child(samples)
    samples = phone(samples) if voice.get("phone") else room(samples)
    return level(samples)


def encode(samples, path):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    pcm = (np.clip(samples, -1, 1) * 32767).astype("<i2").tobytes()
    subprocess.run(["ffmpeg", "-y", "-v", "error", "-f", "s16le", "-ar", str(RATE), "-ac", "1", "-i", "-",
                    "-c:a", "libvorbis", "-q:a", "1", path + ".tmp.ogg"], input=pcm, check=True)
    os.replace(path + ".tmp.ogg", path)


def clip_name(who, text, speed, ending):
    digest = hashlib.sha1(json.dumps([VOICES[who], spoken(text), round(speed, 3), ending]).encode()).hexdigest()
    return "%s/%s.ogg" % (who.replace(".", "_"), digest[:12])


def make_clip(job):
    """Makes one clip. Returns its name and manifest part."""
    model_dir, who, text, speed, ending = job
    name = clip_name(who, text, speed, ending)
    samples = render(model_dir, who, text, speed, ending)
    length = round(len(samples) / RATE, 3)
    encode(samples, os.path.join(OUT, name))
    return name, {"clip": name, "length": length, "words": word_times(spoken(text), length)}


def made_before():
    """The clips the last run made that are still on disk, by name."""
    path = os.path.join(OUT, "manifest.json")
    if not os.path.exists(path):
        return {}
    with open(path) as file:
        old = json.load(file)
    parts = [part for line in old.get("lines", []) for part in line["parts"] if "clip" in part]
    parts += [said for numbers_of in old.get("numbers", {}).values() for said in numbers_of.values()]
    return {part["clip"]: part for part in parts if os.path.exists(os.path.join(OUT, part["clip"]))}


# --- The whole cast ------------------------------------------------------------

def plan(model_dir, only):
    """Every clip to make, and the manifest lines that use them."""
    story = story_lines()
    lines = []      # (who, key, [part spec]) where a part spec is a job or {"number": i}
    numbered = {}   # who -> numbers they need clips for
    skipped = []

    def add(who, text, mood, templated):
        if who == PLAYER or (only and who not in only):
            return
        if who not in VOICES:
            skipped.append((who, text))
            return
        if re.search(r"\{(?!called\})[a-z]+\}", text) or not text.strip():
            skipped.append((who, text))
            return
        speed = MOOD_SPEED.get(mood, 1.0)
        split = number_parts(text) if templated and re.search(r"\d", text) else None
        if split is None:
            lines.append((who, normalize(text), [(model_dir, who, text, speed, ".")]))
            return
        key, parts = split
        specs = []
        for index, part in enumerate(parts):
            if isinstance(part, dict):
                specs.append(part)
            else:
                last = index == len(parts) - 1
                specs.append((model_dir, who, part, speed, "." if last else ","))
        lines.append((who, key, specs))
        needed = numbered.setdefault(who, set())
        for value in re.findall(r"\d+", text):
            low = max(0, int(int(value) * 0.6) - 2)
            high = min(LARGEST_NUMBER, int(int(value) * 1.4) + 3)
            needed.update(range(low, high + 1))

    for who, text, mood in story:
        add(who, text, mood, False)
    for who, text in catalogue_lines(story):
        add(who, text, "", True)
    unique = {}
    for who, key, specs in lines:
        unique.setdefault((who, key), (who, key, specs))
    lines = list(unique.values())
    numbers = {who: [(model_dir, who, str(value), 1.0, ",") for value in sorted(numbered[who])]
               for who in sorted(numbered)}
    return lines, numbers, skipped


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--model", required=True, help="folder with kokoro-v1.0.onnx and voices-v1.0.bin")
    parser.add_argument("--jobs", type=int, default=os.cpu_count() or 2)
    parser.add_argument("--only", default="", help="comma list of cast ids to remake")
    parser.add_argument("--sample", nargs=2, metavar=("WHO", "TEXT"), help="write one line to sample.ogg")
    args = parser.parse_args()
    if args.sample:
        who, text = args.sample
        encode(render(args.model, who, text, 1.0), os.path.join(os.getcwd(), "sample.ogg"))
        print("wrote sample.ogg")
        return
    only = set(filter(None, args.only.split(",")))
    lines, numbers, skipped = plan(args.model, only)
    jobs = {}
    for _who, _key, specs in lines:
        for spec in specs:
            if isinstance(spec, tuple):
                jobs[clip_name(*spec[1:])] = spec
    for specs in numbers.values():
        for spec in specs:
            jobs[clip_name(*spec[1:])] = spec
    print("%d lines, %d clips (%d numbers), %d lines left to the phone's voice" % (
        len(lines), len(jobs), sum(len(v) for v in numbers.values()), len(skipped)))
    made = {name: part for name, part in made_before().items() if name in jobs}
    todo = [job for name, job in jobs.items() if name not in made]
    print("%d clips already made, %d to make" % (len(made), len(todo)), flush=True)
    with multiprocessing.Pool(args.jobs) as pool:
        for count, (name, info) in enumerate(pool.imap_unordered(make_clip, todo, chunksize=4), 1):
            made[name] = info
            if count % 100 == 0:
                print("  %d / %d" % (count, len(todo)), flush=True)
    manifest = {"format": 1, "lines": [], "numbers": {}}
    for who, key, specs in lines:
        parts = [spec if isinstance(spec, dict) else made[clip_name(*spec[1:])] for spec in specs]
        manifest["lines"].append({"who": who, "key": key, "parts": parts})
    for who, specs in numbers.items():
        manifest["numbers"][who] = {spec[2]: made[clip_name(*spec[1:])] for spec in specs}
    if only and os.path.exists(os.path.join(OUT, "manifest.json")):
        # Keep everyone else's lines from the last full run.
        with open(os.path.join(OUT, "manifest.json")) as file:
            old = json.load(file)
        remade = {line["who"] for line in manifest["lines"]}
        manifest["lines"] = [line for line in old["lines"] if line["who"] not in remade] + manifest["lines"]
        for who, said in old.get("numbers", {}).items():
            manifest["numbers"].setdefault(who, said)
    manifest["lines"].sort(key=lambda line: (line["who"], line["key"]))
    with open(os.path.join(OUT, "manifest.json"), "w") as file:
        json.dump(manifest, file, separators=(",", ":"), sort_keys=True)
    # Clips no line uses any more go.
    used = {part["clip"] for line in manifest["lines"] for part in line["parts"] if "clip" in part}
    used |= {said["clip"] for numbers_of in manifest["numbers"].values() for said in numbers_of.values()}
    removed = 0
    for folder in os.listdir(OUT):
        full = os.path.join(OUT, folder)
        if not os.path.isdir(full):
            continue
        for name in os.listdir(full):
            if name.endswith(".ogg") and "%s/%s" % (folder, name) not in used:
                for extra in ("", ".import"):
                    if os.path.exists(os.path.join(full, name + extra)):
                        os.remove(os.path.join(full, name + extra))
                removed += 1
        if not os.listdir(full):
            os.rmdir(full)
    print("manifest: %d lines; removed %d unused clips" % (len(manifest["lines"]), removed))
    for who, text in skipped[:20]:
        print("  left to the phone's voice: %s: %s" % (who, text[:80]))


if __name__ == "__main__":
    sys.exit(main())

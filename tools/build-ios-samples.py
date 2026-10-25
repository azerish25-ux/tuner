#!/usr/bin/env python3
"""Build Timbre's sampled instruments: ios/Timbre/Resources/Samples (AAC .m4a + manifest.json) and the per-file
source/licence table in docs/content/AUDIO-SOURCES.md.

Only CC0 libraries hosted on GitHub are used, each pinned to a commit and checked for its CC0 LICENSE file before a
single sample is read. Every shipped file is traced to its source path and the SHA-256 of the original recording.

What the script does to each recording (the app does the rest at play time, see TimbreCore/Audio/SampleLibrary.swift):
  * mono (channels averaged; drums mix close and overhead mics), 44.1 kHz;
  * leading silence trimmed to a 2-5 ms pre-roll, tails trimmed and faded (sustained notes are cut before their
    natural release and get a loop region of whole periods instead);
  * the fundamental measured to a hundredth of a cent (Hann-windowed DTFT on the steady part), so the app can pitch
    any note from the nearest zone with an exact ratio; samples more than 35 cents from their equal-tempered note
    are rejected;
  * peak-normalised to -1 dBFS for the encoder, with a per-file gain that evens the attack loudness of the set;
  * encoded with ffmpeg's AAC (mono, 80-112 kbps), then decoded again to verify the pitch and the attack position.

Usage:  python3 -I tools/build-ios-samples.py [--cache DIR] [--only piano,guitar] [--doc-only]
Needs git, ffmpeg (/usr/bin/ffmpeg) and numpy. Clones are partial (blob:none) and only the selected recordings are
fetched (about 400 MB in all), into --cache (default ~/.cache/timbre-samples).
"""
from __future__ import annotations

import argparse
import hashlib
import json
import math
import re
import subprocess
import sys
from pathlib import Path

import numpy as np

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'ios/Timbre/Resources/Samples'
DOC = ROOT / 'docs/content/AUDIO-SOURCES.md'
FFMPEG = '/usr/bin/ffmpeg' if Path('/usr/bin/ffmpeg').exists() else 'ffmpeg'
RATE = 44100
MANIFEST_VERSION = 1
BUDGET_BYTES = 35 * 1000 * 1000

CC0_URL = 'https://creativecommons.org/publicdomain/zero/1.0/'

# Pinned sources. `licence_file` must exist at the commit and contain `licence_marker`.
SOURCES = {
    'vcsl': dict(
        title='Versilian Community Sample Library (VCSL)', author='Versilian Studios LLC',
        repo='https://github.com/sgossner/VCSL', commit='c1ea7bcc3c7309650ab0da9d15c9cd1fbc4a4c7e',
        licence='CC0-1.0', licence_file='LICENSE', licence_marker='CC0 1.0 Universal',
        note='README: "This collection is under a Creative Commons 0 license ... even make commercial software, no '
             'royalties, no credit, no special terms."'),
    'vsco2': dict(
        title='VS Chamber Orchestra: Community Edition (VSCO 2 CE)',
        author='Versilian Studios LLC (Sam Gossner) and Ivy Audio (Simon Dalzell)',
        repo='https://github.com/sgossner/VSCO-2-CE', commit='440300901dfe9275fd84e0b7763af1f8443ae62e',
        licence='CC0-1.0', licence_file='LICENSE', licence_marker='CC0 1.0 Universal',
        note='Readme.txt: "You are permitted to use these samples for ANY purpose. We ask that you do not sell the '
             'samples directly" (Timbre does not sell them; they only sound inside the app) and asks for credit, '
             'which Timbre gives in Settings > Acknowledgements.'),
    'virtuosity': dict(
        title='Virtuosity Drums', author='Versilian Studios LLC (drummer Austin McMahon)',
        repo='https://github.com/sfzinstruments/virtuosity_drums', commit='9f04cf9a734527edfbb0a4eee1f674e45bbf71bc',
        licence='CC0-1.0', licence_file='LICENSE', licence_marker='CC0 1.0 Universal',
        note='Recorded at Virtuosity Musical Instruments, Boston.'),
    'shinyguitar': dict(
        title='Shinyguitar (acoustic microphone)', author='Karoryfer Samples (D. Smolken)',
        repo='https://github.com/sfzinstruments/karoryfer.shinyguitar', commit='57243cca85277dbcc120ce17c6178032f93c80f3',
        licence='CC0-1.0', licence_file='LICENSE', licence_marker='CC0 1.0 Universal',
        note='readme.txt: "This sample library is royalty-free for all commercial and non-commercial use."'),
    'growlybass': dict(
        title='Growlybass', author='Karoryfer Samples',
        repo='https://github.com/sfzinstruments/karoryfer.growlybass', commit='4f483268fc66b5a6d5781d421c0d11b8d08d3fc6',
        licence='CC0-1.0', licence_file='LICENSE', licence_marker='CC0 1.0 Universal',
        note='readme.txt: "Royalty-free for all commercial and non-commercial use."'),
    'ganjo': dict(
        title='ganjo (six-string banjo)', author='itsclipping',
        repo='https://github.com/sfzinstruments/ganjo', commit='ccff5cd5cd3b513873a48994c07724d9d3c39e1c',
        licence='CC0-1.0', licence_file='LICENSE.md', licence_marker='CC0 1.0 Universal',
        note=''),
}

# Libraries looked at and not used (kept in the doc so nobody re-adds them without a fresh licence check).
REJECTED = [
    ('nbrosowsky/tonejs-instruments', 'Repackages samples from several origins under one CC-BY 3.0 notice: VSCO 2 CE '
     '(taken from the CC0 original instead), University of Iowa MIS guitar (Iowa terms, not CC0/CC-BY), Freesound '
     'packs 12408 (cello) and 11573 (nylon guitar) whose original licences could not be verified from here. Rejected '
     'as unclear.'),
    ('sfzinstruments/SplendidGrandPiano', 'Described as "public domain samples by AKAI" with no licence file or '
     'dedication from the rights holder. Rejected as unclear.'),
    ('Salamander Drumkit, Sam\'s Sonor, LivingRoom Upright, BJDNiel', 'CC-BY-SA: share-alike terms; not CC0/CC-BY.'),
    ('jRhodes3c/3d, Rickenbacker 4001, MF Tin Whistle', 'Non-commercial (NC) licences.'),
    ('FlameStudios Kay 5-String Banjo', 'GPL-3.0: not a CC0/CC-BY sample licence.'),
    ('Karoryfer Bigcat Cello, Black and Green Guitars', 'CC0, but not needed (Bigcat is not on GitHub).'),
]

NOTE_RE = re.compile(r'^([A-Ga-g])([#b]?)(-?\d)$')
PITCH_CLASS = {'c': 0, 'd': 2, 'e': 4, 'f': 5, 'g': 7, 'a': 9, 'b': 11}


def note_midi(name: str) -> int:
    """MIDI number of a note name in the C4 = 60 convention (C#4, Db4, db2, A#0)."""
    m = NOTE_RE.match(name)
    if not m:
        raise ValueError(name)
    letter, accidental, octave = m.groups()
    pc = PITCH_CLASS[letter.lower()] + (1 if accidental == '#' else -1 if accidental == 'b' else 0)
    return 12 * (int(octave) + 1) + pc


def hz_of(midi: float) -> float:
    return 440.0 * 2 ** ((midi - 69) / 12)


# MARK: - Instruments
#
# `select`: regex over file names in `dir`, with named groups `note` and (optionally) `layer`/`rr`.
# `layers`: layer token -> (name, nominal velocity 0...1). `step(midi)`: semitones to the next zone kept.
# `range`: sounding MIDI range of the zones kept. `seconds(midi)`: longest sample kept (plucked) or the sustain kept
# before the loop end (sustained). `voices`: InstrumentVoice raw values this set plays.

def piano_seconds(m):
    return 6.0 if m < 48 else 5.0 if m < 64 else 4.0 if m < 76 else 3.0


INSTRUMENTS = [
    dict(id='piano', title='Grand piano', voices=['piano'], kind='plucked', source='vcsl',
         dir='Chordophones/Zithers/Grand Piano, Steinway B/Sus',
         select=r'^JHPiano_Sus_Close_(?P<note>[A-G]#?\d)_vl(?P<layer>[23])_rr1\.wav$',
         layers={'3': ('mf', 0.75), '2': ('p', 0.4)},
         step=lambda m: 2 if 34 <= m <= 86 else 4, range=(21, 108), seconds=piano_seconds,
         release=0.18, bitrate=112, coverage=(21, 108)),
    dict(id='guitar', title='Archtop guitar (acoustic)', voices=['guitar'], kind='plucked', source='shinyguitar',
         dir='Samples/acoustic', select=r'^(?P<note>[a-g]b?\d)_vl(?P<layer>3)_rr1_1\.wav$',
         layers={'3': ('mf', 0.75)}, step=lambda m: 3, range=(37, 84), seconds=lambda m: 4.5 if m < 55 else 3.8,
         release=0.08, bitrate=96, coverage=(35, 88)),
    dict(id='bass', title='Electric bass', voices=['bass'], kind='plucked', source='growlybass',
         dir='sustain', select=r'^(?P<note>[a-g]b?\d)_(?P<layer>f|p)_rr1\.wav$',
         layers={'f': ('f', 0.85), 'p': ('p', 0.45)}, step=lambda m: 2, range=(24, 64), seconds=lambda m: 3.2,
         release=0.07, bitrate=80, coverage=(23, 67)),
    dict(id='banjo', title='Six-string banjo', voices=['banjo'], kind='plucked', source='ganjo',
         dir='Common', select=r'^Banjo_Common - (?P<note>[A-G]#?\d)\.wav$', layers={'': ('mf', 0.75)},
         step=lambda m: 2, range=(36, 84), seconds=lambda m: 3.0, release=0.07, bitrate=96, coverage=(36, 88)),
    dict(id='harp', title='Concert harp', voices=['harp'], kind='plucked', source='vcsl',
         dir='Chordophones/Composite Chordophones/Concert Harp',
         select=r'^KSHarp_(?P<note>[A-G]#?\d)_(?P<layer>mf|f|mp|p)\d\.wav$',
         layers={'mf': ('mf', 0.75)}, fallback_layers={'f': ('mf', 0.75), 'mp': ('mf', 0.75), 'p': ('mf', 0.75)},
         step=lambda m: 2, range=(28, 103), seconds=lambda m: 4.0 if m < 60 else 3.0, release=0.12, bitrate=96,
         coverage=(24, 105)),
    dict(id='marimba', title='Marimba', voices=['mallet'], kind='struck', source='vcsl',
         dir='Idiophones/Struck Idiophones/Marimba', select=r'^Marimba_hit_Outrigger_(?P<note>[A-G]#?\d)_(?P<layer>med)_01\.wav$',
         layers={'med': ('mf', 0.75)}, step=lambda m: 2, range=(36, 100), seconds=lambda m: 2.5 if m < 60 else 1.8,
         release=0.06, bitrate=96, coverage=(33, 103)),
    dict(id='violin', title='Solo violin (arco, vibrato)', voices=['violin'], kind='sustained', source='vsco2',
         dir='Strings/Solo Violin/Arco Vib', select=r'^LLVln_ArcoVib_(?P<note>[A-G]#?\d)_(?P<layer>f)\.wav$',
         layers={'f': ('mf', 0.75)}, step=lambda m: 2, range=(55, 100), seconds=lambda m: 3.6, release=0.16,
         bitrate=96, steady=False, coverage=(55, 103)),
    dict(id='cello', title='Cellos (section, vibrato) and solo double bass', voices=['cello'], kind='sustained',
         source='vsco2', dir='Strings/Cello Section/susvib', select=r'^susvib_(?P<note>[A-G]#?\d)_v(?P<layer>3)_1\.wav$',
         layers={'3': ('mf', 0.75)}, step=lambda m: 2, range=(36, 79), seconds=lambda m: 3.6, release=0.18,
         bitrate=96, steady=False, coverage=(26, 82),
         extra=dict(source='vsco2', dir='Strings/Solo Contrabass/SusNV',
                    select=r'^BKCtbss_SusNV_(?P<note>[A-G]#?\d)_v(?P<layer>3)_rr1\.wav$', range=(28, 35))),
    dict(id='flute', title='Flute (non-vibrato)', voices=['flute'], kind='sustained', source='vsco2',
         dir='Woodwinds/Flute/susNV', select=r'^LDFlute_susNV_(?P<note>[A-G]#?\d)_v(?P<layer>[13])_1\.wav$',
         layers={'3': ('mf', 0.75)}, fallback_layers={'1': ('mf', 0.75)}, step=lambda m: 2, range=(58, 98),
         seconds=lambda m: 3.4, release=0.12, bitrate=96, steady=True, coverage=(58, 100)),
    dict(id='clarinet', title='Clarinet', voices=['reed'], kind='sustained', source='vsco2',
         dir='Woodwinds/Clarinet/susLong', select=r'^DCClar_susLong_(?P<note>[A-G]#?\d)_v(?P<layer>2)_rr1_sum\.wav$',
         layers={'2': ('mf', 0.75)}, step=lambda m: 2, range=(48, 92), seconds=lambda m: 3.4, release=0.1,
         bitrate=96, steady=True, coverage=(48, 95)),
    dict(id='brass', title='Trumpet and tenor trombone', voices=['brass'], kind='sustained', source='vsco2',
         dir='Brass/Trumpet/sus', select=r'^Sum_SHTrumpet_sus_(?P<note>[A-G]#?\d)_v(?P<layer>3)_rr1\.wav$',
         layers={'3': ('mf', 0.75)}, step=lambda m: 2, range=(52, 86), seconds=lambda m: 3.2, release=0.1,
         bitrate=96, steady=True, coverage=(36, 88),
         extra=dict(source='vsco2', dir='Brass/Tenor Trombone/sus',
                    select=r'^tenortbn_sus_(?P<note>[A-G]#?\d)_v(?P<layer>2)_1\.wav$', range=(38, 51))),
]

# Drum pieces: (piece, nominal velocity, [files per round robin], mic weights, seconds, attack loudness target).
# Virtuosity Drums keeps separate kick, snare, overhead and room mics; each hit here is the close mic with the
# overheads under it, summed to mono.
V = 'Samples/{mic}/{group}/{mic}_{name}.flac'
DRUMS = dict(
    id='drums', title='Drum kit', source='virtuosity',
    pieces=[
        ('kick', 0.5, ['kick_snon_vl2_rr1', 'kick_snon_vl2_rr2'], 'kick', {'kickmic': 1.0, 'oh': 0.55}, 0.7),
        ('kick', 0.9, ['kick_snon_vl4_rr1', 'kick_snon_vl4_rr2'], 'kick', {'kickmic': 1.0, 'oh': 0.55}, 0.7),
        ('snare', 0.45, ['snare_center_vl16', 'snare_center_vl18'], 'snare', {'snaremic': 1.0, 'oh': 0.6}, 0.8),
        ('snare', 0.85, ['snare_center_vl29', 'snare_center_vl31'], 'snare', {'snaremic': 1.0, 'oh': 0.6}, 0.8),
        ('hat', 0.45, ['hh_closed_vl2_rr1', 'hh_closed_vl2_rr2'], 'hh', {'oh': 1.0}, 0.35),
        ('hat', 0.85, ['hh_closed_vl4_rr1', 'hh_closed_vl4_rr2'], 'hh', {'oh': 1.0}, 0.35),
        ('openhat', 0.75, ['hh_open_vl3_rr1'], 'hh', {'oh': 1.0}, 1.3),
        ('ride', 0.6, ['ride_ride_vl2_rr1', 'ride_ride_vl2_rr2'], 'ride', {'oh': 1.0}, 1.8),
        ('crash', 0.85, ['crash_crash_vl3_rr1'], 'crash', {'oh': 1.0}, 2.6),
    ])


# MARK: - Sources

def run(cmd, **kw):
    return subprocess.run(cmd, check=True, **kw)


def checkout(cache: Path, key: str, paths: list[str]) -> Path:
    """A partial clone of the source at its pinned commit with `paths` fetched; the CC0 licence checked first."""
    source = SOURCES[key]
    repo = cache / key
    if not (repo / '.git').exists():
        run(['git', 'clone', '-q', '--filter=blob:none', '--no-checkout', source['repo'] + '.git', str(repo)])
    have = subprocess.run(['git', '-C', str(repo), 'cat-file', '-e', source['commit'] + '^{commit}'],
                          capture_output=True).returncode == 0
    if not have:
        run(['git', '-C', str(repo), 'fetch', '-q', '--filter=blob:none', 'origin', source['commit']])
    run(['git', '-C', str(repo), 'checkout', '-q', source['commit'], '--', source['licence_file']])
    licence = (repo / source['licence_file']).read_text(encoding='utf-8', errors='replace')
    if source['licence_marker'] not in licence:
        sys.exit(f'{key}: {source["licence_file"]} at {source["commit"]} is not {source["licence"]}; refusing to build')
    missing = [p for p in paths if not (repo / p).exists()]
    for i in range(0, len(missing), 200):
        run(['git', '-C', str(repo), 'checkout', '-q', source['commit'], '--', *missing[i:i + 200]],
            stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    return repo


def listing(cache: Path, key: str, folder: str) -> list[str]:
    source = SOURCES[key]
    repo = cache / key
    if not (repo / '.git').exists():
        checkout(cache, key, [])
    out = subprocess.run(['git', '-C', str(repo), 'ls-tree', '--name-only', source['commit'], folder.rstrip('/') + '/'],
                         check=True, capture_output=True, text=True).stdout
    return [line.split('/')[-1] for line in out.splitlines()]


def sha256(path: Path) -> str:
    h = hashlib.sha256()
    with open(path, 'rb') as f:
        for block in iter(lambda: f.read(1 << 20), b''):
            h.update(block)
    return h.hexdigest()


# MARK: - Audio

def decode(path: Path) -> np.ndarray:
    """Mono float64 at RATE (channels averaged)."""
    raw = subprocess.run([FFMPEG, '-v', 'error', '-i', str(path), '-f', 'f32le', '-acodec', 'pcm_f32le', '-ar', str(RATE),
                          '-ac', '1', '-'], check=True, capture_output=True).stdout
    return np.frombuffer(raw, dtype='<f4').astype(np.float64)


def encode(samples: np.ndarray, path: Path, bitrate: int):
    path.parent.mkdir(parents=True, exist_ok=True)
    pcm = np.clip(samples, -1, 1).astype('<f4').tobytes()
    run([FFMPEG, '-v', 'error', '-y', '-f', 'f32le', '-ar', str(RATE), '-ac', '1', '-i', '-', '-c:a', 'aac',
         '-b:a', f'{bitrate}k', '-movflags', '+faststart', '-map_metadata', '-1', '-fflags', '+bitexact',
         '-flags:a', '+bitexact', '-f', 'ipod', str(path)], input=pcm)


def envelope_db(x: np.ndarray, window: int) -> np.ndarray:
    n = len(x) // window
    if n == 0:
        return np.array([-200.0])
    blocks = x[:n * window].reshape(n, window)
    return 10 * np.log10(np.mean(blocks ** 2, axis=1) + 1e-20)


def onset(x: np.ndarray, below_peak_db: float) -> int:
    peak = np.max(np.abs(x))
    above = np.nonzero(np.abs(x) >= peak * 10 ** (below_peak_db / 20))[0]
    return int(above[0]) if len(above) else 0


def dtft_power(xw: np.ndarray, n: np.ndarray, f: float) -> float:
    """Power of the (already windowed) segment at `f` Hz."""
    return float(np.abs(np.dot(xw, np.exp(-2j * np.pi * f / RATE * n))) ** 2)


def refine_peak(xw: np.ndarray, f: float, cents: float) -> tuple[float, float]:
    """Frequency and power of the strongest component within `cents` of `f`: a coarse grid, then golden section on
    the windowed DTFT (a Hann window keeps the main lobe smooth, so the search converges on its centre)."""
    n = np.arange(len(xw), dtype=np.float64)
    grid = f * 2 ** (np.linspace(-cents, cents, 25) / 1200)
    powers = [dtft_power(xw, n, g) for g in grid]
    i = int(np.argmax(powers))
    low, high = grid[max(0, i - 1)], grid[min(len(grid) - 1, i + 1)]
    golden = (math.sqrt(5) - 1) / 2
    c, d = high - golden * (high - low), low + golden * (high - low)
    pc, pd = dtft_power(xw, n, c), dtft_power(xw, n, d)
    for _ in range(32):
        if pc > pd:
            high, d, pd = d, c, pc
            c = high - golden * (high - low)
            pc = dtft_power(xw, n, c)
        else:
            low, c, pc = c, d, pd
            d = low + golden * (high - low)
            pd = dtft_power(xw, n, d)
    best = (low + high) / 2
    return best, dtft_power(xw, n, best)


def peak_near(seg: np.ndarray, f: float, cents: float) -> tuple[float, float]:
    xw = (seg - np.mean(seg)) * np.hanning(len(seg))
    return refine_peak(xw, f, cents)


def band_peak(spectrum: np.ndarray, bin_hz: float, f: float, cents: float) -> float:
    lo = max(1, int(f * 2 ** (-cents / 1200) / bin_hz))
    hi = min(len(spectrum) - 1, int(math.ceil(f * 2 ** (cents / 1200) / bin_hz)) + 1)
    return float(spectrum[lo:hi].max()) if hi > lo else 0.0


def measure_pitch(x: np.ndarray, nominal_midi: int, start: int, length: int, partial: int | None = None,
                  octave_fixed: bool = False) -> tuple[float, int, int]:
    """The fundamental in Hz over x[start:start+length], and the octave-corrected MIDI note. The note's pitch class is
    trusted; its octave is the candidate whose harmonics hold the most energy (sample sets name octaves differently)."""
    seg = x[start:start + length]
    if len(seg) < 8192:
        seg = x[:max(8192, length)]
    seg = seg - np.mean(seg)
    xw = seg * np.hanning(len(seg))
    size = 1 << 19
    spectrum = np.abs(np.fft.rfft(xw, size))
    bin_hz = RATE / size
    best_score, best_midi = -1.0, nominal_midi
    for k in ((0,) if octave_fixed else (-2, -1, 0, 1, 2)):
        midi = nominal_midi + 12 * k
        f = hz_of(midi)
        if f < 20 or f * 2 > RATE / 2:
            continue
        score = 0.0
        for h in range(1, 9):
            if h * f >= RATE / 2.2:
                break
            score += band_peak(spectrum, bin_hz, h * f, 40) / math.sqrt(h)
        if score > best_score:
            best_score, best_midi = score, midi
    f = hz_of(best_midi)
    partials = [(h, band_peak(spectrum, bin_hz, h * f, 60)) for h in range(1, 7) if h * f < RATE / 2.2]
    strongest = max(p for _, p in partials)
    # The fundamental itself unless it is buried (low piano and bass notes), then the first clear partial.
    h = partial or next((h for h, p in partials if p >= 0.1 * strongest), partials[0][0])
    coarse = np.argmax(spectrum[int(h * f * 2 ** (-60 / 1200) / bin_hz):int(h * f * 2 ** (60 / 1200) / bin_hz) + 2])
    coarse_hz = (int(h * f * 2 ** (-60 / 1200) / bin_hz) + coarse) * bin_hz
    freq, _ = refine_peak(xw, coarse_hz, 3)
    return freq / h, best_midi, h


def raised_cosine_fade(x: np.ndarray, frames: int, at_end: bool) -> None:
    frames = min(frames, len(x))
    if frames <= 0:
        return
    ramp = 0.5 - 0.5 * np.cos(np.pi * np.arange(frames) / frames)
    if at_end:
        x[-frames:] *= ramp[::-1]
    else:
        x[:frames] *= ramp


def loop_region(x: np.ndarray, hz: float, start_s: float, end_frame: int) -> tuple[int, int]:
    """A loop of whole periods inside the steady sustain, ending at `end_frame`, its start nudged (within one period)
    to where the waveform best matches what precedes the end, so the play-time crossfade stays in phase."""
    period = RATE / hz
    length_s = max(0.6, min(1.6, end_frame / RATE - start_s))
    periods = max(1, round(length_s * hz))
    length = int(round(periods * period))
    start = end_frame - length
    xfade = int(0.08 * RATE)
    if start - xfade < int(0.3 * RATE):
        return 0, 0
    ref = x[end_frame - xfade:end_frame]
    best, best_corr = start, -2.0
    span = int(math.ceil(period))
    for s in range(start - span, start + span + 1):
        cand = x[s - xfade:s]
        denom = np.linalg.norm(cand) * np.linalg.norm(ref)
        corr = float(np.dot(cand, ref) / denom) if denom > 0 else -1
        if corr > best_corr:
            best, best_corr = s, corr
    return best, end_frame


# MARK: - Build

def pick_zones(entries: list[tuple[int, str, str]], step, lo: int, hi: int) -> list[int]:
    """Sounding MIDI notes to keep: greedily, each at least `step(midi)` above the previous."""
    notes = sorted({m for m, _, _ in entries if lo <= m <= hi})
    kept: list[int] = []
    for m in notes:
        if not kept or m - kept[-1] >= step(kept[-1]):
            kept.append(m)
    if notes and kept[-1] != notes[-1] and notes[-1] - kept[-1] >= 2:
        kept.append(notes[-1])
    return kept


def survey(cache: Path, spec: dict, select: str, folder: str, source: str) -> list[tuple[int, str, str, Path, str]]:
    """(sounding midi, layer token, file, local path, repo path) for every matching recording, pitch-checked."""
    rx = re.compile(select)
    names = [n for n in listing(cache, source, folder) if rx.match(n)]
    paths = [f'{folder}/{n}' for n in names]
    repo = checkout(cache, source, paths)
    found = []
    for name, rel in zip(names, paths):
        m = rx.match(name)
        token = m.groupdict().get('layer') or ''
        found.append((note_midi(m.group('note')), token, name, repo / rel, rel))
    return found


def process_note(path: Path, nominal: int, kind: str, seconds: float, steady: bool, hint_midi: int | None):
    x = decode(path)
    if len(x) < RATE // 4:
        raise ValueError('too short')
    sustained = kind == 'sustained'
    start = max(0, onset(x, -40 if sustained else -32) - int((0.005 if sustained else 0.002) * RATE))
    x = x[start:].copy()
    raised_cosine_fade(x, int(0.001 * RATE), at_end=False)
    window_start = int((0.45 if sustained else 0.12) * RATE)
    window_len = int(1.0 * RATE)
    hz, midi, partial = measure_pitch(x, nominal if hint_midi is None else hint_midi, window_start, window_len,
                                      octave_fixed=hint_midi is not None)
    cents = 1200 * math.log2(hz / hz_of(midi))
    if abs(cents) > 35:
        raise ValueError(f'{cents:+.1f} cents from {midi}')
    loop = None
    if sustained:
        # Up to `seconds` of the sustain, stopping before the player's own release (the level falling 6 dB under the
        # median of the held note); the app supplies its own release and loops the end when a note is held longer.
        env = envelope_db(x, 1024)
        settled = env[int(0.4 * RATE) // 1024:]
        held = np.median(settled) if len(settled) else env.max()
        falling = np.nonzero(settled < held - 6)[0]
        sustain_end = (int(0.4 * RATE) // 1024 + int(falling[0])) * 1024 if len(falling) else len(x)
        keep = min(len(x), int(seconds * RATE), max(int(1.6 * RATE), sustain_end))
        x = x[:keep]
        end = keep - int(0.02 * RATE)
        ls, le = loop_region(x, hz, 0.9, end)
        if le > ls > 0:
            loop = [ls, le]
        raised_cosine_fade(x, int(0.02 * RATE), at_end=True)
    else:
        env = envelope_db(x, 1024)
        peak_db = env.max()
        quiet = np.nonzero(env < peak_db - 60)[0]
        natural = (int(quiet[quiet > 4][0]) * 1024) if np.any(quiet > 4) else len(x)
        keep = min(len(x), natural, int(seconds * RATE))
        x = x[:keep]
        raised_cosine_fade(x, min(int(0.3 * RATE), keep // 4), at_end=True)
    peak = float(np.max(np.abs(x)))
    x *= 0.89 / peak
    attack = x[:int(0.3 * RATE)] if not sustained else x[int(0.3 * RATE):int(1.0 * RATE)]
    rms = float(np.sqrt(np.mean(attack ** 2)))
    return x, hz, midi, cents, loop, rms, partial


def mark(x: np.ndarray) -> tuple[int, float]:
    """The attack marker: first frame at a quarter of the peak. The app finds the same frame in its own decoding and
    drops whatever its decoder put before it (AAC priming), so attacks land on the sample they were written for."""
    level = float(np.max(np.abs(x))) * 0.25
    idx = np.nonzero(np.abs(x) >= level)[0]
    return int(idx[0]) if len(idx) else 0, level


def verify(path: Path, expect_mark: int, level: float, midi: int | None, sustained: bool,
           partial: int | None = None) -> tuple[int, float | None]:
    """Decodes the encoded file again: how far its attack marker moved, and its fundamental (same window as the build)."""
    y = decode(path)
    idx = np.nonzero(np.abs(y) >= level)[0]
    got = int(idx[0]) if len(idx) else -1
    measured = None
    if midi is not None:
        measured, _, _ = measure_pitch(y, midi, int((0.45 if sustained else 0.12) * RATE), int(1.0 * RATE),
                                       partial=partial, octave_fixed=True)
    return got - expect_mark, measured


def build_instrument(cache: Path, spec: dict, report: list) -> dict:
    groups = [(spec['source'], spec['dir'], spec['select'], spec['range'])]
    if 'extra' in spec:
        e = spec['extra']
        groups.append((e['source'], e['dir'], e['select'], e['range']))
    layers = dict(spec['layers'])
    fallback = spec.get('fallback_layers', {})
    zones = []
    folder = OUT / spec['id']
    for source, directory, select, (lo, hi) in groups:
        found = survey(cache, spec, select, directory, source)
        # Octave-correct each recording first (sets name octaves differently), then keep sparse zones.
        resolved = []
        for nominal, token, name, path, rel in found:
            if token not in layers and token not in fallback:
                continue
            try:
                x, hz, midi, cents, loop, rms, partial = process_note(path, nominal, spec['kind'],
                                                                      spec['seconds'](nominal), spec.get('steady', False), None)
            except ValueError as error:
                report.append(f'  reject {rel}: {error}')
                continue
            resolved.append(dict(midi=midi, token=token, name=name, path=path, rel=rel, x=x, hz=hz, cents=cents,
                                 loop=loop, rms=rms, source=source, partial=partial))
        by_midi = {}
        for r in resolved:
            by_midi.setdefault(r['midi'], []).append(r)
        entries = [(m, '', '') for m in by_midi]
        keep = pick_zones(entries, spec['step'], lo, hi)
        for m in keep:
            choices = by_midi[m]
            primary = [c for c in choices if c['token'] in layers]
            if not primary:
                primary = [c for c in choices if c['token'] in fallback][:1]
            for c in primary:
                lname, velocity = layers.get(c['token']) or fallback[c['token']]
                c['layer'], c['velocity'] = lname, velocity
                zones.append(c)
    # Recompute the trims with each zone's own seconds (by its corrected pitch) for plucked sets.
    target = 0.12 if spec['kind'] != 'sustained' else 0.1
    out_zones = []
    for z in sorted(zones, key=lambda z: (z['midi'], -z['velocity'])):
        if spec['kind'] != 'sustained':
            x, hz, midi, cents, loop, rms, partial = process_note(z['path'], z['midi'], spec['kind'],
                                                                  spec['seconds'](z['midi']), False, z['midi'])
            z.update(x=x, hz=hz, cents=cents, rms=rms, partial=partial)
        file = f"{spec['id']}/{spec['id']}-{z['midi']:03d}-{z['layer']}.m4a"
        encode(z['x'], OUT / file, spec['bitrate'])
        frame, level = mark(z['x'])
        shift, measured = verify(OUT / file, frame, level, z['midi'], spec['kind'] == 'sustained', z['partial'])
        drift = None if measured is None else 1200 * math.log2(measured / z['hz'])
        if abs(shift) > 4 or (drift is not None and abs(drift) > 0.5):
            sys.exit(f'{file}: encoded attack moved {shift} frames, pitch {drift} cents')
        zone = dict(file=file, midi=z['midi'], hz=round(z['hz'], 5), layer=z['layer'], velocity=z['velocity'],
                    gain=round(target * z['velocity'] / max(1e-6, z['rms']), 5), frames=len(z['x']),
                    mark=frame, markLevel=round(level, 6), source=z['source'], original=z['rel'],
                    sha256=sha256(z['path']), cents=round(z['cents'], 2))
        if z['loop']:
            zone['loop'] = z['loop']
        out_zones.append(zone)
        report.append(f"  {file}: {z['hz']:.3f} Hz ({z['cents']:+.1f} c), {len(z['x']) / RATE:.2f} s"
                      + (f", loop {z['loop'][0]}-{z['loop'][1]}" if z['loop'] else ''))
    return dict(id=spec['id'], title=spec['title'], voices=spec['voices'], kind=spec['kind'],
                release=spec['release'], steady=spec.get('steady', spec['kind'] != 'sustained'),
                coverage=list(spec['coverage']), zones=out_zones)


def build_drums(cache: Path, report: list) -> dict:
    spec = DRUMS
    paths = []
    for _, _, files, group, mics, _ in spec['pieces']:
        for f in files:
            for mic in mics:
                paths.append(V.format(mic=mic, group=group, name=f))
    repo = checkout(cache, spec['source'], paths)
    targets = dict(kick=0.30, snare=0.22, hat=0.06, openhat=0.06, ride=0.06, crash=0.08)
    out = []
    for piece, velocity, files, group, mics, seconds in spec['pieces']:
        for rr, f in enumerate(files, 1):
            mix = None
            for mic, weight in mics.items():
                y = decode(repo / V.format(mic=mic, group=group, name=f)) * weight
                mix = y if mix is None else (np.pad(mix, (0, max(0, len(y) - len(mix)))) +
                                             np.pad(y, (0, max(0, len(mix) - len(y)))))
            x = mix
            start = max(0, onset(x, -30) - int(0.002 * RATE))
            x = x[start:start + int(seconds * RATE)].copy()
            raised_cosine_fade(x, int(0.0005 * RATE), at_end=False)
            raised_cosine_fade(x, min(int(0.25 * RATE), len(x) // 3), at_end=True)
            x *= 0.89 / float(np.max(np.abs(x)))
            rms = float(np.sqrt(np.mean(x[:int(0.1 * RATE)] ** 2)))
            layer = 'soft' if velocity < 0.6 else 'hard'
            file = f'drums/{piece}-{layer}-{rr}.m4a'
            encode(x, OUT / file, 112)
            frame, level = mark(x)
            shift, _ = verify(OUT / file, frame, level, None, False)
            if abs(shift) > 4:
                sys.exit(f'{file}: encoded attack moved {shift} frames')
            originals = [V.format(mic=mic, group=group, name=f) for mic in mics]
            out.append(dict(file=file, piece=piece, layer=layer, velocity=velocity, rr=rr, frames=len(x), mark=frame,
                            markLevel=round(level, 6), gain=round(targets[piece] * velocity / max(1e-6, rms), 5),
                            source=spec['source'], original=' + '.join(originals),
                            sha256=' + '.join(sha256(repo / o) for o in originals)))
            report.append(f'  {file}: {len(x) / RATE:.2f} s')
    return dict(id='drums', title=spec['title'], voices=[], kind='drums', release=0.05, steady=False,
                coverage=[0, 0], zones=out)


def write_doc(manifest: dict, sizes: dict):
    total = sum(sizes.values())
    lines = [
        '# Audio sources',
        '',
        'Every sound Timbre plays from a recording, where it came from and under which licence. Generated by',
        '`tools/build-ios-samples.py` together with `ios/Timbre/Resources/Samples/manifest.json`; do not edit the tables',
        'by hand: change the script and run it again.',
        '',
        '## Policy',
        '',
        '- Only libraries whose licence allows redistribution inside a commercial app: **CC0** (preferred) or **CC-BY**',
        '  (then credited in Settings > Acknowledgements and here). Everything shipped today is CC0.',
        '- Each source is pinned to a commit; the build refuses to run unless that commit\'s licence file is CC0.',
        '- Anything with unclear provenance, share-alike, non-commercial or GPL terms is rejected (list below).',
        '- `tools/verify-ios-resources.py` checks the manifest on every CI run: files present, licences allowed,',
        '  sources listed, the total size within budget.',
        '',
        '## How the app uses them',
        '',
        '- Lazily: nothing is decoded at launch. A zone is decoded (AAC to 16-bit PCM in memory) the first time a note',
        '  needs it, and the decoded zones live in a size-capped cache that is emptied on a memory warning.',
        '- Sparse zones are pitch-shifted to the exact frequency asked for (playback ratio = target / the zone\'s',
        '  measured fundamental), so reference tones stay exact; a unit test renders A4 and measures 440 Hz with the',
        '  tuner\'s own detector.',
        '- Instruments without a sample set (ukulele, mandolin, sung voice), notes outside a set\'s range and any',
        '  failure to read a file fall back to the synthesized voices (`ToneSynth`), and the band to `BandSynth`.',
        '',
        f'Total shipped: **{total / 1e6:.1f} MB** in {sum(len(i["zones"]) for i in manifest["instruments"])} files '
        f'(budget {BUDGET_BYTES / 1e6:.0f} MB).',
        '',
        '## Libraries',
        '',
        '| Key | Library | Author | Licence | Source (pinned commit) | Notes |',
        '| --- | --- | --- | --- | --- | --- |',
    ]
    for key, s in manifest['sources'].items():
        lines.append(f"| `{key}` | {s['title']} | {s['author']} | [{s['licence']}]({s['licenceURL']}) | "
                     f"[{s['repo'].split('github.com/')[1]}]({s['repo']}/tree/{s['commit']}) `{s['commit'][:10]}` | "
                     f"{s.get('note', '')} |")
    lines += ['', '## Instruments', '', '| Set | Plays for | Source | Files | Size |', '| --- | --- | --- | --- | --- |']
    for inst in manifest['instruments']:
        srcs = sorted({z['source'] for z in inst['zones']})
        size = sum(sizes[z['file']] for z in inst['zones'])
        voices = ', '.join(inst['voices']) or 'backing band'
        lines.append(f"| {inst['title']} (`{inst['id']}`) | {voices} | {', '.join(srcs)} | {len(inst['zones'])} | "
                     f"{size / 1e6:.2f} MB |")
    lines += ['', '## Rejected', '', '| Library | Why |', '| --- | --- |']
    for name, why in REJECTED:
        lines.append(f'| {name} | {why} |')
    lines += ['', '## Every shipped file', '',
              '| File | Source | Original recording | SHA-256 of the original | Licence |', '| --- | --- | --- | --- | --- |']
    for inst in manifest['instruments']:
        for z in inst['zones']:
            s = manifest['sources'][z['source']]
            lines.append(f"| `Samples/{z['file']}` | `{z['source']}` | `{z['original']}` | "
                         f"`{z['sha256'][:16]}…` | {s['licence']} |")
    DOC.parent.mkdir(parents=True, exist_ok=True)
    DOC.write_text('\n'.join(lines) + '\n', encoding='utf-8')


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--cache', type=Path, default=Path.home() / '.cache/timbre-samples')
    parser.add_argument('--only', default='')
    parser.add_argument('--doc-only', action='store_true')
    args = parser.parse_args()
    args.cache.mkdir(parents=True, exist_ok=True)
    manifest_path = OUT / 'manifest.json'
    if args.doc_only:
        manifest = json.loads(manifest_path.read_text())
    else:
        only = {s for s in args.only.split(',') if s}
        previous = json.loads(manifest_path.read_text()) if manifest_path.exists() and only else None
        instruments = []
        for spec in INSTRUMENTS + [DRUMS]:
            if only and spec['id'] not in only:
                kept = next((i for i in (previous or {}).get('instruments', []) if i['id'] == spec['id']), None)
                if kept:
                    instruments.append(kept)
                continue
            report: list[str] = []
            print(f"{spec['id']}:", flush=True)
            for old in (OUT / spec['id']).glob('*.m4a'):
                old.unlink()
            inst = build_drums(args.cache, report) if spec is DRUMS else build_instrument(args.cache, spec, report)
            print('\n'.join(report), flush=True)
            instruments.append(inst)
        used = sorted({z['source'] for i in instruments for z in i['zones']})
        sources = {}
        for key in used:
            s = SOURCES[key]
            sources[key] = dict(title=s['title'], author=s['author'], licence=s['licence'], licenceURL=CC0_URL,
                                repo=s['repo'], commit=s['commit'], note=s['note'])
        manifest = dict(version=MANIFEST_VERSION, sampleRate=RATE, format='aac-m4a-mono', sources=sources,
                        instruments=instruments)
        manifest_path.parent.mkdir(parents=True, exist_ok=True)
        manifest_path.write_text(json.dumps(manifest, indent=1, ensure_ascii=False) + '\n', encoding='utf-8')
    sizes = {z['file']: (OUT / z['file']).stat().st_size for i in manifest['instruments'] for z in i['zones']}
    total = sum(sizes.values())
    write_doc(manifest, sizes)
    print(f'{len(sizes)} files, {total / 1e6:.2f} MB (budget {BUDGET_BYTES / 1e6:.0f} MB)')
    if total > BUDGET_BYTES:
        sys.exit('over budget')


if __name__ == '__main__':
    main()

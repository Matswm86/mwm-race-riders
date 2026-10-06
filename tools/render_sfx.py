"""Render the MWM Race Riders sound effects to assets/sfx/*.ogg.

Same method as Neon Bricks (tools/render_sfx.py there): own synthesis (FM and
modal bells, filtered noise, convolution reverb) layered with a few Kenney CC0
samples (see CREDITS.md). Modern, soft and round: no chiptune, no square
waves. Output: 44.1 kHz mono Ogg Vorbis, peaks about -10 to -4 dBFS.
Deterministic: every random layer has a fixed seed.

Usage:
    python3 tools/render_sfx.py --kenney <dir holding kenney_impact-sounds> [--out assets/sfx]
    python3 tools/render_sfx.py --only-synth      (just the wind loops, no samples needed)
"""

from __future__ import annotations

import argparse
import subprocess
import tempfile
from pathlib import Path

import numpy as np
import soundfile as sf
from scipy import signal

SR = 44100


# ------------------------------------------------------------------ helpers


def tt(dur: float) -> np.ndarray:
    return np.arange(int(dur * SR)) / SR


def env(dur: float, attack: float, tau: float) -> np.ndarray:
    t = tt(dur)
    a = np.clip(t / max(attack, 1e-4), 0.0, 1.0)
    a = 0.5 - 0.5 * np.cos(np.pi * a)
    # Taper the last 25% to zero so a cut segment never clicks.
    tail = np.clip((dur - t) / (0.25 * dur), 0.0, 1.0)
    return a * np.exp(-np.maximum(t - attack, 0.0) / tau) * (0.5 - 0.5 * np.cos(np.pi * tail))


def fit(x: np.ndarray, n: int) -> np.ndarray:
    if len(x) >= n:
        return x[:n]
    return np.pad(x, (0, n - len(x)))


def mix(*parts: tuple[np.ndarray, float]) -> np.ndarray:
    n = max(len(p) for p, _ in parts)
    out = np.zeros(n)
    for p, g in parts:
        out[: len(p)] += p * g
    return out


def at(x: np.ndarray, start: float, total: float) -> np.ndarray:
    out = np.zeros(int(total * SR))
    i = int(start * SR)
    seg = x[: max(0, len(out) - i)]
    out[i : i + len(seg)] += seg
    return out


def bp(x: np.ndarray, lo: float, hi: float, order: int = 2) -> np.ndarray:
    sos = signal.butter(order, [lo, hi], btype="bandpass", fs=SR, output="sos")
    return signal.sosfilt(sos, x)


def lp(x: np.ndarray, f: float, order: int = 2) -> np.ndarray:
    return signal.sosfilt(signal.butter(order, f, btype="lowpass", fs=SR, output="sos"), x)


def hp(x: np.ndarray, f: float, order: int = 2) -> np.ndarray:
    return signal.sosfilt(signal.butter(order, f, btype="highpass", fs=SR, output="sos"), x)


def noise(dur: float, seed: int) -> np.ndarray:
    return np.random.default_rng(seed).uniform(-1.0, 1.0, int(dur * SR))


def swept_bp(x: np.ndarray, f0: float, f1: float, q: float = 2.0) -> np.ndarray:
    """State-variable band-pass whose centre glides from f0 to f1 (exponential)."""
    n = len(x)
    fc = f0 * (f1 / f0) ** (np.arange(n) / max(n - 1, 1))
    out = np.zeros(n)
    low = band = 0.0
    damp = 1.0 / q
    for i in range(n):
        f = 2.0 * np.sin(np.pi * fc[i] / SR)
        high = x[i] - low - damp * band
        band += f * high
        low += f * band
        out[i] = band
    return out


def sine_glide(dur: float, f0: float, f1: float, glide: float) -> np.ndarray:
    t = tt(dur)
    f = f1 + (f0 - f1) * np.exp(-t / max(glide, 1e-4))
    return np.sin(2.0 * np.pi * np.cumsum(f) / SR)


def modal(f: float, dur: float, ratios, amps, taus, attack: float = 0.001) -> np.ndarray:
    t = tt(dur)
    out = np.zeros(len(t))
    for r, a, tau in zip(ratios, amps, taus, strict=True):
        if f * r < SR * 0.45:
            out += a * np.sin(2.0 * np.pi * f * r * t) * env(dur, attack, tau)
    return out


def fm_bell(
    f: float, dur: float, ratio: float, index: float, idx_tau: float, tau: float
) -> np.ndarray:
    t = tt(dur)
    mod = index * np.exp(-t / idx_tau) * np.sin(2.0 * np.pi * f * ratio * t)
    return np.sin(2.0 * np.pi * f * t + mod) * env(dur, 0.002, tau)


def soft_saw(f: float, dur: float, harmonics: int = 18) -> np.ndarray:
    """Band-limited saw (additive), so no aliasing and no 8-bit edge."""
    t = tt(dur)
    out = np.zeros(len(t))
    for k in range(1, harmonics + 1):
        if f * k > 9000.0:
            break
        out += np.sin(2.0 * np.pi * f * k * t) / k
    return out


def reverb(x: np.ndarray, rt: float, wet: float, damp: float = 6000.0, seed: int = 7) -> np.ndarray:
    """Convolution with a synthetic room: dense decaying noise, darker over time."""
    n = int(rt * SR)
    t = np.arange(n) / SR
    rng = np.random.default_rng(seed)
    bright = rng.uniform(-1, 1, n)
    dark = lp(rng.uniform(-1, 1, n), damp * 0.35)
    mixw = np.exp(-t / (rt * 0.25))
    ir = (bright * mixw + dark * 2.0 * (1.0 - mixw)) * np.exp(-6.9 * t / rt)
    ir = lp(ir, damp)
    pre = int(0.012 * SR)
    ir = np.concatenate([np.zeros(pre), ir])
    ir /= np.sqrt(np.sum(ir**2)) + 1e-9
    w = signal.fftconvolve(x, ir)[: len(x) + len(ir)]
    dry = np.pad(x, (0, len(w) - len(x)))
    return dry * (1.0 - wet * 0.5) + w * wet


def finish(
    x: np.ndarray, peak_db: float, fade_ms: float = 30.0, floor_db: float = -60.0
) -> np.ndarray:
    x = hp(x, 35.0)
    # Trim the silent tail, then fade.
    a = np.abs(x)
    thr = np.max(a) * 10 ** (floor_db / 20.0)
    idx = np.nonzero(a > thr)[0]
    if len(idx):
        x = x[: idx[-1] + 1]
    nf = min(len(x), int(fade_ms / 1000.0 * SR))
    if nf > 0:
        x[-nf:] *= np.linspace(1.0, 0.0, nf) ** 2
    x = x / (np.max(np.abs(x)) + 1e-9) * 10 ** (peak_db / 20.0)
    return x


def load_kenney(root: Path, name: str) -> np.ndarray:
    hits = list(root.rglob(name))
    if not hits:
        raise FileNotFoundError(f"Kenney sample not found: {name}")
    data, sr = sf.read(str(hits[0]), always_2d=True)
    mono = data.mean(axis=1)
    if sr != SR:
        mono = signal.resample_poly(mono, SR, sr)
    return mono / (np.max(np.abs(mono)) + 1e-9)


# ------------------------------------------------------------------ sounds


def loop_crossfade(x: np.ndarray, fade: float = 0.25) -> np.ndarray:
    """Make x loop seamlessly: fade its tail into its head."""
    n = int(fade * SR)
    head = x[:n].copy()
    body = x[n:].copy()
    ramp = np.linspace(0.0, 1.0, n)
    body[-n:] = body[-n:] * (1.0 - ramp) + head * ramp
    return body


def tick(variant: int, kenney: Path) -> np.ndarray:
    """Touch-down on the bike: soft knobby-tyre tick on dirt."""
    d = 0.22
    grit = bp(noise(d, 11 + variant), 900.0, 4200.0) * env(d, 0.001, 0.02)
    thump = sine_glide(d, 180.0, 120.0, 0.02) * env(d, 0.002, 0.03)
    step = lp(load_kenney(kenney, f"footstep_grass_00{variant}.ogg"), 5000.0)
    x = mix((grit, 0.5), (thump, 0.5), (step, 0.45))
    return finish(reverb(x, 0.25, 0.08, 5000.0, seed=15 + variant), -10.0)


def board_whoosh() -> np.ndarray:
    """Touch-down on the hoverboard: short airy swish with a soft hum."""
    d = 0.3
    air = swept_bp(noise(d, 21), 900.0, 2600.0, 2.5) * np.sin(np.pi * np.clip(tt(d) / d, 0, 1)) ** 2
    hum = np.sin(2 * np.pi * 220.0 * tt(d)) * env(d, 0.03, 0.08)
    x = mix((air, 1.0), (hum, 0.12))
    return finish(reverb(x, 0.3, 0.1, 6000.0, seed=23), -11.0)


def pad() -> np.ndarray:
    """Speed pad: rising whoosh-zap (pitched up a step per chain level in game)."""
    d = 0.6
    air = (
        swept_bp(noise(0.45, 31), 600.0, 6000.0, 2.6)
        * np.sin(np.pi * np.clip(tt(0.45) / 0.45, 0, 1)) ** 1.5
    )
    t = tt(d)
    f = 440.0 * 2 ** (np.clip(t / 0.25, 0, 1) * 1.0)
    zap = np.sin(2 * np.pi * np.cumsum(f) / SR + 1.2 * np.sin(2 * np.pi * f * 2.0 * t)) * env(
        d, 0.01, 0.12
    )
    sparkle = at(fm_bell(1760.0, 0.4, 2.0, 0.8, 0.03, 0.1), 0.2, d)
    x = mix((at(air, 0.0, d), 0.8), (zap, 0.32), (sparkle, 0.25))
    x = lp(x, 9000.0)
    return finish(reverb(x, 0.5, 0.18, 7000.0, seed=33), -7.0)


def boost() -> np.ndarray:
    """Boost: turbo swell into a sustained airy roar, 2.5 s, soft tail."""
    d = 2.7
    t = tt(d)
    swell = swept_bp(noise(d, 41), 300.0, 2400.0, 1.4)
    shape = np.clip(t / 0.35, 0, 1) ** 1.5 * np.clip((d - t) / 0.6, 0, 1)
    roar = lp(noise(d, 43), 700.0) * shape
    f = 110.0 * (1.0 + 0.5 * np.clip(t / 0.4, 0, 1))
    body = (
        np.sin(2 * np.pi * np.cumsum(f) / SR) + 0.3 * np.sin(4 * np.pi * np.cumsum(f) / SR)
    ) * shape
    x = mix((swell * shape, 0.7), (roar, 0.9), (body, 0.18))
    x = lp(x, 6000.0)
    return finish(reverb(x, 0.6, 0.15, 5000.0, seed=45), -8.0, fade_ms=300.0)


def ready() -> np.ndarray:
    """Boost meter full: soft two-note chime."""
    d = 1.0
    a = fm_bell(1046.5, d, 2.0, 0.7, 0.04, 0.3)
    b = at(fm_bell(1568.0, d, 2.0, 0.7, 0.04, 0.35), 0.09, d)
    x = mix((a, 0.6), (b, 0.6))
    return finish(reverb(x, 0.9, 0.25, 7000.0, seed=51), -10.0)


def takeoff() -> np.ndarray:
    """Take-off: whoosh as the wind drops away."""
    d = 0.6
    air = (
        swept_bp(noise(d, 61), 2400.0, 500.0, 2.0) * np.sin(np.pi * np.clip(tt(d) / d, 0, 1)) ** 1.2
    )
    return finish(reverb(lp(air, 6000.0), 0.4, 0.12, 5000.0, seed=63), -9.0)


def trick() -> np.ndarray:
    """Automatic trick: short bright swish."""
    d = 0.35
    air = (
        swept_bp(noise(d, 71), 1500.0, 5500.0, 3.0) * np.sin(np.pi * np.clip(tt(d) / d, 0, 1)) ** 2
    )
    return finish(reverb(air, 0.3, 0.1, 7000.0, seed=73), -10.0)


def land_bike(kenney: Path) -> np.ndarray:
    """Bike landing: soft thump plus a little suspension creak."""
    d = 0.5
    thump = sine_glide(d, 120.0, 55.0, 0.04) * env(d, 0.002, 0.08)
    soft = lp(load_kenney(kenney, "impactSoft_heavy_001.ogg"), 3000.0)
    t = tt(0.18)
    creak = np.sin(2 * np.pi * (520.0 + 120.0 * np.sin(2 * np.pi * 9.0 * t)) * t) * env(
        0.18, 0.01, 0.05
    )
    x = mix((thump, 0.9), (soft, 0.6), (at(bp(creak, 300.0, 2000.0), 0.06, d), 0.12))
    return finish(reverb(x, 0.35, 0.1, 4000.0, seed=81), -7.0)


def land_board() -> np.ndarray:
    """Hoverboard landing: soft 'fwump' of air."""
    d = 0.5
    fw = lp(noise(0.25, 91), 500.0) * env(0.25, 0.005, 0.06)
    tone = sine_glide(d, 160.0, 90.0, 0.06) * env(d, 0.004, 0.1)
    x = mix((at(fw, 0.0, d), 1.0), (tone, 0.5))
    return finish(reverb(x, 0.4, 0.12, 3500.0, seed=93), -8.0)


def big_land() -> np.ndarray:
    """Big landing star: bright rising bell pair with sparkle."""
    d = 1.2
    x = np.zeros(int(d * SR))
    for k, f in enumerate([1318.5, 1760.0, 2637.0]):
        x = x + at(fm_bell(f, 0.9, 3.5, 0.9, 0.04, 0.3), 0.05 * k, d) * (0.5 - 0.1 * k)
    return finish(reverb(x, 1.0, 0.3, 8000.0, seed=101), -8.0)


def bonk() -> np.ndarray:
    """Bump: soft rubbery 'bonk' (never harsh)."""
    d = 0.45
    t = tt(d)
    f = 300.0 * (1.0 + 0.4 * np.exp(-t / 0.03)) * (1.0 - 0.25 * np.clip(t / 0.2, 0, 1))
    ph = 2 * np.pi * np.cumsum(f) / SR
    body = (np.sin(ph) + 0.2 * np.sin(2 * ph)) * env(d, 0.003, 0.07)
    x = lp(body, 2500.0)
    return finish(reverb(x, 0.35, 0.1, 3500.0, seed=111), -9.0)


def scrape() -> np.ndarray:
    """Rail scrape: grainy filtered noise, 0.45 s."""
    d = 0.45
    grain = bp(noise(d, 121), 700.0, 3200.0)
    am = 0.6 + 0.4 * np.sin(2 * np.pi * 23.0 * tt(d)) * np.sin(2 * np.pi * 7.0 * tt(d))
    x = grain * am * np.sin(np.pi * np.clip(tt(d) / d, 0, 1))
    return finish(reverb(x, 0.3, 0.1, 5000.0, seed=123), -13.0)


def hay(kenney: Path) -> np.ndarray:
    """Hay bale: soft 'pff' plus straw rustle."""
    d = 0.6
    pff = lp(noise(0.3, 131), 1400.0) * env(0.3, 0.004, 0.08)
    rustle = hp(load_kenney(kenney, "footstep_grass_003.ogg"), 1200.0)
    rustle2 = at(hp(load_kenney(kenney, "footstep_grass_004.ogg"), 1500.0), 0.07, d)
    x = mix((at(pff, 0.0, d), 0.9), (rustle, 0.6), (rustle2, 0.4))
    return finish(reverb(x, 0.4, 0.12, 5000.0, seed=133), -9.0)


def tick_up() -> np.ndarray:
    """Overtake: light rising two-note marimba blip."""
    d = 0.5
    a = modal(784.0, d, [1.0, 3.93, 9.2], [1.0, 0.25, 0.06], [0.12, 0.04, 0.01], 0.002)
    b = at(
        modal(1175.0, d, [1.0, 3.93, 9.2], [1.0, 0.25, 0.06], [0.14, 0.04, 0.01], 0.002), 0.07, d
    )
    x = mix((a, 0.6), (b, 0.7))
    return finish(reverb(x, 0.4, 0.15, 7000.0, seed=141), -11.0)


def swap(kenney: Path) -> np.ndarray:
    """Swap gate: glassy shimmer plus a small mechanical click-clack."""
    d = 1.0
    rng = np.random.default_rng(151)
    sh = np.zeros(int(d * SR))
    for k in range(10):
        f = 1046.5 * 2 ** (rng.integers(0, 12) / 6.0)
        sh += at(fm_bell(f, 0.6, 2.0, 0.6, 0.03, 0.18), 0.03 * k, d) * 0.25
    c1 = hp(load_kenney(kenney, "impactPlank_medium_000.ogg"), 600.0)
    c2 = at(hp(load_kenney(kenney, "impactMetal_light_002.ogg"), 900.0), 0.12, d)
    x = mix((sh, 1.0), (c1, 0.35), (c2, 0.25))
    return finish(reverb(x, 0.8, 0.25, 8000.0, seed=153), -8.0)


def blip() -> np.ndarray:
    """Start lamp: soft marimba note (pitched up per lamp in game)."""
    d = 0.6
    x = modal(523.25, d, [1.0, 3.93, 9.2], [1.0, 0.3, 0.06], [0.22, 0.06, 0.015], 0.002)
    mallet = bp(noise(0.01, 161), 1500.0, 5000.0) * env(0.01, 0.0005, 0.002)
    x = mix((x, 1.0), (mallet, 0.2))
    return finish(reverb(x, 0.6, 0.18, 6000.0, seed=163), -9.0)


def go() -> np.ndarray:
    """GO: bright marimba chord into a forward whoosh."""
    d = 1.0
    x = np.zeros(int(d * SR))
    for f in [523.25, 659.25, 783.99, 1046.5]:
        x = x + modal(f, d, [1.0, 3.93], [1.0, 0.25], [0.3, 0.06], 0.002) * 0.3
    air = (
        swept_bp(noise(0.7, 171), 600.0, 4000.0, 2.0)
        * np.sin(np.pi * np.clip(tt(0.7) / 0.7, 0, 1)) ** 1.5
    )
    x = mix((x, 1.0), (at(air, 0.05, d), 0.6))
    return finish(reverb(x, 0.8, 0.22, 7000.0, seed=173), -7.0)


def cheer() -> np.ndarray:
    """Finish: friendly applause (many soft claps) under a rising bell fanfare."""
    d = 3.0
    rng = np.random.default_rng(181)
    claps = np.zeros(int(d * SR))
    for _ in range(260):
        s0 = rng.uniform(0.0, 2.3) ** 1.15
        c = bp(
            noise(0.03, int(rng.integers(0, 1_000_000))),
            rng.uniform(800.0, 1400.0),
            rng.uniform(2500.0, 4500.0),
        )
        c *= env(0.03, 0.001, rng.uniform(0.004, 0.008))
        claps += at(c, s0, d) * rng.uniform(0.3, 1.0)
    claps *= np.clip((d - tt(d)) / 1.2, 0, 1)
    x = claps * 0.5
    for k, f in enumerate([783.99, 987.77, 1174.66, 1567.98]):
        b = fm_bell(f, 1.8, 3.5, 0.8, 0.05, 0.5) * 0.5 + modal(
            f, 1.8, [1.0, 2.0], [0.6, 0.2], [0.7, 0.3]
        )
        x = x + at(b, 0.1 * k, d) * 0.3
    x = lp(x, 10000.0)
    return finish(reverb(x, 1.4, 0.3, 7000.0, seed=183), -6.0, fade_ms=250.0)


def clink(kenney: Path) -> np.ndarray:
    """Card: trophy clink."""
    d = 1.0
    bell = modal(1568.0, d, [1.0, 2.76, 5.4], [1.0, 0.45, 0.2], [0.45, 0.2, 0.08])
    hit = hp(load_kenney(kenney, "impactMetal_light_000.ogg"), 1200.0)
    x = mix((bell, 0.8), (hit, 0.35))
    return finish(reverb(x, 0.9, 0.25, 8000.0, seed=191), -9.0)


def not_yet() -> np.ndarray:
    """Boost not charged: soft low 'thup'."""
    d = 0.25
    x = sine_glide(d, 200.0, 140.0, 0.02) * env(d, 0.003, 0.04)
    return finish(reverb(lp(x, 1500.0), 0.2, 0.08, 3000.0, seed=201), -12.0)


def click() -> np.ndarray:
    """Button release: small soft click."""
    d = 0.12
    x = sine_glide(d, 900.0, 600.0, 0.01) * env(d, 0.001, 0.015)
    x = mix((x, 1.0), (bp(noise(0.008, 211), 2000.0, 6000.0) * env(0.008, 0.0005, 0.0015), 0.2))
    return finish(x, -12.0)


def roll_loop() -> np.ndarray:
    """Cruise: wind plus tyre roll, seamless 2 s loop (pitch follows speed)."""
    d = 2.25
    wind = swept_bp(noise(d, 221), 500.0, 500.0, 0.8)
    wind *= 0.75 + 0.25 * np.sin(2 * np.pi * 0.9 * tt(d))
    roll = lp(noise(d, 223), 260.0) * (0.8 + 0.2 * np.sin(2 * np.pi * 11.0 * tt(d)))
    grit = bp(noise(d, 225), 1500.0, 4000.0) * 0.15
    x = loop_crossfade(mix((wind, 0.6), (roll, 1.0), (grit, 1.0)))
    x = x / (np.max(np.abs(x)) + 1e-9) * 10 ** (-14.0 / 20.0)
    return x


def wind_loop() -> np.ndarray:
    """Speed wind (GDD 11.1): broadband rush with slow gusts, seamless 3 s loop.
    The game raises its level from -30 dB to -12 dB and its pitch 0.8 -> 1.3 with speed."""
    d = 3.25
    rush = swept_bp(noise(d, 331), 380.0, 380.0, 0.6)
    air = bp(noise(d, 333), 900.0, 2600.0) * 0.45
    gust = (
        0.7
        + 0.2 * np.sin(2 * np.pi * (1.0 / 3.25) * tt(d))
        + 0.1 * np.sin(2 * np.pi * (3.0 / 3.25) * tt(d))
    )
    low = lp(noise(d, 335), 140.0) * 0.8
    x = loop_crossfade(mix((rush * gust, 0.9), (air * gust, 1.0), (low, 1.0)))
    return x / (np.max(np.abs(x)) + 1e-9) * 10 ** (-12.0 / 20.0)


def wind_whistle() -> np.ndarray:
    """High wind layer above 35 m/s and on boost: narrow airy whistle, seamless 3 s loop."""
    d = 3.25
    n = noise(d, 337)
    a = swept_bp(n, 2300.0, 2300.0, 9.0)
    b = swept_bp(noise(d, 339), 3400.0, 3400.0, 12.0) * 0.5
    wob = 0.75 + 0.25 * np.sin(2 * np.pi * (2.0 / 3.25) * tt(d))
    hiss = hp(noise(d, 341), 5000.0) * 0.12
    x = loop_crossfade(mix((a * wob, 1.0), (b, 1.0), (hiss, 1.0)))
    return x / (np.max(np.abs(x)) + 1e-9) * 10 ** (-16.0 / 20.0)


def hum_loop() -> np.ndarray:
    """Hoverboard: low smooth hum with a soft airy layer, seamless loop."""
    d = 2.25
    t = tt(d)
    f = 98.0
    hum = (
        np.sin(2 * np.pi * f * t)
        + 0.35 * np.sin(2 * np.pi * f * 2 * t)
        + 0.12 * np.sin(2 * np.pi * f * 3.01 * t)
    )
    hum *= 0.85 + 0.15 * np.sin(2 * np.pi * (4.0 / d) * t)
    air = lp(noise(d, 231), 1800.0) * 0.25
    x = loop_crossfade(mix((hum, 0.7), (air, 1.0)))
    x = x / (np.max(np.abs(x)) + 1e-9) * 10 ** (-15.0 / 20.0)
    return x


def build(kenney: Path) -> dict[str, np.ndarray]:
    out: dict[str, np.ndarray] = {}
    for v in range(3):
        out[f"tick_{v + 1}"] = tick(v, kenney)
    out["board_whoosh"] = board_whoosh()
    out["pad"] = pad()
    out["boost"] = boost()
    out["ready"] = ready()
    out["takeoff"] = takeoff()
    out["trick"] = trick()
    out["land_bike"] = land_bike(kenney)
    out["land_board"] = land_board()
    out["big_land"] = big_land()
    out["bonk"] = bonk()
    out["scrape"] = scrape()
    out["hay"] = hay(kenney)
    out["tick_up"] = tick_up()
    out["swap"] = swap(kenney)
    out["blip"] = blip()
    out["go"] = go()
    out["cheer"] = cheer()
    out["clink"] = clink(kenney)
    out["not_yet"] = not_yet()
    out["click"] = click()
    out["roll_loop"] = roll_loop()
    out["hum_loop"] = hum_loop()
    out.update(build_synth_only())
    return out


def build_synth_only() -> dict[str, np.ndarray]:
    """Sounds that need no samples (render them alone with --only-synth)."""
    return {"wind_loop": wind_loop(), "wind_whistle": wind_whistle()}


def write_ogg(x: np.ndarray, path: Path, quality: str = "4") -> None:
    with tempfile.TemporaryDirectory() as td:
        wav = Path(td) / "x.wav"
        sf.write(str(wav), x.astype(np.float32), SR, subtype="PCM_16")
        subprocess.run(
            ["ffmpeg", "-v", "error", "-y", "-i", str(wav), "-ac", "1", "-ar", str(SR)]
            + ["-c:a", "libvorbis", "-q:a", quality, str(path)],
            check=True,
        )


def main() -> None:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--kenney", type=Path, help="folder holding kenney_impact-sounds")
    ap.add_argument("--only-synth", action="store_true", help="render only the sample-free loops")
    ap.add_argument(
        "--out", type=Path, default=Path(__file__).resolve().parent.parent / "assets" / "sfx"
    )
    args = ap.parse_args()
    args.out.mkdir(parents=True, exist_ok=True)
    if not args.only_synth and args.kenney is None:
        ap.error("--kenney is required unless --only-synth")
    sounds = build_synth_only() if args.only_synth else build(args.kenney)
    for name, x in sounds.items():
        write_ogg(x, args.out / f"rr_{name}.ogg")
        print(
            f"rr_{name}.ogg  {len(x) / SR:.2f} s  peak {20 * np.log10(np.max(np.abs(x)) + 1e-9):.1f} dBFS"
        )


if __name__ == "__main__":
    main()

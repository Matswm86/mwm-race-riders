#!/usr/bin/env python3
"""MWM Race Riders track kit and layout tool (GDD 17.1). Offline only: the game never generates
tracks; it loads the JSON this tool writes into tracks/.

Each world has a kit of 15 pieces (the GDD 17.1 table has 14 rows; Gate-in and Gate-out share a
row). A piece has fixed content at local metres from its start (pads, kickers, hindrances, its
kid-line segment, bends, narrow spots, set pieces) and a length range: the content sits near the
start, the rest is plain trail, so the tool can stretch pieces until a track is exactly
WORLD_LENGTH + 25 m x (k - 1) long. Every joint is kid line x 0, so pieces join in any order.

Recipe (GDD 17.1): Start, 3-4 pieces, Gate-in, 2-3 smooth pieces, Gate-out, 2-3 pieces,
Signature, 0-1 piece, Finish. A layout must pass: 10 pads incl. 2 chains, 4 kickers incl. the
signature lip at 75-85% of the length, G1 at 28-35%, G2 at 60-66%, the spacing rules of GDD 6.0
and 6.3 at 30 m/s (hindrances >= 45 m apart, >= 90 m in the same lane, none inside a landing
slope or the 30 m after it, none inside a tunnel or right behind its mouth, each one visible
from >= 60 m), kid-line ramps of at most 3 m per 30 m that clear every block and patch, no
piece twice in a row and at most twice per track, each use mirrored or not, and a centre line
that never comes back near itself.

Seeds are fixed: seed = crc32("rr_w{w}_t{k}") (a stable stand-in for the GDD's hash()), so the
same 20 candidates come out on every machine.

Usage:
  python3 tools/track_gen.py --list 1 3     # the 20 valid layouts for world 1 track 3
  python3 tools/track_gen.py --write        # write tracks/w{1,2}_t{2..8}.json + all Pro variants
Picks and hand tuning live in tools/track_picks.json ({"w1_t3": {"pick": 4, "bend_scale": 1.1,
"flavor_seed": 9}}); a track without an entry gets the candidate most different from the
tracks already picked in its world. Pro variants (GDD 17.1): the base track mirrored (x -> -x,
kid line and bends too), evening light, +2 hindrances where the rules allow; track 1's Pro
variant mirrors tracks/w{w}_t1.json, which tests/export_t1.gd writes from RrWorlds.gd.
After writing: run tests/par_times.gd (par times) and tests/bake_world.gd (baked worlds).
"""

from __future__ import annotations

import argparse
import json
import math
import random
import sys
import zlib
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "tracks"
PICKS = Path(__file__).resolve().parent / "track_picks.json"

WORLD_LENGTH = {1: 1425.0, 2: 1470.0}
LENGTH_STEP = 25.0
TRACKS = 8
CANDIDATES = 20
S_TAIL = 155.0  # s_max = length + 155 (run-out 90 m plus margin)

# GDD 6.0 / 6.3 / 13 rules
HIND_GAP = 45.0
HIND_LANE_GAP = 90.0
LAND_CLEAR_AFTER = 30.0
VISIBLE_M = 60.0
PAD_REACH = 3.0 * 0.5 + 0.5
HAY_REACH = 0.8 + 0.5
KID_SLOPE_MAX = 0.1  # 3 m per 30 m
GATE_CLEAR = 12.0
SELF_GAP_M = 120.0
MIN_HINDRANCES = 4
PRO_KID_CLEAR = 1.5
TREE_WALL = 3.6


def landing(lip: float, air: float) -> tuple[float, float]:
    return lip + 18.0 * air - 3.0, lip + 48.0 * air + 5.0


def piece(name: str, length: tuple[float, float], **kw) -> dict:
    d = {
        "name": name,
        "len": length,
        "pads": [],
        "kick": [],
        "blocks": [],
        "patches": [],
        "rollers": [],
        "kid": [],
        "bends": [],
        "narrow": [],
        "gate": None,
        "tunnel": None,
        "fence": None,
        "slot": None,
        "gap": None,
        "drop": None,
        "no_lane": False,
    }
    d.update(kw)
    return d


# ---------------------------------------------------------------- kits

KITS: dict[int, dict[str, dict]] = {
    1: {
        "start": piece("start", (90, 90)),
        "gate_in": piece("gate_in", (60, 60), gate=(30.0, 1)),
        "gate_out": piece("gate_out", (60, 60), gate=(30.0, 0)),
        "pad_a": piece("pad_a", (90, 150), pads=[(45, 0.0)], bends=[(15, 95, 1 / 300)]),
        "pad_b": piece(
            "pad_b",
            (100, 170),
            pads=[(40, -3.0)],
            blocks=[(95, 2.5)],
            bends=[(10, 120, -1 / 260)],
        ),
        "chain": piece(
            "chain",
            (125, 180),
            pads=[(45, 2.5), (63, 2.5), (81, 2.5)],
            kid=[(0, 0.0), (30, 2.5), (90, 2.5), (120, 0.0)],
            bends=[(95, 175, -1 / 300)],
        ),
        "bend_s": piece(
            "bend_s",
            (155, 210),
            bends=[(10, 75, -1 / 90), (85, 150, 1 / 90)],
            pads=[(45, 0.0)],
            patches=[(115, 130, 2.0, 4.5, "mud")],
        ),
        "sweeper": piece(
            "sweeper",
            (130, 200),
            bends=[(10, 135, 1 / 225)],
            blocks=[(60, -2.0)],
            pads=[(115, 3.0)],
        ),
        "kick_s": piece("kick_s", (120, 165), kick=[(25, 1.0, "ramp")]),
        "kick_m": piece("kick_m", (130, 175), kick=[(25, 1.2, "ramp")], pads=[(105, -3.0)]),
        "hay_lane": piece(
            "hay_lane",
            (130, 180),
            blocks=[(35, 2.5), (95, -2.5)],
            bends=[(20, 120, -1 / 400)],
        ),
        "mud_lane": piece(
            "mud_lane",
            (140, 190),
            patches=[(25, 40, -4.0, -1.5, "mud")],
            kid=[(0, 0.0), (5, 0.0), (35, 3.0), (65, 3.0), (95, 0.0)],
            pads=[(50, 3.0)],
            blocks=[(130, 2.0)],
        ),
        # Landmark: the rock tunnel (W1 set piece), a bale 20 m before its mouth.
        "landmark": piece(
            "landmark",
            (145, 190),
            blocks=[(40, -1.0)],
            kid=[(0, 0.0), (5, 0.0), (30, 1.8), (48, 1.8), (70, 0.0)],
            tunnel=(60, 120),
            narrow=[(66, 114, 8.0)],
        ),
        # Signature: the gully plank jump between fences (K3, 1.6 s).
        "signature": piece(
            "signature",
            (210, 240),
            narrow=[(3, 72, 7.0)],
            fence=(-3, 78),
            kick=[(60, 1.6, "ramp")],
            pads=[(150, -3.0), (168, -3.0), (186, -3.0)],
            blocks=[(200, 1.5)],
        ),
        "finish": piece("finish", (105, 105), kick=[(30, 1.0, "ramp")]),
    },
    2: {
        "start": piece("start", (90, 90)),
        "gate_in": piece("gate_in", (60, 60), gate=(30.0, 1)),
        "gate_out": piece("gate_out", (60, 60), gate=(30.0, 0)),
        "pad_a": piece("pad_a", (90, 150), pads=[(45, 0.0)], bends=[(15, 100, 1 / 135)]),
        "pad_b": piece(
            "pad_b",
            (100, 170),
            pads=[(40, 3.0)],
            rollers=[(95, -1.0)],
            bends=[(10, 120, -1 / 180)],
        ),
        "chain": piece(
            "chain",
            (125, 180),
            pads=[(45, -2.5), (63, -2.5), (81, -2.5)],
            kid=[(0, 0.0), (30, -2.5), (90, -2.5), (120, 0.0)],
            bends=[(95, 170, 1 / 315)],
        ),
        "bend_s": piece(
            "bend_s",
            (155, 210),
            bends=[(10, 85, 1 / 112), (95, 170, -1 / 150)],
            pads=[(45, 0.0)],
            patches=[(115, 138, 2.0, 4.5, "sand")],
        ),
        "sweeper": piece(
            "sweeper",
            (130, 200),
            bends=[(10, 140, -1 / 240)],
            rollers=[(70, 1.0)],
            pads=[(115, -3.0)],
        ),
        "kick_s": piece("kick_s", (120, 165), kick=[(25, 1.0, "ramp_rock")]),
        "kick_m": piece("kick_m", (130, 175), kick=[(25, 1.2, "ramp_rock")], pads=[(105, 3.0)]),
        "drift_lane": piece(
            "drift_lane",
            (130, 180),
            patches=[(45, 68, -3.0, 0.5, "sand")],
            kid=[(0, 0.0), (5, 0.0), (32, 2.5), (78, 2.5), (105, 0.0)],
        ),
        "weed_pair": piece(
            "weed_pair",
            (140, 190),
            rollers=[(35, 1.0), (95, -1.0)],
            pads=[(135, 0.0)],
        ),
        # Landmark: the slot canyon (narrow, high walls), only on dirt.
        "landmark": piece(
            "landmark",
            (145, 190),
            narrow=[(12, 120, 8.0)],
            slot=(0, 132),
            rollers=[(60, 1.0)],
            pads=[(98, 2.0)],
            no_lane=True,
        ),
        # Signature: the mesa gap (K3, 1.8 s) over a dry gorge, landing 9 m lower.
        "signature": piece(
            "signature",
            (205, 235),
            narrow=[(30, 114, 8.0)],
            kick=[(60, 1.8, "ramp_rock")],
            gap=(64, 89),
            drop=(63, 111, 9.0),
            pads=[(160, 3.0), (178, 3.0), (196, 3.0)],
        ),
        "finish": piece("finish", (120, 120), kick=[(45, 0.8, "ramp")]),
    },
}
FIXED = ("start", "gate_in", "gate_out", "signature", "finish")

# Per world: section widths, grades, start drop (GDD 6.1 / 6.2 numbers).
WORLD = {
    1: {
        "start_w": [(-60.0, 12.0), (0.0, 12.0), (60.0, 10.0)],
        "w_pre": 10.0,
        "w_lane": 10.0,
        "w_post": 9.0,
        "g_start": (60.0, 0.15),
        "g_pre": 0.08,
        "g_lane": 0.06,
        "g_post": 0.20,
        "g_after_sig": 0.20,
        "g_finish": 0.04,
        "finish_at": 105.0,
    },
    2: {
        "start_w": [(-60.0, 12.0), (0.0, 12.0), (90.0, 10.0)],
        "w_pre": 10.0,
        "w_lane": 11.0,
        "w_post": 9.0,
        "g_start": (90.0, 0.22),
        "g_pre": 0.09,
        "g_lane": 0.06,
        "g_post": 0.18,
        "g_after_sig": 0.12,
        "g_finish": 0.06,
        "finish_at": 120.0,
    },
}


def track_seed(w: int, k: int) -> int:
    return zlib.crc32(f"rr_w{w}_t{k}".encode())


# ---------------------------------------------------------------- assembly


def mirror_piece(p: dict) -> dict:
    q = dict(p)
    q["pads"] = [(s, -x) for s, x in p["pads"]]
    q["blocks"] = [(s, -x) for s, x in p["blocks"]]
    q["patches"] = [(a, b, -x1, -x0, kd) for a, b, x0, x1, kd in p["patches"]]
    q["rollers"] = [(s, -d) for s, d in p["rollers"]]
    q["kid"] = [(s, -x) for s, x in p["kid"]]
    q["bends"] = [(a, b, -c) for a, b, c in p["bends"]]
    return q


def assemble(w: int, k: int, seq: list[tuple[str, bool, float]], bend_scale: float) -> dict:
    """seq = [(piece name, mirrored, length)] incl. the fixed pieces. Returns a track dict
    in the RrWorlds format (s in metres from the start line, x + = right)."""
    kit = KITS[w]
    wd = WORLD[w]
    s0 = 0.0
    t: dict = {
        "pads": [],
        "kickers": [],
        "kicker_air": [],
        "kicker_models": [],
        "blocks": [],
        "patches": [],
        "rollers": [],
        "gates": [],
        "bends": [],
        "kid_pts": [(-60.0, 0.0)],
        "narrow": [],
        "tunnel": [],
        "fence": [],
        "slot": [],
        "gap": [],
        "drops": [],
        "spans": [],
    }
    for name, mir, ln in seq:
        p = kit[name]
        if mir:
            p = mirror_piece(p)
        t["spans"].append((name, s0, s0 + ln, mir))
        for s, x in p["pads"]:
            t["pads"].append([s0 + s, x])
        for s, air, model in p["kick"]:
            t["kickers"].append(s0 + s)
            t["kicker_air"].append(air)
            t["kicker_models"].append(model)
        for s, x in p["blocks"]:
            t["blocks"].append([s0 + s, x])
        for a, b, x0, x1, kd in p["patches"]:
            t["patches"].append([s0 + a, s0 + b, x0, x1, kd])
        for s, d in p["rollers"]:
            t["rollers"].append([s0 + s, d])
        for a, b, c in p["bends"]:
            t["bends"].append([s0 + a, s0 + b, c / bend_scale])
        t["kid_pts"].append((s0, 0.0))
        for s, x in p["kid"]:
            t["kid_pts"].append((s0 + s, x))
        t["kid_pts"].append((s0 + ln, 0.0))
        for a, b, wn in p["narrow"]:
            t["narrow"].append((s0 + a, s0 + b, wn))
        if p["gate"] is not None:
            t["gates"].append([s0 + p["gate"][0], p["gate"][1]])
        for key in ("tunnel", "fence", "slot", "gap"):
            if p[key] is not None:
                t[key] = [s0 + p[key][0], s0 + p[key][1]]
        if p["drop"] is not None:
            a, b, m = p["drop"]
            t["drops"].append([s0 + a, s0 + b, m])
        s0 += ln
    length = s0
    t["length"] = length
    g1 = t["gates"][0][0]
    g2 = t["gates"][1][0]
    finish_start = t["spans"][-1][1]
    sig_lip = t["kickers"][-2]
    t["g1"], t["g2"], t["finish_start"], t["sig_lip"] = g1, g2, finish_start, sig_lip
    s_max = length + S_TAIL
    t["sections"] = [
        [-60.0, g1, "dirt", 1.0],
        [g1, g2, "lane", 1.0],
        [g2, finish_start, "dirt", 1.05],
        [finish_start, length, "dirt", 1.0],
        [length, s_max, "dirt", 0.5],
    ]
    t["grades"] = [
        [-60.0, 0.05],
        [0.0, wd["g_start"][1]],
        [wd["g_start"][0], wd["g_pre"]],
        [g1, wd["g_lane"]],
        [g2, wd["g_post"]],
        [sig_lip + 15.0, wd["g_after_sig"]],
        [finish_start, wd["g_finish"]],
        [length, 0.02],
    ]
    t["widths"] = width_table(w, t, s_max)
    t["kid_line"] = compress_kid(t["kid_pts"], s_max)
    return t


def base_width(w: int, t: dict, s: float) -> float:
    wd = WORLD[w]
    if s < wd["start_w"][2][0]:
        (a, wa), (b, wb) = wd["start_w"][1], wd["start_w"][2]
        return wa if s <= a else wa + (wb - wa) * (s - a) / (b - a)

    def blend(s: float, at: float, w0: float, w1: float) -> float:
        if s < at:
            return w0
        if s >= at + 12.0:
            return w1
        return w0 + (w1 - w0) * (s - at) / 12.0

    v = wd["w_pre"]
    v = blend(s, t["g1"], v, wd["w_lane"])
    if s >= t["g2"]:
        v = blend(s, t["g2"], wd["w_lane"], wd["w_post"])
    if s >= t["finish_start"] - 9.0:
        v = blend(s, t["finish_start"] - 9.0, wd["w_post"], 12.0)
    return v


def width_at(w: int, t: dict, s: float) -> float:
    """Track width at s: from the stored table for a loaded JSON, else from the kit."""
    if "_widths" in t:
        return keyed(t["_widths"], s)
    v = base_width(w, t, s)
    for a, b, wn in t["narrow"]:
        if a - 12.0 <= s <= b + 12.0:
            k = 1.0
            if s < a:
                k = (s - (a - 12.0)) / 12.0
            elif s > b:
                k = ((b + 12.0) - s) / 12.0
            v = min(v, v + (wn - v) * k)
    return v


def width_table(w: int, t: dict, s_max: float) -> list[list[float]]:
    rows: list[list[float]] = []
    s = -60.0
    while s <= s_max + 0.01:
        rows.append([round(s, 1), round(width_at(w, t, s), 2)])
        s += 3.0
    # Drop rows that lie on the line between their neighbours.
    out = [rows[0]]
    for i in range(1, len(rows) - 1):
        a, b, c = out[-1], rows[i], rows[i + 1]
        lerp = a[1] + (c[1] - a[1]) * (b[0] - a[0]) / (c[0] - a[0])
        if abs(lerp - b[1]) > 0.01:
            out.append(b)
    out.append(rows[-1])
    return out


def compress_kid(pts: list[tuple[float, float]], s_max: float) -> list[list[float]]:
    pts = sorted(pts)
    out: list[list[float]] = []
    for s, x in pts:
        if out and abs(out[-1][0] - s) < 0.01:
            out[-1][1] = x
            continue
        out.append([round(s, 1), round(x, 2)])
    out.append([round(s_max, 1), 0.0])
    keep = [out[0]]
    for i in range(1, len(out) - 1):
        a, b, c = keep[-1], out[i], out[i + 1]
        if a[1] == b[1] == c[1]:
            continue
        keep.append(b)
    keep.append(out[-1])
    return keep


def keyed(table: list[list[float]], s: float) -> float:
    if s <= table[0][0]:
        return table[0][1]
    for i in range(1, len(table)):
        a, b = table[i - 1], table[i]
        if s <= b[0]:
            k = (s - a[0]) / max(0.001, b[0] - a[0])
            return a[1] + (b[1] - a[1]) * k
    return table[-1][1]


def curv_at(bends: list, s: float) -> float:
    for a, b, c in bends:
        if a <= s < b:
            k = min(1.0, (s - a) / 10.0, (b - s) / 10.0)
            return c * max(0.0, min(1.0, k))
    return 0.0


# ---------------------------------------------------------------- validation


def hindrances(t: dict) -> list[dict]:
    """Every hindrance as {s0, s1, x0, x1, kind}; rollers span the width (no lane)."""
    out = []
    for s, x in t["blocks"]:
        out.append({"s0": s - 0.6, "s1": s + 0.6, "x0": x - 0.8, "x1": x + 0.8, "kind": "block"})
    for a, b, x0, x1, kd in t["patches"]:
        out.append({"s0": a, "s1": b, "x0": x0, "x1": x1, "kind": kd})
    for s, _d in t["rollers"]:
        out.append({"s0": s, "s1": s, "x0": -99.0, "x1": 99.0, "kind": "roller"})
    out.sort(key=lambda h: h["s0"])
    return out


def chains(pads: list) -> int:
    ss = sorted(p[0] for p in pads)
    n = 0
    i = 0
    while i < len(ss):
        j = i
        while j + 1 < len(ss) and ss[j + 1] - ss[j] <= 20.0:
            j += 1
        if j - i + 1 >= 3:
            n += 1
        i = j + 1
    return n


def kid_hits(t: dict) -> int:
    return sum(1 for s, x in t["pads"] if abs(keyed(t["kid_line"], s) - x) < PAD_REACH)


def validate(w: int, t: dict, base_rules: bool = True) -> list[str]:
    errs: list[str] = []
    length = t["length"]
    if base_rules:
        if len(t["pads"]) != 10:
            errs.append(f"pads {len(t['pads'])} != 10")
        if chains(t["pads"]) != 2:
            errs.append(f"chains {chains(t['pads'])} != 2")
        if len(t["kickers"]) != 4:
            errs.append(f"kickers {len(t['kickers'])} != 4")
        if not 0.75 * length <= t["sig_lip"] <= 0.85 * length:
            errs.append(f"signature at {t['sig_lip'] / length:.2f}")
        if not 0.28 * length <= t["g1"] <= 0.35 * length:
            errs.append(f"G1 at {t['g1'] / length:.2f}")
        if not 0.60 * length <= t["g2"] <= 0.66 * length:
            errs.append(f"G2 at {t['g2'] / length:.2f}")
    zones = [(landing(lip, air), lip) for lip, air in zip(t["kickers"], t["kicker_air"])]
    hs = hindrances(t)
    for h in hs:
        for (a, b), lip in zones:
            if h["s1"] > lip and h["s0"] < b + LAND_CLEAR_AFTER:
                errs.append(f"{h['kind']} s {h['s0']:.0f} after lip {lip:.0f} (landing+30)")
        if t["tunnel"]:
            ta, tb = t["tunnel"]
            if h["s1"] > ta and h["s0"] < tb + VISIBLE_M:
                errs.append(f"{h['kind']} s {h['s0']:.0f} in/behind the tunnel")
        for g, _v in t["gates"]:
            if h["s1"] > g - GATE_CLEAR and h["s0"] < g + GATE_CLEAR:
                errs.append(f"{h['kind']} s {h['s0']:.0f} at a gate")
        if h["s0"] < 60.0 or h["s1"] > length - 10.0:
            errs.append(f"{h['kind']} s {h['s0']:.0f} too close to start or finish")
        # Visible from >= 60 m: a bend may not hide it behind the tree wall.
        sag = 0.0
        s = h["s0"] - VISIBLE_M
        yaw0 = 0.0
        pts = []
        x = z = 0.0
        while s <= h["s0"]:
            yaw0 -= curv_at(t["bends"], s) * 1.0
            x += -math.sin(yaw0)
            z += -math.cos(yaw0)
            pts.append((x, z))
            s += 1.0
        if len(pts) > 2:
            (ax, az), (bx, bz) = pts[0], pts[-1]
            ln = math.hypot(bx - ax, bz - az) or 1.0
            for px, pz in pts:
                sag = max(sag, abs((bx - ax) * (az - pz) - (ax - px) * (bz - az)) / ln)
        hw = width_at(w, t, h["s0"]) * 0.5
        if sag > hw + TREE_WALL:
            errs.append(f"{h['kind']} s {h['s0']:.0f} hidden by a bend (sag {sag:.1f} m)")
    for i in range(len(hs)):
        for j in range(i + 1, len(hs)):
            a, b = hs[i], hs[j]
            gap = b["s0"] - a["s1"]
            if gap < HIND_GAP:
                errs.append(f"{a['kind']} {a['s0']:.0f} and {b['kind']} {b['s0']:.0f} {gap:.0f} m")
            lanes = a["kind"] != "roller" and b["kind"] != "roller"
            if lanes and gap < HIND_LANE_GAP and a["x1"] > b["x0"] and b["x1"] > a["x0"]:
                errs.append(f"same lane {a['s0']:.0f} / {b['s0']:.0f} only {gap:.0f} m")
    for s, _x in t["pads"]:
        for (a, b), lip in zones:
            if a < s < b:
                errs.append(f"pad s {s:.0f} in landing slope of lip {lip:.0f}")
        for g, _v in t["gates"]:
            if abs(s - g) < GATE_CLEAR:
                errs.append(f"pad s {s:.0f} at a gate")
    for g, _v in t["gates"]:
        for (a, b), lip in zones:
            if lip - 5.0 < g < b:
                errs.append(f"gate s {g:.0f} over the jump at {lip:.0f}")
    # Kid line: ramps of at most 3 m per 30 m, clear of every block and patch.
    kl = t["kid_line"]
    for i in range(1, len(kl)):
        ds = kl[i][0] - kl[i - 1][0]
        if ds > 0 and abs(kl[i][1] - kl[i - 1][1]) / ds > KID_SLOPE_MAX + 1e-6:
            errs.append(f"kid ramp too steep at s {kl[i][0]:.0f}")
    for s, x in t["blocks"]:
        for ds in (-6.0, -3.0, 0.0):
            kx = keyed(kl, s + ds)
            if abs(kx - x) < HAY_REACH + 0.15:
                errs.append(f"kid line hits the block at s {s:.0f}")
                break
    for a, b, x0, x1, _kd in t["patches"]:
        ss = a - 8.0
        while ss <= b:
            kx = keyed(kl, ss)
            if x0 - 0.3 <= kx <= x1 + 0.3:
                errs.append(f"kid line rides into the patch at s {a:.0f}")
                break
            ss += 1.0
    # Centre line never comes back near itself (terrain strips would overlap).
    pos = []
    x = z = yaw = 0.0
    s = 0.0
    while s <= length + 90.0:
        yaw -= curv_at(t["bends"], s) * 2.0
        x += -math.sin(yaw) * 2.0
        z += -math.cos(yaw) * 2.0
        pos.append((s, x, z))
        s += 2.0
    for i in range(0, len(pos), 5):
        for j in range(i + 150, len(pos), 5):
            if math.hypot(pos[i][1] - pos[j][1], pos[i][2] - pos[j][2]) < SELF_GAP_M:
                errs.append(f"centre line comes back near itself at s {pos[j][0]:.0f}")
                break
        if errs and errs[-1].startswith("centre"):
            break
    return errs


# ---------------------------------------------------------------- search


def solve_lengths(w: int, groups: dict, target: float, rng: random.Random) -> list | None:
    """groups: pre, smooth, post, tail lists of piece names. Returns [(name, len)] in track
    order with the gate and signature percentages inside their windows, or None."""
    kit = KITS[w]
    fin = kit["finish"]["len"][0]
    sig_lo, sig_hi = kit["signature"]["len"]

    def rng_sum(names: list[str]) -> tuple[float, float]:
        return sum(kit[n]["len"][0] for n in names), sum(kit[n]["len"][1] for n in names)

    def split(names: list[str], total: float) -> list[float] | None:
        lo = [kit[n]["len"][0] for n in names]
        hi = [kit[n]["len"][1] for n in names]
        if not sum(lo) - 0.01 <= total <= sum(hi) + 0.01:
            return None
        out = lo[:]
        rest = total - sum(lo)
        for _ in range(40):
            if rest <= 0.01:
                break
            room = [h - o for h, o in zip(hi, out)]
            wts = [r * rng.uniform(0.5, 1.5) for r in room]
            tw = sum(wts)
            if tw <= 0:
                break
            for i in range(len(out)):
                add = min(room[i], rest * wts[i] / tw)
                out[i] += add
            rest = total - sum(out)
        if abs(sum(out) - total) > 0.5:
            return None
        return [round(v) for v in out]

    for _ in range(60):
        pre_lo, pre_hi = rng_sum(groups["pre"])
        lo = max(pre_lo, 0.28 * target - 120.0)
        hi = min(pre_hi, 0.35 * target - 120.0)
        if lo > hi:
            return None
        pre = rng.uniform(lo, hi)
        g1 = 90.0 + pre + 30.0
        sm_lo, sm_hi = rng_sum(groups["smooth"])
        lo = max(sm_lo, 0.60 * target - g1 - 60.0)
        hi = min(sm_hi, 0.66 * target - g1 - 60.0)
        if lo > hi:
            continue
        smooth = rng.uniform(lo, hi)
        g2 = g1 + 30.0 + smooth + 30.0
        po_lo, po_hi = rng_sum(groups["post"])
        lo = max(po_lo, 0.75 * target - g2 - 90.0)
        hi = min(po_hi, 0.85 * target - g2 - 90.0)
        if lo > hi:
            continue
        post = rng.uniform(lo, hi)
        sig_start = g2 + 30.0 + post
        rest = target - sig_start - fin
        ta_lo, ta_hi = rng_sum(groups["tail"])
        lo = max(sig_lo, rest - ta_hi)
        hi = min(sig_hi, rest - ta_lo)
        if lo > hi:
            continue
        sig = rng.uniform(lo, hi)
        tail = rest - sig
        parts = [
            split(groups["pre"], pre),
            split(groups["smooth"], smooth),
            split(groups["post"], post),
            split(groups["tail"], tail) if groups["tail"] else ([] if abs(tail) < 0.5 else None),
        ]
        if any(p is None for p in parts):
            continue
        seq = [("start", 90.0)]
        seq += list(zip(groups["pre"], parts[0]))
        seq.append(("gate_in", 60.0))
        seq += list(zip(groups["smooth"], parts[1]))
        seq.append(("gate_out", 60.0))
        seq += list(zip(groups["post"], parts[2]))
        seq.append(("signature", 0.0))
        seq += list(zip(groups["tail"], parts[3]))
        seq.append(("finish", fin))
        total_wo_sig = sum(v for n, v in seq if n != "signature")
        sig_len = round(target - total_wo_sig)
        if not sig_lo <= sig_len <= sig_hi:
            continue
        return [(n, sig_len if n == "signature" else float(v)) for n, v in seq]
    return None


def random_groups(w: int, rng: random.Random) -> dict | None:
    """A recipe from the required pieces (chain, landmark, two small kickers) plus random
    fillers, split into the pre / smooth / post / tail groups."""
    n_pre = rng.choice([3, 4])
    n_sm = rng.choice([2, 3])
    n_po = rng.choice([2, 3])
    n_ta = rng.choice([0, 0, 1])
    total = n_pre + n_sm + n_po + n_ta
    names = [
        "chain",
        "landmark",
        rng.choice(["kick_s", "kick_m"]),
        rng.choice(["kick_s", "kick_m"]),
    ]
    fill = [
        n for n in KITS[w] if n not in FIXED and n not in ("chain", "landmark", "kick_s", "kick_m")
    ]
    while len(names) < total:
        names.append(rng.choice(fill))
    rng.shuffle(names)
    groups = {
        "pre": names[:n_pre],
        "smooth": names[n_pre : n_pre + n_sm],
        "post": names[n_pre + n_sm : n_pre + n_sm + n_po],
        "tail": names[n_pre + n_sm + n_po :],
    }
    if any(names.count(n) > 2 for n in set(names)):
        return None
    seq = ["start"] + groups["pre"] + ["gate_in"] + groups["smooth"] + ["gate_out"]
    seq += groups["post"] + ["signature"] + groups["tail"] + ["finish"]
    if any(a == b for a, b in zip(seq, seq[1:])):
        return None
    if any(KITS[w][n]["no_lane"] for n in groups["smooth"]):
        return None
    singles = sum(len(KITS[w][n]["pads"]) for n in names if n != "chain")
    if singles != 4:
        return None
    return groups


def flavor(w: int, rng: random.Random) -> dict:
    if w == 1:
        return {
            "seed": rng.randrange(1, 10_000),
            "trees": round(rng.uniform(0.78, 1.0), 2),
            "reach": round(rng.uniform(34.0, 48.0), 1),
            "hills": round(rng.uniform(5.0, 12.0), 1),
            "meadow": round(rng.uniform(0.0, 0.35), 2),
        }
    return {
        "seed": rng.randrange(1, 10_000),
        "wall": round(rng.uniform(12.5, 19.0), 1),
        "bush": round(rng.uniform(0.75, 1.0), 2),
        "rocks": round(rng.uniform(0.8, 1.0), 2),
        "strata": round(rng.uniform(3.6, 5.6), 2),
        "dune": round(rng.uniform(0.7, 1.5), 2),
    }


def candidates(w: int, k: int, bend_scale: float | None = None) -> list[dict]:
    seed = track_seed(w, k)
    rng = random.Random(seed)
    target = WORLD_LENGTH[w] + LENGTH_STEP * (k - 1)
    out: list[dict] = []
    seen: set[str] = set()
    tries = 0
    while len(out) < CANDIDATES and tries < 600_000:
        tries += 1
        groups = random_groups(w, rng)
        if groups is None:
            continue
        lens = solve_lengths(w, groups, target, rng)
        if lens is None:
            continue
        mirrors = [rng.random() < 0.5 for _ in lens]
        bs = bend_scale if bend_scale is not None else round(rng.uniform(0.9, 1.25), 2)
        seq = [(n, (m and n not in ("start", "finish")), ln) for (n, ln), m in zip(lens, mirrors)]
        sig = "|".join(n + ("~" if m else "") for n, m, _ in seq)
        if sig in seen:
            continue
        t = assemble(w, k, seq, bs)
        errs = validate(w, t)
        if errs:
            continue
        if kid_hits(t) < 4 or len(hindrances(t)) < MIN_HINDRANCES:
            continue
        seen.add(sig)
        out.append({"seq": seq, "bend_scale": bs, "track": t, "hits": kid_hits(t)})
    return out


def describe(c: dict) -> str:
    t = c["track"]
    names = " ".join(n + ("~" if m else "") + f"({ln:.0f})" for n, m, ln in c["seq"])
    return (
        f"L {t['length']:.0f}  G1 {t['g1'] / t['length']:.2f}  G2 {t['g2'] / t['length']:.2f}  "
        f"sig {t['sig_lip'] / t['length']:.2f}  kid pads {c['hits']}/10  hind "
        f"{len(hindrances(t))}  bends x{c['bend_scale']}\n    {names}"
    )


def difference(a: dict, b: dict) -> float:
    sa = [n for n, _m, _l in a["seq"]]
    sb = [n for n, _m, _l in b["seq"]]
    diff = sum(1 for x, y in zip(sa, sb) if x != y) + abs(len(sa) - len(sb))
    la = next(s for n, s, e, m in a["track"]["spans"] if n == "landmark")
    lb = next(s for n, s, e, m in b["track"]["spans"] if n == "landmark")
    return diff + abs(la - lb) / 150.0


# ---------------------------------------------------------------- output


def to_json(w: int, k: int, t: dict, pro: bool, fl: dict, recipe: list, seed: int) -> dict:
    zones = {"lane": [t["g1"], t["g2"]], "mesa": t["g2"], "town": t["finish_start"]}
    if t["slot"]:
        zones["slot"] = t["slot"]
    river = [t["g1"] - 6.0, t["g2"] + 6.0] if w == 1 else []
    d = {
        "id": w,
        "track": k,
        "key": f"w{w}_t{k}{'p' if pro else ''}",
        "pro": pro,
        "seed": seed,
        "length": t["length"],
        "s_max": t["length"] + S_TAIL,
        "look": "evening" if pro else "day",
        "mirrored": pro,
        "sections": t["sections"],
        "widths": t["widths"],
        "kid_line": t["kid_line"],
        "pads": sorted(t["pads"]),
        "kickers": t["kickers"],
        "kicker_air": t["kicker_air"],
        "kicker_models": t["kicker_models"],
        "blocks": sorted(t["blocks"]),
        "patches": sorted(t["patches"]),
        "rollers": sorted(t["rollers"]),
        "gates": t["gates"],
        "bends": [[round(a, 1), round(b, 1), round(c, 6)] for a, b, c in t["bends"]],
        "grades": t["grades"],
        "drops": t["drops"],
        "gap": t["gap"],
        "tunnel": t["tunnel"],
        "fence": t["fence"],
        "river": river,
        "zones": zones,
        "flavor": fl,
        "recipe": recipe,
    }
    return d


def write(path: Path, d: dict) -> None:
    # One key per line keeps diffs readable and the file small.
    lines = ["{"]
    keys = list(d.keys())
    for i, k in enumerate(keys):
        sep = "," if i < len(keys) - 1 else ""
        lines.append(f"  {json.dumps(k)}: {json.dumps(d[k], ensure_ascii=False)}{sep}")
    lines.append("}")
    path.write_text("\n".join(lines) + "\n", encoding="utf-8")


def mirror_track(t: dict) -> dict:
    m = json.loads(json.dumps(t))
    m["pads"] = sorted([[s, -x] for s, x in t["pads"]])
    m["blocks"] = sorted([[s, -x] for s, x in t["blocks"]])
    m["patches"] = sorted([[a, b, -x1, -x0, kd] for a, b, x0, x1, kd in t["patches"]])
    m["rollers"] = sorted([[s, -d] for s, d in t["rollers"]])
    m["kid_line"] = [[s, -x if x else 0.0] for s, x in t["kid_line"]]
    m["bends"] = [[a, b, -c] for a, b, c in t["bends"]]
    return m


def add_pro_hindrances(w: int, t: dict, rng: random.Random, n: int = 2) -> list:
    """GDD 17.1: +2 hindrances where the spacing rules allow (the world's own types), clear
    of the kid line. Returns the added rows."""
    added = []
    for _ in range(n):
        options = []
        s = 70.0
        while s < t["length"] - 40.0:
            if w == 1:
                for x in (-3.0, 3.0):
                    options.append(("block", [s, x]))
                for x0, x1 in ((-4.5, -2.2), (2.2, 4.5)):
                    options.append(("patch", [s, s + 15.0, x0, x1, "mud"]))
            else:
                options.append(("roller", [s, 1.0 if rng.random() < 0.5 else -1.0]))
                for x0, x1 in ((-4.5, -1.8), (1.8, 4.5)):
                    options.append(("patch", [s, s + 22.0, x0, x1, "sand"]))
            s += 5.0
        rng.shuffle(options)
        for kind, row in options:
            if not _clear_of_kid(t, kind, row):
                continue
            trial = json.loads(json.dumps(t))
            trial["narrow"] = t.get("narrow", [])
            if kind == "block":
                trial["blocks"] = sorted(trial["blocks"] + [row])
            elif kind == "patch":
                trial["patches"] = sorted(trial["patches"] + [row])
            else:
                trial["rollers"] = sorted(trial["rollers"] + [row])
            if not validate(w, trial, base_rules=False):
                t.update(
                    {k: trial[k] for k in ("blocks", "patches", "rollers")},
                )
                added.append([kind, row])
                break
    return added


def _clear_of_kid(t: dict, kind: str, row: list) -> bool:
    """Pro additions sit PRO_KID_CLEAR m clear of the kid line, so a nudge or a
    roller never pushes an idle Lett rider into them."""
    if kind == "roller":
        return True
    if kind == "block":
        s0, s1, x0, x1 = row[0] - 20.0, row[0] + 1.0, row[1] - 0.8, row[1] + 0.8
    else:
        s0, s1, x0, x1 = row[0] - 20.0, row[1], row[2], row[3]
    s = s0
    while s <= s1:
        kx = keyed(t["kid_line"], s)
        if x0 - PRO_KID_CLEAR < kx < x1 + PRO_KID_CLEAR:
            return False
        s += 2.0
    return True


def internal(w: int, d: dict) -> dict:
    """A track JSON back into the validator's shape."""
    t = json.loads(json.dumps(d))
    t["g1"] = d["gates"][0][0]
    t["g2"] = d["gates"][1][0]
    t["sig_lip"] = d["kickers"][-2]
    t["finish_start"] = d.get("zones", {}).get("town", d["length"] - WORLD[w]["finish_at"])
    t["narrow"] = []
    # Width-only narrow spots are already in the width table; rebuild them from it so the
    # visibility check sees the same half widths.
    t["_widths"] = d["widths"]
    return t


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    ap.add_argument("--list", nargs=2, type=int, metavar=("WORLD", "TRACK"))
    ap.add_argument("--write", action="store_true")
    a = ap.parse_args()
    picks = json.loads(PICKS.read_text(encoding="utf-8")) if PICKS.exists() else {}
    if a.list:
        w, k = a.list
        cs = candidates(w, k, picks.get(f"w{w}_t{k}", {}).get("bend_scale"))
        print(f"world {w} track {k}: seed {track_seed(w, k)}, {len(cs)} valid layouts")
        for i, c in enumerate(cs):
            print(f"[{i:2d}] {describe(c)}")
        return 0
    if not a.write:
        ap.print_help()
        return 1
    OUT.mkdir(exist_ok=True)
    for w in (1, 2):
        chosen: list[dict] = []
        for k in range(2, TRACKS + 1):
            key = f"w{w}_t{k}"
            pk = picks.get(key, {})
            cs = candidates(w, k, pk.get("bend_scale"))
            if not cs:
                print(f"{key}: NO valid layout", file=sys.stderr)
                return 1
            if "pick" in pk:
                c = cs[int(pk["pick"])]
                why = f"pick {pk['pick']} (track_picks.json)"
            else:
                # Prefer layouts whose kid line hits 5+ pads (an idle Lett
                # child needs the speed), then the most different one.
                strong = [i for i in range(len(cs)) if cs[i]["hits"] >= 5]
                pool = strong or list(range(len(cs)))
                best = max(
                    pool,
                    key=lambda i: (
                        min((difference(cs[i], o) for o in chosen), default=0.0)
                        + 0.3 * cs[i]["hits"]
                        + 0.25 * len(hindrances(cs[i]["track"]))
                    ),
                )
                c = cs[best]
                why = f"candidate {best} (most different)"
            chosen.append(c)
            seed = track_seed(w, k)
            fl = flavor(w, random.Random(seed ^ 0x5EED))
            if "flavor_seed" in pk:
                fl["seed"] = int(pk["flavor_seed"])
            recipe = [[n, m, ln] for n, m, ln in c["seq"]]
            d = to_json(w, k, c["track"], False, fl, recipe, seed)
            write(OUT / f"{key}.json", d)
            print(f"{key}: {why}\n  {describe(c)}")
        # Pro variants of all 8 tracks (track 1 from the exported hand-made table).
        for k in range(1, TRACKS + 1):
            src = OUT / f"w{w}_t{k}.json"
            if not src.exists():
                print(f"{src.name} missing (run tests/export_t1.gd first)", file=sys.stderr)
                return 1
            base = json.loads(src.read_text(encoding="utf-8"))
            pro = mirror_track(base)
            pro["key"] = f"w{w}_t{k}p"
            pro["pro"] = True
            pro["mirrored"] = True
            pro["look"] = "evening"
            t = internal(w, pro)
            rng = random.Random(track_seed(w, k) ^ 0x9E0)
            added = add_pro_hindrances(w, t, rng)
            pro["blocks"], pro["patches"], pro["rollers"] = t["blocks"], t["patches"], t["rollers"]
            pro["pro_added"] = added
            errs = validate(w, t, base_rules=False)
            if errs or len(added) != 2:
                print(f"{pro['key']}: {len(added)} added, errors {errs}", file=sys.stderr)
                return 1
            write(OUT / f"{pro['key']}.json", pro)
            print(f"{pro['key']}: mirrored, evening, +{len(added)} {added}")
    return 0


if __name__ == "__main__":
    sys.exit(main())

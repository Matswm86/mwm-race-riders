"""MWM Race Riders pack sim (game-designer, 2026-10-06).

1D progress model of worlds 1 (Furuløypa) and 2 (Ørkenjuvet): the player (idle / average / skilled) vs 5 rival AI
with rubber-banding and player knock-offs (owner change 2026-10-06 12:42: the player can bump a
rival off its bike; rivals only nudge the player sideways, the player never falls or slows). Numbers mirror docs/GDD.md section 13 (RrBalance.gd). Results are design
estimates (my calc), not measurements. Run: python3 tools/pack_sim.py [runs] [world ...]
"""

import random
import statistics
import sys

DT = 1 / 60
ACC_UP, ACC_DOWN = 7.0, 12.0
V_CRUISE = 20.0
HOVER_MULT = 1.06
PAD_MULT = [1.25, 1.32, 1.40]
PAD_T = 1.2
CHAIN_WINDOW = 1.5
LAND_BONUS_MIN_AIR, LAND_MULT, LAND_T = 1.2, 1.10, 0.8
BOOST_FIRST, BOOST_REFILL, BOOST_T, BOOST_MULT = 10.0, 10.0, 2.5, 1.40

# Slow events: (s, mult, seconds, centre_hit, hover_immune). centre_hit = a straight idle Vanlig
# rider (x 0) rides into it. Lett idle never hits (kid line avoids all of them). Moving rollers
# (tumbleweeds) only nudge sideways and cost no speed, so they are not listed.
TRACKS = {
    1: dict(
        name="W1 Furuløypa",
        L=950.0,
        sections=[(0, 1.00), (300, 1.00), (600, 1.05), (880, 1.00)],
        smooth=(300, 600),
        pads=[120, 210, 340, 352, 364, 470, 700, 800, 812, 824],
        kid={120, 340, 352, 364, 700},
        centre={120},
        kickers=[(180, 1.0), (430, 1.2), (760, 1.6), (900, 1.0)],
        slows=[
            (150, 0.90, 0.5, False, False),  # M1 mud
            (260, 0.85, 0.5, False, False),  # H1 hay
            (520, 0.85, 0.5, True, False),  # H2 hay (centre on purpose)
            (650, 0.85, 0.5, False, False),  # H3 hay
            (690, 0.90, 0.5, False, False),  # M2 mud
            (840, 0.85, 0.5, False, False),
        ],
    ),  # H4 hay
    2: dict(
        name="W2 Ørkenjuvet",
        L=980.0,
        sections=[(0, 1.00), (300, 1.00), (620, 1.05), (900, 1.00)],
        smooth=(300, 620),
        pads=[110, 285, 350, 362, 374, 540, 670, 830, 842, 854],
        kid={110, 350, 362, 374, 670},
        centre={110},
        kickers=[(200, 1.0), (480, 1.2), (780, 1.8), (930, 0.8)],
        slows=[
            (150, 0.88, 0.75, True, False),  # D1 sand drift, 15 m
            (580, 0.88, 0.75, True, True),  # D2 sand drift on the rim road (board floats)
            (870, 0.88, 0.75, True, False),
        ],
    ),  # D3 sand drift, 15 m
}
SAND_MULT_L = 0.94  # Lett: drifts slow less (applied to mult < 0.89 entries)
START_GAP = 3.0
BUMP_RATE = 1 / 15
BUMP_T = 0.5
BUMP_MULT_AI = 0.90  # rival-rival wobble; player is never slowed
# Knock-offs: chance per pass that the player steers into the rival hard enough (side contact,
# lateral closing speed >= KNOCK_LAT_MIN). Lett idle = auto-steer drift into a rival.
KNOCK_P = {
    ("easy", "idle"): 0.10,
    ("normal", "idle"): 0.0,
    ("easy", "average"): 0.30,
    ("normal", "average"): 0.30,
    ("easy", "skilled"): 0.60,
    ("normal", "skilled"): 0.60,
}
FALL_DECEL = 40.0  # m/s^2 while sliding to a stop
FALL_DOWN_S = 1.2  # lying down, counted from the hit
GETUP_S = 0.5  # sits up and remounts, speed 0
REJOIN_ACCEL = 10.0  # m/s^2 back to its target speed
KNOCK_IMMUNE_S = 6.0  # after it is riding again, that rival cannot be knocked off
RB_OFF_UNTIL_FRAC = 0.9  # rubber band ignores a rejoining rival until v >= 0.9 x target

MODES = {
    "easy": dict(
        ai_skill=[0.93, 0.95, 0.97, 0.99, 1.01],
        ai_pad=[0.20, 0.25, 0.30, 0.35, 0.40],
        rb_ahead=0.08,
        rb_behind=0.04,
        rb_range=30.0,
        rb_fade_from=1.1,
        auto_boost=2.0,
    ),
    "normal": dict(
        ai_skill=[0.90, 0.92, 0.94, 0.96, 0.98],
        ai_pad=[0.30, 0.35, 0.40, 0.45, 0.50],
        rb_ahead=0.05,
        rb_behind=0.03,
        rb_range=30.0,
        rb_fade_from=0.40,
        auto_boost=None,
    ),
}


class Rider:
    def __init__(s, pos, is_player):
        s.s = pos
        s.v = 0.0
        s.p = is_player
        s.fx = []  # (mult, until)
        s.boost_ready_at = BOOST_FIRST
        s.boost_pending = None
        s.chain = 0
        s.last_pad = -9
        s.done = None
        s.air_until = -1
        s.next_pad = 0
        s.next_kick = 0
        s.next_hay = 0
        s.fall_at = -99.0
        s.ride_at = -99.0
        s.immune_until = -1.0
        s.rejoining = False
        s.was_ahead_of_player = True


def run(mode, strat, hover, rng, track=1):
    m = MODES[mode]
    T = TRACKS[track]
    L = T["L"]
    SECTIONS = T["sections"]
    SMOOTH = T["smooth"]
    PADS = T["pads"]
    KICKERS = T["kickers"]
    SLOWS = T["slows"]
    riders = [Rider(START_GAP * (i + 1), False) for i in range(5)] + [Rider(0.0, True)]
    player = riders[-1]
    t = 0.0
    knocks = 0
    kp = KNOCK_P[(mode, strat)]
    while t < 120 and any(r.done is None for r in riders):
        t += DT
        for i, r in enumerate(riders):
            if r.done is not None:
                continue
            # knock-off check: the player passes this rival (player.s crosses r.s)
            if not r.p and player.done is None:
                ahead = r.s > player.s
                if (
                    r.was_ahead_of_player
                    and not ahead
                    and t >= r.immune_until
                    and t >= r.ride_at
                    and rng.random() < kp
                ):
                    r.fall_at = t
                    r.ride_at = t + FALL_DOWN_S + GETUP_S
                    r.immune_until = r.ride_at + KNOCK_IMMUNE_S
                    r.rejoining = True
                    knocks += 1
                r.was_ahead_of_player = ahead
            if not r.p and t < r.ride_at:
                r.v = max(0.0, r.v - FALL_DECEL * DT)
                r.s += r.v * DT
                continue
            # pads
            while r.next_pad < len(PADS) and r.s >= PADS[r.next_pad]:
                pos = PADS[r.next_pad]
                r.next_pad += 1
                if r.p:
                    hit = {
                        "skilled": True,
                        "average": rng.random() < 0.5,
                        "idle": (pos in T["kid"]) if mode == "easy" else (pos in T["centre"]),
                    }[strat]
                else:
                    hit = rng.random() < m["ai_pad"][i]
                if hit:
                    r.chain = min(r.chain + 1, 3) if t - r.last_pad < CHAIN_WINDOW else 1
                    r.last_pad = t
                    r.fx.append((PAD_MULT[r.chain - 1], t + PAD_T))
            while r.next_kick < len(KICKERS) and r.s >= KICKERS[r.next_kick][0]:
                air = KICKERS[r.next_kick][1]
                r.next_kick += 1
                if air >= LAND_BONUS_MIN_AIR:
                    r.fx.append((LAND_MULT, t + air + LAND_T))
            while r.next_hay < len(SLOWS) and r.s >= SLOWS[r.next_hay][0]:
                _, smult, sdur, centre_hit, hover_immune = SLOWS[r.next_hay]
                r.next_hay += 1
                if hover and hover_immune:
                    continue
                if r.p:
                    p_hit = {
                        "skilled": 0.0,
                        "average": 0.4,
                        "idle": 0.0 if mode == "easy" else (1.0 if centre_hit else 0.0),
                    }[strat]
                else:
                    p_hit = 0.2
                if mode == "easy" and smult < 0.89:
                    smult = SAND_MULT_L
                if rng.random() < p_hit:
                    r.fx.append((smult, t + sdur))
            # bumps (only when another rider within 2 m)
            near = any(o is not r and o.done is None and abs(o.s - r.s) < 2.0 for o in riders)
            if near and rng.random() < BUMP_RATE * DT * 4:
                if not r.p:
                    r.fx.append((BUMP_MULT_AI, t + BUMP_T))  # player: sideways nudge only
            # boost
            if t >= r.boost_ready_at:
                if r.boost_pending is None:
                    if r.p:
                        d = {"skilled": 0.0, "average": rng.uniform(1, 4), "idle": None}[strat]
                        if strat == "idle" and m["auto_boost"] is not None:
                            d = m["auto_boost"]
                    else:
                        d = rng.uniform(0.5, 3.0)
                    r.boost_pending = None if d is None else t + d
                if r.boost_pending is not None and t >= r.boost_pending:
                    r.fx.append((BOOST_MULT, t + BOOST_T))
                    r.boost_ready_at = t + BOOST_T + BOOST_REFILL
                    r.boost_pending = None
            r.fx = [f for f in r.fx if f[1] > t]
            mult = 1.0
            for f in r.fx:
                mult *= f[0]
            sec = [mm for (st, mm) in SECTIONS if r.s >= st][-1]
            mult *= sec
            if hover and SMOOTH[0] <= r.s < SMOOTH[1]:
                mult *= HOVER_MULT
            if not r.p:
                mult *= m["ai_skill"][i]
                gap = r.s - player.s if player.done is None else 0.0
                k = min(1.0, abs(gap) / m["rb_range"])
                prog = player.s / L
                fade = (
                    1.0
                    if prog < m["rb_fade_from"]
                    else max(0.0, 1 - (prog - m["rb_fade_from"]) / 0.1)
                )
                if not r.rejoining:
                    if gap > 0:
                        mult *= 1 - m["rb_ahead"] * k * fade
                    else:
                        mult *= 1 + m["rb_behind"] * k * fade
            target = V_CRUISE * mult
            if r.rejoining and r.v >= RB_OFF_UNTIL_FRAC * target:
                r.rejoining = False
            a = (REJOIN_ACCEL if r.rejoining else ACC_UP) if target > r.v else -ACC_DOWN
            r.v = min(target, r.v + a * DT) if a > 0 else max(target, r.v + a * DT)
            r.s += r.v * DT
            if r.s >= L:
                r.done = t
    times = [r.done for r in riders]
    order = sorted(range(6), key=lambda j: times[j])
    place = order.index(5) + 1
    win = times[order[0]]
    second = times[order[1]]
    margin = (second - times[5]) if place == 1 else None
    return place, times[5], max(times) - min(times), margin, times[5] - win, knocks


def report(mode, strat, hover, n=400, track=1):
    rng = random.Random(42)
    res = [run(mode, strat, hover, rng, track) for _ in range(n)]
    places = [r[0] for r in res]
    pt = [r[1] for r in res]
    spread = [r[2] for r in res]
    margins = [r[3] for r in res if r[3] is not None]
    behind = [r[4] for r in res if r[0] != 1]
    dist = {p: places.count(p) * 100 // n for p in range(1, 7)}
    top3 = sum(1 for p in places if p <= 3) * 100 // n
    kn = statistics.mean(r[5] for r in res)
    print(
        f"W{track} {mode:6s} {strat:8s} hover={int(hover)} time {statistics.median(pt):5.1f}s  place med {statistics.median(places):.0f} "
        f"win% {dist[1]:3d} top3% {top3:3d} knocks {kn:.1f} dist {dist}  spread {statistics.median(spread):.1f}s  "
        f"win margin {statistics.median(margins) if margins else float('nan'):.2f}s  behind winner {statistics.median(behind) if behind else 0:.2f}s"
    )


if __name__ == "__main__":
    n = int(sys.argv[1]) if len(sys.argv) > 1 else 200
    tracks = [int(a) for a in sys.argv[2:]] or sorted(TRACKS)
    for track in tracks:
        for mode in ("easy", "normal"):
            for strat in ("idle", "average", "skilled"):
                for hover in (False, True):
                    report(mode, strat, hover, n, track)

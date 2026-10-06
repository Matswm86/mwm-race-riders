"""MWM Race Riders pack sim (game-designer, 2026-10-06).

1D progress model of track 1 (Furuløypa): the player (idle / average / skilled) vs 5 AI with
rubber-banding. Numbers mirror docs/GDD.md section 13 (RrBalance.gd). Results are design
estimates (my calc), not measurements. Run: python3 tools/pack_sim.py [runs]
"""
import random, statistics, sys

DT = 1/60
L = 950.0
V_CRUISE = 20.0
ACC_UP, ACC_DOWN = 7.0, 12.0
# section cruise multipliers (start m, mult)
SECTIONS = [(0, 1.00), (300, 1.00), (600, 1.05), (880, 1.00)]
SMOOTH = (300, 600)                       # hoverboard section
HOVER_MULT = 1.06
PADS = [(120, 'c'), (210, 'l'), (340, 'r'), (352, 'r'), (364, 'r'), (470, 'l'), (700, 'r'), (800, 'l'), (812, 'l'), (824, 'l')]
KID_LINE = {120, 340, 352, 364, 700}   # pads on the Lett auto-steer line
CENTRE = {120}                         # pads an idle Vanlig rider (straight line) hits
PAD_MULT = [1.25, 1.32, 1.40]; PAD_T = 1.2; CHAIN_WINDOW = 1.5
KICKERS = [(180, 1.0), (430, 1.2), (760, 1.6), (900, 1.0)]
LAND_BONUS_MIN_AIR, LAND_MULT, LAND_T = 1.2, 1.10, 0.8
BOOST_FIRST, BOOST_REFILL, BOOST_T, BOOST_MULT = 10.0, 10.0, 2.5, 1.40
HAY = [260, 520, 650, 840]; HAY_MULT, HAY_T = 0.85, 0.5
BUMP_RATE = 1/15; BUMP_T = 0.5; BUMP_MULT_PLAYER, BUMP_MULT_AI = 0.95, 0.90
START_GAP = 3.0

MODES = {
    'easy':   dict(ai_skill=[0.93, 0.95, 0.97, 0.99, 1.01], ai_pad=[0.20, 0.25, 0.30, 0.35, 0.40],
                   rb_ahead=0.08, rb_behind=0.04, rb_range=30.0, rb_fade_from=1.1, auto_boost=2.0),
    'normal': dict(ai_skill=[0.90, 0.92, 0.94, 0.96, 0.98], ai_pad=[0.30, 0.35, 0.40, 0.45, 0.50],
                   rb_ahead=0.05, rb_behind=0.03, rb_range=30.0, rb_fade_from=0.40, auto_boost=None),
}

class Rider:
    def __init__(s, pos, is_player):
        s.s = pos; s.v = 0.0; s.p = is_player; s.fx = []  # (mult, until)
        s.boost_ready_at = BOOST_FIRST; s.boost_pending = None
        s.chain = 0; s.last_pad = -9; s.done = None; s.air_until = -1
        s.next_pad = 0; s.next_kick = 0; s.next_hay = 0

def run(mode, strat, hover, rng):
    m = MODES[mode]
    riders = [Rider(START_GAP*(i+1), False) for i in range(5)] + [Rider(0.0, True)]
    player = riders[-1]
    t = 0.0
    while t < 120 and any(r.done is None for r in riders):
        t += DT
        for i, r in enumerate(riders):
            if r.done is not None: continue
            # pads
            while r.next_pad < len(PADS) and r.s >= PADS[r.next_pad][0]:
                pos, lane = PADS[r.next_pad]; r.next_pad += 1
                if r.p:
                    hit = {'skilled': True, 'average': rng.random() < 0.5,
                           'idle': (pos in KID_LINE) if mode == 'easy' else (pos in CENTRE)}[strat]
                else:
                    hit = rng.random() < m['ai_pad'][i]
                if hit:
                    r.chain = min(r.chain+1, 3) if t - r.last_pad < CHAIN_WINDOW else 1
                    r.last_pad = t; r.fx.append((PAD_MULT[r.chain-1], t+PAD_T))
            while r.next_kick < len(KICKERS) and r.s >= KICKERS[r.next_kick][0]:
                air = KICKERS[r.next_kick][1]; r.next_kick += 1
                if air >= LAND_BONUS_MIN_AIR: r.fx.append((LAND_MULT, t+air+LAND_T))
            while r.next_hay < len(HAY) and r.s >= HAY[r.next_hay]:
                r.next_hay += 1
                if r.p:
                    p_hit = {'skilled': 0.0, 'average': 0.4, 'idle': 0.0 if mode == 'easy' else 0.25}[strat]
                else:
                    p_hit = 0.2
                if rng.random() < p_hit: r.fx.append((HAY_MULT, t+HAY_T))
            # bumps (only when another rider within 2 m)
            near = any(o is not r and o.done is None and abs(o.s-r.s) < 2.0 for o in riders)
            if near and rng.random() < BUMP_RATE*DT*4:
                r.fx.append((BUMP_MULT_PLAYER if r.p else BUMP_MULT_AI, t+BUMP_T))
            # boost
            if t >= r.boost_ready_at:
                if r.boost_pending is None:
                    if r.p:
                        d = {'skilled': 0.0, 'average': rng.uniform(1, 4), 'idle': None}[strat]
                        if strat == 'idle' and m['auto_boost'] is not None: d = m['auto_boost']
                    else:
                        d = rng.uniform(0.5, 3.0)
                    r.boost_pending = None if d is None else t + d
                if r.boost_pending is not None and t >= r.boost_pending:
                    r.fx.append((BOOST_MULT, t+BOOST_T)); r.boost_ready_at = t + BOOST_T + BOOST_REFILL; r.boost_pending = None
            r.fx = [f for f in r.fx if f[1] > t]
            mult = 1.0
            for f in r.fx: mult *= f[0]
            sec = [mm for (st, mm) in SECTIONS if r.s >= st][-1]
            mult *= sec
            if hover and SMOOTH[0] <= r.s < SMOOTH[1]: mult *= HOVER_MULT
            if not r.p:
                mult *= m['ai_skill'][i]
                gap = r.s - player.s if player.done is None else 0.0
                k = min(1.0, abs(gap)/m['rb_range'])
                prog = player.s / L
                fade = 1.0 if prog < m['rb_fade_from'] else max(0.0, 1 - (prog - m['rb_fade_from'])/0.1)
                if gap > 0: mult *= 1 - m['rb_ahead']*k*fade
                else: mult *= 1 + m['rb_behind']*k*fade
            target = V_CRUISE*mult
            a = ACC_UP if target > r.v else -ACC_DOWN
            r.v = min(target, r.v + a*DT) if a > 0 else max(target, r.v + a*DT)
            r.s += r.v*DT
            if r.s >= L: r.done = t
    times = [r.done for r in riders]
    order = sorted(range(6), key=lambda j: times[j])
    place = order.index(5) + 1
    win = times[order[0]]; second = times[order[1]]
    margin = (second - times[5]) if place == 1 else None
    return place, times[5], max(times) - min(times), margin, times[5] - win

def report(mode, strat, hover, n=400):
    rng = random.Random(42)
    res = [run(mode, strat, hover, rng) for _ in range(n)]
    places = [r[0] for r in res]
    pt = [r[1] for r in res]; spread = [r[2] for r in res]
    margins = [r[3] for r in res if r[3] is not None]; behind = [r[4] for r in res if r[0] != 1]
    dist = {p: places.count(p)*100//n for p in range(1, 7)}
    print(f"{mode:6s} {strat:8s} hover={int(hover)} time {statistics.median(pt):5.1f}s  place med {statistics.median(places):.0f} "
          f"win% {dist[1]:3d} dist {dist}  spread {statistics.median(spread):.1f}s  "
          f"win margin {statistics.median(margins) if margins else float('nan'):.2f}s  behind winner {statistics.median(behind) if behind else 0:.2f}s")

if __name__ == '__main__':
    n = int(sys.argv[1]) if len(sys.argv) > 1 else 200
    for mode in ('easy', 'normal'):
        for strat in ('idle', 'average', 'skilled'):
            for hover in (False, True):
                report(mode, strat, hover, n)

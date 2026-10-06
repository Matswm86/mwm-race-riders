"""MWM Race Riders league sim (game-designer, 2026-10-06).

Offline league ladder check for docs/GDD.md section 17. One tier season = 5 rounds. Each round
has two heats of 6: the player's heat (simulated with pack_sim.run against the 5 rivals nearest
the player in the table) and a seeded rival-only heat for the other 6 rivals. Points per place
are POINTS below. Top PROMOTE_TOP of the 12-rider table promote. Results are design estimates
(my calc), not measurements.

Run: python3 tools/league_sim.py [seasons] [mode] [strategy] [league_index] [world]
  mode: easy|normal, strategy: idle|average|skilled, league_index 0 (Bronze) .. 5 (Champion)
"""

import copy
import random
import statistics
import sys
from pathlib import Path

_src = (Path(__file__).parent / "pack_sim.py").read_text(encoding="utf-8").split("if __name__")[0]
PS: dict = {}
exec(_src, PS)  # noqa: S102 - our own sim file

POINTS = [10, 8, 6, 5, 4, 3]
ROUNDS = 5
TABLE_RIVALS = 11
PROMOTE_TOP = 3
# Rival skill of the 11 table rivals in the lowest tier (Bronze III), spread around the
# calibrated pack_sim AI skills, plus a step per league and a third of a step per tier.
RIVAL_SKILL_BASE = {
    "easy": [0.90 + 0.01 * k for k in range(TABLE_RIVALS)],  # 0.90 .. 1.00
    "normal": [0.89 + 0.01 * k for k in range(TABLE_RIVALS)],  # 0.89 .. 0.99
}
LEAGUE_SKILL_STEP = {"easy": 0.006, "normal": 0.01}


def rival_skills(mode: str, league: int, tier: int = 0) -> list[float]:
    """tier 0 = III (lowest), 2 = I."""
    off = LEAGUE_SKILL_STEP[mode] * (league + tier / 3)
    return [round(s + off, 4) for s in RIVAL_SKILL_BASE[mode]]


def rival_heat(skills: list[float], rng: random.Random) -> list[int]:
    """Indices ordered by finish: time ~ 1/skill with 2.5% noise (seeded)."""
    t = [(1.0 / s) * (1.0 + rng.gauss(0.0, 0.025)) for s in skills]
    return sorted(range(len(skills)), key=lambda i: t[i])


def season(mode, strat, league, world, rng, places):
    skills = rival_skills(mode, league)
    pts = [0] * TABLE_RIVALS
    me = 0
    for _ in range(ROUNDS):
        # table order now (player included as index -1)
        order = sorted(range(TABLE_RIVALS), key=lambda i: -pts[i])
        # the 5 rivals nearest the player's points
        near = sorted(order, key=lambda i: (abs(pts[i] - me), -skills[i]))[:5]
        near.sort(key=lambda i: skills[i])  # pack_sim slot 4 = fastest, starts in front
        modes = copy.deepcopy(PS["MODES"])
        modes[mode]["ai_skill"] = [skills[i] for i in near]
        saved = PS["MODES"]
        PS["MODES"] = modes
        PS["run"].__globals__["MODES"] = modes
        res = PS["run"](mode, strat, True, rng, world)
        PS["MODES"] = saved
        PS["run"].__globals__["MODES"] = saved
        place = res[0]
        places.append(place)
        me += POINTS[place - 1]
        # rival places in the player's heat: approximate by skill order around the player
        others = sorted(near, key=lambda i: -skills[i] * (1 + rng.gauss(0, 0.02)))
        slots = [p for p in range(1, 7) if p != place]
        for i, p in zip(others, slots, strict=True):
            pts[i] += POINTS[p - 1]
        rest = [i for i in range(TABLE_RIVALS) if i not in near]
        for p, k in enumerate(rival_heat([skills[i] for i in rest], rng)):
            pts[rest[k]] += POINTS[p]
    rank = 1 + sum(1 for x in pts if x > me) + 0.5 * sum(1 for x in pts if x == me)
    return me, rank


def main() -> None:
    n = int(sys.argv[1]) if len(sys.argv) > 1 else 60
    mode = sys.argv[2] if len(sys.argv) > 2 else "easy"
    strat = sys.argv[3] if len(sys.argv) > 3 else "idle"
    league = int(sys.argv[4]) if len(sys.argv) > 4 else 0
    world = int(sys.argv[5]) if len(sys.argv) > 5 else 1
    rng = random.Random(7)
    places: list[int] = []
    out = [season(mode, strat, league, world, rng, places) for _ in range(n)]
    top3 = sum(1 for p in places if p <= 3) * 100 / len(places)
    win = sum(1 for p in places if p == 1) * 100 / len(places)
    ranks = [r for _, r in out]
    promo = sum(1 for r in ranks if r <= PROMOTE_TOP) * 100 // n
    bottom2 = sum(1 for r in ranks if r >= TABLE_RIVALS) * 100 // n
    print(
        f"{mode:6s} {strat:8s} league {league} W{world}: season pts med {statistics.median(p for p, _ in out):.0f}  "
        f"race top3 {top3:.0f}% wins {win:.0f}%  table rank med {statistics.median(ranks):.1f}  promoted {promo}%  bottom-2 {bottom2}%"
    )


if __name__ == "__main__":
    main()

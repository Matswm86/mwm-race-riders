# MWM Race Riders: game design doc

Version 1, 2026-10-06, game-designer. Slug `mwm-race-riders`, class prefix `Rr`, save `user://mwm_race_riders_save.json`. The feel study used an older working name; the game is **MWM Race Riders** everywhere now.

Target: Android, portrait 1080x1920, Godot 4.6 `mobile` renderer, stand-alone app first, later a game inside MWM Play (ages 4-7 and 8+). Visuals belong to graphic-designer (`docs/DESIGN.md`); this doc only lists game-feel hooks.

Legend: **(owner)** = decided by the owner, do not reopen. **(feel N)** = row N of the targets table in `projects/game-studio/docs/ridge-riders-feel-2026-10-05.md`, which is measured from 3 gameplay videos of the genre reference. **(rule N)** = numbered rule in `projects/mwm-play/docs/CHILD_UX_RESEARCH.md`. **(my calc)** = my own simulation or arithmetic (`tools/pack_sim.py`), not a source. **(my call)** = a design choice I made; change it freely.

**Legal line (owner):** we copy the genre feel only: one-thumb steering, speed, jumps, vehicle swapping, race length, a pack you overtake. We copy no characters, palette, UI layout, tracks, vehicle models, sounds, popup words or name. Never use the reference game's name, its words, or the old working names (owner list in the hand-off) in code, assets, store text or voice lines.

---

## 1. Pitch

Hold the left or right side of the screen to steer a mountain bike, and later a hoverboard, down a bright mountain trail against five friendly riders: hit glowing speed pads, fly off jumps, swap vehicles at magic gates and cross the finish in about 45 seconds; nobody ever crashes and everyone always finishes.

## 2. Core loop

**Hold** (steer left or right) -> **chase** (pads, boost, overtakes) -> **fly** (jumps with automatic tricks) -> **swap** (bike <-> hoverboard at gates) -> **finish** (cup or ribbon, time vs your ghost) -> race again, or stop at the card.

One race is about 45 s, plus about 8 s from the card to the next start (feel 25-27). There is no score, no currency and no game over (owner). Every finish earns a trophy shape and counts toward unlocks (rule 30).

## 3. Controls

One thumb, portrait. Hold left half / hold right half. No swipe, no tilt, no double tap, no long-press gestures (owner, rules 9-11, 14).

### 3.1 Zones (logic px at 1080x1920)

| Zone | Rect | What happens |
|---|---|---|
| Shell home square | x 0-232, y 0-232 | Nothing of the game is drawn or tappable here. Stand-alone build draws its own home disc here (dia 136, centre 104,104, hit area 0-216 to the edges, same "tap again" guard as the shell). Hidden when `Engine.get_meta(&"mwm_play_shell")` is set. Touches that start here never steer. |
| Settings gear | x 848-1080, y 0-232 | Gear disc dia 136 at (976, 104), hit area runs to the top and right edges (rule 7). Two-tap guard, see 3.2. Present in every race and on the card (owner). |
| HUD strip | y 232-330 | Not tappable. Progress bar and place badge (section 10.1). Touches starting here DO steer (it is a big, forgiving zone). |
| Steer left | x 0-539, y 232-1663, minus the boost disc | Touch-down = hold left. |
| Steer right | x 540-1080, y 232-1663, minus the boost disc | Touch-down = hold right. |
| Boost disc | circle centre (540, 1490), drawn dia 220, hit dia 280 (y 1350-1630) | A button: acts on release inside the hit circle (owner: menu buttons act on release). A touch that starts here never steers. |
| Wrist strip | y >= 1664 | Touches that START here are ignored (rule 6). A held steer touch that slides into the strip keeps steering. |

Taller screens (20:9, canvas about 1080x2400): HUD anchors to the top, boost disc anchors to the bottom at `screen_h - 430`, the steer zones stretch between them, the 3D view simply shows more sky. Safe area: push the home disc and gear below `DisplayServer.get_display_safe_area()` but keep their hit areas running to the edge (copy the ball-connect `7ad7d50` fix).

### 3.2 Inputs

| Input | Where | Effect |
|---|---|---|
| Touch down | Steer zone | Acts on touch-down (owner: steering acts on hold). Starts steering that way in the same frame; a soft "tick" of the tyre/board plays and a translucent arrow chevron (200 px) lights on that screen edge at y 1000 (rule 19). |
| Hold | Same pointer | Keeps steering that way. The pointer's half is re-read every frame, so sliding the thumb across x 540 changes direction. |
| Second finger | Other half | **Latest touch wins** (rule 14). When the newer finger lifts, the older one, if still down, takes over again. A resting palm (touch held > 8 s with no movement) is ignored from then on (my call). |
| Release | Steer pointer | Steering eases back to straight over `STEER_RELEASE_S`. In Lett the auto-steer takes over after `ASSIST_RESUME_S`. |
| Tap boost disc | Boost disc | On release inside, if charged: boost fires. If not charged: a soft "not yet" thump, the ring wiggles 6 px for 150 ms. |
| Pre-race start | Anywhere in the steer zones or boost disc | Touch-down starts the gate lights (section 10.2). If nobody touches, the race starts by itself after `AUTO_START_S`. |
| Gear | Gear zone | First tap: disc pops to 1.2x, a ring fills over 2.0 s, the race keeps running. Second tap between 0.3 and 2.0 s: race pauses and the settings panel opens. No second tap: ring fades in 250 ms. |
| Home disc / Android back | Top-left | Stand-alone: same guard as the gear; the second tap leaves to the track page. In the shell the shell owns this. |
| App to background | | Pause. On return, a 240 px "play" disc in the centre resumes on release. |
| Card buttons | Card | Section 10.3. |

Holdover filter: ignore all touches for 300 ms after any screen change (rule 8), so the finger that tapped "replay" does not instantly steer.

## 4. Riding model (how the builder simulates it)

The track is a `Path3D` centre line. Every rider is simulated in track space: **s** = metres along the centre line, **x** = metres sideways from it (left negative), **h** = height above the track surface (0 unless airborne). The world position comes from the curve's transform at s, offset by x and h. Curves never push a rider sideways: holding nothing keeps you on your line (my call: this is what makes "hold nothing and still finish" safe).

### 4.1 Speed

- Every rider has a speed v along s. Each frame: `target = CRUISE * section_mult * vehicle_mult * product(active effects) * (AI: skill * rubber band)`. v moves toward target at `ACCEL_UP` when below, `ACCEL_DOWN` when above.
- Speed floor after the start: `v >= MIN_SPEED_FRAC * CRUISE` (12 m/s). Nothing in the game can stop a rider, so a race always ends (worst case 950 / 12 = 79 s, my calc).
- Effects multiply and each has its own timer. The same effect again refreshes its timer instead of stacking, except pad chains (4.4).

### 4.2 Steering

- Holding a side: lateral velocity eases toward `+-STEER_LAT_MAX` (5.0 m/s; hoverboard x1.10) over `STEER_EASE_S` (0.12 s).
- Release: lateral velocity eases to 0 over `STEER_RELEASE_S` (0.15 s).
- Airborne: steering works at `AIR_STEER_FRAC` (50%).
- Visual lean: roll = `lat_v / STEER_LAT_MAX * LEAN_MAX_DEG` (18 deg), smoothed over 0.1 s.
- **Track edges are soft rails** (fences, snow banks, rock walls): x is clamped to `+-(width/2 - RIDER_RADIUS)`. While touching a rail: speed x`RAIL_MULT` (Lett 0.97, Vanlig 0.92), dust puffs, a soft scrape loop. Never a stop, never a bounce-back the child has to fight.

### 4.3 Lett auto-steer (kid-easy assist)

- Each track has a hand-placed **kid line** `x_kid(s)` (a `Curve` sampled by s) that runs over about half of the pads and around every hay bale.
- Lett only: when no steer pointer is down and `ASSIST_RESUME_S` (0.6 s) has passed since release, the rider steers toward `x_kid(s)` at up to `ASSIST_LAT_MAX` (2.5 m/s), easing over 0.3 s. Touching always overrides it at once.
- Vanlig: no assist; holding nothing rides straight along the current x.

### 4.4 Speed pads

- Pad: a 3 m wide x 4 m long glowing plate. Triggered when the rider's centre x is inside the pad's width while crossing its s range (forgiving: rider radius counts, so effective width 4 m).
- Effect: speed x`PAD_MULT[chain]` for `PAD_TIME_S` (1.2 s).
- **Chain:** a pad hit within `PAD_CHAIN_WINDOW_S` (1.5 s) of the previous one raises the chain level: x1.25 -> x1.32 -> x1.40 (cap 3). The chain shows as 1, 2, 3 chevrons above the rider (shape, not digits).
- AI use pads too (section 7).

### 4.5 Boost

- Meter fills from GO in `BOOST_FIRST_S` (10 s), then refills in `BOOST_REFILL_S` (10 s) after each boost ends (feel 6). That is about 3 boosts in a 45 s race (my calc).
- Effect: speed x`BOOST_MULT` (1.40) for `BOOST_TIME_S` (2.5 s).
- Input: the boost disc (3.1). **Lett: auto-boost** fires by itself `AUTO_BOOST_S` (2.0 s) after the meter is full if the child has not pressed it; pressing earlier is always allowed. Vanlig: manual only (my call: a full meter waiting is the skill decision).
- Boost disc look: an empty ring that fills clockwise; full = the disc glows and pulses at 1 Hz (well under 3 flashes/s, rule 37).
- AI boost on their own timers (section 7).

### 4.6 Jumps (kickers)

- A kicker is a ramp across the full track width, so every rider jumps; no aiming needed (my call, rule 16).
- Launch: vertical speed `vy = GRAVITY * air_s / 2`, with `GRAVITY` 22 m/s^2 and air_s set per kicker (track table). Horizontal speed is kept.
- **Automatic trick** (no input, feel 13): if air_s >= `TRICK_MIN_AIR_S` (0.8 s), one trick starts 0.15 s after take-off and lasts `TRICK_TIME_S` (0.6 s), ending at least 0.15 s before landing. Tricks cycle in a fixed order per vehicle (bike: no-hands, tail-whip, superman; hoverboard: 360 spin, grab, board-flip). Graphic-designer animates them.
- **Landing always succeeds** (owner: no crashes). Landing squash (section 11). If air_s >= `LAND_BONUS_MIN_AIR_S` (1.2 s): speed x`LAND_BONUS_MULT` (1.10) for `LAND_BONUS_TIME_S` (0.8 s) and a star popup.

### 4.7 Bumps (owner: wobble, nobody crashes)

- Riders are circles of `RIDER_RADIUS` 0.5 m. Contact when `|dx| < 1.0` and `|ds| < 1.4` m.
- On contact: both get pushed apart sideways at `BUMP_PUSH` 3 m/s for 0.2 s, both **wobble** for `BUMP_TIME_S` (0.5 s): player speed x0.95, AI speed x0.90 (my call: bumping is never bad for the child). Same pair cannot bump again for 1.0 s.
- No knock-out, no fall, no skull, no "out" word. The AI never aims at the player.

### 4.8 Soft obstacles

- Hay bales only in the slice (1.6 m wide, 1.0 m deep). Riding into one: it bursts into straw particles, speed x`HAY_MULT` (0.85) for `HAY_TIME_S` (0.5 s). The rider goes straight through; no stop, no bounce.

### 4.9 Swap gates (owner: auto swap at 2 gates)

- Two gate arches per track. Gate 1 turns bike -> hoverboard (start of the smooth section), gate 2 turns hoverboard -> bike.
- **Before the hoverboard is unlocked** (race 1 ever) the gates are dormant: arches stand, no glow, no swap. Everyone rides the bike all race (AI follow the same rule, so race 1 is fair).
- **After unlock:** passing a gate morphs the vehicle in `SWAP_FX_S` (0.3 s): ring of light runs down the arch, old vehicle scales 1->0 in 0.15 s while the new one scales 0->1 in 0.15 s, rider hops 0.3 m. **No speed loss.** AI swap at the same gates.
- First active gate ever (race 2): time scale 0.5 for 0.6 s so a child sees the change happen (once only, saved flag).
- Hoverboard: speed x`HOVER_SMOOTH_MULT` (1.06) on smooth sections, steering x1.10, floats 0.3 m with a 0.05 m bob at 1.5 Hz.

## 5. Elements

### 5.1 Vehicles

| Vehicle | Unlock | Where it rides | Feel | Speed mult |
|---|---|---|---|---|
| Mountain bike | Start | Dirt, planks, steep | Knobby crunch, chain whirr, suspension dip on landing | 1.00 |
| Hoverboard | First finish (owner) | Smooth: forest road, boardwalk, tunnel, later ice and city | Low hum that rises with speed, soft blue under-glow, floaty lean | 1.06 on smooth |

### 5.2 Track pieces (slice)

| Piece | Shape cue (colour never the only cue, rule 36) | Effect | Ref |
|---|---|---|---|
| Speed pad | Plate with 3 static arrow chevrons, glows | 4.4 | feel 11 |
| Kicker | Ramp with a curved lip, plank or earth | 4.6 | feel 12 |
| Swap gate | Tall arch with a bike icon on one pillar and a board icon on the other | 4.9 | feel 16 |
| Hay bale | Round bale, straw texture | 4.8 | feel 18 |
| Rail | Low wooden fence (forest), rock (tunnel) | 4.2 | feel 17 |
| Finish gate | Wide arch with a chequered banner (no text) | Section 10.2 | feel 20 |

## 6. Track 1, the vertical slice: "Furuløypa / Pine Run"

Forest mountain trail on a sunny afternoon (setting cue only; graphic-designer owns the look). Length **950 m** to the finish line, plus a 60 m run-out. Target times (my calc, `tools/pack_sim.py`, 150-400 runs): idle Lett child 43.8 s on the bike, average player 43.7-44.5 s, skilled player 41.0 s, idle Vanlig rider 46.9-47.8 s. All inside the owner's ~45 s.

### 6.1 Section table (s in metres from the start line; x in metres, + = right)

| s from-to | Section | Surface / vehicle | Width | Cruise mult | Contents | Kid line x |
|---|---|---|---|---|---|---|
| -15-0 | Start grid | Dirt | 12 | - | 5 AI ahead of the player (section 7.2) | 0 |
| 0-40 | Start drop | Dirt / bike | 12 -> 10 | 1.00 | Short downhill out of the start gate | 0 |
| 40-180 | Skogsstien (forest path) | Dirt / bike | 10 | 1.00 | Gentle S-bend (radius 60 m left, then right). **P1** pad at s 120, x 0 | 0 |
| 180 | **K1** log kicker | Dirt | 10 | | Air **1.0 s** (first jump, short) | 0 |
| 180-300 | Pine slope | Dirt / bike | 10 | 1.00 | **P2** s 210, x -3. **H1** hay s 260, x +2.5 | 0 |
| 300 | **Gate G1** | | 10 | | Bike -> hoverboard (after unlock) | 0 |
| 300-600 | Elvevegen (river road) | Smooth gravel road + boardwalk / hoverboard | 10 | 1.00 (hover x1.06) | **Chain P3-P5** at s 340, 352, 364, x +2.5. **K2** bridge hump at s 430, air **1.2 s**. **P6** s 470, x -3. **H2** hay s 520, x -0.5 (in the straight-line path on purpose). Rock tunnel s 540-580, width 8 | +2.5 at 330-375, 0 to 495, +1.8 at 500-540, 0 after |
| 600 | **Gate G2** | | 10 | | Hoverboard -> bike | 0 |
| 600-880 | Bratthenget (steep slope) | Dirt + plank ramp / bike | 9 (7 at 720-770) | 1.05 | **H3** s 650, x -2. **P7** s 700, x +3. Track narrows with fences to the plank ramp. **K3** big plank kicker s 760, air **1.6 s** (the hero jump). **Chain P8-P10** at s 800, 812, 824, x -3. **H4** s 840, x +1.5 | +3 at 685-715, 0 after |
| 880-950 | Finish meadow | Grass / bike | 12 | 1.00 | **K4** finish hill s 900, air **1.0 s**. Finish gate at s 950 | 0 |
| 950-1010 | Run-out | Grass | 12 | target 0.5 | Riders coast; finish shot plays here | 0 |

Counts: 10 pads (2 chains of 3), 4 kickers (one every ~11 s, feel 12), 4 hay bales, 2 swap gates. The kid line hits 5 of 10 pads (P1, P3, P4, P5, P7) and no hay. A straight idle Vanlig rider hits P1 and H2. A skilled rider can take all 10 pads and avoid all hay.

Elevation hint for the level builder: about 120 m total drop, steepest in Bratthenget; the camera must always see 40+ m of track ahead, so no blind crests except the K3 lip.

### 6.2 Later tracks (full game, one new idea each)

| # | Name (NO / EN) | Setting cue | New idea | Length | Target time |
|---|---|---|---|---|---|
| 1 | Furuløypa / Pine Run | Forest trail, river road | Basics: steer, pads, jumps, swap gates | 950 m | ~44 s |
| 2 | Havnebyen / Harbour Town | Quayside, boardwalk, rooftops | **Split path**: the track forks around a lighthouse into two equal-length lanes, then joins | 1000 m | ~46 s |
| 3 | Snøtoppen / Snow Top | Snow bowl, ice tunnel | **Ice patches**: lateral speed x1.3 and 0.3 s longer ease (slidey), hoverboard section longer | 1000 m | ~46 s |
| 4 | Ørkenjuvet / Red Canyon | Red rock canyon, rope bridge | **Whoops**: rows of small bumps that give 0.4 s mini-airs (no tricks) | 1050 m | ~48 s |
| 5 | Lysskogen / Glow Forest | Night forest, glowing mushrooms | **Breather**: no new element, no hay, 14 pads, wide track | 1000 m | ~45 s |
| 6 | Nordlysfjellet / Aurora Peak | Night summit, aurora sky | **Bounce mushrooms** (a pad that launches a 1.2 s jump) + every earlier element, finale | 1100 m | ~52 s |

Cruise speed stays 20 m/s on every track; tracks get longer, not faster (feel 1: the reference grows 33 -> 50 s, then plateaus). All still 2 swap gates.

## 7. AI pack

### 7.1 Riders

5 AI riders, each told apart by **helmet shape icon + colour** (rule 36): Star, Moon, Leaf, Drop, Triangle. A small icon floats above each rider; the player has a big down-arrow chevron. No names, no text tags (owner: icons not text).

| Slot | Icon | Lett skill | Vanlig skill | Pad seek Lett / Vanlig | Lane offset | Start s |
|---|---|---|---|---|---|---|
| 0 | Leaf | 0.93 | 0.90 | 0.20 / 0.30 | -3 | 3 |
| 1 | Drop | 0.95 | 0.92 | 0.25 / 0.35 | +3 | 6 |
| 2 | Triangle | 0.97 | 0.94 | 0.30 / 0.40 | -1.5 | 9 |
| 3 | Moon | 0.99 | 0.96 | 0.35 / 0.45 | +1.5 | 12 |
| 4 | Star | 1.01 | 0.98 | 0.40 / 0.50 | 0 | 15 |

The player starts last at s 0, x 0 (feel 3). The fastest AI starts at the front.

### 7.2 Behaviour per frame

1. **Line:** lateral target = `x_kid(s) + lane_offset`, clamped inside the rails.
2. **Pads:** 30 m before each pad, roll once against `pad_seek`; on success the lateral target becomes the pad's x until the pad is passed.
3. **Hay:** 25 m before a bale in its path, roll 0.8 to swerve 2 m to the more open side.
4. **Traffic:** if another rider is within 3 m ahead and `|dx| < 1.2`, roll 0.7 to shift 1.5 m to the more open side (the failed rolls make the natural bumps).
5. **Boost:** when its meter is full, fires after a random 0.5-3.0 s.
6. **Lateral speed:** 4.0 m/s max, 0.2 s ease (slightly calmer than the player).
7. **Never** aims at the player, never blocks on purpose.

### 7.3 Rubber-banding (visible, fair, symmetric caps; feel 5)

`gap = ai.s - player.s` (metres), `k = min(1, |gap| / RB_RANGE_M)` with `RB_RANGE_M` 30.

- AI ahead of the player (`gap > 0`): speed x `(1 - RB_AHEAD * k * fade)`.
- AI behind the player (`gap < 0`): speed x `(1 + RB_BEHIND * k * fade)`.
- `fade` = 1 until the player's progress reaches `RB_FADE_FROM`, then drops linearly to 0 over the next 10% of the track.
- Clamp the AI's total multiplier to 0.80-1.50. After the player finishes, AI run on skill alone.

| | Lett | Vanlig |
|---|---|---|
| `RB_AHEAD` | 0.08 | 0.05 |
| `RB_BEHIND` | 0.04 | 0.03 |
| `RB_FADE_FROM` | never (1.1) | 0.40 (fully off at 0.50) |

Why: in Lett the pack waits for a child all race. In Vanlig it keeps the first half close and exciting, then lets go so skill decides the end.

### 7.4 Expected results (my calc, `tools/pack_sim.py`, 150 runs each, 1D model; tune again on the phone)

| Player | Mode | Vehicle | Time | Places | Wins | Gap |
|---|---|---|---|---|---|---|
| Holds nothing (4-year-old) | Lett | bike | 43.8 s | 1st 33%, 2nd 59%, 3rd 7% | 33% | 0.23 s behind the winner (median when not 1st) |
| Holds nothing | Lett | + hoverboard | 43.3 s | 1st 20%, 2nd 66%, 3rd 13% | 20% | 0.28 s |
| Steers at random (half the pads, hits 40% of hay) | Lett | either | 43.8-44.5 s | mostly 2nd-3rd | 10-14% | 0.5 s |
| Skilled (all pads, instant boost) | Lett | either | 41.0-41.8 s | always 1st | 100% | wins by 1.1-1.3 s |
| Holds nothing | Vanlig | either | 46.9-47.8 s | 4th-5th | 0% | 3.1-3.3 s behind |
| Average | Vanlig | either | 43.7-44.4 s | 1st 45-48%, 2nd 42-49% | ~46% | photo finishes, 0.4 s |
| Skilled | Vanlig | either | 41.0-41.8 s | always 1st | 100% | **wins by 2.2-2.3 s** |

Owner targets met in the model: a child holding nothing always finishes, in the pack, usually 2nd; a skilled player wins by a few seconds. Pack spread is 2.6-4.7 s except when a skilled Vanlig player escapes (7 s), which is the reward for skill (feel 5 says <= 4 s for the pack itself).

## 8. Modes: Lett (4-7, default) vs Vanlig (8+)

| Aspect | Lett | Vanlig |
|---|---|---|
| Auto-steer to the kid line when not touching | yes (4.3) | no |
| Boost | auto after 2 s if not pressed | manual |
| Rail slowdown | x0.97 | x0.92 |
| AI skill | 0.93-1.01 | 0.90-0.98 |
| Rubber band | strong, never fades | mild, fades out at 40-50% |
| Race timer on HUD | hidden | small, top centre-right |
| Same track, same speed, same bumps | yes | yes |

Rule 16 (no reflex demand at the easiest level) and rule 31 (no game over for 4-7) hold in both: nothing can stop or eliminate a rider.

Where the setting lives: inside MWM Play the adapter calls `set_difficulty(easy: bool)` (same as Neon Bricks; parent-area row). Stand-alone: a two-icon segment (small rider / big rider) in the settings panel. Takes effect at the next race start.

## 9. Progression and unlocks (owner: by playing only)

### 9.1 Unlock order (counted on finishes, any place, so a 4-year-old progresses as fast as a skilled player)

| Total finishes | Unlock | Notes |
|---|---|---|
| 1 | **Hoverboard** (gates go live) | Owner. Reveal card after the reward card |
| 2 | Rider outfit 2 | Cosmetic |
| 3 | **Track 2** Havnebyen | Full game only |
| 4 | Hoverboard skin 2 | |
| 5 | Rider outfit 3 | |
| 6 | **Track 3** Snøtoppen | |
| 7 | Bike skin 2 | |
| 9 | **Track 4** Ørkenjuvet | |
| 12 | **Track 5** Lysskogen | |
| 15 | **Track 6** Nordlysfjellet | |
| First 1st place on a track | That track's gold trim for the bike | 6 total, a nod to skill; never needed |

Not-yet-earned items are **not drawn at all** (no padlocks, no greyed tiles, rule 22 counter-consideration 1). Each new item arrives with one reveal card (2 s spin on a pedestal, one tap continues). No stat upgrades: they would break the fair pack (feel 24).

Garage (outfits and skins): one "garage" disc on the track page, opening a single screen with big 240 px swatch discs. Out of the slice.

### 9.2 Free part (MWM Play)

- The game holds `full_unlock: bool`, default `true`. Public hook `set_full_unlock(on: bool)` (owner), same style as Neon Bricks. The game never checks purchases itself.
- `full_unlock == false`: **track 1 only, bike + hoverboard, outfit 2** (whatever finishes 1-2 unlock). Track 2+ and later cosmetics are never drawn. On every finish from total finish 3 onward, at most **once per app session**, the game emits `free_levels_finished` after the reward card closes; the shell then shows its "Du har spilt alle banene her" card. Replay keeps working forever.
- `full_unlock == true`: all 6 tracks and all unlocks as earned.
- The stand-alone build never calls the hook, so it is fully open (owner's own copy).

Free part size: 1 of 6 tracks, both vehicles, about 3 races (about 3 minutes) before the shell card first shows (my calc).

## 10. Screens and session shape

### 10.1 Race HUD (no text)

- Progress bar: x 260-820, y 250-286, a rounded track line with 6 rider icons sliding along it (player icon 1.5x size with the arrow). A finish-flag shape at the right end.
- Place badge: disc dia 110 centred at (540, 350), under the bar and clear of the home and gear squares. Gold, silver, bronze disc with the digit for 1-3; white disc with the digit for 4-6. Digits are the only text (children know 1-6, my call). Not tappable; touches on it steer like the rest of the zone.
- Vanlig only: race time `0:43.8` centred at (780, 350), 40 px, not tappable.
- Boost disc (3.1). Ghost has no HUD element; it is just visible on the track.

### 10.2 Launch to racing (owner: <= 10 s)

| Step | Time | What |
|---|---|---|
| Engine boot + splash | ~2.0 s | Plain splash, logo only |
| Scene load | <= 2.0 s | Straight into track 1 on first ever launch (no menu). Later launches: also straight into the last track played (my call; the track page is one home-tap away) |
| Pre-race | until touch, max `AUTO_START_S` (4.0 s; 3.0 s on first launch) | Rider on the start line, camera eases from a front 3/4 view to the chase view over 1.0 s. Two hand icons press the left and right halves in turn (loop 1.6 s) |
| Gate lights | `START_LIGHTS_S` 1.2 s | 3 lamps light 0.4 s apart with rising soft marimba blips, then the gate drops: GO |
| Racing | | |

Worst case about 9.2 s from icon tap to GO (my calc).

### 10.3 Finish and reward card (natural stopping point)

1. Player crosses s 950: HUD hides, camera drops low beside the finish gate for `FINISH_SHOT_S` (2.0 s), time scale 0.6 for the first 0.4 s, confetti (top 3 only; particles, no flashes). AI keep riding; any AI not finished within 4 s is placed by projected time (`remaining_s / v`) so the card never shows blanks.
2. Card fades in over 250 ms (instant under less motion). Contents, no text:
   - **Trophy by place:** 1st gold cup, 2nd silver cup, 3rd bronze cup, 4th-6th a "finish flag" rosette. Every finish gets one (rule 30). The player's rider stands on the podium for 1-3, beside it for 4-6.
   - **Time** in digits, 64 px.
   - **Ghost line:** ghost icon + green up-arrow and star burst if this run beat the saved best ("new best"); ghost icon + the saved best time if not. First race: no ghost line.
   - **Discs** at y 1420 (all >= 200 px, act on release): **home** (x 270, dia 200) to the track page; **replay** (x 810, dia 240, the most visible); **next track** (x 540, dia 200) only when a next track is unlocked and not yet raced.
3. Spoken praise of the action, when a voice exists (rule 32): "Du kom i mål!" ("You reached the finish!"), 1st: "Du vant løpet!" ("You won the race!"). Blocked on the native Norwegian voice (same as Neon Bricks).
4. Unlock reveal card (if any) after the first tap on any disc, then the chosen action.
5. **Never auto-advances** (rule 26). Emits `level_card_shown(track_id)` so the shell's play limit can end here.

What counts as a **win**: crossing the finish line in 1st place. Results that matter for saves: best place and best time per track, total finishes.

### 10.4 Track page (stand-alone home, and the shell's "home inside the game")

Cards 440 x 380 in a 2-column grid from y 300, one per unlocked track, each with its picture and its best trophy shape. Garage disc bottom-right of the grid (above y 1664). Gear top-right. Slice: one card.

### 10.5 First 60 seconds (no text anywhere)

- 0 s: launch -> track 1 pre-race (10.2). Hand icons show "hold here or here".
- ~5-9 s: GO. In Lett, a child holding nothing rides the kid line and still passes riders.
- 7 s without touch during the race (rule 18): a hand icon pulses on the side toward the next pad for 2 s.
- ~10 s: boost meter full. Race 1 only: a hand taps the boost disc once; Lett auto-fires 2 s later anyway.
- ~9 s: first jump K1 with an automatic trick.
- ~44 s: finish, trophy card.
- Race 2: gates come alive, slow-mo at G1 shows the swap; the ghost of race 1 rides along.

### 10.6 Session shape

One race plus card is about 1 minute. A child plays 3-6 races and stops at a card. Pull to come back: the next unlock (hoverboard after race 1, a new track every 3 finishes), beating your own ghost. No streaks, daily rewards, timers, energy or "come back" messages (rule 27). Quitting mid-race costs nothing; the race is simply not counted (rule 28).

### 10.7 Settings panel (gear, owner: in every race, pauses)

Pauses the race (time scale 0, audio paused except the panel's own blips). Rows 160 px tall, controls >= 200 px wide:
- Effects: on/off toggle + volume slider (0-100, default 80).
- Music: on/off toggle + volume slider (0-100, default 60).
- Ghost: on/off (default **on**, owner).
- Stand-alone only: Lett / Vanlig (two icons), Less motion, Vibration (default off, rule 33).
- Close: big "play" disc (240 px) at y 1450 resumes on release.
Copy `NbSettings.gd` and `NbMain._open_settings/_close_settings` from `projects/mwm-neon-bricks/`. Inside MWM Play the shell's sound, music, haptics and less-motion settings win; the game shows only volume sliders and the ghost toggle there (my call).

### 10.8 Ghost (owner: on by default, local, offline)

- Record the player's s, x, h and vehicle id at `GHOST_HZ` (10 Hz) during each race. On a new best time for that track, save it (one ghost per track, any mode).
- Playback: linear interpolation, translucent (40% opacity), cool white tint, no shadow, no collision, not counted in places, no icon on the progress bar (my call: it is "you", not a rival). Shown from the second finish on a track.
- Ghost uses the vehicle it rode at each moment (a pre-hoverboard ghost stays on the bike).
- Size: ~45 s x 10 Hz x 4 numbers = 1,800 numbers per track, about 12 KB of JSON (my calc).

### 10.9 Save (`user://mwm_race_riders_save.json`)

```json
{
  "version": 1,
  "finishes": 4,
  "hover_unlocked": true,
  "seen_first_swap": true,
  "tracks": {"1": {"best_time": 42.31, "best_place": 1, "won": true, "ghost": [[0.0, 0.0, 0.0, 0], [2.1, 0.0, 0.0, 0]]}},
  "cosmetics": {"outfit": 2, "bike": 1, "board": 1, "owned": ["outfit2", "board2"]},
  "last_track": 1,
  "difficulty": "lett",
  "settings": {"sfx_on": true, "sfx_vol": 80, "music_on": true, "music_vol": 60, "ghost": true, "haptics": false, "less_motion": false}
}
```
Ghost rows are `[s, x, h, vehicle]`, rounded to 2 decimals. Save on finish, on setting change, on leaving and on `NOTIFICATION_APPLICATION_PAUSED`. Mid-race state is not saved.

## 11. Feel

"Less motion" column = what replaces the effect when the shell's or the panel's less-motion switch is on (rule 39).

| Event | Visual | Sound (modern, no chiptune) | Haptic (if on) | Less motion |
|---|---|---|---|---|
| Touch-down steer | Edge chevron lights, 80 ms | Soft tyre tick / board whoosh | none | same |
| Steering | Rider leans up to 18 deg; dust or hover sparkle on that side | Tyre scrub layer rises | none | Lean kept (it is the feedback), no particles |
| Cruise | Camera chase (below); wind | Wind + tyre roll loop, pitch and volume follow speed | none | same |
| Speed above 1.1x cruise | Soft speed lines at screen edges, alpha <= 0.25, low contrast (rule 38), no strobing | Wind rises | none | No lines |
| Pad hit | Pad flares once; 1/2/3 chevrons pop over the rider, 300 ms | Rising "whoosh-zap", pitch steps up per chain level | 10 ms | Chevrons only |
| Boost | FOV 70 -> 80 over 0.15 s, back over 0.4 s at the end; trail behind the vehicle; edge vignette tint | Turbo swell + sustained roar, 2.5 s | 20 ms | No FOV kick, trail only |
| Boost charged | Disc glow, 1 Hz pulse | Soft "ready" chime once | none | Static glow |
| Take-off | Camera keeps 1.0 m extra height lag so the jump looks big | Whoosh + wind drop | none | same |
| Trick | Animation 0.6 s | Short swish | none | same |
| Landing | Squash: scale y 0.80 / xz 1.10 in 0.08 s, spring back over 0.18 s; dust ring; camera dip 0.08 m for 0.15 s | Thump + suspension creak (bike) or soft hover "fwump" | 25 ms | No squash, no dip; dust stays |
| Big landing (>= 1.2 s air) | + star popup (icon, 400 ms) | + bright chime | 30 ms | Popup stays |
| Bump | Both riders wobble: roll +-12 deg at 3 Hz, decaying over 0.5 s | Soft rubbery "bonk" | 15 ms | No roll, small colour blink once |
| Rail scrape | Dust puffs | Scrape loop | none | No dust |
| Hay bale | Straw burst, 20 particles, 0.6 s | Soft "pff" | 10 ms | Bale vanishes |
| Overtake | Tiny "+" sparkle over the passed rider, place badge pops 1.15x for 150 ms | Light "tick-up" blip | none | No pop |
| Swap gate | Light ring runs down the arch, vehicle morph 0.3 s | Shimmer + mechanical click-clack | 15 ms | Instant swap, ring only |
| Gate lights | 3 lamps | Three rising marimba blips, then a whoosh | none | same |
| Finish | Low camera, slow-mo 0.6x 0.4 s, confetti (top 3) | Crowd cheer + finish chime; music ducks 4 dB | 40 ms | No slow-mo, no confetti |
| Card | Fade 250 ms, trophy drops in with one bounce | Trophy "clink" sting | none | Instant |

**Camera** (feel 19): chase offset (0, 2.2, 4.5) m behind and above, pitch -12 deg, FOV 70; rider at about 60-70% of screen height, horizon about 30% from the top. Position follow rate 8/s, yaw follow 6/s, height follow 4/s (jumps feel tall). No camera roll ever (motion comfort, my call).

**Flash safety:** global limiter, at most 3 bright flashes per second (rule 37, owner); a pad chain within 333 ms shows chevrons but only one flare. No full-screen flashes. Pad chevrons are static, they glow, they do not scroll.

**Music (owner):** `assets/music/race_riders_theme.ogg`, 18.7 min long (my measurement, ffprobe 1123.9 s). Starts at the first pre-race, loops, and keeps playing across races and cards (it does not restart each race). Sits at least 6 dB under effects. Credit line: "Music supplied by the game owner." No source details anywhere.

**SFX (owner: modern):** build with Neon Bricks' `tools/render_sfx.py` method (own synthesis + Kenney CC0 samples), peaks about -10 dBFS.

## 12. Shell hooks (summary for the builder)

- Read `Engine.get_meta(&"mwm_play_shell")`: hide own home disc; settings panel shows only volumes and ghost.
- `set_full_unlock(on: bool)` (default true), `set_difficulty(easy: bool)` (default Lett), `set_shell_inset(Vector2(232, 232))` (no-op: nothing sits there), plus the shell's four settings (sfx, music, haptics, less motion).
- Signals up: `level_card_shown(track_id: int)`, `free_levels_finished()`.
- Public `save_game()` for the adapter's `exit()`.
- All class names start with `Rr` (`RrMain`, `RrRider`, `RrAi`, `RrTrack`, `RrGhost`, `RrSettings`, `RrBalance`, `RrMusic`, `RrSfx`).

## 13. Numbers: `scripts/RrBalance.gd`

Every tunable lives here (studio rule). Paste as is; `_L` = Lett, `_V` = Vanlig.

```gdscript
class_name RrBalance
extends RefCounted
## All MWM Race Riders tunables. Source: docs/GDD.md. Sim: tools/pack_sim.py.

# Race and track 1
const TRACK1_LENGTH_M: float = 950.0
const RUNOUT_M: float = 60.0
const RIDER_COUNT: int = 6                     # player + 5 AI (owner)
const AI_START_GAP_M: float = 3.0              # AI at s 3, 6, 9, 12, 15; player at 0
const AI_LANE_OFFSETS: Array[float] = [-3.0, 3.0, -1.5, 1.5, 0.0]

# Speed
const CRUISE_MPS: float = 20.0
const ACCEL_UP: float = 7.0                    # m/s^2
const ACCEL_DOWN: float = 12.0
const MIN_SPEED_FRAC: float = 0.6              # never below 12 m/s after GO
const STEEP_MULT: float = 1.05                 # Bratthenget section
const HOVER_SMOOTH_MULT: float = 1.06
const RUNOUT_MULT: float = 0.5

# Steering
const STEER_LAT_MAX: float = 5.0               # m/s
const HOVER_STEER_MULT: float = 1.10
const STEER_EASE_S: float = 0.12
const STEER_RELEASE_S: float = 0.15
const AIR_STEER_FRAC: float = 0.5
const LEAN_MAX_DEG: float = 18.0
const RIDER_RADIUS: float = 0.5
const RAIL_MULT_L: float = 0.97
const RAIL_MULT_V: float = 0.92
const PALM_IGNORE_S: float = 8.0

# Lett assist
const ASSIST_LAT_MAX: float = 2.5              # m/s toward the kid line
const ASSIST_EASE_S: float = 0.3
const ASSIST_RESUME_S: float = 0.6
const AUTO_BOOST_S_L: float = 2.0              # Lett only; Vanlig = manual

# Pads
const PAD_W_M: float = 3.0
const PAD_L_M: float = 4.0
const PAD_MULT: Array[float] = [1.25, 1.32, 1.40]
const PAD_TIME_S: float = 1.2
const PAD_CHAIN_WINDOW_S: float = 1.5

# Boost
const BOOST_FIRST_S: float = 10.0
const BOOST_REFILL_S: float = 10.0
const BOOST_TIME_S: float = 2.5
const BOOST_MULT: float = 1.40

# Jumps
const GRAVITY: float = 22.0                    # m/s^2, game gravity
const KICKER_AIR_S: Array[float] = [1.0, 1.2, 1.6, 1.0]   # K1-K4, track 1
const TRICK_MIN_AIR_S: float = 0.8
const TRICK_TIME_S: float = 0.6
const LAND_BONUS_MIN_AIR_S: float = 1.2
const LAND_BONUS_MULT: float = 1.10
const LAND_BONUS_TIME_S: float = 0.8

# Bumps and obstacles
const BUMP_DX_M: float = 1.0
const BUMP_DS_M: float = 1.4
const BUMP_PUSH_MPS: float = 3.0
const BUMP_PUSH_S: float = 0.2
const BUMP_TIME_S: float = 0.5
const BUMP_MULT_PLAYER: float = 0.95
const BUMP_MULT_AI: float = 0.90
const BUMP_PAIR_COOLDOWN_S: float = 1.0
const HAY_MULT: float = 0.85
const HAY_TIME_S: float = 0.5

# Swap gates
const SWAP_FX_S: float = 0.3
const FIRST_SWAP_TIMESCALE: float = 0.5
const FIRST_SWAP_SLOWMO_S: float = 0.6

# AI
const AI_SKILL_L: Array[float] = [0.93, 0.95, 0.97, 0.99, 1.01]
const AI_SKILL_V: Array[float] = [0.90, 0.92, 0.94, 0.96, 0.98]
const AI_PAD_SEEK_L: Array[float] = [0.20, 0.25, 0.30, 0.35, 0.40]
const AI_PAD_SEEK_V: Array[float] = [0.30, 0.35, 0.40, 0.45, 0.50]
const AI_PAD_LOOKAHEAD_M: float = 30.0
const AI_HAY_AVOID: float = 0.8
const AI_HAY_LOOKAHEAD_M: float = 25.0
const AI_TRAFFIC_AVOID: float = 0.7
const AI_LAT_MAX: float = 4.0
const AI_LAT_EASE_S: float = 0.2
const AI_BOOST_DELAY_S: Vector2 = Vector2(0.5, 3.0)
const AI_MULT_CLAMP: Vector2 = Vector2(0.80, 1.50)
const RB_RANGE_M: float = 30.0
const RB_AHEAD_L: float = 0.08
const RB_BEHIND_L: float = 0.04
const RB_FADE_FROM_L: float = 1.1              # never fades
const RB_AHEAD_V: float = 0.05
const RB_BEHIND_V: float = 0.03
const RB_FADE_FROM_V: float = 0.40
const RB_FADE_SPAN: float = 0.10

# Start, finish, flow
const AUTO_START_S: float = 4.0
const AUTO_START_FIRST_S: float = 3.0
const START_LIGHTS_S: float = 1.2
const FINISH_SHOT_S: float = 2.0
const FINISH_SLOWMO: float = 0.6
const FINISH_SLOWMO_S: float = 0.4
const AI_FINISH_WAIT_S: float = 4.0
const CARD_FADE_S: float = 0.25
const HOLDOVER_S: float = 0.3
const GUARD_WINDOW_S: Vector2 = Vector2(0.3, 2.0)   # gear and home two-tap guard
const IDLE_HINT_S: float = 7.0

# Camera
const CAM_OFFSET: Vector3 = Vector3(0.0, 2.2, 4.5)
const CAM_PITCH_DEG: float = -12.0
const CAM_FOV: float = 70.0
const CAM_FOV_BOOST: float = 80.0
const CAM_FOV_IN_S: float = 0.15
const CAM_FOV_OUT_S: float = 0.4
const CAM_FOLLOW_POS: float = 8.0
const CAM_FOLLOW_YAW: float = 6.0
const CAM_FOLLOW_HEIGHT: float = 4.0
const SPEED_LINES_FROM: float = 1.1            # x cruise
const SPEED_LINES_ALPHA_MAX: float = 0.25

# Feel
const LAND_SQUASH: Vector2 = Vector2(1.10, 0.80)   # xz, y
const LAND_SQUASH_IN_S: float = 0.08
const LAND_SQUASH_OUT_S: float = 0.18
const WOBBLE_DEG: float = 12.0
const WOBBLE_HZ: float = 3.0
const HOVER_HEIGHT_M: float = 0.3
const HOVER_BOB_M: float = 0.05
const HOVER_BOB_HZ: float = 1.5
const MAX_FLASHES_PER_S: int = 3

# Ghost
const GHOST_HZ: int = 10
const GHOST_ALPHA: float = 0.4
const GHOST_DEFAULT_ON: bool = true

# Unlocks (total finishes)
const UNLOCK_HOVER: int = 1
const UNLOCK_TRACKS: Array[int] = [0, 3, 6, 9, 12, 15]   # finishes needed for track 1..6
const FREE_TRACKS: int = 1
const FREE_CARD_FROM_FINISH: int = 3

# Audio
const SFX_VOL_DEFAULT: int = 80
const MUSIC_VOL_DEFAULT: int = 60
const MUSIC_UNDER_SFX_DB: float = -6.0
const FINISH_DUCK_DB: float = -4.0
```

## 14. Vertical slice scope (what godot-android-dev builds first)

In:
1. Track 1 Furuløypa exactly as in table 6.1 (Path3D, widths, 10 pads, 4 kickers, 4 hay bales, 2 swap gates, finish gate, run-out, kid line curve).
2. Rider in track space (section 4): steering by half-screen hold, latest touch wins, soft rails, speed model, pads with chains, boost disc + meter, jumps with automatic tricks (one animation per vehicle is enough), landing squash and bonus, bumps with wobble, hay.
3. Bike + hoverboard, dormant gates in race 1, live gates after the first finish, reveal card, first-swap slow-mo.
4. 5 AI with section 7 behaviour and rubber band, both modes.
5. Lett / Vanlig, auto-steer and auto-boost in Lett.
6. Pre-race hold-to-start + auto-start + gate lights; finish shot; reward card with trophy, time, ghost line, home + replay discs.
7. Ghost record, save and playback, on by default.
8. Settings gear with two-tap guard and pause; effects and music on/off + volume; ghost toggle; difficulty; less motion; haptics.
9. Music from `assets/music/race_riders_theme.ogg`; modern SFX set from section 11.
10. `full_unlock` hook, both signals, `set_difficulty`, `save_game()`, save file, shell-home square free, nothing tappable at y >= 1664, flash limiter, PerfOverlay.
11. Track page with one card (home target in stand-alone).

Out: tracks 2-6, garage and cosmetics (save fields exist, no UI), voice lines, store art, gold trims.

Acceptance hints for game-qa: kids walk-through with sound off, touching nothing after launch: the race starts by itself, the rider finishes inside 50 s and the card appears (Lett). Log check: no rider's speed ever below 12 m/s after GO; never more than 3 flashes in any 1 s window during the P3-P5 chain; no touch target inside 0-232 x 0-232 or at y >= 1664; launch to GO <= 10 s on the 32-bit tablet; Vanlig skilled bot (all pads, instant boost) wins by >= 1.5 s in 9 of 10 runs; idle Lett bot finishes in the top 3 in 9 of 10 runs.

## 15. Play together tip (rule 42, draft)

"Bytt på: den ene styrer til venstre, den andre til høyre." ("Take turns: one of you steers left, the other steers right.") Two thumbs, one on each half, works with latest-touch-wins.

## 16. Open questions (each has a default the builder uses now)

1. **Boost input.** Steering owns both screen halves, so boost is a centre disc at y 1490 that never steers. The feel reference also used double tap, which rule 10 forbids. **Default: centre disc, Lett auto-fires 2 s after full.** Alternative: no button at all, boost fires automatically in both modes.
2. **Place digits.** The HUD place badge and the card time use digits (1-6 and a clock). **Default: digits kept** (children 4-7 know 1-6; times are for older riders and parents). Alternative: shapes only, with the time hidden in Lett.
3. **Free-card frequency.** **Default: `free_levels_finished` on finish 3, then at most once per app session.** Alternative: only once ever.
4. **Unlocks counted on finishes, not wins.** **Default: finishes** (a 4-year-old progresses too); wins only add gold trims.
5. **Ghost per track, shared by both modes.** **Default: one ghost per track, best time from either mode.** A Vanlig parent's ghost will then lead a Lett child's race. Alternative: one ghost per mode.
6. **Hoverboard on track 1 smooth section only.** The kid line and AI numbers were simulated with the 1.06 hover bonus; if graphic-designer wants the board to look faster, raise `HOVER_SMOOTH_MULT` and re-run `tools/pack_sim.py`.
7. **Track names in Norwegian** (Furuløypa etc.) with English pairs, like Neon Bricks. **Default: yes.**

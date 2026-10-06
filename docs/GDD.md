# MWM Race Riders: game design doc

Version 1, 2026-10-06, game-designer. Slug `mwm-race-riders`, class prefix `Rr`, save `user://mwm_race_riders_save.json`. The feel study used an older working name; the game is **MWM Race Riders** everywhere now.

Target: Android, portrait 1080x1920, Godot 4.6 `mobile` renderer, stand-alone app first, later a game inside MWM Play (ages 4-7 and 8+). Visuals belong to graphic-designer (`docs/DESIGN.md`); this doc only lists game-feel hooks.

Legend: **(owner)** = decided by the owner, do not reopen. **(feel N)** = row N of the targets table in `projects/game-studio/docs/ridge-riders-feel-2026-10-05.md`, which is measured from 3 gameplay videos of the genre reference. **(rule N)** = numbered rule in `projects/mwm-play/docs/CHILD_UX_RESEARCH.md`. **(my calc)** = my own simulation or arithmetic (`tools/pack_sim.py`), not a source. **(my call)** = a design choice I made; change it freely.

**Legal line (owner):** we copy the genre feel only: one-thumb steering, speed, jumps, vehicle swapping, race length, a pack you overtake. We copy no characters, palette, UI layout, tracks, vehicle models, sounds, popup words or name. Never use the reference game's name, its words, or the old working names (owner list in the hand-off) in code, assets, store text or voice lines.

---

## 1. Pitch

Hold the left or right side of the screen to steer a mountain bike, and later a hoverboard, down a bright mountain trail against five rival riders: hit glowing speed pads, fly off jumps, swap vehicles at magic gates and cross the finish first in about 45 seconds. Shoulder a rival off their bike to get past; you never fall, and everyone always finishes.

## 2. Core loop

**Hold** (steer left or right) -> **chase** (pads, boost, overtakes) -> **shove** (knock a rival off its bike) -> **fly** (jumps with automatic tricks) -> **swap** (bike <-> hoverboard at gates) -> **finish** (cup or ribbon, time vs your ghost) -> race again, or stop at the card.

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
| Home disc / Android back | Top-left | Stand-alone: same guard as the gear; the second tap leaves to the world page. In the shell the shell owns this. |
| App to background | | Pause. On return, a 240 px "play" disc in the centre resumes on release. |
| Card buttons | Card | Section 10.3. |

Holdover filter: ignore all touches for 300 ms after any screen change (rule 8), so the finger that tapped "replay" does not instantly steer.

## 4. Riding model (how the builder simulates it)

The track is a `Path3D` centre line. Every rider is simulated in track space: **s** = metres along the centre line, **x** = metres sideways from it (left negative), **h** = height above the track surface (0 unless airborne). The world position comes from the curve's transform at s, offset by x and h. Curves never push a rider sideways: holding nothing keeps you on your line (my call: this is what makes "hold nothing and still finish" safe).

### 4.1 Speed

- Every rider has a speed v along s. Each frame: `target = CRUISE * section_mult * vehicle_mult * product(active effects) * (AI: skill * rubber band)`. v moves toward target at `ACCEL_UP` when below, `ACCEL_DOWN` when above.
- Speed floor after the start: `v >= MIN_SPEED_FRAC * CRUISE` (18 m/s). Nothing in the game can stop the player, so a race always ends (worst case 1425 / 18 = 79 s, my calc). The only exception to the floor is a knocked-off rival during its fall, lie-down, get-up and rejoin (4.7); the floor applies to it again once it is back to 0.9 of its target speed.
- **Cruise is 30 m/s** (108 km/h; owner 18:27: "go faster, action speed"; was 20 m/s). All effects together are capped at `SPEED_MULT_CAP` x1.6 = **48 m/s** top speed (my call: keeps jumps, landing zones and reaction distances bounded).
- Effects multiply and each has its own timer. The same effect again refreshes its timer instead of stacking, except pad chains (4.4).

### 4.2 Steering

- Holding a side: lateral velocity eases toward `+-STEER_LAT_MAX` (6.0 m/s; hoverboard x1.10; was 5.0) over `STEER_EASE_S` (0.12 s).
- Release: lateral velocity eases to 0 over `STEER_RELEASE_S` (0.15 s).
- Airborne: steering works at `AIR_STEER_FRAC` (50%).
- Visual lean: roll = `lat_v / STEER_LAT_MAX * LEAN_MAX_DEG` (18 deg), smoothed over 0.1 s.
- **Track edges are soft rails** (fences, snow banks, rock walls): x is clamped to `+-(width/2 - RIDER_RADIUS)`. While touching a rail: speed x`RAIL_MULT` (Lett 0.97, Vanlig 0.92), dust puffs, a soft scrape loop. Never a stop, never a bounce-back the child has to fight.

### 4.3 Lett auto-steer (kid-easy assist)

- Each track has a hand-placed **kid line** `x_kid(s)` (a `Curve` sampled by s) that runs over about half of the pads and around every hay bale.
- Lett only: when no steer pointer is down and `ASSIST_RESUME_S` (0.6 s) has passed since release, the rider steers toward `x_kid(s)` at up to `ASSIST_LAT_MAX` (3.0 m/s), easing over 0.3 s. Kid-line changes are drawn as ramps of at least 30 m per 3 m of sideways change, so the assist can always follow them at 30 m/s. Touching always overrides it at once.
- Vanlig: no assist; holding nothing rides straight along the current x.

### 4.4 Speed pads

- Pad: a 3 m wide x 6 m long glowing plate (6 m keeps 0.2 s on the pad at 30 m/s). Triggered when the rider's centre x is inside the pad's width while crossing its s range (forgiving: rider radius counts, so effective width 4 m).
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

### 4.7 Bumps and knock-offs (owner change 2026-10-06 12:42)

The player can **knock a rival off**: the rival falls, lies down briefly, gets up and rejoins. Rivals can only **nudge** the player sideways; **the player never falls and is never slowed by contact**.

**Contact:** riders are circles of `RIDER_RADIUS` 0.5 m. Contact when `|dx| < BUMP_DX_M` (1.0) and `|ds| < BUMP_DS_M` (1.4). Same pair cannot make contact again for `BUMP_PAIR_COOLDOWN_S` (1.0 s). Each contact is resolved as exactly one of these, checked in this order:

1. **Knock-off (player hits rival).** All must be true:
   - side contact: `|ds| < KNOCK_DS_M` (1.0 m), so the two are roughly side by side, not nose to tail;
   - the player's own lateral speed **toward** the rival is at least `KNOCK_LAT_MIN` (Lett 1.2 m/s, Vanlig 1.8 m/s). Full steer is 6.0 m/s, so holding toward a rival always qualifies; Lett auto-steer (3.0 m/s) can also do it by accident, which is fine. The rival's own lean-in never counts;
   - both on the ground (contacts in the air are plain nudges);
   - the rival is not immune (`KNOCK_IMMUNE_S`, 6 s after it is riding again; no visible marker, a contact with an immune rival is a plain nudge).

   When true, it **always** knocks off (no dice roll; the child must be able to learn it). The player keeps full speed and gets no push.
2. **Rival hits player, or a player contact that does not qualify.** The player gets a **nudge**: pushed sideways away from the rival at `NUDGE_PUSH_MPS` (3.0 m/s) for `NUDGE_PUSH_S` (0.25 s), then **auto-recentres**: steers back to the x it had before the nudge at `RECENTRE_LAT_MPS` (2.4 m/s), for at most `RECENTRE_MAX_S` (1.0 s), cancelled the moment the player touches a steer zone. No speed change. In Lett the kid-line assist then resumes as usual. The rival gets the old bump: pushed the other way at `BUMP_PUSH_MPS` 3.6 m/s for 0.2 s and wobbles for `BUMP_TIME_S` 0.5 s at speed x`BUMP_MULT_AI` 0.90.
3. **Rival hits rival:** both pushed apart at 3.6 m/s for 0.2 s, both wobble 0.5 s at x0.90. Rivals never knock each other off.

**The fall (rival), in time from the hit:**

| Time | What happens |
|---|---|
| 0-0.5 s | Bike (or board) tips over to the side away from the player; rider and vehicle slide toward the nearest rail at `FALL_SLIDE_LAT_MPS` (3 m/s) while slowing at `FALL_DECEL` (60 m/s^2, so from 30 m/s to a stop in 0.5 s). The fallen rival has **no collision** from the hit until it rides again, so nobody piles into it. |
| 0.5-1.2 s | Lies on the ground by the rail (`FALL_DOWN_S` 1.2 s from the hit). |
| 1.2-1.7 s | Gets up, lifts the bike, remounts (`GETUP_S` 0.5 s). Unhurt: no limp, no pain sound. |
| 1.7 s on | Rejoins: accelerates at `REJOIN_ACCEL` (15 m/s^2) back to its target speed and steers back to its line at the normal AI lateral speed. |

Time lost by the rival is about 3 s (my calc: about 1.7 s stopped or nearly stopped, plus half of the 0.5 s slow-down and half of the 2 s re-acceleration), which is enough to drop it to the back of a 3-5 s pack.

**Rubber band while fallen:** a rival that is falling, lying, getting up or rejoining is **left out of the rubber band** until its speed is back to `REJOIN_RB_OFF_FRAC` (0.9) of its target. After that the normal band applies (in Lett the +4% catch-up slowly brings it back to the pack, so races stay close).

**Rivals pushing back (competitive tone):** in Vanlig, a rival riding beside the player (`|ds| < 1.0`, `|dx| < 2.0`) rolls `RIVAL_LEAN_IN_V` (0.25) every `RIVAL_LEAN_IN_EVERY_S` (2.0 s) to lean 1.0 m toward the player, which causes nudges. In Lett rivals never lean in (`RIVAL_LEAN_IN_L` 0). No rival ever blocks the finish or rams from behind on purpose.

No skull, no "out" word, no mocking popup: the knocked-off rival gets a small tumbling-bike icon for 500 ms (section 11).

### 4.8 Hindrances (owner 13:05: they slow or nudge, they NEVER make anyone fall)

Every world's hindrances are built from four generic types, so the builder writes four behaviours and each world only places them with its own model and effect. Only the player can knock someone off (4.7); no hindrance ever does.

| Type | Behaviour | Slice uses | Later worlds use |
|---|---|---|---|
| **Block** (static, burst) | Rider passes straight through; the object bursts or tips away; speed x`mult` for `time` | W1 hay bales (x`HAY_MULT` 0.85, 0.5 s) | W5 fallen-branch piles, W6 traffic cones |
| **Patch** (area on the ground) | While the rider's centre is inside: speed x`mult`, and/or a steering change. Optional `hover_immune`: the hoverboard floats over it | W1 mud puddles (x`MUD_MULT` 0.90, bike and board), W2 sand drifts (x`SAND_MULT` Lett 0.94 / Vanlig 0.88, **hoverboard floats over**) | W3 ice (no slow, slide), W3 snow drifts, W4 ash, W5 river ford (board immune), W6 wet steel (slide) |
| **Roller** (moving across the track) | Spawns at one rail when the player is `ROLLER_TRIGGER_M` (60 m, 2 s at cruise) before its s, rolls across at `ROLLER_LAT_MPS` (Lett 2.0, Vanlig 3.0 m/s), leaves at the other rail. Contact: the rider gets a **nudge** sideways in the roller's direction (`ROLLER_NUDGE_MPS` 2.0 m/s for 0.25 s), no speed loss; the player auto-recentres as in 4.7. The roller bursts (tumbleweed) or bounces off the rail and is gone | W2 tumbleweeds | W3 snow slough, W4 small falling rocks, W6 empty cable spools |
| **Hop** (low object across the track) | A mini-kicker: 0.4 s of air, no trick, no slow | none | W5 logs, W4 lava-crust ridges |

Lett kid lines route around every Block and Patch; Rollers are not dodged by the kid line (they only nudge, which is harmless and funny). AI avoid Blocks and Patches with `AI_HAY_AVOID` 0.8 and ignore Rollers.

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
| Hay bale (W1) | Round bale, straw texture | 4.8 Block | feel 18 |
| Mud puddle (W1) | Dark wet patch with ruts, splashes | 4.8 Patch | owner 13:05 |
| Sand drift (W2) | Pale ridged sand tongue across the hard-pack | 4.8 Patch, board floats over | owner 13:05 |
| Tumbleweed (W2) | Rolling ball of dry brush, about 1.2 m | 4.8 Roller | owner 13:05 |
| Rail | Low wooden fence (forest), rock (tunnel) | 4.2 | feel 17 |
| Finish gate | Wide arch with a chequered banner (no text) | Section 10.2 | feel 20 |

## 6. Worlds (owner 13:05: every level is a different world)

Each level is its own realistic world: its own look, weather effects, jumps, hindrances and landmarks. The next level is **never** the same track again. Cruise speed is 30 m/s everywhere (owner 18:27); worlds get a little longer, never faster. Every distance was scaled x1.5 from the 20 m/s design so all timings (seconds between pads, jumps, hindrances) stay the same. Weather is one GPU particle emitter (<= 600 particles, my call for the phone budget) plus depth fog; no volumetrics, no real-time reflections.

### 6.0 The six worlds

| # | World (NO / EN) | Setting (realistic) | Length / time | Signature jump or feature | Hindrances (slow or nudge, never a fall) | Weather / particles | Landmarks and objects | Teaches |
|---|---|---|---|---|---|---|---|---|
| 1 | **Furuløypa / Pine Run** | Alpine pine forest, summer afternoon | 1425 m / ~44 s (sim) | **Gully plank jump** (K3, 1.6 s air) | Hay bales (Block), mud puddles (Patch) | Sun shafts through pines, drifting pollen, falling needles | Log cabin, wooden river bridge, rock tunnel, farm fences, cowbell meadow at the finish | Steer, pads, boost, jumps, swap gates, knocking rivals off |
| 2 | **Ørkenjuvet / Red Canyon** | Desert canyon, red sandstone, hard midday sun | 1470 m / ~45 s (sim) | **Mesa gap**: jump across a dry gorge between two mesas (K3, 1.8 s air, the longest yet) | Sand drifts (Patch; the board floats over), tumbleweeds (Roller) | Blowing sand streaks, dust devils in the distance, heat haze as a cheap fog tint | Sandstone arch, old highway on the rim, rusty water tower, abandoned gas station, mining-town street finish | **Moving hindrances** (tumbleweeds) and that the board beats sand |
| 3 | **Isbreen / Glacier Run** | Snowy glacier under a pale blue sky | 1500 m / ~46 s (est.) | **Ice-cave exit**: ride through a blue ice cave and launch out over a crevasse (1.6 s) | Ice patches (Patch: no slow, steering slides: lateral speed x1.3, ease x2), snow drifts (Patch x0.90), snow slough (Roller) | Light snowfall, spindrift off ridges, sun glare sprite | Glacier hut, crevasse ladder-bridge, flag poles, snow-cat tracks, blue seracs | **Slippery steering** on ice |
| 4 | **Askefjellet / Ash Mountain** | Volcanic slope, black ash, cooled lava fields, dim orange light | 1470 m / ~46 s (est.) | **Steam vent launch**: a vent puffs every 2 s; ride over it while it puffs for a 1.4 s jump (miss it and you just ride on) | Ash dunes (Patch x0.88, board floats), small falling rocks (Roller from the uphill side), lava-crust ridges (Hop) | Falling ash flakes, ember sparks, smoke haze; lava glows only behind rails, never on the track | Smoking crater cone, basalt columns, research station, cooled lava rivers | **Timed launch** (first jump the rider must aim at) |
| 5 | **Regnskogen / Rainforest** | Tropical rainforest, after rain | 1500 m / ~46 s (est.) | **Waterfall drop**: launch off a waterfall lip into the pool below (1.8 s), splash | River ford (Patch x0.85 on the bike, board immune), logs (Hop), fallen-branch piles (Block) | Rain drops, mist, waterfall spray, a few butterflies | Waterfall, rope suspension bridge, giant buttress roots, moss-covered stone ruins | **Split path**: bridge route (narrow, 1 pad) or ford route (wide, 3 pads but the ford slows the bike); equal length |
| 6 | **Nattehavna / Night Harbour** | Industrial port at night | 1575 m / ~48 s (est.) | **Crane jump**: ramp off a container stack, through a gantry crane, over the water channel (2.0 s) | Wet steel plates (Patch, slide like ice), traffic cones (Block x0.95), rolling cable spools (Roller) | Light drizzle, sodium-lamp glow sprites, crane warning lights (slow blink, under 1 Hz) | Container stacks, gantry cranes, moored ferry, warehouses, a lit bridge in the distance | **Air rings**: fly through a ring over a jump for +1 s of x1.25 speed (uses air steering) |

Times for worlds 1-2 come from `tools/pack_sim.py` (my calc); worlds 3-6 are estimates from length / cruise, to be simulated once their section tables exist. Spacing rules at 30 m/s (my call): any two hindrances >= 45 m apart (1.5 s), two in the same lane >= 90 m apart; nothing in a landing zone (6.3) or in the 30 m after it; every hindrance visible from >= 60 m (1.25 s at the 48 m/s cap, so >= 1.2 s reaction in Lett, owner 18:27): no blind crest, tunnel mouth or bend hides one closer than that. Flash rule (rule 37) holds everywhere: crane lights, embers and lightning-free weather only.

### 6.1 World 1, slice: "Furuløypa / Pine Run"

Alpine pine forest trail on a summer afternoon (graphic-designer owns the look). Length **1425 m** to the finish line, plus a 90 m run-out. Target times at 30 m/s (my calc, `tools/pack_sim.py 150 1`): idle Lett child 43.2-43.7 s, average 43.7-44.4 s, skilled 41.8-42.3 s, idle Vanlig rider 46.8-47.7 s. Same as at 20 m/s, because every distance scaled with the speed.

### 6.1.1 Section table (s in metres from the start line; x in metres, + = right)

| s from-to | Section | Surface / vehicle | Width | Cruise mult | Contents | Kid line x |
|---|---|---|---|---|---|---|
| -23-0 | Start grid | Dirt | 12 | - | 5 AI ahead of the player (section 7.1) | 0 |
| 0-60 | Start drop | Dirt / bike | 12 -> 10 | 1.00 | Downhill out of the start gate | 0 |
| 60-270 | Skogsstien (forest path) | Dirt / bike | 10 | 1.00 | Long S-bend (radius 90 m left, then right). **P1** pad s 180, x 0. **M1** mud puddle s 225-240, x +2 to +4.5 | 0 |
| 270 | **K1** log kicker | Dirt | 10 | | Air **1.0 s**, lands s 285-323 (6.3) | 0 |
| 270-450 | Pine slope | Dirt / bike | 10 | 1.00 | **P2** s 345, x -3. **H1** hay s 390, x +2.5 | 0 |
| 450 | **Gate G1** | | 10 | | Bike -> hoverboard (after unlock) | 0 |
| 450-900 | Elvevegen (river road) | Smooth gravel road + boardwalk / hoverboard | 10 | 1.00 (hover x1.06) | **Chain P3-P5** s 510, 528, 546, x +2.5. **K2** bridge hump s 645, air **1.2 s**, lands 664-708. **P6** s 735, x -3. **H2** hay s 780, x -0.5 (in the straight-line path on purpose). Rock tunnel s 810-870, width 8 (H2 sits 30 m before the mouth, visible from 100 m) | +2.5 at 495-563, 0 to 743, +1.8 at 750-810, 0 after |
| 900 | **Gate G2** | | 10 | | Hoverboard -> bike | 0 |
| 900-1320 | Bratthenget (steep slope) | Dirt + plank ramp / bike | 9 (7 at 1080-1155) | 1.05 | **H3** s 975, x +2 (moved from -2 so it shares no lane with M2). **M2** mud s 1028-1043, x -4 to -1.5. **P7** s 1050, x +3. Fences narrow the track to the plank ramp. **K3 gully jump** s 1140, air **1.6 s**, lands 1166-1222 (hero jump). **Chain P8-P10** s 1230, 1248, 1266, x -3 (moved past the landing zone). **H4** s 1300, x +1.5 | +3 at 1028-1073, 0 after (at s 1300 the kid line x 0 clears H4: bale edge +0.7, rider edge +0.5) |
| 1320-1425 | Finish meadow | Grass / bike | 12 | 1.00 | **K4** finish hill s 1350, air **1.0 s**, lands 1365-1403. Finish gate s 1425 | 0 |
| 1425-1515 | Run-out | Grass | 12 | target 0.5 | Riders coast; finish shot plays here | 0 |

Counts: 10 pads (2 chains of 3), 4 kickers (one every ~11 s, feel 12), 4 hay bales, 2 mud puddles, 2 swap gates. The kid line hits 5 of 10 pads (P1, P3, P4, P5, P7) and no hindrance. A straight idle Vanlig rider hits P1 and H2.

Elevation hint for the level builder: about 180 m total drop, steepest in Bratthenget; the camera must see >= 60 m of track ahead everywhere (120 m on straights), so no blind crests except the K3 lip, and nothing is placed in the 60 m after that lip except the landing slope.

### 6.2 World 2, slice: "Ørkenjuvet / Red Canyon"

Desert canyon of red sandstone under a hard midday sun. Length **1470 m** plus a 90 m run-out. Same pad count, kicker count and gate count as world 1 so the owner sees the **world** change, not a difficulty spike. Target times at 30 m/s (my calc, `tools/pack_sim.py 150 2`): idle Lett child 44.3-45.2 s, average 44.7-45.5 s, skilled 42.9-43.6 s, idle Vanlig rider 48.3-49.3 s.

| s from-to | Section | Surface / vehicle | Width | Cruise mult | Contents | Kid line x |
|---|---|---|---|---|---|---|
| -23-0 | Start grid | Red dirt by a rusty water tower | 12 | - | Same grid as world 1 | 0 |
| 0-90 | Canyon drop | Red dirt / bike | 12 -> 10 | 1.00 | Steep drop between rock walls | 0 |
| 90-330 | Tørrelva (dry wash) | Packed sand / bike | 10 | 1.00 | **P1** s 165, x 0. **D1** sand drift s 225-248, x -3 to +0.5. **K1** rock lip s 300, air **1.0 s**, lands 315-353 | 0; +2 at 195-255 |
| 330-450 | Slot canyon | Sandstone / bike | 8 | 1.00 | Narrow, high walls, light from above. **T1** tumbleweed rolls left -> right, centred on s 390. **P2** s 428, x +2 | 0 |
| 450 | **Gate G1** | | 10 | | Bike -> hoverboard | 0 |
| 450-930 | Gamleveien (old rim highway) | Cracked asphalt / hoverboard | 11 | 1.00 (hover x1.06) | Canyon drop-off on the left behind a rail. **Chain P3-P5** s 525, 543, 561, x -2.5. **T2** s 600 (right -> left) and **T3** s 660 (left -> right). **K2** culvert hump s 720, air **1.2 s**, lands 739-783. **P6** s 810, x +3. Abandoned gas station s 840. **D2** sand drift s 870-893, x -1 to +3.5 (the board floats over it; on the bike in race 1 it slows) | -2.5 at 495-590, 0 after; -2.5 at 840-900 |
| 930 | **Gate G2** | | 10 | | Hoverboard -> bike | 0 |
| 930-1350 | Mesakanten (mesa switchbacks) | Red dirt / bike | 9 (8 at 1140-1170) | 1.05 | **P7** s 1005, x -3. **T4** s 1080 (right -> left). **K3 Mesa gap** s 1170: the track narrows to an 8 m lip and jumps a dry gorge (visible gap at most 26 m, 6.3) to the next mesa, air **1.8 s**, lands 1199-1261 (signature, camera keeps 1.0 m extra height lag). **Chain P8-P10** s 1275, 1293, 1311, x +3 on the run-out of the landing. **D3** sand drift s 1330-1352, x -3.5 to 0 | -3 at 975-1035, 0 after; +1.5 at 1315-1365 |
| 1350-1470 | Mining-town street | Hard dirt between wooden fronts / bike | 12 | 1.00 | **K4** wooden loading-ramp s 1395, air **0.8 s** (no bonus), lands 1406-1438. Finish gate s 1470 under a water tower | 0 |
| 1470-1560 | Run-out | Dirt | 12 | target 0.5 | Finish shot | 0 |

Counts: 10 pads (2 chains of 3), 4 kickers, 3 sand drifts, 4 tumbleweeds, 2 swap gates. Kid line hits P1, P3-P5, P7 (5 of 10) and no drift. A straight idle Vanlig rider hits P1 and all three drifts (D2 only on the bike). Elevation hint: about 210 m total drop; the mesa gap lands 9 m lower than it takes off.

### 6.3 Jumps at 30 m/s (airtimes unchanged; distances recomputed, my calc)

Launch `vy = GRAVITY * air / 2` (`GRAVITY` 22 m/s^2) is unchanged, so apex heights are the same as before. Flight distance = speed x air. Speeds: floor 18 m/s, cruise 30 m/s, cap 48 m/s. The **landing slope** runs from `lip + 18*air - 3` to `lip + 48*air + 5` m, so every rider at any legal speed lands on it. A visible gap (gully, gorge, water) is at most `18*air - 6` m wide, so even the slowest rider visibly clears it.

| World | Kicker | Lip s | Air | Apex | Flight at 18 / 30 / 48 m/s | Landing slope s | Max visible gap |
|---|---|---|---|---|---|---|---|
| 1 | K1 log | 270 | 1.0 s | 2.8 m | 18 / 30 / 48 m | 285-323 | 12 m |
| 1 | K2 bridge hump | 645 | 1.2 s | 4.0 m | 22 / 36 / 58 m | 664-708 | 16 m |
| 1 | K3 gully plank | 1140 | 1.6 s | 7.0 m | 29 / 48 / 77 m | 1166-1222 | 23 m |
| 1 | K4 finish hill | 1350 | 1.0 s | 2.8 m | 18 / 30 / 48 m | 1365-1403 | 12 m |
| 2 | K1 rock lip | 300 | 1.0 s | 2.8 m | 18 / 30 / 48 m | 315-353 | 12 m |
| 2 | K2 culvert | 720 | 1.2 s | 4.0 m | 22 / 36 / 58 m | 739-783 | 16 m |
| 2 | K3 mesa gap | 1170 | 1.8 s | 8.9 m | 32 / 54 / 86 m | 1199-1261 | 26 m |
| 2 | K4 loading ramp | 1395 | 0.8 s | 1.8 m | 14 / 24 / 38 m | 1406-1438 | 8 m |

In the track-space model the landing is simply `h` returning to 0 over a virtual surface, so a gap is pure scenery; these limits only make sure the scenery never shows a rider "landing in the gorge".

### 6.4 Worlds 3-6 (full game)

Built after the slice, each with its own section table in the same format, 10 pads, 4 kickers including the signature, 2 swap gates and the hindrances from table 6.0. Each world adds exactly one new mechanic (table 6.0, last column); world 5's split path is the only layout change. Section tables are game-designer work for the next pass.

## 7. AI pack

### 7.1 Riders

5 AI riders, each told apart by **helmet shape icon + colour** (rule 36): Star, Moon, Leaf, Drop, Triangle. A small icon floats above each rider; the player has a big down-arrow chevron. No names, no text tags (owner: icons not text).

| Slot | Icon | Lett skill | Vanlig skill | Pad seek Lett / Vanlig | Lane offset | Start s |
|---|---|---|---|---|---|---|
| 0 | Leaf | 0.93 | 0.90 | 0.20 / 0.30 | -3 | 4.5 |
| 1 | Drop | 0.95 | 0.92 | 0.25 / 0.35 | +3 | 9 |
| 2 | Triangle | 0.97 | 0.94 | 0.30 / 0.40 | -1.5 | 13.5 |
| 3 | Moon | 0.99 | 0.96 | 0.35 / 0.45 | +1.5 | 18 |
| 4 | Star | 1.01 | 0.98 | 0.40 / 0.50 | 0 | 22.5 |

The player starts last at s 0, x 0 (feel 3). The fastest AI starts at the front.

### 7.2 Behaviour per frame

1. **Line:** lateral target = `x_kid(s) + lane_offset`, clamped inside the rails.
2. **Pads:** 45 m before each pad, roll once against `pad_seek`; on success the lateral target becomes the pad's x until the pad is passed.
3. **Hay and patches:** 38 m before one in its path, roll 0.8 to swerve 2 m to the more open side.
4. **Traffic:** if another rider is within 4.5 m ahead and `|dx| < 1.2`, roll 0.7 to shift 1.5 m to the more open side (the failed rolls make the natural bumps). Fallen rivals are not traffic (no collision).
5. **Boost:** when its meter is full, fires after a random 0.5-3.0 s.
6. **Lateral speed:** 4.8 m/s max, 0.2 s ease (slightly calmer than the player).
7. **Contact with the player:** Lett: never aims at the player. Vanlig: leans in now and then (4.7, "Rivals pushing back"); the player is only ever nudged. Never blocks on purpose.
8. **Knocked off:** follows the fall table in 4.7, then resumes from step 1.

### 7.3 Rubber-banding (visible, fair, symmetric caps; feel 5)

`gap = ai.s - player.s` (metres), `k = min(1, |gap| / RB_RANGE_M)` with `RB_RANGE_M` 45 (the same 1.5 s time gap as before at the new speed).

- AI ahead of the player (`gap > 0`): speed x `(1 - RB_AHEAD * k * fade)`.
- AI behind the player (`gap < 0`): speed x `(1 + RB_BEHIND * k * fade)`.
- `fade` = 1 until the player's progress reaches `RB_FADE_FROM`, then drops linearly to 0 over the next 10% of the track.
- Clamp the AI's total multiplier to 0.80-1.50. After the player finishes, AI run on skill alone.
- A knocked-off rival is left out of the band until it is back to 0.9 of its target speed (4.7).

| | Lett | Vanlig |
|---|---|---|
| `RB_AHEAD` | 0.08 | 0.05 |
| `RB_BEHIND` | 0.04 | 0.03 |
| `RB_FADE_FROM` | never (1.1) | 0.40 (fully off at 0.50) |

Why: in Lett the pack waits for a child all race. In Vanlig it keeps the first half close and exciting, then lets go so skill decides the end.

### 7.4 Expected results at 30 m/s with knock-offs (my calc, `tools/pack_sim.py`, 150 runs each, 1D model; tune again on the phone)

| Player | Mode | World | Time (bike / board) | Places | Wins | Top 3 | Knock-offs per race | Gap |
|---|---|---|---|---|---|---|---|---|
| Holds nothing (4-year-old) | Lett | 1 | 43.7 / 43.2 s | 1st 19-51%, 2nd 47-70%, 3rd 1-10% | 19-51% | **100%** | 0.6-0.7 | 0.2-0.3 s behind the winner (median when not 1st) |
| Holds nothing | Lett | 2 | 45.2 / 44.3 s | 1st 38-50%, 2nd 46-58%, 3rd 2-4% | 38-50% | **100%** | 0.7 | 0.2-0.3 s |
| Steers at random (half the pads, 40% of hindrances) | Lett | 1 / 2 | 43.7-45.5 s | mostly 1st-2nd | 44-55% | 98-100% | 1.9-2.0 | 0.3-0.4 s |
| Skilled (all pads, instant boost) | Lett | 1 / 2 | 41.8-43.6 s | 1st 99-100% | 99-100% | 100% | 3.3-3.5 | wins by 1.9-2.4 s |
| Holds nothing | Vanlig | 1 | 47.7 / 46.8 s | 4th 70-72%, 5th 28-29% | 0% | 0% | 0 | 2.9 s behind |
| Holds nothing | Vanlig | 2 | 49.3 / 48.3 s | 4th 60-66%, 5th 32-39% | 0% | 0-2% | 0 | 3.0-3.1 s behind |
| Average | Vanlig | 1 / 2 | 43.7-45.5 s | 1st 63-81%, 2nd 18-35% | 63-81% | 100% | 1.9-2.0 | wins by 1.2-1.3 s |
| Skilled | Vanlig | 1 / 2 | 41.8-43.6 s | always 1st | 100% | 100% | 3.1-3.4 | **wins by 3.4-3.8 s** |

The new 1.6x speed cap (48 m/s) trims the skilled player's best stacks slightly (41.8 s vs 40.9 s at 20 m/s scale); everything else matches the 20 m/s results within sampling noise, as expected from scaling distances, accelerations and the rubber-band range by 1.5.

The ranges are bike-only (race 1) vs hoverboard unlocked; in practice world 2 is always raced with the board unlocked. The 1D sim models a knock-off as a chance per pass that the player steers into the rival hard enough: holds nothing in Lett 10% (auto-steer drift), holds nothing in Vanlig 0%, average 30%, skilled 60%; immunity and the fall table as in 4.7. Rival nudges, tumbleweeds and Vanlig lean-in cost no speed, so they are not simulated. World 1 now models hindrance hits deterministically for the idle Vanlig rider (H2 only) instead of the old 25% guess, which moved the numbers slightly.

Before knock-offs (same sim, version 1 of this doc): Lett idle won 20-33% with top 3 at 99-100%; Vanlig average won about 46%; Vanlig skilled won by 2.2-2.3 s. Knock-offs help only the player, so every player type moves up. Owner targets still met: a child holding nothing finishes top 3 in Lett in 99-100% of runs in both slice worlds; a skilled player wins by a few seconds. Pack spread is now 3-6 s for normal play and 7-9 s when a skilled player knocks rivals down and escapes. If Vanlig turns out too easy on the phone, raise every `AI_SKILL_V` by 0.01 first (open question 8). Shortening the fall barely changes the results (sim: Vanlig average wins 65-67% at 0.6-0.8 s down vs 62% at 1.2 s), so keep the fall long enough to read.

## 8. Modes: Lett (4-7, default) vs Vanlig (8+)

| Aspect | Lett | Vanlig |
|---|---|---|
| Auto-steer to the kid line when not touching | yes (4.3) | no |
| Boost | auto after 2 s if not pressed | manual |
| Rail slowdown | x0.97 | x0.92 |
| AI skill | 0.93-1.01 | 0.90-0.98 |
| Rubber band | strong, never fades | mild, fades out at 40-50% |
| Race timer on HUD | hidden | small, top centre-right |
| Knock-off lateral speed threshold | 1.0 m/s | 1.5 m/s |
| Rivals lean in toward the player | never | 25% chance every 2 s when side by side |
| Same track, same speed, same knock-off and fall rules | yes | yes |

Rule 16 (no reflex demand at the easiest level) and rule 31 (no game over for 4-7) hold in both: nothing can stop or eliminate the player, and a knocked-off rival always gets up and finishes.

Where the setting lives: inside MWM Play the adapter calls `set_difficulty(easy: bool)` (same as Neon Bricks; parent-area row). Stand-alone: a two-icon segment (small rider / big rider) in the settings panel. Takes effect at the next race start.

## 9. Progression and unlocks (owner: by playing only)

### 9.1 Unlock order (owner 13:05: the next world opens on finishing the previous one, any place)

| When | Unlock | Notes |
|---|---|---|
| First finish of world 1 | **Hoverboard** (gates go live everywhere) **and world 2** | Owner. Two reveal cards in a row: board, then the world-2 picture |
| First finish of world N (N = 2-5) | **World N+1** | Any place counts, so a 4-year-old progresses as fast as a skilled player |
| 2 total finishes | Rider outfit 2 | Cosmetic |
| 4 total finishes | Hoverboard skin 2 | |
| 5 total finishes | Rider outfit 3 | |
| 7 total finishes | Bike skin 2 | |
| First 1st place in a world | That world's gold trim for the bike | 6 total, a nod to skill; never needed |

Replaying an old world is always allowed from the world page, but the card's biggest disc always points to the next new world while one is open (10.3), so "next level" is never the same track.

Not-yet-earned items are **not drawn at all** (no padlocks, no greyed tiles, rule 22 counter-consideration 1). Each new item arrives with one reveal card (2 s spin on a pedestal, one tap continues). No stat upgrades: they would break the fair pack (feel 24).

Garage (outfits and skins): one "garage" disc on the world page, opening a single screen with big 240 px swatch discs. Out of the slice.

### 9.2 Free part (MWM Play)

- The game holds `full_unlock: bool`, default `true`. Public hook `set_full_unlock(on: bool)` (owner), same style as Neon Bricks. The game never checks purchases itself.
- `full_unlock == false`: **world 1 only, bike + hoverboard, outfit 2** (the hoverboard still unlocks on the first finish). World 2+ and later cosmetics are never drawn, and the card shows no "next world" disc. From the first finish on, at most **once per app session**, the game emits `free_levels_finished` after the reward card closes; the shell then shows its "Du har spilt alle banene her" card. Replay keeps working forever.
- `full_unlock == true`: all 6 worlds, each opening when the previous one is finished.
- The stand-alone build never calls the hook, so it is fully open (owner's own copy).

Free part size: 1 of 6 worlds, both vehicles. The shell card first shows after race 1 (about 1 minute); a child can keep replaying world 1 with its ghost (open question 11).

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
| Scene load | <= 2.0 s | Straight into world 1 on first ever launch (no menu). Later launches: straight into the newest open world not yet finished, else the last world played (my call; the world page is one home-tap away) |
| Pre-race | until touch, max `AUTO_START_S` (4.0 s; 3.0 s on first launch) | Rider on the start line, camera eases from a front 3/4 view to the chase view over 1.0 s. Two hand icons press the left and right halves in turn (loop 1.6 s) |
| Gate lights | `START_LIGHTS_S` 1.2 s | 3 lamps light 0.4 s apart with rising soft marimba blips, then the gate drops: GO |
| Racing | | |

Worst case about 9.2 s from icon tap to GO (my calc).

### 10.3 Finish and reward card (natural stopping point)

1. Player crosses the finish line (s 1425 in world 1, 1470 in world 2): HUD hides, camera drops low beside the finish gate for `FINISH_SHOT_S` (2.0 s), time scale 0.6 for the first 0.4 s, confetti (top 3 only; particles, no flashes). AI keep riding; any AI not finished within 4 s is placed by projected time (`remaining_s / v`) so the card never shows blanks.
2. Card fades in over 250 ms (instant under less motion). Contents, no text:
   - **Trophy by place:** 1st gold cup, 2nd silver cup, 3rd bronze cup, 4th-6th a "finish flag" rosette. Every finish gets one (rule 30). The player's rider stands on the podium for 1-3, beside it for 4-6.
   - **Time** in digits, 64 px.
   - **Ghost line:** ghost icon + green up-arrow and star burst if this run beat the saved best for this world ("new best"); ghost icon + the saved best time if not. First run in a world: no ghost line.
   - **Discs** at y 1420 (all >= 200 px, act on release): **home** (x 270, dia 200) to the world page. When a next world is open and not yet raced: **next world** (x 810, dia 240, the most visible, showing a small picture of that world) and **replay** (x 540, dia 200). Otherwise: **replay** (x 810, dia 240). After world 6: replay and home only.
3. Spoken praise of the action, when a voice exists (rule 32): "Du kom i mål!" ("You reached the finish!"), 1st: "Du vant løpet!" ("You won the race!"). Blocked on the native Norwegian voice (same as Neon Bricks).
4. Unlock reveal card (if any) after the first tap on any disc, then the chosen action.
5. **Never auto-advances** (rule 26). Emits `level_card_shown(track_id)` so the shell's play limit can end here.

What counts as a **win**: crossing the finish line in 1st place. Results that matter for saves: best place and best time per track, total finishes.

### 10.4 World page (stand-alone home, and the shell's "home inside the game")

Cards 440 x 380 in a 2-column grid from y 300, one per open world, each with its picture and its best trophy shape. Unopened worlds are not drawn. Garage disc bottom-right of the grid (above y 1664). Gear top-right. Slice: two cards once world 2 is open.

### 10.5 First 60 seconds (no text anywhere)

- 0 s: launch -> world 1 pre-race (10.2). Hand icons show "hold here or here".
- ~5-9 s: GO. In Lett, a child holding nothing rides the kid line and still passes riders.
- 7 s without touch during the race (rule 18): a hand icon pulses on the side toward the next pad for 2 s.
- ~10 s: boost meter full. Race 1 only: a hand taps the boost disc once; Lett auto-fires 2 s later anyway.
- ~9 s: first jump K1 with an automatic trick.
- ~44 s: finish, trophy card.
- Race 2 (the card's biggest disc): **world 2, Red Canyon**, a new place; gates come alive, slow-mo at G1 shows the swap. No ghost, because it is the first run there.

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

### 10.8 Ghost (owner: on by default, local, offline; reworked 13:05 after QA finding 1)

- **What it is:** your best run on THIS world, nothing else. One ghost per world, best time from either mode.
- **When it shows:** only when the player races a world they have finished before. **Never on a world's first run.** Never a ghost from another world.
- **Record:** the player's s, x, h and vehicle id at `GHOST_HZ` (10 Hz). On a new best time for that world, save it.
- **Fade near the player (QA finding 1: the ghost hid the child's own rider 40% of race 2):** `d = sqrt(ds^2 + dx^2)` between ghost and player. Opacity = `GHOST_ALPHA * clamp((d - GHOST_FADE_NEAR_M) / (GHOST_FADE_FAR_M - GHOST_FADE_NEAR_M), 0, 1)` with near 4 m and far 6 m: fully visible from 6 m, gone at 4 m and closer. Hide it entirely (not just alpha 0) under 4 m so it costs no draw.
- **Look:** translucent (max 40% opacity), cool white tint, no shadow, no collision, not counted in places, no icon on the progress bar (it is "you", not a rival).
- Uses the vehicle it rode at each moment (a pre-hoverboard ghost stays on the bike).
- Size: ~45 s x 10 Hz x 4 numbers = 1,800 numbers per world, about 12 KB of JSON (my calc).

### 10.9 Save (`user://mwm_race_riders_save.json`)

```json
{
  "version": 1,
  "finishes": 4,
  "hover_unlocked": true,
  "seen_first_swap": true,
  "worlds": {"1": {"best_time": 42.31, "best_place": 1, "won": true, "ghost": [[0.0, 0.0, 0.0, 0], [2.1, 0.0, 0.0, 0]]}},
  "cosmetics": {"outfit": 2, "bike": 1, "board": 1, "owned": ["outfit2", "board2"]},
  "last_world": 1,
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
| Speed above 25 m/s | Soft speed lines at screen edges (11.1), low contrast (rule 38), no strobing | Wind rises (11.1) | none | No lines |
| Pad hit | Pad flares once; 1/2/3 chevrons pop over the rider, 300 ms | Rising "whoosh-zap", pitch steps up per chain level | 10 ms | Chevrons only |
| Boost | FOV +8 (75 -> 83 at cruise) over 0.15 s, back over 0.4 s at the end; trail behind the vehicle; edge vignette tint | Turbo swell + sustained roar, 2.5 s | 20 ms | No FOV kick, trail only |
| Boost charged | Disc glow, 1 Hz pulse | Soft "ready" chime once | none | Static glow |
| Take-off | Camera keeps 1.0 m extra height lag so the jump looks big | Whoosh + wind drop | none | same |
| Trick | Animation 0.6 s | Short swish | none | same |
| Landing | Squash: scale y 0.80 / xz 1.10 in 0.08 s, spring back over 0.18 s; dust ring; camera dip 0.08 m for 0.15 s | Thump + suspension creak (bike) or soft hover "fwump" | 25 ms | No squash, no dip; dust stays |
| Big landing (>= 1.2 s air) | + star popup (icon, 400 ms) | + bright chime | 30 ms | Popup stays |
| Knock-off (player hits rival) | Rival tips over away from the player and slides to the rail (4.7 fall table); dust burst at the contact, 30 particles, 0.8 s; **camera shake** 0.10 m for 0.2 s, decaying; small tumbling-bike icon over the rival, 500 ms; place badge pops if the place changes | Hard shoulder thud + bike clatter + gravel skid (board: clack + scrape) | 35 ms | No shake, no dust; the fall itself stays (it is game information) |
| Rival gets up and rejoins | Sits up, lifts the vehicle, remounts, 0.5 s | Short pedal whirr / hover spin-up | none | same |
| Nudge (rival hits player) | Player sways 6 deg for 0.3 s and slides sideways 0.25 s, small side dust; then recentres | Soft side thud | 15 ms | No sway, no dust |
| Rival-rival bump | Both wobble: roll +-12 deg at 3 Hz, decaying over 0.5 s | Muted thud | none | No roll |
| Rail scrape | Dust puffs | Scrape loop | none | No dust |
| Hay bale | Straw burst, 20 particles, 0.6 s | Soft "pff" | 10 ms | Bale vanishes |
| Overtake | Tiny "+" sparkle over the passed rider, place badge pops 1.15x for 150 ms | Light "tick-up" blip | none | No pop |
| Swap gate | Light ring runs down the arch, vehicle morph 0.3 s | Shimmer + mechanical click-clack | 15 ms | Instant swap, ring only |
| Gate lights | 3 lamps | Three rising marimba blips, then a whoosh | none | same |
| Finish | Low camera, slow-mo 0.6x 0.4 s, confetti (top 3) | Crowd cheer + finish chime; music ducks 4 dB | 40 ms | No slow-mo, no confetti |
| Card | Fade 250 ms, trophy drops in with one bounce | Trophy "clink" sting | none | Instant |

**Camera** (feel 19, retuned for speed 18:27): chase offset (0, 1.8, 3.8) m behind and above (was 2.2 / 4.5: lower and closer so the ground rushes past), pitch -10 deg, FOV by speed (11.1); rider at about 62-72% of screen height, horizon about 30% from the top. Position follow rate 10/s, yaw follow 7/s, height follow 4/s (jumps feel tall). No camera roll ever (motion comfort, my call).

### 11.1 Speed feel (owner 18:27: "action speed, cool")

| Cue | Spec | Less motion |
|---|---|---|
| FOV | `fov = CAM_FOV_REST + (CAM_FOV_CRUISE - CAM_FOV_REST) * clamp(v / CRUISE, 0, 1) + CAM_FOV_BOOST_ADD * boost_blend`: 70 at a standstill, **75 at cruise**, **+8 on boost** (83). Smoothed 0.25 s, boost blend in 0.15 s, out 0.4 s | FOV fixed at 72 |
| Speed lines | Thin soft streaks in the outer 25% of the screen. Start at **25 m/s**, alpha ramps 0 -> 0.25 at 45 m/s; streak length grows with speed. Colour close to the background (low contrast, rule 38), random positions, never a regular stripe pattern | Off |
| Wind | Wind loop volume from -30 dB at 0 to -12 dB at 45 m/s, pitch 0.8 -> 1.3; a second high whistle layer fades in above 35 m/s and on boost | same (sound is not motion) |
| Roadside density | Close "streamer" props on both sides: grass tufts, rocks, marker poles, fence posts (W1), cacti, rocks, sign posts (W2), 1-3 m off the rail, **random spacing 3-6 m** (about 7 per second per side at cruise, irregular so it never flickers, rule 38). Mid props (trees, boulders) 4-15 m off the rail every 6-10 m. One MultiMesh per prop type per 100 m chunk, culled beyond 150 m, so the cost is a handful of draws | same |
| Ground rumble | On dirt, sand and planks only: camera position noise 0.02 m at 12 Hz, amplitude x(v / CRUISE), capped 0.03 m; off on asphalt, gravel road and on the hoverboard (it floats: smooth is the contrast) | Off |
| Motion blur | None (mobile renderer, cost); speed lines do the job | - |

These cues plus the 30 m/s cruise are the speed feel; nothing here changes game logic, so `tools/pack_sim.py` is unaffected by them.

**Flash safety:** global limiter, at most 3 bright flashes per second (rule 37, owner); a pad chain within 333 ms shows chevrons but only one flare. No full-screen flashes. Pad chevrons are static, they glow, they do not scroll.

**Music (owner):** `assets/music/race_riders_theme.ogg`, 92.6 min long (QA full decode, `docs/QA_SLICE_2026-10-06.md`; my earlier 18.7 min came from an ffprobe header estimate and was wrong). Starts at the first pre-race, loops, and keeps playing across races and cards (it does not restart each race). Sits at least 6 dB under effects. Credit line: "Music supplied by the game owner." No source details anywhere.

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

# Race (per-world lengths under Unlocks)
const TRACK1_LENGTH_M: float = 1425.0          # kept for the current build; = WORLD_LENGTH_M[0]
const RUNOUT_M: float = 60.0
const RIDER_COUNT: int = 6                     # player + 5 AI (owner)
const AI_START_GAP_M: float = 4.5              # AI at s 4.5, 9, 13.5, 18, 22.5; player at 0
const AI_LANE_OFFSETS: Array[float] = [-3.0, 3.0, -1.5, 1.5, 0.0]

# Speed
const CRUISE_MPS: float = 30.0                 # owner 18:27 (was 20)
const SPEED_MULT_CAP: float = 1.6              # all effects together, 48 m/s top
const ACCEL_UP: float = 10.5                   # m/s^2
const ACCEL_DOWN: float = 18.0
const MIN_SPEED_FRAC: float = 0.6              # never below 18 m/s after GO (except a fallen rival)
const STEEP_MULT: float = 1.05                 # Bratthenget section
const HOVER_SMOOTH_MULT: float = 1.06
const RUNOUT_MULT: float = 0.5

# Steering
const STEER_LAT_MAX: float = 6.0               # m/s
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
const ASSIST_LAT_MAX: float = 3.0              # m/s toward the kid line
const ASSIST_EASE_S: float = 0.3
const ASSIST_RESUME_S: float = 0.6
const AUTO_BOOST_S_L: float = 2.0              # Lett only; Vanlig = manual

# Pads
const PAD_W_M: float = 3.0
const PAD_L_M: float = 6.0
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
const KICKER_AIR_S: Array[float] = [1.0, 1.2, 1.6, 1.0]   # K1-K4, world 1
const KICKER_AIR_S_W2: Array[float] = [1.0, 1.2, 1.8, 0.8] # K1-K4, world 2 (K3 = mesa gap)
const TRICK_MIN_AIR_S: float = 0.8
const TRICK_TIME_S: float = 0.6
const LAND_BONUS_MIN_AIR_S: float = 1.2
const LAND_BONUS_MULT: float = 1.10
const LAND_BONUS_TIME_S: float = 0.8

# Bumps and obstacles
const BUMP_DX_M: float = 1.0
const BUMP_DS_M: float = 1.4
const BUMP_PUSH_MPS: float = 3.6
const BUMP_PUSH_S: float = 0.2
const BUMP_TIME_S: float = 0.5
const BUMP_MULT_PLAYER: float = 1.0           # owner 12:42: contact never slows the player
const BUMP_MULT_AI: float = 0.90
const BUMP_PAIR_COOLDOWN_S: float = 1.0

# Knock-offs (player hits rival) and nudges (rival hits player)
const KNOCK_DS_M: float = 1.0                  # side contact: |ds| below this
const KNOCK_LAT_MIN_L: float = 1.2             # player lateral speed toward rival, m/s
const KNOCK_LAT_MIN_V: float = 1.8
const KNOCK_IMMUNE_S: float = 6.0              # after the rival rides again
const FALL_DECEL: float = 60.0                 # m/s^2, 30 m/s to 0 in 0.5 s
const FALL_SLIDE_LAT_MPS: float = 3.0          # slides toward the nearest rail
const FALL_DOWN_S: float = 1.2                 # from the hit, incl. the slide
const GETUP_S: float = 0.5
const REJOIN_ACCEL: float = 15.0               # m/s^2
const REJOIN_RB_OFF_FRAC: float = 0.9          # no rubber band until v >= 0.9 x target
const NUDGE_PUSH_MPS: float = 3.0
const NUDGE_PUSH_S: float = 0.25
const RECENTRE_LAT_MPS: float = 2.4
const RECENTRE_MAX_S: float = 1.0
const RIVAL_LEAN_IN_L: float = 0.0
const RIVAL_LEAN_IN_V: float = 0.25            # chance per check when side by side
const RIVAL_LEAN_IN_EVERY_S: float = 2.0
const RIVAL_LEAN_IN_M: float = 1.0
const KNOCK_ICON_S: float = 0.5
const HAY_MULT: float = 0.85               # W1 Block
const HAY_TIME_S: float = 0.5
const MUD_MULT: float = 0.90               # W1 Patch, bike and board
const SAND_MULT_L: float = 0.94            # W2 Patch, hoverboard floats over
const SAND_MULT_V: float = 0.88
const ROLLER_TRIGGER_M: float = 60.0       # roller spawns when the player is this far before it
const ROLLER_LAT_MPS_L: float = 2.0
const ROLLER_LAT_MPS_V: float = 3.0
const ROLLER_DIAM_M: float = 1.2
const ROLLER_NUDGE_MPS: float = 2.0        # sideways, 0.25 s, no speed loss
const ROLLER_NUDGE_S: float = 0.25
const HOP_AIR_S: float = 0.4               # later worlds (logs, lava crust)
const HINDRANCE_MIN_GAP_M: float = 45.0        # any two; same lane 90
const HINDRANCE_SAME_LANE_GAP_M: float = 90.0
const HINDRANCE_VISIBLE_M: float = 60.0        # >= 1.2 s reaction at the 48 m/s cap
const LANDING_CLEAR_AFTER_M: float = 30.0
# Later worlds, not in the slice
const ICE_LAT_MULT: float = 1.3
const ICE_EASE_MULT: float = 2.0
const SNOW_MULT: float = 0.90
const ASH_MULT: float = 0.88
const VENT_PERIOD_S: float = 2.0
const VENT_AIR_S: float = 1.4
const FORD_MULT_BIKE: float = 0.85
const CONE_MULT: float = 0.95
const RING_MULT: float = 1.25
const RING_TIME_S: float = 1.0

# Swap gates
const SWAP_FX_S: float = 0.3
const FIRST_SWAP_TIMESCALE: float = 0.5
const FIRST_SWAP_SLOWMO_S: float = 0.6

# AI
const AI_SKILL_L: Array[float] = [0.93, 0.95, 0.97, 0.99, 1.01]
const AI_SKILL_V: Array[float] = [0.90, 0.92, 0.94, 0.96, 0.98]
const AI_PAD_SEEK_L: Array[float] = [0.20, 0.25, 0.30, 0.35, 0.40]
const AI_PAD_SEEK_V: Array[float] = [0.30, 0.35, 0.40, 0.45, 0.50]
const AI_PAD_LOOKAHEAD_M: float = 45.0
const AI_HAY_AVOID: float = 0.8
const AI_HAY_LOOKAHEAD_M: float = 38.0
const AI_TRAFFIC_AVOID: float = 0.7
const AI_LAT_MAX: float = 4.8
const AI_TRAFFIC_AHEAD_M: float = 4.5
const AI_LAT_EASE_S: float = 0.2
const AI_BOOST_DELAY_S: Vector2 = Vector2(0.5, 3.0)
const AI_MULT_CLAMP: Vector2 = Vector2(0.80, 1.50)
const RB_RANGE_M: float = 45.0
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
const CAM_OFFSET: Vector3 = Vector3(0.0, 1.8, 3.8)
const CAM_PITCH_DEG: float = -10.0
const CAM_FOV: float = 70.0                    # = CAM_FOV_REST, standstill
const CAM_FOV_CRUISE: float = 75.0
const CAM_FOV_BOOST_ADD: float = 8.0
const CAM_FOV_LESS_MOTION: float = 72.0
const CAM_FOV_BOOST: float = 83.0              # cruise 75 + 8
const CAM_FOV_IN_S: float = 0.15
const CAM_FOV_OUT_S: float = 0.4
const CAM_FOLLOW_POS: float = 10.0
const CAM_FOLLOW_YAW: float = 7.0
const CAM_FOLLOW_HEIGHT: float = 4.0
const SPEED_LINES_FROM_MPS: float = 25.0
const SPEED_LINES_FULL_MPS: float = 45.0
const WIND_DB: Vector2 = Vector2(-30.0, -12.0)  # at 0 and at 45 m/s
const WIND_PITCH: Vector2 = Vector2(0.8, 1.3)
const RUMBLE_M: float = 0.02                   # dirt/sand/planks, x v/cruise, cap 0.03
const RUMBLE_HZ: float = 12.0
const PROP_NEAR_SPACING_M: Vector2 = Vector2(3.0, 6.0)   # random, both sides
const PROP_MID_SPACING_M: Vector2 = Vector2(6.0, 10.0)
const PROP_CULL_M: float = 150.0
const SPEED_LINES_ALPHA_MAX: float = 0.25

# Feel
const LAND_SQUASH: Vector2 = Vector2(1.10, 0.80)   # xz, y
const LAND_SQUASH_IN_S: float = 0.08
const LAND_SQUASH_OUT_S: float = 0.18
const WOBBLE_DEG: float = 12.0
const WOBBLE_HZ: float = 3.0
const NUDGE_SWAY_DEG: float = 6.0
const NUDGE_SWAY_S: float = 0.3
const KNOCK_SHAKE_M: float = 0.10
const KNOCK_SHAKE_S: float = 0.2
const KNOCK_DUST_PARTICLES: int = 30
const KNOCK_DUST_S: float = 0.8
const HOVER_HEIGHT_M: float = 0.3
const HOVER_BOB_M: float = 0.05
const HOVER_BOB_HZ: float = 1.5
const MAX_FLASHES_PER_S: int = 3

# Ghost
const GHOST_HZ: int = 10
const GHOST_ALPHA: float = 0.4
const GHOST_DEFAULT_ON: bool = true
const GHOST_FADE_NEAR_M: float = 4.0       # hidden at or under this distance to the player
const GHOST_FADE_FAR_M: float = 6.0        # full GHOST_ALPHA from here

# Unlocks (total finishes)
const UNLOCK_HOVER: int = 1
const WORLD_COUNT: int = 6
const WORLD_LENGTH_M: Array[float] = [1425.0, 1470.0, 1500.0, 1470.0, 1500.0, 1575.0]
# World N+1 opens on the first finish of world N (any place).
const FREE_WORLDS: int = 1
const FREE_CARD_FROM_FINISH: int = 1           # at most once per app session

# Audio
const SFX_VOL_DEFAULT: int = 80
const MUSIC_VOL_DEFAULT: int = 60
const MUSIC_UNDER_SFX_DB: float = -6.0
const FINISH_DUCK_DB: float = -4.0
```

## 14. Vertical slice scope (what godot-android-dev builds first)

In:
1. **World 1 Furuløypa** exactly as in 6.1 (Path3D, widths, 10 pads, 4 kickers, 4 hay bales, 2 mud puddles, 2 swap gates, finish gate, run-out, kid line curve) and **world 2 Ørkenjuvet** exactly as in 6.2 (10 pads, 4 kickers incl. the mesa gap, 3 sand drifts, 4 tumbleweeds, gas station, water tower), each with its own sky, light, fog colour and one weather emitter (pollen vs blowing sand). The owner must see the world change.
1b. Hindrance types Block, Patch (with `hover_immune`) and Roller (4.8); Hop can wait.
2. Rider in track space (section 4): steering by half-screen hold, latest touch wins, soft rails, speed model, pads with chains, boost disc + meter, jumps with automatic tricks (one animation per vehicle is enough), landing squash and bonus, hay, and contact per 4.7: player knock-offs with the rival fall/get-up/rejoin, nudge + auto-recentre on the player, rival-rival wobble, Vanlig lean-in.
3. Bike + hoverboard, dormant gates in race 1, live gates after the first finish, reveal card, first-swap slow-mo.
4. 5 AI with section 7 behaviour and rubber band, both modes.
5. Lett / Vanlig, auto-steer and auto-boost in Lett.
6. Pre-race hold-to-start + auto-start + gate lights; finish shot; reward card with trophy, time, ghost line, home + replay discs.
7. Ghost record, save and playback, on by default.
8. Settings gear with two-tap guard and pause; effects and music on/off + volume; ghost toggle; difficulty; less motion; haptics.
9. Music from `assets/music/race_riders_theme.ogg`; modern SFX set from section 11.
10. `full_unlock` hook, both signals, `set_difficulty`, `save_game()`, save file, shell-home square free, nothing tappable at y >= 1664, flash limiter, PerfOverlay.
11. World page with up to two cards (home target in stand-alone); world 2 opens on the first finish of world 1; the card's biggest disc goes to world 2.
12. Ghost per world, never on a world's first run, faded out within 4 m of the player (10.8).

Out: worlds 3-6, Hop hindrance, garage and cosmetics (save fields exist, no UI), voice lines, store art, gold trims.

Acceptance hints for game-qa: kids walk-through with sound off, touching nothing after launch: the race starts by itself, the rider finishes inside 50 s and the card appears (Lett). Log check: no rider's speed ever below 18 m/s after GO, except a rival inside its knock-off sequence; no pad, hindrance or roller inside a landing slope (6.3); FOV reads 75 +-1 at steady cruise and 83 +-1 at the peak of a boost; never more than 3 flashes in any 1 s window during the P3-P5 chain; no touch target inside 0-232 x 0-232 or at y >= 1664; launch to GO <= 10 s on the 32-bit tablet; Vanlig skilled bot (all pads, instant boost) wins by >= 1.5 s in 9 of 10 runs; idle Lett bot finishes in the top 3 in 9 of 10 runs; in world 2 the same idle Lett bot also finishes top 3 in 9 of 10 runs and never touches a sand drift; the ghost is never drawn on a world's first run and never within 4 m of the player (log check); the player's speed never drops on any contact (log check); a bot that holds toward every rival it passes knocks off at least 2 per race and never knocks the same rival twice within 6 s of it riding again.

## 15. Play together tip (rule 42, draft)

"Bytt på: den ene styrer til venstre, den andre til høyre." ("Take turns: one of you steers left, the other steers right.") Two thumbs, one on each half, works with latest-touch-wins.

## 16. Open questions (each has a default the builder uses now)

1. **Boost input.** Steering owns both screen halves, so boost is a centre disc at y 1490 that never steers. The feel reference also used double tap, which rule 10 forbids. **Default: centre disc, Lett auto-fires 2 s after full.** Alternative: no button at all, boost fires automatically in both modes.
2. **Place digits.** The HUD place badge and the card time use digits (1-6 and a clock). **Default: digits kept** (children 4-7 know 1-6; times are for older riders and parents). Alternative: shapes only, with the time hidden in Lett.
3. **Free-card frequency.** **Default: `free_levels_finished` on finish 3, then at most once per app session.** Alternative: only once ever.
4. **Unlocks counted on finishes, not wins.** **Default: finishes** (a 4-year-old progresses too); wins only add gold trims.
5. **Ghost per track, shared by both modes.** **Default: one ghost per track, best time from either mode.** A Vanlig parent's ghost will then lead a Lett child's race. Alternative: one ghost per mode.
6. **Hoverboard bonus.** The kid line and AI numbers were simulated with the 1.06 hover bonus; if graphic-designer wants the board to look faster, raise `HOVER_SMOOTH_MULT` and re-run `tools/pack_sim.py`.
7. **Track names in Norwegian** (Furuløypa etc.) with English pairs, like Neon Bricks. **Default: yes.**
8. **Vanlig got easier with knock-offs** (average player wins 67-75% vs 46% before, my calc). **Default: leave it** and judge on the phone; the first lever is `AI_SKILL_V` +0.01 across the board.
9. **Knock-off threshold in Lett.** At 1.0 m/s, Lett auto-steer drift sometimes knocks a rival off by itself (0.6 per race when holding nothing). **Default: keep it**, because a young child seeing a rival fall is part of the fun. Alternative: raise `KNOCK_LAT_MIN_L` to 3.0 so only deliberate steering counts.
10. **Fall look with the new realistic art.** The fall is a controlled tip-over and slide, the rider gets up unhurt, with no ragdoll and no pain sounds. **Default: that**, for a 4-7 audience; the art agent decides the animation.
11. **Free part in MWM Play is world 1 only**, so the shell's "all levels played" card can show after the very first race. **Default: world 1 only, card at most once per session.** Alternative: worlds 1 and 2 free, so a trial child also sees a world change.
12. **World names and settings** (table 6.0, realistic: pine forest, red canyon, glacier, volcanic ash, rainforest, night harbour). **Default: as listed.** The volcano keeps lava behind rails and never on the track; swap it for a quarry if the owner finds lava too scary for 4-year-olds.
13. **Mud added to world 1** (2 puddles) so each world has 2+ hindrances. **Default: add them**; the current build has hay only.

## 17. Progression v2: many tracks, an offline league ladder, track boards (owner 21:00)

Post-slice. Until the track kits of 17.1 exist, the build keeps the slice rule (world 2 opens on the first finish of world 1). Everything here is **offline**: no internet, no accounts, no data leaves the phone (MWM Play rule). "Leaderboards" are local tables of named computer rivals plus your own times. Speed numbers stay as in sections 4 and 13.

### 17.1 Tracks: 6 worlds x 8 tracks, plus Pro variants = 96 races

| | Count | How it is made |
|---|---|---|
| Worlds | 6 | Table 6.0 (unchanged) |
| Tracks per world | 8 | Track 1 = the hand-made table (6.1, 6.2; worlds 3-6 to come). Tracks 2-8 are assembled from that world's **track kit** |
| Base tracks | **48** | Lengths per world: `WORLD_LENGTH_M[w] + 25 m x (k - 1)`, so a world's tracks run from about 44 s (track 1) to about 50 s (track 8) (my calc: 175 m more at 30 m/s is 5.8 s) |
| Pro variants | **48** | Same track **mirrored** (x -> -x, kid line too), **evening light** preset (low warm sun, longer shadows, one HDRI swap per world), **+2 hindrances** where the spacing rules allow, rivals +0.01 skill. No new art |
| Total races | **96** | |

**Track kit (per world, built once by the art and level side, reused by all 8 tracks):** 14 pieces, each 90-240 m long, with fixed content and its own kid-line segment, joining at a standard 10 m wide joint:

| Piece | Variants | Content |
|---|---|---|
| Start | 1 | Grid, start drop |
| Finish | 1 | Finish kicker (K4 type), finish gate, run-out |
| Gate-in / Gate-out | 1 each | Swap gate G1 / G2 with the surface change |
| Pad straight | 2 | 1 pad left or right |
| Chain zone | 1 | Chain of 3 pads |
| Bend | 2 | S-bend, long sweeper |
| Small kicker | 2 | 1.0 s and 1.2 s kickers with their landing slopes (6.3) |
| Hindrance zone | 2 | The world's two main hindrances (W1: hay lane, mud lane; W2: drift, tumbleweed pair) |
| Landmark | 1 | Tunnel, bridge, gas station, ice cave ... the world's set piece |
| Signature | 1 | The world's signature jump (table 6.0) with its landing slope |

**Recipe:** Start, 3-4 pieces, Gate-in, 2-3 smooth pieces, Gate-out, 2-3 pieces, Signature, 0-1 piece, Finish. Rules a generated track must pass: 10 pads incl. 2 chains, 4 kickers incl. the signature at 75-85% of the length, G1 at 28-35% and G2 at 60-66%, all spacing rules from 6.0 and 6.3, no piece twice in a row and at most twice per track, each piece mirrored or not per use.

**Workflow:** a small offline tool (`tools/track_gen.py`, to build with the kits) lists 20 valid recipes per track from a fixed seed, `seed = hash("rr_w{w}_t{k}")`. game-designer picks one per track, hand-tunes bend radii, mirror flags and the prop-scatter seed, and checks the times with `tools/pack_sim.py`. The result is saved as data, `res://tracks/w{w}_t{k}.json`; the game never generates tracks at runtime, so every child gets the same 96 races.

### 17.2 League ladder (offline, like the reference's league climb)

**Leagues:** Bronze -> Silver -> Gold -> Platinum -> Diamond -> Champion, each with 3 tiers (III -> II -> I) = **18 tiers**. Each league has a home world: Bronze = world 1 ... Champion = world 6.

**A season** = 5 rounds in one tier. Each round, you race 5 rivals from your league's table on a new track:

| Tier | The 5 rounds |
|---|---|
| III | Home world tracks 1, 2, 3, 4, 5 |
| II | Home world tracks 6, 7, 8 + next world tracks 1, 2 (a preview of the next world; Champion previews Pro tracks of worlds 1-2) |
| I | Home world Pro tracks 1, 3, 5, 7, 8 |

The next level is never the same track (owner 13:05). A child first sees world 2 in Bronze II round 4, about race 9 (my calc).

**The table:** you + **11 named rivals** per league (66 in total, persistent in the save: name, jersey colour, number, helmet icon). Each round has two heats of 6: **your heat** (you + the 5 rivals nearest you in points, so you always fight your neighbours) and a **rival heat** of the other 6, simulated with a seeded RNG (`seed = hash(save_seed, tier, round)`): time = `1 / skill x (1 + N(0, 0.025))`. Both heats score points, so the whole table moves every round.

**Points per place in a heat:** 1st **10**, 2nd **8**, 3rd **6**, 4th **5**, 5th **4**, 6th **3**. Every finish scores (rule 30). Ties: more wins, then the better best finish, then the player (my call).

**Promotion:** finish the season in the **top 3** of the 12-rider table -> next tier (after tier I: next league, a new world and roster).
- **Lett (4-7): no demotion ever.** Safety net: after **2 seasons** in the same tier without promotion, the next season end promotes anyway. Nobody gets stuck.
- **Vanlig (8+):** soft demotion is a setting ("Nedrykk", default **off**). When on, the bottom 2 drop one tier, never out of the league they have reached.

**Rival skill:** tier III of Bronze uses the table skills `RIVAL_SKILL_BASE` (Lett 0.90-1.00, Vanlig 0.89-0.99, one rival per 0.01). Each league adds `LEAGUE_SKILL_STEP` (Lett **0.006**, Vanlig **0.01**), each tier a third of that. Champion III: Lett +0.030, Vanlig +0.050. Pro tracks +0.01 on top. Rubber banding (7.3) applies unchanged in every heat.

**Between sessions (rule 27 kept):** the owner asked that rivals "race between your sessions". Points that change while you are away would punish a child for stopping, which rule 27 bans. **Default:** after 8 h or more away, each rival in your table gets a seeded **form** of -0.01, 0 or +0.01 skill for the next round, shown as a small up or down arrow by its name. Points only change in rounds you race. Open question 17-1.

**League screen:** shown after the reward card when you tap "next": the 12-row table (jersey, icon, name, points; your row highlighted, rows slide 1.5 s to their new places), 5 round dots, one big race disc. Names are text for older riders and parents; jerseys and icons carry it for non-readers. Launch still goes straight into the next league race (10.2: 10 s or less to racing).

**Season end card:** the table's top 3 on a podium. Promoted: your rider steps up, new tier badge, reward reveal (17.4). Not promoted: a "ride again" disc, with no sad sound and no red. Lett safety-net promotion looks exactly like a normal promotion.

**Free ride:** any open track or Pro variant can be raced alone from the world page (no points), with its ghost.

### 17.3 Track boards (local leaderboard per track)

Each track card opens a 12-row board: **your best time** (with the ghost of that run) + the **11 rivals of that world's league**. A rival's board time starts seeded: `par / skill x (1 + N(0, 0.015))`, and improves when that rival beats it in a heat against you. `par` = the skilled time from `tools/pack_sim.py` for that track (world 1 track 1: 41.8 s, world 2 track 1: 42.9 s, my calc). **Time medals** on the track card: gold <= par x 1.01, silver <= x 1.04, bronze <= x 1.08. Example (my calc): an idle Lett child (43.2 s on world 1 track 1) gets silver.

### 17.4 Rewards (all by playing, nothing for sale)

| Event | Reward |
|---|---|
| Promotion III -> II | A livery (bike and board paint set) |
| Promotion II -> I | A part: wheels, frame decal, board deck or helmet |
| League won (I -> next league) | League trophy (6 cups on the trophy shelf) + that league's jersey |
| Gold medal on a track | Gold flag on the track card |
| First win in a world | That world's gold trim (9.1) |

**Parts are cosmetic only** (my call). Small stats would widen the gap the rubber band keeps fair, the same reason as feel 24. If the owner wants stats, cap them at +1% cruise per part and +3% in total, and re-run the sims (open question 17-2).

### 17.5 MWM Play free part

`full_unlock == false`: **world 1 tracks 1-5** = the whole **Bronze III** season, both vehicles, outfit 2. The season-end card shows normally; instead of promoting, the game emits `free_levels_finished` (at most once per app session), and the shell shows its "Du har spilt alle banene her" card. Bronze III can be replayed forever, with its ghosts and track boards. This replaces the "world 1 only, 1 track" rule of 9.2.

### 17.6 Expected league results (my calc, `tools/league_sim.py`, 40 seasons = 200 races per row, world 1 track 1 used as the stand-in track, rubber band on)

| Player | Mode | League (tier III) | Race top 3 | Race wins | Promoted per season |
|---|---|---|---|---|---|
| Holds nothing (4-year-old) | Lett | **Bronze** | **100%** | 42% | 100% |
| Holds nothing | Lett | Gold | 98% | 22% | 92% |
| Holds nothing | Lett | Champion | 86% | 12% | 32% (safety net promotes after 2 seasons) |
| Steers at random | Lett | Gold | 91% | 24% | 75% (old step 0.01; at 0.006 it is higher) |
| Holds nothing | Vanlig | Bronze | 40% | 0% | 0% (as intended: Vanlig needs input) |
| Average | Vanlig | Bronze | 99% | 41% | 97% |
| Average | Vanlig | Gold | 84% | 18% | 65% |
| Average | Vanlig | Diamond | 70% | 4% | 7% |
| Average | Vanlig | Champion | 65% | 4% | 2% |
| Skilled | Vanlig | Platinum | 100% | 96% | 100% |
| Skilled | Vanlig | Champion | 100% | 75% | 100% |

So an average Vanlig rider climbs to Gold or Platinum and stalls there; only skilled riders reach Champion. The Lett safety net carries a child to the end. Rows for Lett Bronze, Vanlig idle Bronze and Vanlig average Bronze were run with the first step values, which do not matter at Bronze III (offset 0). The 1D model lacks lanes, so retune `LEAGUE_SKILL_STEP` on the phone.

### 17.7 Rival roster (66 names, invented; the owner may rename)

| League | Rivals |
|---|---|
| Bronze | Ola Berg, Mia Lund, Sami Ray, Ida Fjell, Leo Park, Nora Vik, Emil Dahl, Ava Moss, Theo Kim, Liv Storm, Max Brook |
| Silver | Selma Hart, Jonas Reed, Zara Quinn, Aksel Holm, Lea Frost, Omar Vale, Tuva Bay, Finn Cole, Ines Ruiz, Kai Moon, Ella Stone |
| Gold | Sindre Falk, Maja Wren, Luca Rossi, Hedda Lie, Arlo Grant, Sofie Nygård, Ravi Shah, Frida Sol, Noah Pike, Yuki Mori, Thea Lark |
| Platinum | Henrik Ås, Clara Dune, Mateo Cruz, Ingrid Skog, Oscar Hale, Amira Noor, Elias Vang, Ronja Elv, Felix Byrne, Saga Nord, Iver Rask |
| Diamond | Viktor Stål, Alma Bright, Diego Sol, Mathea Ruud, Hugo Lane, Leila Haddad, Johan Brekke, Signe Tind, Rafael Costa, Nina Hav, Sverre Ulv |
| Champion | Astrid Krone, Magnus Fjord, Isla Grey, Tobias Rønning, Elena Petrova, Bjørn Stein, Kaya Lin, Marius Eik, Selin Aydin, Even Brattli, Jade Rivers |

Within a league, skill rises with list position (first name = slowest). Jersey colours: 11 distinct hues per league, each also with a number 2-12 and one of 5 helmet icons (rule 36: never colour alone).

### 17.8 New `RrBalance.gd` rows (append; the speed block in 13 is unchanged)

```gdscript
# Progression v2 (GDD 17)
const WORLDS: int = 6
const TRACKS_PER_WORLD: int = 8
const TRACK_LENGTH_STEP_M: float = 25.0          # track k = WORLD_LENGTH_M[w] + 25 * (k - 1)
const PRO_AI_SKILL_ADD: float = 0.01
const PRO_EXTRA_HINDRANCES: int = 2
const LEAGUES: Array[StringName] = [&"bronze", &"silver", &"gold", &"platinum", &"diamond", &"champion"]
const TIERS_PER_LEAGUE: int = 3
const ROUNDS_PER_SEASON: int = 5
const TABLE_RIVALS: int = 11
const LEAGUE_POINTS: Array[int] = [10, 8, 6, 5, 4, 3]
const PROMOTE_TOP: int = 3
const LETT_SAFETY_SEASONS: int = 2
const VANLIG_DEMOTE_BOTTOM: int = 2
const DEMOTION_DEFAULT_ON: bool = false
const RIVAL_SKILL_BASE_L: Array[float] = [0.90, 0.91, 0.92, 0.93, 0.94, 0.95, 0.96, 0.97, 0.98, 0.99, 1.00]
const RIVAL_SKILL_BASE_V: Array[float] = [0.89, 0.90, 0.91, 0.92, 0.93, 0.94, 0.95, 0.96, 0.97, 0.98, 0.99]
const LEAGUE_SKILL_STEP_L: float = 0.006         # per league; a third per tier
const LEAGUE_SKILL_STEP_V: float = 0.01
const RIVAL_HEAT_NOISE: float = 0.025            # seeded rival-only heat
const RIVAL_FORM_STEP: float = 0.01              # -1, 0 or +1 step after an absence
const RIVAL_FORM_AWAY_H: float = 8.0
const BOARD_TIME_NOISE: float = 0.015
const MEDAL_PAR_MULT: Array[float] = [1.01, 1.04, 1.08]   # gold, silver, bronze
const FREE_TRACKS_W1: int = 5                    # = Bronze III
const FREE_LEAGUE_TIERS: int = 1
```

Save additions: `league` (index), `tier`, `season_round`, `seasons_in_tier`, `table` (11 rivals: id, points, form), `boards` (per track: rival best times), `medals`, `trophies`, `demotion_on`, `save_seed` (random once at first launch, on the device only).

### 17.9 Open questions (progression)

1. **Rivals racing while you are away.** Default: only a form arrow changes, and points never move while away (rule 27). Alternative (owner's wording): one rival-only round per real day that scores points. That would pressure children to come back, so I advise against it.
2. **Parts: cosmetic or small stats.** Default: cosmetic only. Alternative: capped stats (+1% per part, +3% total) with re-tuned rival skill.
3. **Track count.** Default: 8 per world (48 + 48 Pro). The kit makes 10 per world cheap if the owner wants more; seasons would then use tracks 1-5 / 6-10.
4. **World order vs league.** Default: a new world arrives with its league (preview in tier II). This replaces the 13:05 "next world on finishing the previous one" after the slice; the slice keeps the 13:05 rule.
5. **Names.** Default: the invented roster in 17.7, shown as text with jersey and icon. Alternative: jerseys and icons only in Lett.

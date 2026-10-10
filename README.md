# MWM Race Riders

**[⬇ Download the APK (Android)](https://github.com/Matswm86/mwm-race-riders/releases/download/latest/mwm-race-riders.apk)**

<p align="center"><img src="docs/screenshots/17_w3_glacier.jpg" alt="World 3 mid-race: rider 7 chases rivals down a groomed glacier piste between red course flags and blue seracs, snow peaks ahead" width="360"> <img src="docs/screenshots/24_w6_midrace.jpg" alt="World 6 mid-race: the racers ride a wet quay at night under sodium lamps, container stacks on the right, a lit ferry across the harbour" width="360"></p>

A fast, realistic downhill racer for Android, made for children (ages 4-7 on "Lett", 8+ on "Vanlig"). Hold the left or right side of the screen to steer a mountain bike, and later a hoverboard, against five rivals: speed pads, jumps with automatic tricks, gates that swap your vehicle, and a finish in 44-51 seconds at 108 km/h cruise (up to 173 km/h on boost). Steer into a rival's side to knock it off its bike; rivals can only nudge you, you never fall, and everyone finishes. No ads, no tracking, works offline, no Android permissions.

## Levels: 96 races in six worlds

Each world has 8 tracks, and each track has a Pro variant: 48 tracks and 48 Pro races.

- **World 1 "Furuløypa / Pine Run"**: alpine pine forest on a summer afternoon, log cabins, course tape, hay bales, mud puddles, a gravel river road with a wooden bridge for the hoverboard, a closed rock tunnel and the gully plank jump.
- **World 2 "Ørkenjuvet / Red Canyon"**: red sandstone walls under a mesa skyline, a natural arch, sand drifts (the hoverboard floats over them), rolling tumbleweeds, a narrow slot canyon, the old rim highway with its abandoned gas station and the mesa-gap jump.
- **World 3 "Isbreen / Glacier Run"**: a groomed glacier piste between red flags and blue seracs, falling snow, ice patches that make the steering slide, snow drifts, snow slides rolling across, and the jump out of a blue ice cave over a crevasse.
- **World 4 "Askefjellet / Ash Mountain"**: black ash under a smoky sunset and a smoking cinder cone, glowing lava only behind a steel rail, ash dunes (the hoverboard floats), rocks rolling down, lava-crust ridges to hop, embers, and the steam vent that launches you only while it puffs.
- **World 5 "Regnskogen / Rainforest"**: a wet mud trail under giant trees, rain and mist, logs to hop, branch piles, a split path (a narrow rope bridge or a wide river ford with more pads) and the jump off a waterfall into its pool.
- **World 6 "Nattehavna / Night Harbour"**: a wet quay at night under sodium lamps, container canyons, traffic cones, rolling cable spools, wet steel plates that slide, air rings over the jumps for extra speed, and the crane jump off a container stack over the water.

Track 1 of worlds 1 and 2 is the hand-made course; every other track is built from its world's kit of 15 pieces, each with its own order of bends, jumps, hindrances and set pieces and its own scenery, and a little longer than the one before (an idle child finishes every track in 44-51 seconds). Hindrances only slow you or nudge you; nothing makes you fall. Pro variants are the same track mirrored, at sunset, with two extra hindrances and slightly faster rivals. Every track has three medal times (gold, silver, bronze) and keeps your best run as a ghost.

| Pine Run: tunnel | Red Canyon: swap gate | Glacier: ice cave | Ash Mountain: lava rail | Rainforest: split path | Night Harbour: crane jump |
|---|---|---|---|---|---|
| ![](docs/screenshots/t1_w1_t3.jpg) | ![](docs/screenshots/10_swap_gate.jpg) | ![](docs/screenshots/16_w3_ice_cave.jpg) | ![](docs/screenshots/18_w4_lava_rail.jpg) | ![](docs/screenshots/20_w5_split_path.jpg) | ![](docs/screenshots/23_w6_crane_jump.jpg) |

## Leagues

<p align="center"><img src="docs/screenshots/08_league_screen.jpg" alt="League screen: six league cups at the top (Bronze lit, the rest dark), a table of you and 11 named rivals with jersey discs and points, five round dots, and a big round race disc showing the next track" width="320"> <img src="docs/screenshots/09_season_end.jpg" alt="Season end: the top three on a podium, an up arrow from the Bronze cup with one pip to the Bronze cup with two pips" width="320"></p>

The home screen is a league table you can use without reading: one big disc races the next round, everything else is shapes and digits. You climb six leagues, each with its own world and tiers III, II and I: Bronze (world 1), Silver (world 2), Gold (world 3), Platinum (world 4), Diamond (world 5) and Champion (world 6). A season is 5 rounds on 5 different tracks: tier III uses tracks 1-5, tier II tracks 6-8 plus a preview of the next world (Champion previews Pro tracks of worlds 1 and 2), tier I the Pro tracks. You race the five rivals nearest you in points while the other six race their own heat; places score 10, 8, 6, 5, 4 and 3 points, and the top 3 of the 12-rider table move up a tier, with a cosmetic reward (paint set, part, league trophy). On "Lett" nobody ever drops and a child who gets stuck is moved up after two seasons; on "Vanlig" the bottom two drop only if "Nedrykk" is switched on in settings. Rivals never score while you are away; after 8 hours they just show a small form arrow. Each league has 11 named rivals of its own, a little faster in every league.

Every race is on a new track. After a race the biggest disc on the result card starts the next race straight away, on a different track from the one just ridden; the league table (home) and a replay of the same track are small discs at the sides. Each season mixes in one guest track from another world you have open (never in round 1, never a track twice), and the season's list is saved, so a restart picks up the same season. After free rides the next disc picks a new track, mostly in the same world and sometimes in another.

The map disc opens free ride: any track or Pro race on its own, no points, with your ghost and the track's board of best times.

| Card | League table | Promotion | Free ride | Track board |
|---|---|---|---|---|
| ![](docs/screenshots/04_w1_results_card.jpg) | ![](docs/screenshots/11_league_bronze2_form.jpg) | ![](docs/screenshots/10_promotion_reward.jpg) | ![](docs/screenshots/14_world_page.jpg) | ![](docs/screenshots/14_track_board.jpg) |

All screenshots come from the real Godot build (screenshot bot, `tests/capture.tscn`). Rules and numbers: `docs/GDD.md` (section 17 for tracks and leagues). Look: `docs/DESIGN.md`.

## Install on a phone or tablet

1. On the device, tap [mwm-race-riders.apk](https://github.com/Matswm86/mwm-race-riders/releases/download/latest/mwm-race-riders.apk) (or open the [latest release](https://github.com/Matswm86/mwm-race-riders/releases/tag/latest)).
2. Open the file and allow "Install from this source" if Android asks.
3. If an older build will not update (signature mismatch), uninstall it first.

The APK runs on 64-bit phones and 32-bit tablets (arm64-v8a and armeabi-v7a). It is debug-signed, for sideloading only.

## How to play

- Hold the left half of the screen to steer left, the right half to steer right. The newest finger wins.
- Touch anywhere (or wait 4 seconds) and the start lights count you in.
- Ride over the amber chevron pads for speed; three in a row go faster each time. In the night harbour, fly through the amber rings over the jumps.
- Steer into the side of a rival riding next to you and it tumbles off its bike, then gets up and rides on. Mud, sand, snow, ash and the ford slow you a little, ice and wet steel make you slide, hay, branches and cones burst away, rolling things push you aside, logs and crust ridges give a little hop; nothing makes you fall.
- Tap the round lightning disc when it is full for a boost. On "Lett" it boosts by itself, and the rider follows a helper line when you let go.
- After your first finish, the gates turn your bike into a hoverboard and back. The card's biggest disc opens the league table; its big disc starts the next round. When you race a track again, your best run there rides along as a see-through ghost that fades away when it gets close to you.
- Gear (top right): tap twice to open settings (difficulty, Nedrykk, sound, music, ghost, less motion, graphics Høy/Lav). Three-finger tap shows the performance readout (fps, draw calls, memory).

## Graphics

Realistic look: scanned PBR textures, HDRI skies, a matching sun with real shadows, depth fog, AgX tone mapping. "Høy" (default) adds the sun shadow, glow on the LEDs and lamps, 2x MSAA, normal maps everywhere, triplanar rock walls, the full forest and grass, and sun shafts in world 1. "Lav" (32-bit tablet) drops shadows and glow, uses FXAA, keeps normal maps on the racers only, thins the forest and cuts grass at 15 m. 32-bit devices start on "Lav", and the game drops to "Lav" by itself if a race runs under 45 fps for 3 seconds.

## For a host app (MWM Play)

The autoload `RaceRiders` holds the hooks: `set_full_unlock(on)` (default `true`, so the stand-alone build has every track open for free ride), `set_difficulty(easy)`, `set_shell_inset(inset)`, `set_sfx_on`, `set_music_on`, `set_haptics_on`, `set_less_motion`, `save_game()`, and the signals `level_card_shown(track_id)` (world x 10 + track, +100 for Pro: world 1 track 3 = 13) and `free_levels_finished()`. With `set_full_unlock(false)` the game is the Bronze III season (world 1 tracks 1-5); its season end sends `free_levels_finished` (once per session) instead of promoting, and it can be replayed forever. With `Engine.set_meta(&"mwm_play_shell", true)` the game hides its own home disc, shows only the volume, ghost and graphics rows in settings, and leaves the back button to the host. Save file: `user://race_riders_save.json`.

## Development

- Godot 4.6, `mobile` renderer, portrait 1080x1920. APKs are built by GitHub Actions on every push to `main`.
- Race test (all 96 races with an idle Lett bot inside 41-51 s, landing zones, skilled and knock-off bots in every world, the world features, ghost fade, flash limiter, league rules, the whole ladder Bronze III -> Champion I with an idle child, the MWM Play free part, save migrations v1 and v2, touch targets, and a whole Bronze III season in the real scene with no input): `godot --headless --audio-driver Dummy --resolution 1080x1920 res://tests/race_test.tscn`
- Screenshot bot and graphics cost probe: `tests/capture.tscn` (phases `shots`, `tracks`, `worlds`, `budget`, `cost`, `look`, `thumbs`, `probe`; see the header of `tests/capture.gd`). The `budget` phase measures draw calls on all 96 races (Høy at most 80, Lav at most 60).
- Tracks: kits for all six worlds live in `tools/track_gen.py`; `python3 tools/track_gen.py --list 1 3` lists the 20 valid layouts of world 1 track 3; pin a pick in `tools/track_picks.json`, then `python3 tools/track_gen.py --write` (after `godot --headless -s tests/export_t1.gd` if track 1 changed), `godot --headless -s tests/par_times.gd` (par and medal times) and `godot --headless -s tests/bake_world.gd` (one baked landscape per track in `assets/generated/`; bump `RrWorldBake.VERSION` when `RrWorldGen` changes). Track pictures: capture phase `thumbs`, then `python3 tools/make_thumbs.py <capture dir>`.
- Art: GLBs and textures are rebuilt by `tools/art/` (DESIGN section 16). The GLBs are imported without their embedded textures (`tools/write_imports.py`, size caps in `tools/texture_budget.py`); the game builds every material from the loose files in `assets/textures/`, so each texture ships once. HUD sprites: `python3 tools/art/make_hud_atlas.py`.
- Sound effects: `python3 tools/render_sfx.py --kenney <folder with kenney_impact-sounds>`.
- Lint: `gdlint scripts tests` and `gdformat --check scripts tests`.

Credits and licences: `CREDITS.md`. Font: Barlow Condensed (SIL OFL 1.1, `assets/fonts/BarlowCondensed-OFL.txt`).

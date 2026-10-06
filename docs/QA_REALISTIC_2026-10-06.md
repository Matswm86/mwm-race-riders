# QA: MWM Race Riders realistic rebuild (2026-10-06)

**Verdict: NEEDS-CHANGES.** Nothing blocks a sideload. Android lint, gdlint, headless load, the race test (0 failed) and CI all pass, and none of the 15 bot screenshots is blank or cut off. Knock-offs, world unlock, the ghost, the MWM Play lock, touch and saved settings all work as the GDD says. Of the old findings re-checked, 1, 3, 4, 5, 6, 7, 10 and 11 are fixed and 2 is partly fixed. These keep it from SHIP:
- **The phone frame is over budget, and phone speed is unverified.** World 2 Høy draws 206k triangles at s 200 and 239k at s 173 (budget 200k). World 2 Lav is 68 draws / 120k triangles (budget 60 / 90k). The RTX 3060 laptop needs 8-14 ms of GPU per frame on Høy.
- **Near rivals cover the player and the boost disc.** In world 2, a rival is between the camera and the player in 37% of race frames (shot 08: rider 31 fills the lower right third).
- **The settings play disc overlaps the Grafikk button.**
- **APK size is 283.9 MB.** 157 MB of that is two debug engine libraries.

Audited commit: `7bd9657` (HEAD; CI build and gdlint green).

## 1. Checks run (real output, trimmed)

**Android lint** (`gd-android-lint.sh .`)
```
PASS .
EXIT=0
```

**gdlint / gdformat** (`gdlint scripts tests`, `gdformat --check scripts tests`)
```
Success: no problems found
33 files would be left unchanged
```

**Headless load** (`godot --headless --audio-driver Dummy --quit`)
```
Godot Engine v4.6.2.stable.official.71f334935
WARNING: ObjectDB instances leaked at exit
ERROR: 2 resources still in use at exit
LOADEXIT=0        (no SCRIPT ERROR)
```

**Race test** (`--headless --audio-driver Dummy --resolution 1080x1920 res://tests/race_test.tscn`, fresh `XDG_DATA_HOME`)
```
PASS  world 1 bake is current / PASS  world 2 bake is current
--- world 1
idle Lett times [44.0 .. 44.1] places [2, 2, 1, 2, 2, 2, 2, 1, 1, 2]
PASS  idle Lett: top 3 in 10 of 10 (need 9)
PASS  speed never below 12 m/s after GO (min 12.02)
INFO  skilled Vanlig bot wins by >= 1.5 s in 8 of 10 (GDD hint 9)
knock bot W1 knock-offs per race [4, 5, 5, 5, 3, 5, 3, 3, 5, 4], player contacts 63
PASS  the player is never knocked off
PASS  player speed never drops on contact (0 of 63)
PASS  no rival re-knocked inside its 6 s immunity (0)
--- world 2
idle Lett times [44.4 .. 44.7] places [2, 2, 1, 1, 1, 2, 2, 1, 1, 1]
INFO  skilled Vanlig bot wins by >= 1.5 s in 1 of 10 (GDD hint 9)
knock bot W2 knock-offs per race [4, 4, 4, 4, 4, 4, 3, 4, 4, 5], player contacts 74
PASS  the player is never knocked off
PASS  player speed never drops on contact (0 of 74)
ghost alpha at 3 m 0.00, 5 m 0.20, 8 m 0.40
PASS  ghost fades out within 4 m / PASS  ghost fully visible from 6 m
PASS  flash limiter: worst 1 s window 3 (max 3)
viewport (1080.0, 1920.0)
PASS  touch checks run on a portrait viewport
PASS  touch in the home/gear square never steers, wrist strip ignored, boost hit circle ends above 1630
main race 1: auto start after 3.1 s, finish 44.04 s, place 1, card true
PASS  card's biggest disc is world 2 / PASS  race 2 is world 2 (980 m)
PASS  no ghost on world 2's first run / PASS  ghost never drawn on world 2's first run
W1 replay ghost frames drawn: far 354, within 4 m 0
RACE TEST PASS (0 failed)
```

**Screenshot bot** (Xvfb :117, `--audio-driver Dummy`, NVIDIA ICD, fresh user dir, 242 s)
```
Vulkan 1.4.329 - Forward Mobile - Using Device #0: NVIDIA - NVIDIA GeForce RTX 3060 Laptop GPU
touch hold right half: phase 2, x moved +0.73 m (expect > 0)
wrist-strip touch: steer dir 0 (expect 0)
W1 mid-race: s 206 place 4 draws 82 tris 230k
knock-off shot: rider 3 fall_t 0.20 ds -1.5
race 2: world 2, ghost false
W2 mid-race: s 173 place 3 draws 73 tris 239k
Lav: draws 59 tris 114k, sun shadow false
W2 first run: ghost ever visible false (expect false)
W1 replay: ghost on true alpha 0.00
```
I opened all 15 PNGs and the two mock-ups. None is pure white or black. Nothing is cut off at the 1080x1920 edges. Body text (time, settings) is at least 40 px, white on ink. The home disc and gear stay in their corners on every screen, and the HUD band starts at y 250, below the 80 px status strip.

**Own probe** (real `InputEventScreenTouch` via `Input.parse_input_event`, 1080x1920, GPU; the script ran in a copy of the project outside the repo)
```
fresh launch: world 1 (expect 1)
pre-race boost tap -> phase 1                      (starts the lights)
hold boost centre and 130 px N/W/E/S: zone boost steer 0 dx +0.000 max|lat_v| 0.00   (all 5)
hold (200,1800) / (900,1900): zone none steer 0    (wrist strip)
hold (104,104) / (976,150): zone none steer 0      (home / gear squares)
hold (200,1100): steer -1 dx -1.729   hold (880,700): steer +1 dx +1.208
notch 156: top_shift 120 hud.top_dy 120 zone(104,248) none zone(104,300) none
after W1: launch_world 2 next_new 2 open [1, 2]
card: next visible true r 120 world 2, replay r 100, home r 100
card: next pressed, not released -> revealing false
card: released off the disc -> revealing false     (acts on release inside only)
card idle 8 s: next pulse 1.046                    (idle cue)
card: tap next -> revealing true kind board
reveal: tap in wrist strip -> still revealing true kind board
reveal: tap -> kind world:2 ; tap -> screen race world 2 ghost false
relaunch after W1: world 2 (expect 2)
W2 race 1: ghost visible frames 0
after W2: launch_world 2 (last 2) next_new 0
saved settings: {ghost false, less_motion true, music_on false, quality "lav", sfx_on false, sfx_volume 0.15}
reloaded: sfx false music false ghost false less_motion true quality_high false sfx_vol 0.15
```
**MWM Play lock** (`set_full_unlock(false)`, real W1 race)
```
free: launch world 1 open [1]
free: card next_disc visible false next_world 0 replay visible true
free: open [1] launch 1 next_new 0 page worlds [1]
free: start_race(2) loads world 1
free->full: open [1, 2] launch 2
```
**Shell mode** (`mwm_play_shell` meta): home hidden; settings rows Innstillinger, slider, slider, Spøkelse, Grafikk, with no gaps (p_shell_settings).

**Near-rival probe** (each race frame: is a rival closer to the camera than the player and on screen; does its projected body reach the boost disc or the player's column; my heuristic)
```
W1 race 1: 772 frames, rival in front of player 12%, over disc 3%, over player 3%
W2 race 1: 895 frames, rival in front of player 37%, over disc 15%, over player 17%
```

**Flash probe** (54x96 luminance grid; one event = at least 5% of the grid at least 0.2 brighter than the frame 0.1 s before; sampled at about 17 fps)
```
W1: 50 events, worst 1 s window 5; peak area mostly 5-22%; >= 25% of screen: 2 events (20.9 s, 35.9 s)
W2: 37 events, worst 1 s window 4
```
I opened the frame pairs (fl_00 to fl_03). Every event is the trail passing from pine shade into sun. None is a game effect. The game's own flashes stay under the limiter (race test: worst window 3).

**Graphics cost probe** (`CAPTURE_PHASE=cost`, frozen frame at s 200, RTX 3060 laptop, 1080x1920; GPU ms is noisy: the W1 "all on" row read 4.4 ms once and 13.7 ms in warm-up)
```
W1 Høy (all on)        draws 81  tris 187.9k  gpu 4.4-13.7 ms
W1 Høy minus shadows   draws 64  tris  98.4k  gpu  8.9 ms
W1 Høy without trees   draws 60  tris 179.0k  gpu  8.2 ms
W1 Høy without racers  draws 65  tris  63.6k  gpu 12.9 ms
W1 Lav                 draws 52  tris  94.3k  gpu  6.1 ms   (HUD hidden: 48 / 93.9k)
W2 Høy (all on)        draws 87  tris 206.4k  gpu  8.2 ms
W2 Høy minus shadows   draws 70  tris 120.8k  gpu  7.5 ms
W2 Høy without racers  draws 71  tris  98.3k  gpu  7.4 ms
W2 Høy without ground  draws 63  tris 151.4k  gpu  5.5 ms
W2 Lav                 draws 68  tris 119.6k  gpu  4.8 ms
```

**CI and APK** (`gh run list`, `gh release view latest`, `unzip -v` of the downloaded APK)
```
[ok] Build Android APK 37492321252   [ok] gdlint 37492321217
mwm-race-riders.apk 283891203 bytes 2026-10-06T16:03:54Z
lib/armeabi-v7a/libgodot_android.so 80.3 MB (stored)   lib/arm64-v8a/libgodot_android.so 74.9 MB (stored)
ETC2 textures 64.0 MB in APK (103.6 MB raw); normal maps 34.3 MB; other ctex (HDRIs, UI) 11.6 MB
race_riders_theme.ogg 43.5 MB (5555 s = 92.6 min, 61 kbps)
largest textures: sky_alps_field_2k.hdr 6.0 MB, terrain_rocky_trail_02_normal 5.5, terrain_red_laterite_..._normal 5.5, sky_goegap_2k.hdr 4.9
```
No source texture is above 2048 px (PIL scan of `assets/`, `_raw` excluded). `assets/_raw` (1.9 GB) has a `.gdignore` and is in the export exclude filter. The build uses `--export-debug` (`.github/workflows/build-android.yml:143`).

## 2. Re-check of the slice QA findings

| # | Old finding | Now | Evidence |
|---|---|---|---|
| 1 | Ghost covered the player 40% of race 2 | **Fixed** | The ghost is per world (`RrMain.gd:221-226`), so a world's first run has none: 0 visible frames in the W2 first race (probe and bot). It is hidden at 4 m or closer and fully visible from 6 m (`RrWorld.gd:629-650`, `RrBalance.gd:176-177`): 354 frames drawn far, 0 within 4 m |
| 2 | Draws over budget, HUD 16 draws | **Partly** | The HUD costs 4 draws (Lav 52 -> 48 with it hidden). Høy draws are 81-87, under the new 100 budget (DESIGN 12). Lav W2 is 68 draws (budget 60), and triangles are over in both tiers (finding 1) |
| 3 | Boost disc "active" before GO | **Fixed** | `RrRider.gd:38` `boost_until = -99.0`, `:86-87` requires `t >= 0`. Shot 01 shows a white disc pre-race |
| 4 | Medal under the punch hole | **Fixed** | Medal at y 350 + `top_dy`, bar at 268 + `top_dy` (`RrHud.gd:16-17,185,205`). With a 156 px inset the whole band moves down 120 (p_notch156) |
| 5 | Notch corner both homes and steers | **Fixed** | `RrMain.gd:369-371` grows the no-steer square with `top_shift()`. Probe: `zone(104,248)` and `zone(104,300)` = none at a 156 px inset |
| 6 | Reveal continues on a wrist-strip tap | **Fixed** | `RrCard.gd:144`. Probe: a tap at y 1800 left the board reveal up |
| 7 | Card has no idle cue | **Fixed** | `RrCard.gd:168-174`: the biggest disc pulses at 1 Hz after 7 s. Probe: pulse 1.046 at 8 s |
| 10 | Shell settings left empty bands | **Fixed** (new issue in finding 6) | Rows re-flow with no gaps (shell probe, p_shell_settings) |
| 11 | Touch test ran on 1920x1920 | **Fixed** | The test asserts a portrait viewport (`viewport (1080.0, 1920.0)`, PASS), and the README command has `--resolution 1080x1920` |

## 3. Kids walk-through (non-reading 4-year-old, sound off, Lett, fresh install)

| Task | Result | Where a child can get stuck |
|---|---|---|
| Launch to W1 race | PASS. World 1 opens with no menu. Two hands pulse on the halves, and with no touch the lights start after 3.1 s | For about 1 s the intro camera swings from a front view to the chase view. At 1.5 s the rider is half off-screen at the bottom left, and the camera faces an empty hillside (01, finding 8). It is gone by GO |
| W1 race | PASS with no input: 44.0 s, 1st or 2nd (10 of 10 idle runs top 3). Lett auto-steers and boosts. Holding a half steers at once, the boost disc never steers, and the wrist strip is dead. Riding into a rival's side knocks it off, and the child is never knocked off or slowed | Riding through pine shade gives sun/shade stripes on the trail up to 5 per s (finding 5). On 5th place a stray "- -" sits under the medal (finding 4) |
| Card | PASS. Cup with the place digit, the time, and three discs: home 200, replay 200, and the world-2 picture disc 240 on the right. Nothing advances by itself. After 7 s the picture disc pulses. Act on release is confirmed | The reveal cards (board, then the canyon picture) each sit on an empty grey pill that looks like a blank button (06, 07, finding 7). Any tap continues, so the child cannot get stuck |
| W2 race | PASS. The picture disc leads to world 2. On relaunch the game opens world 2, the newest unfinished world. No ghost on the first run, live swap gates, and the hoverboard on the rim highway (11) | **Rivals ride between the camera and the child's rider** 37% of the race. In shot 08, rider 31 fills the lower right third and half the boost disc. In shot 10, rider 4 covers the left of the disc and part of the player. The child loses "which one is me" and the disc (finding 2) |

If the child taps replay or home instead of the picture disc, the two reveal cards (board, then canyon) play and the child lands back on world 1 or the world page. That follows GDD 10.3 item 4, but the canyon picture they just saw is not where they go (finding 14).

## 4. Phone performance risk (no phone attached)

**Phone performance: UNVERIFIED.** The PerfOverlay autoload is present (`project.godot:23`), and a three-finger tap toggles it. It needs fps, draws and VRAM from the phone (Høy, W1 at s 200 and W2 at s 173) and from the 32-bit tablet (Lav).

**Risk: high.** The laptop GPU time is 8-14 ms on Høy (W1 13.7 ms in my warm-up read, builder 16.5 ms) on an RTX 3060 at 1080x1920. A mid-range phone GPU has roughly a tenth of that compute (my estimate), so Høy will not hold 60 fps there. The auto-drop to Lav after 3 s under 45 fps exists and saves the choice, but Lav is still 4.8-6.1 ms on the 3060. The triangle counts are over the DESIGN 12 ceilings in both tiers (W2 Høy 206-239k vs 200k, Lav 114-120k vs 90k). CPU time is about 1 ms. Particles are 300 at most per system (W1 pollen) and no texture is above 2048. SSAO is off. Depth fog is on, which is cheap. There is one directional light with 2 PSSM splits at 2048.

**Top 3 perf fixes** (savings are my estimates from the cost-probe deltas above):
1. **Shadow pass: stop the pines casting.** `RrWorld.gd:722-735` lets pine chunks within 90 m cast, while the shadow distance is only 60 m. There are 2 splits (`RrWorld.gd:137`). The shadow pass costs 17 draws, about 89k triangles (W1) / 86k (W2), and about 4.8 ms of the W1 laptop frame. Fix: pines never cast (bake a soft tree-shadow layer into the trail splat), use 1 split over about 30 m, and let only the player and the nearest rival cast. Expected: about -12 draws, -60-70k triangles, -3-4 ms on the laptop. This also tames the shade stripes (finding 5).
2. **Rival LOD.** Racers cost 124k triangles in W1 and 108k in W2 (including their shadow pass). `set_lod_bias(0.35)` (`RrWorld.gd:735`) does nothing on skinned meshes. Fix: a decimated rider-plus-bike GLB (about 4k triangles) for rivals more than about 8 m away, or a hand-made LOD swap. Expected: -70-90k triangles. W2 Høy goes from 206k to about 120-135k, and Lav W2 gets under 90k.
3. **Pine overdraw.** Turning the trees off saves 21 draws and about 5.5 ms in W1 (13.7 -> 8.2 ms). Each of the 1500 pines is four alpha-tested cards. Fix: single-card impostors beyond 40 m, a near visibility end of 80 m instead of 120/170 m (`RrWorld.gd:530-533`, hidden by the fog), and trim the transparent margin of the card atlas. Expected: -2-3 ms on the laptop and -8-10 draws.

## 5. APK size (283.9 MB): top cuts

| Cut | Now | Expected saving |
|---|---|---|
| **Engine libraries.** Ship one APK per ABI (arm64 for phones, v7a for the tablet), or an AAB for the store. Also try the release template (`--export-debug` at `build-android.yml:143`) | 155 MB of debug `libgodot_android.so`, stored uncompressed | -75 to -80 MB per download from the split. The release-template saving is unmeasured |
| **Music.** Trim the 92.6 min theme to a loop of about 10 min (owner's call) | 43.5 MB | about -38 MB (10 min at 61 kbps = 4.6 MB, my calc) |
| **Normal maps.** 512 px for props and secondary terrain layers, and 1024 for the two 2048 terrain sets (rocky trail 02, red laterite) | 34.3 MB in the APK, almost incompressible | about -20-25 MB (my calc: halving the side quarters the size) |
| **HDRIs.** Halve to 1024x512 (VRAM uncompressed half float, `compress/mode=3`) or use an LDR panorama | 2 x 8.4 MB raw, 10.9 MB in the APK | about -8 MB in the APK (-12.6 MB raw) |

## 6. Look (premium stylized tier, DESIGN.md 10; compared with `docs/mockups/realistic_mock.png` and `realistic_mock_w2.png`)

W1 mid-race (02) matches the mock closely: camera height and pitch, the HUD band (bar, red 7 token, medal at y 350), the boost disc at (540, 1490), the forest corridor and the course tape. W2 (08-12) keeps the HUD and camera but loses the mock's enclosed canyon. The five biggest prototype tells, ranked by visual gain per ms of phone GPU:
1. **Rivals filling the foreground** (08, 10, 03). Costs 0 ms to fix (fade near-camera rivals, or AI spacing) (finding 2).
2. **Dark-fringed, aliased pine cards** (02, 15). The foliage edges read as noisy cut-outs, where the mock's look soft. Costs about 0 ms: alpha antialiasing / alpha-to-coverage on the card material, a fixed alpha border, or premultiplied atlas edges.
3. **W2 is open on the left to a blurry green HDRI hillside** (08, 09, 10), where the mock has red walls on both sides. Costs about 0 ms: rotate the HDRI or add a second wall (finding 9).
4. **Stretched cliff textures on the W2 walls** (10 right, 11, 12): vertical smearing where the mesh is steep. About 0.3 ms for triplanar on the wall material only.
5. **Flat 2D board and blank pedestal on the reveal cards** (06, 07), and the white gravel road in W1 that reads like snow with jagged edges (03). Costs 0 ms.

Section 10 static budget: 1 shadowed light; 5 particle systems at most per world (pollen 300, needles 80, sand 200, dust devils 40, knock dust 20); transparent materials: ghost, dust and contact quads, board glow, mud and sand; 0 textures above 2048; SSAO off; no SSR; depth fog on; glow and sun shafts on Høy only.

## 7. Findings

1. **Medium (perf):** both tiers are over the triangle budget: W2 Høy 206k (cost probe) and 239k (bot, s 173), W1 Høy 230k (bot, s 206), Lav W2 68 draws / 120k triangles (budget 60 / 90k). The laptop GPU needs 8-14 ms. Phone speed is UNVERIFIED. Fixes are in section 4: pine shadows `scripts/RrWorld.gd:722-735,137`, rival LOD `:735`, pine ranges `:530-533`.
2. **Medium (child UX):** near rivals ride between the camera and the player. Shots 08 and 10; probe: W2 37% of frames, 15% over the boost disc zone, 17% over the player column (W1 12/3/3%). Fade or dither any rival closer to the camera than the player (like the ghost fade in `scripts/RrWorld.gd:637-650`), or keep rivals from sitting within about 5 m behind the player.
3. **Low-Medium (layout):** the settings play disc overlaps the Grafikk button (`scripts/RrSettings.gd:108` puts the disc at y 1450-1660; the Grafikk row from `:102` ends at about y 1505). Both hit areas cover x 570-650, y 1450-1505 (05, p_settings). Move the disc down about 60 px or tighten the row heights.
4. **Low (visual bug):** the 5th-place medal shows two white dashes under it (15, p_notch156). Atlas bleed: `place5` is `Rect2(600, 300, 150, 154)` (`scripts/RrHudAtlas.gd:18`), which reaches y 454, and the checkered flag sprite starts at about y 450 in `assets/textures/ui/hud_atlas.png`. Pad the atlas (`tools/art/make_hud_atlas.py`) or crop the rect to 150.
5. **Low (flash, rule 38):** pine shade stripes on the trail. At least 5% of the screen brightens by at least 0.2 within 100 ms up to 5 times in 1 s (W1, 50 events per race; W2 worst window 4). Only 2 events per race reach 25% of the screen, so it passes the WCAG area test, and the game's own effects stay inside the limiter. Perf fix 1 (no pine shadows, or a softer, baked shade) removes most of it. Optionally let Mindre bevegelse soften the sun shadow.
6. **Low (shell settings):** in MWM Play the first slider (sound) has no label or icon, only the music slider has the note, and the lower half of the panel is empty from y 850 to 1450 (p_shell_settings). `scripts/RrSettings.gd:120-153`: add a speaker icon on the sound slider row and shrink the panel in shell mode.
7. **Low (reveal cards):** the pedestal is drawn as an empty grey pill (`scripts/RrCard.gd:226`) and reads as a blank button. The board is a flat 2D drawing next to realistic art (06, 07). Use the world-picture treatment for the board (a rendered thumbnail), and drop or shade the pedestal.
8. **Low (first screen):** the intro camera interpolates from a front 3/4 view to the chase view (`scripts/RrWorld.gd:749-806`, `interpolate_with`) and swings through a frame with the rider half off-screen and the camera on an empty hillside (01, at 1.5 s). Start the intro from a side or rear 3/4 angle, or orbit around the rider instead of lerping the transform.
9. **Low (look, W2):** the left side is open to a soft green HDRI hill, and the steep cliff textures stretch (08-12) against `docs/mockups/realistic_mock_w2.png`. See section 6, items 3-4.
10. **Low (look, W1):** the pine card edges are dark and aliased (02, 15), and the gravel river road reads as snow with jagged edges (03). See section 6, items 2 and 5.
11. **Low (size):** the APK is 283.9 MB. See the table in section 5 (ABI split -75 to -80 MB, music -38 MB, normal maps -20-25 MB, HDRIs -8 MB).
12. **Info (design):** a skilled Vanlig bot wins by at least 1.5 s in 8 of 10 races on W1 and only 1 of 10 on W2 (GDD hint 9). Game designer's call.
13. **Info (test):** `tests/race_test.gd:371` accepts launch world 1 or 2. The probe proved the exact rule (relaunch after W1 opens 2; after both, the last world). Tighten the assert to `== 2` after the W1 finish.
14. **Info (spec drift):** the knock-off has an extra rule that is not in GDD 4.7: no knock-off from 30 m before the mesa gap to its end (`scripts/RrRace.gd:559`). Add it to the GDD. Also, after the canyon reveal, replay or home still goes to W1 or the world page (GDD 10.3 item 4). Designer's call whether the reveal should route to W2.
15. **Info:** leak warnings at quit (2-12 resources) in the load check, the race test and the bot.

## 8. Not checked

- **A real device**, phone or the 32-bit tablet: fps, draws, VRAM (PerfOverlay readings), touch feel, the Vulkan or Compatibility fallback, and launch-to-GO time. An installed APK.
- 20:9 and real punch-hole layouts beyond the 156 px fake inset.
- Audio by ear (Dummy driver throughout) and music loudness against effects.
- Animated motion: stills plus sampled frames only. The fall animation, tricks and the swap curtain were not watched.
- The flash measurement ran at about 17 fps, so short effects between samples can be missed.
- The release template APK size, the Play Store checklist (not a store release), and `look.py` (not a classic original).

Screenshots and probe output (outside the repo): `/tmp/claude-1000/-home-mm-MWM/56cd0316-e790-4e78-a268-96549e94fe5b/scratchpad/shots/01-15_*.png`, `.../scratchpad/qa2/pshots/`, `.../scratchpad/qa2/fl/`, `.../scratchpad/qa2/{full,cost}.log`.

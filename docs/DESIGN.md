# MWM Race Riders: visual design spec

Owner: graphic-designer. Version 1, 2026-10-06. The builder reads this before touching any colour, model, material, light, camera or UI node. Every token carries its rule and its reason. Game rules and numbers live in `docs/GDD.md` (game-designer); feel targets come from `projects/game-studio/docs/ridge-riders-feel-2026-10-05.md` (old working name). Child rules (rule N) are in `projects/mwm-play/docs/CHILD_UX_RESEARCH.md`. Numbers tagged (my calc) are my own arithmetic, WCAG 2.x formula on rendered pixels.

Mockups (all rebuilt by the scripts in `docs/mockups/src/`):

| File | What it shows |
|---|---|
| `docs/mockups/track_mock.png` | Race frame, 1080x1920: chase camera behind the player (fox, red, 5th), a boost pad just ahead, 4 AI riders ahead (one airborne off a kicker, one on the hoverboard past the swap gate), full HUD |
| `docs/mockups/track_zones.png` | Same frame with zones: reserved home square (white), gear and boost hit areas (green outline), steering drag zone (green tint), wrist strip with nothing tappable (red) |
| `docs/mockups/hud_parts.png` | The 6 head tokens (normal and player-ring version) and the place medal 1-6 |
| `docs/mockups/kit_sheet.png` | Every model: 6 riders on bikes from behind, board rider, bare board and bike, cheer pose, standing rider, pad, ramp, both swap gates, finish arch, trees, rock |
| `docs/mockups/src/*.py` | Blender 4.5 scripts and Pillow overlays (commands at the end of this file) |

---

## 1. Visual theme

**A sunny toy hillside in early summer: round toy riders on chunky bikes and hoverboards race down a warm dirt trail and a sky-blue skyway, through faceted green hills, pines and puffy clouds.**

References (take the idea, not the look):
- **A Short Hike (adamgryu):** faceted low-poly hills and trees in flat, sunlit colour, with distance carried by a pale haze. We take the faceted landscape and the haze; we leave its pixel filter and its muted autumn tones.
- **Fall Guys (Mediatonic):** round toy figures that you tell apart at a distance by costume silhouette. We take "one shape on the head says who it is"; we leave its candy-pink and purple palette and its jelly-bean bodies.

Two materials of form, on purpose: **the world is faceted** (flat-shaded hills, trees, rocks, clouds) and **the racers and the kit are rounded** (smooth helmets, tubes, bevels). The eye reads soft and round as "the things that matter".

Distinct from Neon Bricks (night, synthwave, glow, dark glass field) and from RUSH (section 9).

## 2. Palette

Split about 60 / 30 / 10: 60% world (sky, grass, dirt), 30% track kit and scenery (ramps, gates, trees, curbs), 10% racer team colours plus **sun yellow, which is reserved for "speed for you"**: boost pads, the boost button ring and the progress fill. The most saturated warm colour on screen is always something the player should drive over or press.

All 3D colours live in **one 64x64 palette texture**, `assets/textures/rr_palette.png`: 8x8 cells of 8 px. Every face of every model has its UVs on the centre of one cell. Row and column numbers below are counted from the top-left, as Godot reads UVs.

### 2a. World and track (lit, rows 0-2 and 5)

| Token | Hex | Godot | Cell (col,row) | Use |
|---|---|---|---|---|
| grass | #7DC75A | Color(0.490, 0.780, 0.353) | 0,0 | Terrain base |
| grass_dark | #5AA845 | Color(0.353, 0.659, 0.271) | 1,0 | Terrain patches (low-frequency noise, never per triangle) |
| meadow | #A9DB72 | Color(0.663, 0.859, 0.447) | 2,0 | Light terrain patches |
| hill_far | #A7D3A6 | Color(0.655, 0.827, 0.651) | 3,0 | Background hill cards |
| mountain | #9CC3D3 | Color(0.612, 0.765, 0.827) | 4,0 | Far mountains |
| snow | #F4F8F7 | Color(0.957, 0.973, 0.969) | 5,0 | Mountain caps |
| flower / petal | #FFD23F / #FFFFFF | (1.000, 0.824, 0.247) / (1, 1, 1) | 6,0 / 7,0 | Optional meadow flowers (MultiMesh) |
| dirt | #D39A63 | Color(0.827, 0.604, 0.388) | 0,1 | Bike section track surface |
| dirt_dark | #B47A47 | Color(0.706, 0.478, 0.278) | 1,1 | Two wheel ruts at +-1.3 m |
| curb | #FFF1D6 | Color(1.000, 0.945, 0.839) | 2,1 | Rounded cream curb on dirt edges |
| lane | #74BEE0 | Color(0.455, 0.745, 0.878) | 3,1 | Hoverboard "skyway" surface |
| lane_dark | #4A93C2 | Color(0.290, 0.576, 0.761) | 4,1 | Skyway outer bands |
| lane_stripe | #FFFFFF | Color(1, 1, 1) | 5,1 | Skyway edge lines and centre dashes (3 m on, 3 m off) |
| rock / rock_dark | #B9AC9F / #948677 | (0.725, 0.675, 0.624) / (0.580, 0.525, 0.467) | 6,1 / 7,1 | Boulders |
| trunk | #8A5A3B | Color(0.541, 0.353, 0.231) | 0,2 | Tree trunks |
| leaf / leaf_light | #4CAF50 / #7CCB52 | (0.298, 0.686, 0.314) / (0.486, 0.796, 0.322) | 1,2 / 2,2 | Round tree crowns |
| pine / pine_dark | #2F8F5B / #22744A | (0.184, 0.561, 0.357) / (0.133, 0.455, 0.290) | 3,2 / 4,2 | Pine tiers, alternating |
| shadow_grass | #4E9440 | Color(0.306, 0.580, 0.251) | 5,2 | Baked shadow disc under trees |
| cloud / cloud_shade | #FFFFFF / #E3EFF7 | (1, 1, 1) / (0.890, 0.937, 0.969) | 6,2 / 7,2 | Faceted clouds |
| dirt_mid | #C98B55 | Color(0.788, 0.545, 0.333) | 0,5 | Spare dirt tone (not used in the mock: periodic patches strobe at speed) |
| pebble | #E6D3B8 | Color(0.902, 0.827, 0.722) | 1,5 | Pebbles along the dirt edges (MultiMesh) |

### 2b. Track kit and racers (lit, rows 3-4)

| Token | Hex | Godot | Cell | Use |
|---|---|---|---|---|
| tangerine / tangerine_dark | #FF8A3D / #EE7429 | (1.000, 0.541, 0.239) / (0.933, 0.455, 0.161) | 0,3 / 5,4 | Ramp deck planks (alternating), bike swap gate, boost pad rim |
| wood | #C77B45 | Color(0.780, 0.482, 0.271) | 1,3 | Ramp sides and back |
| cream | #FFF1D6 | Color(1.000, 0.945, 0.839) | 2,3 | Ramp rails and lip, gate bands, fox inner ears, bobble |
| sun | #FFD23F | Color(1.000, 0.824, 0.247) | 3,3 | Boost pad body, unicorn horn, arch segments |
| sky | #3E9BDB | Color(0.243, 0.608, 0.859) | 4,3 | Board swap gate, skyway rails, arch feet |
| white | #FFFFFF | Color(1, 1, 1) | 5,3 | Gate signs, back badges, visor eye shines |
| ink | #24211D | Color(0.141, 0.129, 0.114) | 6,3 | Gate icons, checker, sign rims |
| red | #F2543D | Color(0.949, 0.329, 0.239) | 7,3 | Balloons only (never a rider-like red elsewhere) |
| pants | #34405A | Color(0.204, 0.251, 0.353) | 0,4 | Rider legs and hips |
| dark | #2B2F3A | Color(0.169, 0.184, 0.227) | 1,4 | Tyres, gloves, shoes, seat, collar, hover pods |
| visor | #1E2633 | Color(0.118, 0.149, 0.200) | 2,4 | Helmet visor |
| metal | #B9C2CC | Color(0.725, 0.761, 0.800) | 3,4 | Fork, handlebar, hubs |
| deck | #FFF8EE | Color(1.000, 0.973, 0.933) | 4,4 | Hoverboard deck |
| sole | #FFFFFF | Color(1, 1, 1) | 6,4 | Shoe soles |
| grey | #8A94A0 | Color(0.541, 0.580, 0.627) | 7,4 | Spare |

### 2c. Glow row (row 6, unshaded/emissive) and team cell (row 7)

| Token | Hex | Godot | Cell | Use |
|---|---|---|---|---|
| g_white | #FFFFFF | Color(1, 1, 1) | 0,6 | Boost pad arrows |
| g_yellow | #FFE680 | Color(1.000, 0.902, 0.502) | 1,6 | Spare (pad-chain sparkle) |
| g_cyan | #8FEFFF | Color(0.561, 0.937, 1.000) | 2,6 | Hover pod discs under the board |
| g_sun | #FFD23F | Color(1.000, 0.824, 0.247) | 3,6 | Spare |
| **team** | #FFFFFF | Color(1, 1, 1) | **0,7** | Jacket, sleeves, helmet, ears/fin, bike frame, board rim and stripe. Multiplied by the racer's team colour in the shader |

### 2d. The six riders (colour + shape; colour is never the only cue, rule 36)

| Id | Team colour | Godot | Head shape (3D hat and HUD token) | Back badge |
|---|---|---|---|---|
| fox (player default) | #E8412C tomato | Color(0.910, 0.255, 0.173) | Two pointed ears with cream insides | White triangle |
| bobble | #FFC21A sunflower | Color(1.000, 0.761, 0.102) | Cream pom-pom on top | White circle |
| shark | #2F6FE4 cobalt | Color(0.184, 0.435, 0.894) | One swept-back fin | White diamond |
| bunny | #12A08F teal | Color(0.071, 0.627, 0.561) | Two long ears | White square |
| bear | #FF7EB6 pink | Color(1.000, 0.494, 0.714) | Two round ears | White heart |
| unicorn | #F2F2EE snow | Color(0.949, 0.949, 0.933) | One sun-yellow horn | Ink star |

The player picks any of the six (GDD decides when); the five AI take the rest. Skins bought with coins (feel target 24) change the team colour only, never the head shape, so the shape always identifies the rider.

**Colour-blind check (my calc, Machado 2009 at full severity, minimum CIELAB distance between the six team colours):** normal 52.2 (bunny-unicorn), protan 21.1 (bunny-bear), deutan 15.6 (bunny-bear), tritan 20.0 (shark-bunny). Deutan bunny vs bear is the closest pair; they differ by long ears vs round ears and square vs heart badge. In greyscale at half size every token in `hud_parts.png` is still told apart by silhouette (checked by eye).

### 2e. Sky, fog and UI chrome

| Token | Hex | Godot | Use |
|---|---|---|---|
| sky_top | #4FA9E8 | Color(0.310, 0.663, 0.910) | ProceduralSkyMaterial `sky_top_color` |
| sky_mid | #93CDF2 | Color(0.576, 0.804, 0.949) | Gradient stop (mock); Godot curve `sky_curve` 0.12 |
| horizon / fog | #D6EEFB | Color(0.839, 0.933, 0.984) | `sky_horizon_color`, `ground_horizon_color`, depth fog colour |
| ui_white | #FFFFFF | Color(1, 1, 1) | Discs, progress track (92% alpha), medal 4-6 |
| ui_ink | #24211D | Color(0.141, 0.129, 0.114) | Rings, icons, digits, outlines (same ink as MWM Play) |
| ui_sun | #FFD23F | Color(1.000, 0.824, 0.247) | Boost charge ring, ready state, progress fill, medal 1, crown |
| medal_silver | #D9DEE4 | Color(0.851, 0.871, 0.894) | Medal 2 |
| medal_bronze | #E3A06B | Color(0.890, 0.627, 0.420) | Medal 3 |
| ribbon | #34405A | Color(0.204, 0.251, 0.353) | Medal ribbon tails |
| charge_empty | #E8E4DC | Color(0.910, 0.894, 0.863) | Uncharged part of the boost ring |

No purple anywhere in UI chrome, and none in this game's play content either.

### 2f. Contrast (my calc, sampled from the rendered `track_raw.png`)

| Pair | Ratio | Need |
|---|---|---|
| Ink digit on medal gold / silver / bronze / white | 11.1 / 11.8 / 7.3 / 16.0:1 | 4.5 (text) |
| Ink icons on white discs (home, gear, boost bolt) | 16.0:1 | 3.0 (rule 35) |
| Ink disc ring vs sky behind home / gear (#69B4EB, #71B9EC) | 7.1 / 7.5:1 | 3.0 |
| White disc vs that sky | 2.3:1 | the ink ring carries the edge (above) |
| Progress bar ink outline vs cloud behind it (#E3F9FF) | 14.7:1 | 3.0 |
| Sun fill vs ink outline | 11.1:1 | 3.0 |
| Boost disc ink ring vs dirt / grass / curb behind it | 6.5 / 7.4 / 13.1:1 | 3.0 |
| Rider dark mass (pants, tyres, visor #34405A) vs dirt / skyway / grass | 4.2 / 4.3 / 4.8:1 | 3.0 (object) |
| Team colours vs dirt (#BBA080 rendered) | 1.05 (bear) to 2.2 (unicorn):1 | see rule below |
| Boost pad sun vs dirt | 1.7:1 | see rule below |

**Rule for racers and pads.** Saturated team colours sit close to the dirt in brightness, so they carry *identity*, not figure-ground. Figure-ground comes from the dark mass every racer has (pants, tyres, gloves, visor: 4.2:1 or more on every surface), the blob shadow, and the hue jump. The boost pad stands out by its orange rim, its glowing white arrows and its hue. Never make pants, tyres or visors lighter, and never lay pads or ramps on a tangerine or yellow surface.

## 3. Typography

Children 4-7 do not need to read during a race. Digits 1-6 (medal) are the only text in the HUD.

- **Fredoka** (SIL OFL 1.1, `assets/fonts/Fredoka.ttf` + `Fredoka-OFL.txt`, copied from MWM Play), variable font, use the **SemiBold** instance: medal digit 112 px, popup words 84 px, results numbers 96 px.
- Adult text (stand-alone settings, credits): Andika Regular 40 px body, Fredoka SemiBold 56 px headings. Copy `Andika-*.ttf` and `Andika-OFL.txt` from `projects/mwm-play/assets/fonts/` when that screen is built.
- Popup words (GDD owns the words): short, friendly, our own. Ink on a white pill, never mockery, never a skull.

## 4. Components (px at 1080 wide)

| Component | Size and place | Look | States |
|---|---|---|---|
| Home disc (stand-alone build only; hidden when the MWM Play shell is present) | dia 136, centre (104, 104), hit 0,0-216,216 | White, 5 px ink ring, ink house 66 px. Copies the shell disc and its tap-again guard exactly | As the shell (`mwm-play/docs/DESIGN.md` 2b) |
| Gear | dia 136, centre (976, 104), hit 864,0-1080,216 to the corner | White, 5 px ink ring, ink 8-tooth gear r 40 | Pressed: scale 0.92 + fill #E3F0EA for 100 ms, act on release. Opens pause (GDD) |
| Place medal (not tappable) | rosette r 100, centre (540, 112); ribbon tails to y 258 | Scalloped ink-edged rosette, inner disc r 70 with 4 px ink ring, Fredoka digit 112 px ink. Fill: 1 gold + ink-edged crown, 2 silver, 3 bronze, 4-6 white | On a place change: scale 0.85 -> 1.1 -> 1.0 over 0.25 s, at most one change shown per 0.5 s (no flicker when two riders swap back and forth) |
| Progress bar (not tappable) | track x 92-930, centre y 312, 30 px tall, 6 px ink outline, radius 21 | White 92% track, sun-yellow fill from the left to the player's progress. The player's head token (r 36 + white ring) rides the fill end. Checker flag 56 px at x 964 | Fill eases 0.1 s. Only the player is on the bar: the pack is about 13% of the track wide, so rival heads would overlap into a blob (tried and cut, see `hud_parts.png` for the token art) |
| Boost button | dia 220, centre (930, 1110) = 58% height (feel target 8), hit 800,980-1060,1240 | White disc, 6 px ink ring, 22 px charge ring, ink bolt 110 px | **Charging:** sun ring fills clockwise from 12 o'clock over 10 s, rest charge_empty. **Ready:** disc fills sun-yellow, one pop 1.0 -> 1.08 -> 1.0 (0.2 s), then a slow 1 Hz scale breathe 1.00-1.04 (smooth, never a flash). **Active (2 s):** disc sun, ring empties anticlockwise. Also fires on double tap (GDD) |
| Popup word | white pill, height 120, 5 px ink edge, radius 60; centred x 540, y 640 | Fredoka SemiBold 84 px ink | Scale 0.6 -> 1.05 -> 1.0 in 0.2 s, hold 0.7 s, fade 0.2 s. One at a time; a new one replaces the old |
| Steering hint (race start only) | 180 px white hand with 5 px ink outline at y 1450 | Slides x 380-700 and back over 1.6 s | Hides on the first drag; never shown again in that session |

Every tappable target is at least 216 px, nothing tappable sits at y >= 1664, and the 232 x 232 top-left square holds only the home disc.

## 5. Layout

| Band (y px) | Content |
|---|---|
| 0-232 | Home square top-left (home disc in the stand-alone build, shell disc otherwise, nothing else). Medal top-centre. Gear top-right |
| 262-362 | Progress bar and flag |
| 380-760 | Open sky and horizon (horizon at about 33%). Popup words appear at y 580-700 |
| 760-1663 | Steering drag zone (feel target 9: lower 60%), minus the boost hit square. The player rider stands at y 910-1430 (47-74%), measured on the mock |
| 1664-1920 | Wrist strip: track only, no HUD, nothing tappable (rule 6) |

Taller phones (20:9, about 2400 px tall): top band anchors to the top, the boost button stays at 58% of the height, and the camera FOV is vertical (`keep_height`), so the extra height shows more track below the rider, never stretched art. Tablets (16:10): the canvas grows wider; side margins show more hillside; the gear and boost anchor to the right edge.

## 6. Camera, depth and motion

### 6a. Chase camera
| Setting | Value | Why |
|---|---|---|
| Offset | **4.8 m behind, 2.8 m up** the rider, along the track tangent | Measured on the mock: rider body at 47-74% of the height, horizon at about 33%, matching the RUSH framing in the feel notes (rider 50-75%, horizon 30-35%). The feel notes' first pick (4.5 m / 2.2 m / -12 deg) put the rider's head at 43% and the horizon too low; this supersedes it |
| Pitch | -14 deg | |
| FOV | 70 deg vertical (`keep_height`), near 0.3, far 450 | Fog hides the far plane |
| Follow | Position lerp 8/s, yaw lerp 5/s; the camera **never rolls** | Roll makes young children carsick |
| Air | Height follows the rider with lerp 4/s so jumps lift the rider on screen by up to 12% before the camera catches up | Sells the jump without a cut |
| Boost | FOV 70 -> 78 over 0.15 s ease-out, back over 0.4 s | Feel target 7 (80 is fine too; 78 keeps HUD-free edges calmer) |
| Finish | HUD hides, camera swings low to the side of the arch for 2.0 s (feel target 20) | |
| Reduced motion (shell "Mindre bevegelse") | No shake, no speed lines, boost FOV 70 -> 73, finish swing becomes a cut | Rule 39 |

### 6b. Effects and the flash budget
**Flash limit: at most 3 per second, never a full-screen flash** (rule 37). A "flash" is any change that brightens more than 5% of the screen by more than 20% luminance within 100 ms. A global limiter drops extra bright events inside the same 333 ms (keep their sound).

| Event | Effect | Cost |
|---|---|---|
| Boost | 8 white speed-line quads along the screen sides, 30% alpha, scrolling; a soft sun-yellow ribbon trail behind the vehicle (12 points, 1.2 m) | 2 draw calls, small additive areas |
| Pad hit | Pad arrows brighten to 1.6x for 0.2 s, 12 yellow sparkles at the wheels; pad chain x2/x3 = one popup | 1 GPUParticles3D |
| Swap gate | White cloud puff ring, 16 particles, 0.3 s (feel target 16); the vehicle swaps under it | 1 GPUParticles3D |
| Landing | 8 dirt-coloured dust puffs (skyway: white) | shared pool |
| Bump | Rival wobbles (rider roll +-12 deg, 0.5 s) and 2 small white puffs. No stars circling, no ragdoll | none |
| Shake | Only on landings with airtime over 1.2 s: 6 px for 120 ms on the camera, never on the UI | free |

## 7. Game art

### 7a. Construction and the one shader
Own Blender models only, built by `docs/mockups/src/rr_parts.py` and exported by `export_models.py` to `assets/models/` (GLB, +Y up, metres, front = Godot -Z, origin on the ground). Every model is **one mesh surface with one material** that samples the palette, so each model is one draw call.

The GLBs import with a StandardMaterial3D called `rr_kit`. Replace it with this ShaderMaterial via `material_override` (static props share one instance; each racer gets its own duplicate with its `team_color`):

```glsl
shader_type spatial;
render_mode cull_back, diffuse_lambert, specular_schlick_ggx;
uniform sampler2D palette : source_color, filter_nearest;
uniform vec3 team_color : source_color = vec3(1.0);
uniform float glow_energy = 1.6;
void fragment() {
	vec3 c = texture(palette, UV).rgb;
	vec2 cell = floor(UV * 8.0);
	float team = step(6.5, cell.y) * step(cell.x, 0.5);      // row 7, col 0
	float glow = step(5.5, cell.y) * step(cell.y, 6.5);      // row 6
	c = mix(c, c * team_color, team);
	ALBEDO = c;
	ROUGHNESS = 0.62;
	SPECULAR = 0.35;
	EMISSION = c * glow * glow_energy;
}
```
Import `rr_palette.png` with **mipmaps off, filter nearest, compression Lossless** (VRAM compression or mip blending would mix neighbouring cells).

### 7b. Models (measured on export; size is Godot x / y-up / z)

| File | Size (m) | Tris | Notes |
|---|---|---|---|
| `rider.glb` | 0.84 x 1.31 x 0.52 standing | body 2,244; identity 24-644 | Skeleton `root, hips, spine, head, arm.L/R, thigh.L/R, shin.L/R`, rigid weights. Animations (static poses): `bike`, `board`, `cheer`. Meshes: `rider_body` + six identity meshes `id_fox, id_bobble, id_shark, id_bunny, id_bear, id_unicorn` (hat on the head bone, badge on the spine bone): show one, hide five. Rider root sits at the vehicle origin, so the same rider rides both vehicles. Round-trip checked: the imported poses match the mock to 0.01 m |
| `bike.glb` | 0.74 x 1.04 x 1.65 | 1,524 | Fat toy tyres (dark), cream hubs, frame in the team cell, metal fork and bar, round cream front plate |
| `hoverboard.glb` | 0.50 x 0.17 x 1.42 | 644 | Deck top at 0.30 m. Cream deck, team rim and stripe, two dark pods with g_cyan glow discs. Add a 0.6 m additive cyan ground-glow quad under each pod in Godot (not in the GLB) |
| `boost_pad.glb` | 2.50 x 0.09 x 2.10 | 320 | Sun body, tangerine rim, three glowing white rounded play-triangles pointing forward |
| `ramp.glb` | 4.60 x 1.29 x 3.65 | 344 | Parabolic kicker, 4.4 m deck (6 rider widths, feel target 17), 1.15 m lip. Tangerine planks, wood sides, cream rails and a round cream lip |
| `swap_gate_bike.glb` | 9.00 x 8.51 x 1.00 | 2,820 | **To bike.** Tangerine round arch, cream bands, round white sign with an ink bicycle |
| `swap_gate_board.glb` | 9.00 x 6.19 x 1.00 | 2,116 | **To board.** Sky-blue flat beam, pill-shaped white sign with an ink side-view board, pods and speed lines. Gates differ by colour, arch shape and sign shape |
| `finish_arch.glb` | 11.11 x 5.50 x 1.37 | 2,752 | Inflatable-look arch, white/sun segments, two-sided checker banner, red/sun/sky/white balloon clusters, sky feet |
| `tree_round.glb` | 2.70 x 3.94 x 2.57 | 116 | Faceted crowns, baked shadow disc |
| `tree_pine.glb` | 2.44 x 4.65 x 2.39 | 92 | Three faceted tiers, baked shadow disc |
| `rock.glb` | 2.59 x 1.22 x 1.71 | 40 | Faceted boulder + small stone |

Per racer: body 2,244 + identity up to 644 + bike 1,524 = **4,412 tris** (my calc). Godot generates mesh LODs on import; check in the editor that `rider.glb` gets them (skinned mesh), else ask graphic-designer for a 1,200-tri far version.

### 7c. Track and terrain (built in Godot, not GLBs)
- **Track ribbon:** a Path3D centreline swept into a mesh in 40 m chunks, using the palette UVs per strip. Open track 6.6 m wide (about 9 bike widths), never under 3.0 m (4 widths, feel target 17).
  - Dirt section (bike): dirt, two dirt_dark ruts 0.3 m wide at +-1.3 m, round cream curb tubes (r 0.22) on both edges, pebbles (MultiMesh) in the outer 0.9 m.
  - Skyway section (hoverboard): lane, lane_dark outer bands 0.35 m, white edge lines 0.2 m, white centre dashes 3 m on / 3 m off, sky-blue rail tubes (r 0.16). Dash period 6 m at 20 m/s passes 3.3 dashes per second under the camera (lane_stripe on lane 2.1:1, my calc). Each dash is 0.2 m wide and covers under 1% of the screen, so it stays below the flash definition in 6b; never widen the dashes or add cross stripes.
  - The surface changes exactly at the swap gate: the gate marks the change, the surface confirms it.
- **Terrain:** flat-shaded chunks (3 m grid near the track, 9 m far), colour per quad from low-frequency noise (grass, grass_dark, meadow). The terrain sits 0.25 m under the track centre and banks up gently away from the curbs, then rolls into hills 10-40 m out.
- **Sky:** ProceduralSkyMaterial (colours in 2e), sun disc off, `radiance_size` 32, updated once. Far mountains: 7 faceted cones at 400-500 m, mountain colour with snow caps.
- **Clouds:** faceted cloud meshes 30-60 m up, scale 3-5, drifting 0.5 m/s.

### 7d. Lighting, fog and post (identical on Mobile and Compatibility)
| Item | Setting | Why |
|---|---|---|
| Key light | One DirectionalLight3D, colour #FFF0D2, energy 1.0, rotation_degrees (-48.6, -26.6, 0): sun behind the rider's left shoulder on the main heading. **Shadows off** | Real-time shadow is a full extra pass; at chase distance the blob shadow plus faceted shading gives the same read (four questions, 7f) |
| Ambient | Colour ambient #BFDDF2, energy 0.6; reflections from the sky at radiance 32 | Fill so the shaded sides of riders stay readable |
| Contact shadows | One unshaded alpha quad per racer (64 px radial texture, #2A4A22 at 45% centre), 1.0 x 1.9 m on a bike, 0.9 x 1.6 m on a board, raycast to the ground; airborne it shrinks to 70% and fades to 60% | Tells a child how high the rider is in a jump |
| Tree shadows | Baked in the model (shadow_grass disc) | Zero cost |
| Fog | Depth fog (`fog_mode` depth), colour #D6EEFB, begin 55 m, end 260 m, density tuned so far hills reach about 70% haze as in the mock, `fog_sky_affect` 0 | Atmospheric haze, hides pop-in |
| Tonemap | Linear, exposure 1.0; glow, SSAO, SSR, SSIL, SDFGI, volumetric fog, DOF all off | Palette shows as authored; the mock used Blender's Standard transform to match |
| Anti-aliasing | MSAA 2x on phones; on the 32-bit tablet MSAA off + FXAA, `scaling_3d_scale` 0.8 if under 60 fps | |

The tablet may lack a usable Vulkan driver; with `rendering/rendering_device/fallback_to_opengl3` on, Godot falls back to Compatibility. Nothing in this look depends on a Mobile-only feature, so the fallback looks the same.

### 7e. Phone budget (design ceilings; the PerfOverlay on the device decides)
| Item | Tablet (32-bit) | Phone |
|---|---|---|
| Draw calls in a race | **<= 60** (racers 6 x 4 = 24: body, identity, vehicle, blob; track chunks 5; terrain chunks 5; scenery MultiMeshes 5; kit 4; sky 1; particles 4; HUD about 8) | <= 80 |
| Visible triangles | **<= 70k** (racers 26.5k worst case, track + terrain 15k, scenery 10k, kit 6k, about 58k, my calc) | <= 100k |
| Textures | `rr_palette.png` 64x64 (16 KB), blob 64x64, sparkle 64x64, HUD icons atlas <= 1024x1024 | same |
| Transparency | Blob quads, speed lines, sparkles, hover glow only; never a large transparent surface | same |
| Lights | 1 directional, no shadows, no omni/spot lights | same |
| Particles | Pool of 4 GPUParticles3D (CPUParticles3D on Compatibility), <= 64 alive | same |
| visibility_range | Trees, rocks, pebbles end at 120 m with 10 m fade; pebbles at 30 m | same |
| Target | 60 fps; 30 fps is not acceptable for a racer | 60 fps |

### 7f. Four questions for the features in this spec
| Feature | Noticed at camera distance? | Phone cost | Cheaper trick | Fits spec? | Verdict |
|---|---|---|---|---|---|
| Real-time shadows | Under the rider yes, elsewhere barely | Full shadow pass | Blob quads + baked tree discs | Yes | **Cut**, use the trick |
| Bloom/glow | No: daylight scene, nothing is meant to glow except pad arrows | Post pass | Unshaded glow row in the palette | Yes | **Cut** |
| Depth fog | Yes, sets the sunny haze and hides pop-in | Cheap per-pixel | None needed | Yes | Keep |
| Rounded racers (2-4k tris) | Yes, they are the focal point | 26k tris worst case | LOD at distance | Yes | Keep |
| Faceted world | Yes, it is the style | Low | n/a | Yes | Keep |
| Speed lines on boost | Yes | 1 small additive draw | n/a | Yes | Keep; off under reduced motion |
| Per-strip track texture detail (gravel, cracks) | No at 20 m/s | Texture memory + mips | Ruts and pebbles | Yes | **Cut** |
| Animated grass | No | Vertex shader on every chunk | Static faceted patches | Yes | **Cut** |

## 8. Do and don't

- Do: keep every model on the one palette shader; add colours by filling a free palette cell, never a new material.
- Do: keep pants, tyres, gloves and visors dark on every rider (figure-ground, 2f).
- Do: keep sun yellow for "speed for you" (pads, boost, progress fill).
- Do: tell riders apart by head shape and back badge first, colour second.
- Do: change the surface at a swap gate, and only there.
- Don't: use purple, black-and-lime UI, hazard stripes, flames, skulls or knockout popups.
- Don't: flash, strobe or flicker; respect the 3-per-second limiter; no periodic high-contrast stripes in the lower screen.
- Don't: roll the camera or shake the UI.
- Don't: draw anything tappable at y >= 1664 or anything but the home disc in the top-left 232 x 232.
- Don't: share this game's look with other MWM games.

## 9. Do NOT copy from RUSH: Xtreme

We copy the **genre and the feel only** (hold-to-ride, steering by drag, boost button at the right edge, pads, kickers, mid-race vehicle swap, race length, chase camera). Nothing below may appear in this game:

1. **Name and words:** "RUSH", "Xtreme", "SayGames", and their popup and screen words: "OWNED!", "OUTTA HERE!", "SLAMMED!", "NAILED IT!", "CLEAN!", "INSAAANE!", "AIRTIME +N", "BOOSTER +N", "2x/3x BOOSTER", "HOLD TO RIDE", "UP NEXT", "KEEP PLAYING TO UNLOCK", "POWER". Our words come from the GDD and must be our own.
2. **Characters:** their human riders with realistic proportions, wardrobe items (helmets, tops, bottoms, shoes), rider names and floating rank-and-name tags over rivals.
3. **Palette and effects:** lime-green boost ring and lightning, black/lime UI, green chevron pads, blue neon pads, cyan arrow pads, red hazard-stripe bars at the screen edges on boost, orange flame streaks behind the wheels, blue lightning aura, heavy motion blur.
4. **UI layout:** "xx/09" rank text, the race timer readout, the lobby, the garage with Frame/Fork/Shocks/Wheels upgrade bars, the FINISHED table, the multiplier wheel, teaser cards, "!" and "1" tab badges.
5. **Tracks and biomes:** their desert canyons, wooden plank ramps with chevrons, shipping containers, X-crates, spiked hoops, helicopter props, tunnels, ice tunnel, city rooftops, and any of their track layouts.
6. **Vehicles:** their mountain bike, skateboard/longboard, jet wing, glider wings in the air, and their skins.
7. **Sounds and music:** none of theirs. Our music is the owner's track (CREDITS.md).
8. **Monetisation look:** banner strips, rewarded-video icons, offer pop-ups, countdown badges, "%" promo badges, shop tabs.

Allowed because it is feel, not look: a round boost button at the right edge at about 58% height, a chase camera behind the rider, automatic swap at a gate, finish-gate shot.

## 10. Store assets (later, not part of the slice)

- **Icon (512x512):** the fox rider's head (helmet, ears, visor with two eye shines) leaning into a turn on the red bike, a sun-yellow speed swoosh behind, sky gradient with one faceted cloud. No text. Check at 48 px: one head, one bike.
- **Feature graphic (1024x500):** three riders (fox, bunny, unicorn) in the air off the tangerine kicker, the finish arch on the right, the green hills and sky. Name in Fredoka SemiBold on the sky, ink with a white outline. No "Best / #1 / Free".
- **Screenshots (game-qa capture bot, never mock-ups):** this mock's moment (pad ahead, pack ahead); the swap gate as the player rides through it; the airborne cheer pose off a kicker; the finish arch shot.

## 11. Visual tier

**Premium stylized 3D.** The hero scene is the first 50 m of the slice track as in `track_mock.png`: dirt with pads and a kicker, then the swap gate onto the skyway. Mats signs it off from the builder's real Godot screenshot (not this mock) before more track is built; the rest of the track copies its lighting, fog, camera and materials.

Rebuild commands (from the game folder):
```
blender -b -P docs/mockups/src/export_models.py -- docs/mockups/src/kit_sheet_raw.png
blender -b -P docs/mockups/src/track_mock.py -- docs/mockups/src/track_raw.png
python3 docs/mockups/src/hud_overlay.py docs/mockups/src/track_raw.png docs/mockups/track_mock.png --zones docs/mockups/track_zones.png
python3 docs/mockups/src/hud_parts.py docs/mockups/hud_parts.png
```
`export_models.py` also rewrites `assets/textures/rr_palette.png` from the palette in `rr_parts.py`; change colours there, never in the PNG.

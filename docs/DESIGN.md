# MWM Race Riders: visual design spec

Owner: graphic-designer. Version 2, 2026-10-06 (replaces the toy look of version 1, which the owner rejected: "graphics is way too bad. Should be more modern high end realistic"). The builder reads this before touching any model, material, light, camera or UI node. Game rules and numbers live in `docs/GDD.md`; this file owns the look. Numbers tagged (my calc) are my own arithmetic.

Mockups (rendered in Blender 4.5 EEVEE from the exported GLBs and real textures, with the game camera; HUD drawn by `tools/art/hud_overlay.py`):

| File | What it shows |
|---|---|
| `docs/mockups/realistic_mock.png` | World 1 "Furuløypa / Pine Run", 1080x1920: behind the player (#7, 4th), boost pad P2 ahead, rivals #23, #12, #31 ahead, course tape, swap gate G1 in the distance, full HUD |
| `docs/mockups/realistic_zones.png` | Same frame with the HUD zones: home square (white), gear and boost hit areas (green), wrist strip (red) |
| `docs/mockups/realistic_mock_w2.png` | World 2 "Ørkenjuvet / Red Canyon": sandstone canyon, water tower, tumbleweed, sand drift, rivals #4, #88, #23, Vanlig race time |

Everything is rebuilt by the scripts in `tools/art/` (commands in section 14). Raw CC0 downloads live in `assets/_raw/` (not in git). Licences: `CREDITS.md`.

---

## 1. Visual theme

**A real downhill race on a phone: real-proportion racers in full-face helmets and numbered jerseys on real downhill bikes, racing through scanned terrain under a real sky. Each world is a different real place with its own light, ground, props and weather.**

References (take the idea, not the assets):
- **Descenders (RageSquid):** riders read as real athletes from behind (helmet, jersey, baggy pants, bike geometry), dusty sunlit trails lined with tape. We take the rider silhouette, the course tape and the warm trail dust; we leave its procedural low-detail terrain.
- **Riders Republic (Ubisoft):** race-event dressing (aluminium truss arches, banners, numbered racers) in real landscapes, and a clean, thin HUD. We take the truss-arch event look and the HUD restraint; we leave its saturated cartoon-leaning colour grade and brand clutter.

Rules of the look:
1. **Real materials only.** Every surface is PBR (albedo, normal, roughness/AO/metal) from a scan or measured values. No flat colours, no faceting, no palette textures.
2. **Real proportions.** Riders are 1.69 m adults; bikes have 29 in wheels, a 63 deg head angle, 1.28 m wheelbase; gates are 6 m truss.
3. **Rivals look serious.** Racing posture (attack position), no mascots, no animal hats, no smiling faces (faces are behind visors).
4. **Light does the work.** HDRI sky plus a matching sun with real shadows; depth fog for distance. Spend the phone budget on the racers and the first 40 m of track.

## 2. Shared kit: racers and vehicles

### 2a. The six racers (colour is never the only cue: number + helmet design differ too)

| Id | Jersey | Godot Color | Number (back, chest, helmet back) | Helmet design | Number colours (fill / outline) |
|---|---|---|---|---|---|
| r1 (player default) | Crimson #C8202B | Color(0.784, 0.125, 0.169) | **7** | Matte black, crimson centre stripe + white pinstripes | white / black |
| r2 | Amber #F2A900 | Color(0.949, 0.663, 0.000) | **12** | Split: left amber, right black | black / white |
| r3 | Cobalt #1E5BD6 | Color(0.118, 0.357, 0.839) | **23** | White with a cobalt diagonal slash | white / navy |
| r4 | Emerald #0F8F6E | Color(0.059, 0.561, 0.431) | **31** | Emerald with a black/white chequer band | white / dark green |
| r5 | Ice white #E9ECEF | Color(0.914, 0.925, 0.937) | **4** | White with twin red stripes | black / red |
| r6 | Graphite #2A2E35 | Color(0.165, 0.180, 0.208) | **88** | Graphite fading to orange at the rim, dot band | white / orange |

Every racer: dark pants #1C1E22 with a jersey-colour side stripe, gloves in the jersey colour, black shoes with a grey midsole, goggles with an amber mirror lens. The dark pants and shoes give figure-ground on every surface (4.0:1 or more against both trail textures, my calc on the mock pixels).

Colour-blind check (my calc, Machado 2009 full severity, minimum CIELAB distance between the six jersey colours): normal 54.4 (r4-r6), protan 23.5 (r1-r4), deutan 34.2 (r4-r6), tritan 22.1 (r3-r4). Closest pairs still differ by number and helmet pattern.

### 2b. Models (sizes in Godot axes x / y-up / z; front = -Z; origin on the ground)

| File | Size (m) | Tris | Nodes, bones, animations |
|---|---|---|---|
| `rider.glb` | 0.88 x 1.80 x 0.45 (rest A-pose) | 6,216 | One skinned mesh `rider_body`, one material. Skeleton `rider_rig`: `root, hips, spine, chest, neck, head, shoulder.L/R, upper_arm.L/R, forearm.L/R, hand.L/R, thigh.L/R, shin.L/R, foot.L/R`. Helmet and goggles are weighted 100% to `head`. Animations (30 fps): `bike` (attack position, hands on the real grips, feet on the real pedals), `cheer` (fist pump, finish), `trick_nohands`, `trick_superman`, `board` (sideways stance), `board_grab`, **`fall`** (1.2 s over-the-bars tumble, ends on the back, feet downhill, body travels 2.2 m forward and 0.4 m sideways), **`lying`** (static end pose of `fall`), **`getup`** (1.0 s: sit up, kneel, stand; ends standing beside the fall spot at +0.4 m x, +2.6 m forward) |
| `bike.glb` | 0.81 x 1.09 x 2.04 | 6,870 | One skinned mesh, one material. Bones: `root, frame, fork, wheel_front, wheel_rear, crank`. Wheel and crank bones point along +X, so spin = rotate the bone about its own Y. `fork` steers about the head-tube axis. Animations: `ride` (rest), **`crash`** (0.5 s: bike tips onto its left side and slides 1.0 m), **`lying`** (on its side, bar turned 25 deg) |
| `hoverboard.glb` | 0.38 x 0.23 x 1.32 | 1,208 | Carbon deck with kicktails, grip top, team-colour rail, two hover pods with an emissive ring. Deck top at y 0.30 (the rider's `board` pose stands on it) |

Livery textures: `assets/textures/rider/rider_r1..r6_albedo.png` (1024), shared `rider_normal.png`, `rider_orm.png`; `assets/textures/bike/bike_r1..r6_albedo.png` (1024), shared `bike_orm.png`; `assets/textures/kit/hoverboard_r1..r6_albedo.png` (512). The GLBs embed the r1 set. **To dress a racer, swap only the albedo texture** on a duplicate of the imported material; normal and ORM stay shared.

Godot setup for the racers:
- Import: `rider.glb`, `bike.glb` with *Meshes > Generate LODs* on, *Skins* on. The importer makes LODs for the skinned meshes; check that LOD1 lands near 50%.
- Material: StandardMaterial3D, `albedo_texture` = livery, `normal_enabled` + `normal_texture`, ORM via `ao_texture` (R) + `roughness_texture` (G, channel Green) + `metallic_texture` (B, channel Blue), `ao_light_affect` 0.6. Do not add rim light; the HDRI ambient and the sun read the shapes.
- Ragdoll (optional, instead of `fall` on Høy): `PhysicalBoneSimulator3D` with `PhysicalBone3D` on `hips` (box 0.34 x 0.22 x 0.25), `spine`, `chest` (capsules r 0.15), `head` (sphere r 0.16, includes the helmet), `upper_arm.*`, `forearm.*` (capsules r 0.05), `thigh.*` (r 0.08), `shin.*` (r 0.06). Joint limits: cone 40 deg on the arms, hinge 0 to 130 deg on the knees and elbows. Blend the ragdoll back into `lying`, then play `getup`. On Lav, always use the authored `fall`.

### 2c. The knock-off (GDD 4.7) in pictures
| Time from hit | Rider | Bike | FX |
|---|---|---|---|
| 0-0.5 s | `fall` frames 0-15 (thrown forward and sideways) | `crash` | **Dust burst** at the contact point (section 7) and 6 small stones |
| 0.5-1.2 s | `fall` frames 15-36, ends in `lying` | `lying` | Dust settles |
| 1.2-1.7 s | `getup` (scaled to 0.5 s, GDD `GETUP_S`) | Lifted: blend `lying` to `ride` over the last 0.25 s while the rider steps back on (cut to `bike` pose at 1.7 s) | none |

No stars, no skull, no comic sound words. The tumbling-bike HUD icon (GDD section 11) is a white side-view bike tilted 60 deg in the rider's token colour ring.

### 2d. Shared track kit

| File | Size (m) | Tris | Look | Texture |
|---|---|---|---|---|
| `boost_pad.glb` | 3.00 x 0.08 x 4.00 | 864 | Steel-framed rubber plate with three amber LED chevrons pointing forward (-Z) | `kit/boost_pad_*` 512 + `boost_pad_emission.png` |
| `ramp.glb` | 4.60 x 1.29 x 3.68 | 2,488 | Plank kicker: boards across the track on timber stringers, steel lip bar. Deck length 3.65 m, lip 1.15 m (matches `RrBalance.KICKER_LEN_M` / `KICKER_LIP_M`) | `kit/ramp_*` 1024 |
| `swap_gate.glb` | 12.20 x 6.60 x 0.70 | 2,484 | Aluminium box-truss arch, 11.2 m span. Bike icon on the left pillar banner, hoverboard icon on the right, white LED strips on both legs and along the header (the swap "light run") | `kit/swap_gate_*` 1024 + emission |
| `finish_arch.glb` | 15.66 x 7.40 x 0.98 | 2,740 | 13.6 m truss arch, chequered header banner (both faces), chequered leg banners, two flag poles. No text | `kit/finish_arch_*` 1024 |

Dormant gate (race 1): set the emission energy to 0 (icons stay white fabric). Active: emission energy 1.5; the light run animates the emission along the strips (shader `UV.y` mask, 0.3 s), never a full flash.

## 3. UI chrome palette (HUD, all worlds)

| Token | Hex | Godot | Use |
|---|---|---|---|
| ink | #14171C | Color(0.078, 0.090, 0.110) | Disc fills (88-92% alpha), progress track, place-disc ring, digits |
| white | #FFFFFF | Color(1, 1, 1) | Icons, 4 px disc rings, player token ring |
| amber | #FFB000 | Color(1.000, 0.690, 0.000) | "Speed for you" only: progress fill, boost charge ring, LED chevrons on pads |
| gold / silver / bronze | #F2C14E / #C9CED6 / #C98A55 | (0.949, 0.757, 0.306) / (0.788, 0.808, 0.839) / (0.788, 0.541, 0.333) | Place disc 1 / 2 / 3; 4-6 white |
| rider tokens | the six jersey colours (2a) | | Progress-bar tokens with the rider's number |

No purple anywhere in UI chrome. No glass blur, no glow halos, no gradients on the HUD.

## 4. Typography

**Barlow Condensed** (SIL OFL 1.1, `assets/fonts/BarlowCondensed-*.ttf` + `BarlowCondensed-OFL.txt`): ExtraBold Italic 84 px for the place digit, Bold 22 px (rival tokens) and 32 px (player token) for numbers, SemiBold 40 px for the Vanlig race time. Digits are the only HUD text (GDD 10.1). Fredoka is retired with the toy HUD.

## 5. HUD (positions from GDD 10.1 and 3.1; px at 1080x1920)

| Element | Place and size | Look | States |
|---|---|---|---|
| Home disc (stand-alone only) | dia 136, centre (104, 104); hit 0-216 | Ink disc, 4 px white ring, white house 60 px | Shell rules unchanged |
| Gear | dia 136, centre (976, 104); hit to the corner | Ink disc, 4 px white ring, white 8-tooth gear r 34 | Pressed: scale 0.92 for 100 ms |
| Progress bar | x 260-820, y 250-286 | Ink rounded bar 26 px with a 14 px track (white 27%), amber fill to the player. Rival tokens dia 34 in jersey colour, 3 px ink ring, number 22 px. Player token dia 52, 5 px white ring, number 32 px, white pointer below. Chequered flag at the right end | Tokens ease 0.1 s. Pack tokens overlap when close; the player token is always drawn on top |
| Place disc | dia 110, centre (540, 350) | Gold / silver / bronze / white disc, 5 px ink ring, 2 px inner white line, ink digit 84 px | On change: scale 0.85 -> 1.08 -> 1.0 over 0.25 s, max one change per 0.5 s |
| Race time (Vanlig) | centre (780, 350) | White 40 px on an ink chip (78% alpha), radius 10 | Updates every 0.1 s |
| Boost disc | centre (540, 1490), dia 220, hit dia 280 | Ink disc, 4 px white outer ring, 14 px charge ring (white 24% empty, amber filled, clockwise from 12), white bolt 112 px | Ready: ring full amber, one 1.0 -> 1.06 -> 1.0 pop, then a 1 Hz breathe 1.00-1.03. Active: ring empties anticlockwise over the boost |

Every disc has a soft drop shadow (black, 45% alpha, 10 px blur, 4 px down) so it holds on bright sky and on dark forest. Nothing tappable at y >= 1664; the 232 x 232 top-left square holds only the home disc.

Contrast (my calc, WCAG 2.x on the rendered mock pixels behind each element):

| Pair | World 1 | World 2 | Need |
|---|---|---|---|
| White icon / bolt on ink disc | 18.0:1 | 18.0:1 | 3.0 |
| Ink digit on place disc (white) | 18.0:1 | 18.0:1 | 4.5 |
| Ink digit on gold / silver / bronze | 10.7 / 11.4 / 6.2:1 | same | 4.5 |
| Amber fill / charge ring on ink | 9.8:1 | 9.8:1 | 3.0 |
| Gear disc edge vs what is behind it (ink disc / white ring) | 7.8 / 2.3:1 | 3.1 / 5.8:1 | 3.0 (one edge) |
| Ink bar vs background behind the bar | 4.1:1 | 4.9:1 | 3.0 |
| Place disc (white) vs background behind it | 4.1:1 | 3.3:1 | 3.0 |
| Boost disc edge vs trail behind it (ink disc / white ring) | 4.0 / 4.5:1 | 2.1 / 8.6:1 | 3.0 (one edge) |

On the red World 2 trail the ink disc alone is 2.1:1, so the 4 px white ring is required on every disc; never remove it.

## 6. Lighting, sky and post (Godot 4.6, Mobile renderer)

Available on Mobile and used: DirectionalLight3D with PSSM shadows, sky (PanoramaSkyMaterial), ambient and reflected light from the sky, depth fog, tonemap, glow, MSAA, FXAA, Decal, ReflectionProbe (not needed). **Not available on Mobile:** SSAO, SSIL, SSR, SDFGI, VoxelGI, volumetric fog. Do not try to fake them with extra passes; the baked AO in every ORM texture stands in for SSAO.

| Item | Høy (default) | Lav (32-bit tablet) |
|---|---|---|
| Sky | `PanoramaSkyMaterial`, panorama = the world's 2K HDRI (`assets/textures/worldN/sky_*.hdr`, import as *Texture2D*, VRAM uncompressed half float), `energy_multiplier` 1.0. `Sky.radiance_size` 256, `process_mode` Automatic | Same HDRI; `radiance_size` 64 |
| Ambient | `ambient_light_source` Sky, `ambient_light_energy` 1.0, `reflected_light_source` Sky | Same |
| Sun | DirectionalLight3D aimed to match the HDRI sun (per world, sections 9-10), `light_energy` 1.6, `shadow_enabled`, PSSM 2 splits, `directional_shadow_max_distance` 60 m, shadow atlas 2048, `shadow_blur` 1.5 | `shadow_enabled` off; racers use the contact-shadow quad (`assets/textures/fx/contact_shadow.png`) |
| Who casts shadows | Racers, kit (gates, ramps, hay, pads off), trees within 40 m (cards cast alpha-scissor shadows), rocks | Nothing |
| Tonemap | **ACES**, `tonemap_exposure` 1.0, `tonemap_white` 6.0 (the mock used Blender AgX; Godot 4.4+ also has AgX: if the builder's screenshot looks harsher than the mock, switch to AgX and keep everything else) | Same |
| Glow | On, intensity 0.4, `glow_hdr_threshold` 1.2, levels 3-4 only: lights LEDs, pad chevrons and the hover ring, nothing else | Off |
| Fog | `fog_mode` Depth, `fog_depth_begin` per world, `fog_depth_end` per world, `fog_light_color` per world, `fog_sky_affect` 0.12, `fog_density` 1.0 (depth curve 1.0) | Same (cheap per pixel) |
| Adjustments | Off (the HDRI and textures carry the colour) | Off |
| Anti-aliasing | MSAA 2x | MSAA off, FXAA on, `scaling_3d_scale` 0.8 when under 60 fps |

Note on the sun: the race direction is Godot -Z. Put the HDRI sun **behind the camera, over its right shoulder**, so the racers' backs and the forest in front are lit (the mock was first rendered against the sun: backlit pines turn black and the jersey numbers die). Set `DirectionalLight3D.rotation_degrees` per world and rotate the sky (`Environment.sky_rotation.y`) until the sun disc in the panorama sits on the same yaw (check with the sun gizmo in the editor; the HDRI sun pixels are given per world).

## 7. FX (one pool of GPUParticles3D, CPUParticles3D on Compatibility; textures in `assets/textures/fx/`)

| Event | Effect | Budget |
|---|---|---|
| Rolling (every racer) | 2 `dust_puff` billboards per second behind the rear wheel, colour = the world's trail dust, alpha 0.16, size 1.1 -> 2.0 m, life 0.8 s | <= 12 alive per racer |
| **Knock-off dust burst** (GDD 4.7) | 20 `dust_puff` particles in a 1.5 m ring at the contact point, upward 1.5-3 m/s, drag 2, alpha 0.35 -> 0, size 0.8 -> 2.4 m, life 0.9 s, trail-dust colour; plus 6 small stones (instance `rock_c` at 0.06 scale) thrown 2-4 m/s with gravity. Realistic dust only: no stars, no impact rings, no screen shake for rival falls | 26 particles, one burst at a time |
| Landing | 10 dust puffs, alpha 0.25 | shared pool |
| Pad hit | Pad emission energy 1.5 -> 3.0 for 0.2 s, 8 amber sparks | shared |
| Boost | 6 `speed_streak` quads at the screen sides, white 22% alpha, scrolling; FOV 70 -> 78 | 1 draw |
| Swap gate | LED light run down the arch 0.3 s; 16 white dust puffs at the vehicle | shared |
| Hoverboard | Cyan-white ring glow under the pods (emission), one additive `contact_shadow`-shaped glow quad tinted #8FDFFF at 25% | 1 draw |
| Hindrances | Hay: 20 straw-coloured flakes (`pollen` sprite tinted #D8C089). Mud: 12 dark-brown droplets + darker mud decal on the rider's tyres is not needed. Sand drift: sand puffs. Tumbleweed burst: 16 twig flakes | shared pool |

Flash rule (GDD rule 37) holds: at most 3 bright events per second, never a full-screen flash.

## 8. Camera (unchanged)

4.8 m behind, 2.8 m up, pitch -14 deg, vertical FOV 70 (`keep_height`), near 0.3, far 900 (raised from 450 so the HDRI mountains and canyon rims are not clipped; fog hides the far plane). Follow lerps, boost FOV and finish swing as in GDD; never roll.

## 9. World 1: "Furuløypa / Pine Run" (alpine pine forest, summer afternoon)

**Mood:** a real Norwegian-alpine race trail: packed brown dirt with stones, red-and-white course tape on stakes, tall pines, a hazy valley wall behind.

| Layer | Asset | Godot |
|---|---|---|
| Sky | `world1/sky_alps_field_2k.hdr` (Poly Haven alps_field; sun pixel u 0.600, v 0.267 from the top, elevation 42 deg) | Sun `rotation_degrees` (-42, -12, 0), colour #FFF1DC Color(1.000, 0.945, 0.863) |
| Fog | depth begin 30 m, end 450 m, colour #9EB3C7 Color(0.620, 0.702, 0.780), max mix about 42% at the end | |
| Trail (bike sections) | `terrain_rocky_trail_02_*` (2K), tile 3.2 m | Splat layer R |
| Verge | `terrain_forest_leaves_04_*` (pine needles), tile 3 m | |
| Forest floor | `terrain_forest_ground_04_*`, tile 4 m | Base layer |
| Grass patches | `terrain_sparse_grass_*`, tile 3 m | Splat layer B |
| Rock faces / tunnel | `terrain_rocky_trail_*` triplanar, tile 4 m | Splat layer G |
| River road (hoverboard section, s 300-600) | `terrain_gravel_floor_02_*`, tile 2.5 m; the boardwalk uses the `weathered_planks` ramp texture | |
| Trees | `tree_pine_a/b/c.glb` (Poly Haven pine scans rendered into 4-plane impostors, 8 tris each, 10-21 m tall), random yaw and 0.7-1.2 scale | MultiMesh per 100 m chunk and kind; alpha scissor 0.5, cull disabled; `visibility_range_end` 220 m (Høy) / 120 m (Lav) |
| Undergrowth | `grass_card.glb` (6 tris), `fern.glb` (900 tris), `rock_a/b/c.glb` (400-600 tris) | Grass: MultiMesh, visibility 30 m (Lav 15 m). Fern: visibility 35 m. Rocks: visibility 120 m |
| Course edge | `tape_stake.glb` every 4 m on both edges at the rail (x = +-(width/2 + 0.7)) | One MultiMesh per chunk |
| Hindrances | `hay_bale.glb` (Block), `mud_puddle.glb` (Patch; vertex alpha fades the edge, glossy roughness 0.1) | Mud: transparent material, `render_priority` -1, no shadow |
| Farm fences | `fence_rail.glb` (4 m sections) where the GDD narrows the track (Bratthenget) | |
| Weather | Pollen: 300 `pollen` sprites (white 35%, 2-4 cm) drifting in a 30 m box around the camera; falling needles: 80 thin brown streaks. Sun shafts: 6 additive vertical cards (`speed_streak` stretched, #FFF1DC at 6%) between the trees on the sunny side, only in Høy | <= 400 particles |
| Landmarks (to build next) | Log cabin, wooden river bridge, rock tunnel, cowbell meadow at the finish: not modelled yet | |

**World 1 palette (60/30/10, measured from the textures, my calc):** 60% earth and trail (#876B51 trail, #815E3A needles), 30% forest (#403E2C pine crowns, #4F3D15 grass) and sky (#9EB3C7 haze), 10% racers, tape red #D2232A and the amber pads.

## 10. World 2: "Ørkenjuvet / Red Canyon" (desert canyon, hard midday sun)

**Mood:** a dry wash between layered red sandstone walls, a rusty water tower, dry brush and tumbleweeds, heat haze on the far rocks. Clearly a different place from World 1: warm red ground, deep blue sky, no trees, hard short shadows.

| Layer | Asset | Godot |
|---|---|---|
| Sky | `world2/sky_goegap_2k.hdr` (Poly Haven goegap, hard sun; sun pixel u 0.608, v 0.242 from the top, elevation 46 deg) | Sun `rotation_degrees` (-46, 15, 0), colour #FFF6E8 Color(1.000, 0.965, 0.910), `light_energy` 1.9 |
| Fog (heat haze tint) | depth begin 50 m, end 650 m, colour #D1B394 Color(0.820, 0.702, 0.580), max mix about 30% | |
| Trail | `terrain_red_laterite_soil_stones_*` (2K), tile 3.2 m | Splat R |
| Sand floor | `terrain_red_sand_*`, tile 3-4 m | Base |
| Canyon walls | `terrain_cliff_side_*`, **triplanar** (`uv1_triplanar` / world-position box projection), tile 9 m; walls are terrain rising from 16 m off the centre line in 4.5 m strata ledges up to about 50 m | Splat G by slope |
| Old rim highway (hoverboard section) | `terrain_worn_asphalt_*`, tile 4 m, faded white edge line as a Decal | |
| Fallen blocks | `rock_a/b/c.glb` at 1.5-3.5x scale along the wall foot, `albedo_color` Color(1.25, 0.62, 0.42) multiplies the grey scan to sandstone | |
| Brush | `bush_desert.glb` (Poly Haven wild rooibos rendered to a 3-plane impostor, 6 tris), `dead_trunk.glb` (1,200 tris) | Bush MultiMesh, visibility 120 m |
| Landmarks | `water_tower.glb` (14 m, rusty steel, start grid and finish). Sandstone arch, gas station and mining-town fronts: not modelled yet | |
| Kicker skin | `ramp_rock.glb` (sandstone lip, same footprint as `ramp.glb`) for K1 "rock lip"; K4 uses `ramp.glb` (wooden loading ramp) | |
| Hindrances | `sand_drift.glb` (Patch, pale wind-rippled sand, vertex-alpha edge, 15 x 4 m), `tumbleweed.glb` (Roller, 1.2 m, rotate about its centre 0.6 m up while it rolls) | |
| Weather | Blowing sand: 200 `sand_streak` sprites (#E2B48C, 20%) moving across the track with the wind; 2 distant dust devils (spiralling `dust_puff` columns, 40 particles each) on the canyon floor 150 m+ ahead | <= 300 particles |

**World 2 palette (my calc):** 60% red earth (#643E2E trail, #805945 sand, #7B5231 cliff), 30% sky (#3F6DB5) and pale rock, 10% racers and amber pads.

## 11. Worlds 3-6 (direction only; kits are built when their section tables land)

| World | Sky (Poly Haven, CC0) | Ground and walls | Signature props |
|---|---|---|---|
| 3 Glacier Run | `snowy_hillside` or a clear-sky snow HDRI | Snow and blue ice (scan textures + a cheap fresnel ice shader, no refraction) | Glacier hut, ladder bridge, flag poles, blue seracs |
| 4 Ash Mountain | A dim hazy HDRI tinted warm, sun low | Black ash, basalt, cooled lava (lava glow only behind rails, emissive) | Crater cone, basalt columns, research station |
| 5 Rainforest | A forest HDRI after rain | Wet mud, moss, river stones (roughness 0.2-0.4 for wet) | Waterfall (scrolling alpha cards), rope bridge, buttress roots, stone ruins |
| 6 Night Harbour | A night or dusk HDRI with low energy | Wet steel and asphalt (roughness 0.25), container scans | Containers, gantry cranes, sodium lamps (emissive cards, no real lights beyond 2 omni near the track) |

Each world keeps the same phone budget (section 12) and swaps only its texture set, HDRI, prop GLBs and particle textures; the racers and the kit are shared.

## 12. Phone budget (Høy = mid-range phone, 60 fps; numbers are my calc for the mock frames)

| Item | Høy ceiling | Estimate, World 1 frame | Estimate, World 2 frame | Lav |
|---|---|---|---|---|
| Draw calls | <= 100 | about 82: racers 6 x 2 = 12, their shadow pass 12, terrain chunks 6, tree MultiMeshes 4 chunks x 3 kinds = 12, grass + fern 8, rocks 3, stakes 2, kit 6, sky 1, particles 3, contact quads 1, HUD about 10, plus 6 spare | about 62 (no trees; bushes 4, rocks 3) | <= 60: shadow pass off (-12), grass off beyond 15 m |
| Visible triangles | <= 200k | about 160k: player rider + bike LOD0 13.1k, 5 rivals at LOD1 about 33k (78.6k worst case all LOD0), terrain 18k, trees 600 x 8 = 4.8k, grass 400 x 6 = 2.4k, rocks 40 x 530 = 21k, ferns 12 x 900 = 11k, stakes 80 x 44 = 3.5k, kit 8k, shadow pass racers about 46k | about 120k | <= 90k (no shadow pass, rivals LOD1, ferns off) |
| Texture memory | <= 150 MB | about 82 MB (ETC2/ASTC with mips; 1024 RGB = 0.67 MB, 2048x1024 RGBA = 2.7 MB): racers 5.3, bikes 4.7, hoverboards 1.5, kit 7.4, trees 16, grass + fern 3.3, rocks 2, terrain layers 14, sky HDRI 16 (half float) + radiance 3, FX 1, HUD + fonts 4, spare 4 | about 70 MB | Same files; set *Lav* `mipmap bias` +1 (halves the sampled size, not the memory). For the 32-bit tablet, re-import the trail textures at 1K if memory runs short |
| Lights | 1 directional with shadows | | | 1 directional, no shadows |
| Transparency | Mud, sand drift, dust, sand streaks, contact quads; trees and grass are alpha *scissor* (opaque pipeline) | | | Same |

Import settings: every albedo / ORM / normal PNG and JPG as VRAM Compressed (ETC2 on Android; `rendering/textures/vram_compression/import_etc2_astc` is already on), mipmaps on, normal maps with *Normal Map* = Enable. The tree and grass atlases: *Fix Alpha Border* on, mipmaps on, alpha scissor material. HDRIs: no VRAM compression.

## 13. Four questions for the features in this spec

| Feature | Noticed at camera distance? | Phone cost | Cheaper trick | Fits the spec? | Verdict |
|---|---|---|---|---|---|
| Real-time sun shadow on racers | Yes: grounds the racer, shows the jump height | One PSSM pass over racers and kit (about 12 draws, 46k tris) | Contact quad (used on Lav) | Yes | **Keep on Høy** |
| PBR normal maps on racers and kit | Yes on the player and the nearest rivals | One extra sample per pixel | none needed | Yes | Keep (Lav keeps them on racers only) |
| Scanned 2K trail texture | Yes: the trail fills half the screen | 2.7 MB | 1K looks soft under the camera | Yes | Keep |
| Impostor trees (8 tris) | Yes as a forest; flat only if you look straight down | Tiny | Mesh trees would cost 1-7 million tris each | Yes | **Keep**; never use the raw Poly Haven pines in game |
| Glow | Only on LEDs, pads and the hover ring | One post pass | Emission without glow | Yes | Høy only |
| Volumetric fog / god rays | Would be noticed | Not on Mobile | Depth fog + 6 additive sun-shaft cards | Yes | Use the trick |
| SSAO | Barely at chase distance | Not on Mobile | Baked AO in every ORM | Yes | Use the trick |
| Grass cards beyond 30 m | No | Overdraw | Grass splat layer in the terrain | Yes | **Cut** beyond 30 m |
| Motion blur | Would read as speed | Not cheap on Mobile | Dust, speed streaks on boost, FOV kick | Yes | Use the trick |

## 14. Do and don't

- Do: dress racers only by swapping the albedo texture; keep the shared normal and ORM.
- Do: keep pants, shoes and gloves' palms dark on every livery (figure-ground on bright trails).
- Do: keep amber for "speed for you": pads, boost ring, progress fill.
- Do: keep the white 4 px ring on every HUD disc.
- Do: put the sun behind the camera on the main heading in every world.
- Do: give every world its own HDRI, ground set, props and particles; share only racers, vehicles and the kit.
- Don't: bring back flat colours, faceted shapes, cartoon proportions, animal hats or friendly faces.
- Don't: use purple in UI chrome; don't add glass blur or glow halos to the HUD.
- Don't: use the raw Poly Haven tree or boulder meshes in the game (millions of tris).
- Don't: flash, strobe, shake the UI, or roll the camera.
- Don't: draw anything tappable at y >= 1664 or anything but the home disc in the top-left 232 x 232.

## 15. Do NOT copy from RUSH: Xtreme (legal line, owner)

We copy the genre feel only. Realistic human racers are now our own look (owner, 2026-10-06), but nothing below may appear: their names, words and popups ("OWNED!", "SLAMMED!", "AIRTIME +N", "HOLD TO RIDE", and the rest of the version-1 list); their character designs, wardrobe sets, rider names and floating name tags; lime-green boost ring and lightning, black/lime UI, green chevron pads, hazard-stripe bars, flame streaks, heavy motion blur; "xx/09" rank text, their garage, tables and lobby; their canyons, plank ramps with chevrons, containers, X-crates, spiked hoops and track layouts; their vehicles and skins; their sounds; any monetisation look. Our pads are amber LED plates, our ranks are a place disc, our canyon is our own layout from the GDD.

## 16. Rebuild (from the game folder; Blender 4.5, `-b` keeps every window closed)

```
python3 -I tools/art/fetch_polyhaven.py                  # CC0 downloads -> assets/_raw/ (+ ambientCG thatch, Human Base Meshes: see CREDITS.md)
python3 tools/art/make_decals.py && python3 tools/art/make_fx.py
blender -b --factory-startup -P tools/art/build_rider.py -- --stage all
blender -b --factory-startup -P tools/art/build_bike.py
blender -b --factory-startup -P tools/art/build_kit.py
blender -b --factory-startup -P tools/art/build_nature.py
blender -b --factory-startup -P tools/art/mock_world.py -- 1 assets/_raw/build/mock_w1_raw.png
python3 tools/art/hud_overlay.py assets/_raw/build/mock_w1_raw.png docs/mockups/realistic_mock.png --place 4 --progress 0.206 --zones docs/mockups/realistic_zones.png
blender -b --factory-startup -P tools/art/mock_world.py -- 2 assets/_raw/build/mock_w2_raw.png
python3 tools/art/hud_overlay.py assets/_raw/build/mock_w2_raw.png docs/mockups/realistic_mock_w2.png --place 4 --progress 0.20 --time 0:09.8
```
Pose check sheet: `blender -b --factory-startup assets/_raw/build/rider_rigged.blend -P tools/art/preview_poses.py -- <out_dir>`.

## 17. Visual tier and sign-off

Premium realistic 3D. The hero scene is World 1, s 180-320 as in `realistic_mock.png`. The owner signs it off from the builder's **real Godot screenshot** (not this mock) before more track is built; World 2 follows from its own screenshot. What is still below the bar is listed in the graphic-designer's report of 2026-10-06 and in section 18.

## 18. Known gaps (not yet realistic)

- Trees are 4-plane impostors: perfect as a forest wall, but a tree right beside the camera can look flat when the camera yaws fast. Fix later with 2-3 near "hero" pines made of branch cards (about 1.5k tris).
- Rider clothing has no real cloth folds (a noise-based fold normal map only); the jersey reads a little stiff in close-ups. A sculpted fold normal from a cloth sim would lift it.
- Faces are never shown (visor + goggles); the eye port is dark. Fine for racing, weak for a podium close-up.
- Canyon walls are a heightfield with strata steps; they need 3-4 large sandstone cliff meshes for real overhangs and silhouettes.
- Track has no braking bumps, roots or berm geometry in the mesh yet: the texture and the riding-line darkening carry it.
- Landmarks listed in GDD 6.0 (cabin, bridge, tunnel, arch, gas station, mining town) are not modelled.

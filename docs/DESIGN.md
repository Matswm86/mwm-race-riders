# MWM Race Riders: visual design spec

Owner: graphic-designer. Version 2.1, 2026-10-07 (adds the worlds 3-6 art kit, the World 1/2 landmarks and the World 2 canyon fixes); version 2, 2026-10-06 (replaces the toy look of version 1, which the owner rejected: "graphics is way too bad. Should be more modern high end realistic"). The builder reads this before touching any model, material, light, camera or UI node. Game rules and numbers live in `docs/GDD.md`; this file owns the look. Numbers tagged (my calc) are my own arithmetic.

Mockups (rendered in Blender 4.5 EEVEE from the exported GLBs and real textures, with the game camera; HUD drawn by `tools/art/hud_overlay.py`):

| File | What it shows |
|---|---|
| `docs/mockups/realistic_mock.png` | World 1 "Furuløypa / Pine Run", 1080x1920: behind the player (#7, 4th), boost pad P2 ahead, rivals #23, #12, #31 ahead, course tape, swap gate G1 in the distance, full HUD |
| `docs/mockups/realistic_zones.png` | Same frame with the HUD zones: home square (white), gear and boost hit areas (green), wrist strip (red) |
| `docs/mockups/realistic_mock_w2.png` | World 2 "Ørkenjuvet / Red Canyon": sandstone canyon, water tower, tumbleweed, sand drift, rivals #4, #88, #23, Vanlig race time |
| `docs/mockups/realistic_mock_w2_fix.png` | World 2 fix check (same frame as `realistic_mock_w2.png`): sky-only HDRI (the pale hill at the canyon end is gone, a fogged mesa wall closes the view), level-strata canyon-wall layer, scanned cliff masses breaking the wall foot (section 10a) |
| `docs/mockups/realistic_mock_w3.png` | World 3 "Isbreen / Glacier Run": groomed piste with blue dye lines and red flags, ice patch ahead, the blue ice cave in an icefall with seracs, red glacier hut, snow peaks, light snowfall |
| `docs/mockups/realistic_mock_w4.png` | World 4 "Askefjellet / Ash Mountain": black-ash trail, steam vent puffing on the track, guardrail with glowing lava cracks behind it, basalt columns, smoking crater cone, embers and ash |
| `docs/mockups/realistic_mock_w5.png` | World 5 "Regnskogen / Rainforest": wet mud trail, mossy log across the track, the fork: rope bridge (left) over the river and the shallow ford (right), buttress tree, big-leaf undergrowth, mist and rain |
| `docs/mockups/realistic_mock_w6.png` | World 6 "Nattehavna / Night Harbour": wet asphalt quay at night, sodium lamps and light pools, steel plates, cones, a cable spool, the crane-jump container ramp, gantry crane with the amber air ring, ferry and far lit bridge |

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
| Landmarks | `world1/cabin.glb`, `world1/river_bridge.glb` (the K2 hump), `world1/rock_tunnel_portal.glb` + `rock_tunnel_segment.glb` (section 9a) | |

**World 1 palette (60/30/10, measured from the textures, my calc):** 60% earth and trail (#876B51 trail, #815E3A needles), 30% forest (#403E2C pine crowns, #4F3D15 grass) and sky (#9EB3C7 haze), 10% racers, tape red #D2232A and the amber pads.

### 9a. World 1 landmarks (built 2026-10-06, `tools/art/build_landmarks12.py`)

| File | Size (m) | Tris | Place | Godot |
|---|---|---|---|---|
| `world1/cabin.glb` | 8.4 x 5.8 x 6.7 | 2,332 | Log cabin with notched corners, turf roof, white-framed windows, stone chimney; door faces -Y. By the start drop or the finish meadow, 12-20 m off the track, door towards the track | Shadows on |
| `world1/river_bridge.glb` | 14.0 x 5.6 x 22.8 | 3,056 | K2 "bridge hump" (s 645): drive along +Y, deck 10.4 m wide, 1.2 m hump, deck top z 0 at both ends; stone abutments go 3.2 m down to the river | The hump is the K2 kicker; the bridge is its skin |
| `world1/rock_tunnel_portal.glb` | 34 x 16 x 6.6 | 1,268 | Tunnel mouth at s 810 (and a mirrored copy, yaw 180, at s 870): rock face at y about 0 looking -Y, opening 8 m wide x 6 m high, first 6 m of lining included | Shadows on |
| `world1/rock_tunnel_segment.glb` | 8.8 x 6.4 x 10 | 472 | Inner lining only (the hill outside is terrain); repeat every 10 m from the portal's y 6; one warm wall lamp per segment in the emission map | Inside the tunnel lower `ambient_light_energy` to 0.35 (an Area3D or a second Environment blend): the sky ambient would otherwise light the inside like day |

### 9b. Cowbell meadow (finish)

Not modelled as its own GLB: it is the World 1 grass layer, `fence_rail.glb` round the meadow and `hay_bale.glb` stacks; cowbells are too small to read at chase distance (four questions: not noticed at 4.8 m behind a moving rider).

## 10. World 2: "Ørkenjuvet / Red Canyon" (desert canyon, hard midday sun)

**Mood:** a dry wash between layered red sandstone walls, a rusty water tower, dry brush and tumbleweeds, heat haze on the far rocks. Clearly a different place from World 1: warm red ground, deep blue sky, no trees, hard short shadows.

| Layer | Asset | Godot |
|---|---|---|
| Sky | `world2/sky_goegap_skyonly_1k.exr` (Poly Haven goegap with the hills above the horizon painted out, section 10a; sun pixel u 0.608, v 0.242 from the top, elevation 46 deg) | Sun `rotation_degrees` (-46, 15, 0), colour #FFF6E8 Color(1.000, 0.965, 0.910), `light_energy` 1.9 |
| Fog (heat haze tint) | depth begin 50 m, end 650 m, colour #D1B394 Color(0.820, 0.702, 0.580), max mix about 30% | |
| Trail | `terrain_red_laterite_soil_stones_*` (2K), tile 3.2 m | Splat R |
| Sand floor | `terrain_red_sand_*`, tile 3-4 m | Base |
| Canyon walls | `terrain_canyon_wall_*` (replaces `terrain_cliff_side_*`; level strata baked in), **world-aligned triplanar** with sand on the ledges (section 10a), tile 9 m; walls are terrain rising from 16 m off the centre line in 4.5 m strata ledges up to about 50 m, topped by `canyon_cliff_a/b.glb` | Splat G by slope |
| Old rim highway (hoverboard section) | `terrain_worn_asphalt_*`, tile 4 m, faded white edge line as a Decal | |
| Fallen blocks | `rock_a/b/c.glb` at 1.5-3.5x scale along the wall foot, `albedo_color` Color(1.25, 0.62, 0.42) multiplies the grey scan to sandstone | |
| Brush | `bush_desert.glb` (Poly Haven wild rooibos rendered to a 3-plane impostor, 6 tris), `dead_trunk.glb` (1,200 tris) | Bush MultiMesh, visibility 120 m |
| Landmarks | `water_tower.glb` (14 m, rusty steel, start grid and finish), `world2/sandstone_arch.glb`, `world2/gas_station.glb`, `world2/mesa_backdrop.glb` (section 10a). Mining-town fronts: not modelled yet | |
| Kicker skin | `ramp_rock.glb` (sandstone lip, same footprint as `ramp.glb`) for K1 "rock lip"; K4 uses `ramp.glb` (wooden loading ramp) | |
| Hindrances | `sand_drift.glb` (Patch, pale wind-rippled sand, vertex-alpha edge, 15 x 4 m), `tumbleweed.glb` (Roller, 1.2 m, rotate about its centre 0.6 m up while it rolls) | |
| Weather | Blowing sand: 200 `sand_streak` sprites (#E2B48C, 20%) moving across the track with the wind; 2 distant dust devils (spiralling `dust_puff` columns, 40 particles each) on the canyon floor 150 m+ ahead | <= 300 particles |

**World 2 palette (my calc):** 60% red earth (#643E2E trail, #805945 sand, #7B5231 cliff), 30% sky (#3F6DB5) and pale rock, 10% racers and amber pads.

### 10a. World 2 fixes and landmarks (2026-10-06)

**Open-left HDRI hill.** The goegap panorama has real hills 5-21 deg above its horizon; where the canyon opens they showed through as a green-beige slope (QA screenshots 08 and 11). Two fixes, use both:
1. Sky: `world2/sky_goegap_skyonly_1k.exr` (2K `.hdr` beside it). Everything above the horizon up to 21 deg is replaced by the panorama's own clean sky colour fading into a pale warm haze at the horizon; the sun, the upper sky and the ground below the horizon (warm bounce light) are untouched. Swap the `"sky"` path in `RrWorlds.W2.look`; nothing else changes.
2. Horizon: `world2/mesa_backdrop.glb` (a 120-degree ring segment of mesas and buttes, radius 620-800 m, 35-140 m high, caprock steps, 2,640 tris). Place three copies at yaw 0 / 120 / 240 round the track's middle at scale 1.25, no shadow, fogged, and raise the camera far plane to 1100 m in World 2.

**Canyon-wall stretch.** The wall layer is sampled from one side axis (`rr_terrain.gdshader`, `xside` branch), so faces at about 45 deg and the strata ledges smear the `cliff_side` texture. Replace the wall layer with `terrain_canyon_wall` (ambientCG Rock030 re-coloured to sandstone with level strata beds baked in: texture v = world height) and sample it world-aligned triplanar, with sand on the ledges:

```glsl
// rock layer: world-aligned triplanar; strata stay level on every wall angle, ledges take the sand layer
vec3 bw = pow(abs(nw), vec3(4.0));
bw /= (bw.x + bw.y + bw.z);
vec3 rx = texture(rock_alb, vec2(wpos.z, -wpos.y) / rock_tile).rgb;
vec3 rz = texture(rock_alb, vec2(wpos.x, -wpos.y) / rock_tile).rgb;
vec3 ry = texture(base_alb, wpos.xz / base_tile).rgb;          // sand collects on ledges
vec3 ra = (rx * bw.x + rz * bw.z + ry * bw.y) * rock_tint;
```
Cost (my calc): two extra texture samples on wall pixels only, about 15% of the frame in the canyon; Høy only. Lav keeps the single-axis path but still gets the new texture (its level beds hide most of the stretch). `rock_tile` stays 9 m.

**Cliff silhouettes.** `world2/canyon_cliff_a.glb` (38 x 23 x 20, 2,599 tris) and `canyon_cliff_b.glb` (52 x 19 x 17, 2,999 tris) are Poly Haven Namaqualand cliff scans, decimated and re-skinned with the same strata (baked atlas; or override with the triplanar material above for perfect continuity with the terrain walls). Set 4-6 of them along the wall tops and at the canyon mouths to break the heightfield's smooth outline; shadows on.

| File | Size (m) | Tris | Place |
|---|---|---|---|
| `world2/sandstone_arch.glb` | 45 x 23 x 14 | 2,816 | Natural arch, legs at x +-17 m, about 16 m clearance; the track runs along Y under it (dry wash, s 150-250) |
| `world2/gas_station.glb` | 22 x 8.2 x 14 | 1,044 | Abandoned station at s 840 on the rim highway, forecourt faces the road (-Y), blank sign (no text) |

## 11. Worlds 3-6 (art kit built 2026-10-06; section tables still come from game-designer)

Same method as worlds 1-2: CC0 scans (Poly Haven, ambientCG) baked into one atlas material per GLB (albedo + OpenGL normal + ORM, plus an emission map where something glows). Every GLB is in `assets/models/world3..6/`, its maps and the terrain sets in `assets/textures/world3..6/`. Sizes below are Godot x / y-up / z in metres, origin on the ground, front = -Z (the race direction). Mocks: `docs/mockups/realistic_mock_w3.png` ... `_w6.png`.

### 11.0 Rules for every new world

1. **Terrain sets** keep the World 1/2 names and channels, so `RrWorld._terrain_material()` loads them unchanged: `terrain_<name>_albedo.jpg` (1024, sRGB, tint baked in), `_normal.jpg` (512, OpenGL), `_arm.jpg` (512, R AO, G roughness, B metal). Map them to the five shader layers `trail`, `base`, `rock`, `verge`, `patch` as each world table says.
2. **Patches** (`ice_patch`, `snow_drift`, `ash_dune`, `river_ford`) fade at the edge through vertex alpha in **COLOR_0**. Blender 4.5's exporter had put the real alpha in COLOR_1 and a white COLOR_0 first, so Godot (which reads only COLOR_0) drew hard edges; `w36_lib.fix_vertex_alpha()` now repoints COLOR_0, and the same fix was applied to the existing `mud_puddle.glb` and `sand_drift.glb` (originals kept in `assets/_raw/build/*.bak`). Add the new names to `RrMats.PATCHES`.
3. **Cards:** every impostor (`tree_jungle_*`, `plant_*`, `shrub_jungle`) and every `*_card.glb` is an alpha-scissor material (threshold 0.5, cull disabled), same as the W1 pines. Every near scatter prop has a far version: rocks and seracs swap to their `_card.glb` at 60 m, `basalt_columns` at 80 m, `buttress_tree` at 70 m, `container` to `container_far.glb` at 40 m.
4. **Emission** lives in the atlas (`*_emission.png`, also in the GLB): ice-cave inner light, lava cracks, crane and ferry lights, lamp heads, the air-ring LED band. Glow (Høy only, threshold 1.2) picks them up; nothing flashes faster than 1 Hz (GDD rule 37).
5. **Weather** = one GPUParticles3D emitter per world (<= 600 particles) with the world's `fx_*.png`, plus a few static camera-facing cards (spindrift, smoke plume, mist banks) placed by the level builder.
6. Skies come in two sizes like the slice: `sky_*_2k.hdr` (reference) and `sky_*_1k.exr` (half float, ZIP; what the game loads). All four suns sit at u 0.600-0.605 in their panoramas, the same as World 1, so `sun_rot.y` 135 and `sky_yaw` 0 put every sun behind the camera's right shoulder.

### 11.1 World 3 "Isbreen / Glacier Run" (glacier under a pale-blue sky)

**Mood:** a groomed race piste on a glacier: blue course-dye lines and red flags on white, blue seracs and an icefall ahead, a red mountain hut, sharp snow peaks behind. Bright but not blinding: snow albedo is about 0.8, never pure white, and the exposure comes down.

| Layer | Asset | Godot |
|---|---|---|
| Sky | `world3/sky_horn_koppe_snow_1k.exr` (Poly Haven horn-koppe_snow; sun u 0.600, v 0.343 from the top, elevation 28 deg) | `sun_rot` (-28, 135, 0), colour #FFF6EC Color(1.000, 0.965, 0.925), `sun_energy` 1.6; `tonemap_exposure` 0.7 (snow). Keep the valley wall on the sun side under 28 deg (slope <= 0.3) or it shades the whole piste grey (the first mock did exactly that) |
| Fog | begin 40 m, end 700 m, colour #CCDBF0 Color(0.80, 0.86, 0.94), max 0.35 | |
| `trail` | `terrain_snow_groomed` (snow_02 with 3 cm snow-cat corduroy ribs; ribs run along the track: rotate the trail UV 90 deg), tile 3 m | |
| `base` | `terrain_snow`, tile 4 m | |
| `patch` | `terrain_snow_wind` (wind-packed, aerial scan), tile 9 m, noise patches off the piste | |
| `rock` | `terrain_glacier_rock` (ambientCG Rock030, cooled grey), triplanar tile 8 m, on the valley walls 30 m+ out | |
| `verge` | `terrain_snow_wind` | |
| Snow-cat tracks | `terrain_snowcat_tracks` as a 3.2 m decal strip outside the course (x about +-10.5), v along the track, tile 12 m | Decal or a strip mesh, no shadow |
| Course edge | `flag_pole.glb` (0.56 x 3.33 x 1.2, 160 tris) every 10 m at x +-6.3, plus blue dye lines: 0.5 m strips at x +-5.4, Color(0.12, 0.30, 0.85) at 60% (game content, not UI) | One MultiMesh per chunk; dye = the `pollen.png` sprite as a strip |
| Signature | `ice_cave.glb` (21.5 x 11.2 x 24, 2,100 tris; inner width 12.4 m, height 6.6 m; faint blue emission inside = the light ice transmits) set into an icefall (terrain raised about 9.5 m around it), then `crevasse.glb` (40 x 18 x 24, 1,200 tris; 14 m gap after the cave mouth, 18 m deep, under the 22.8 m limit of GDD 6.3) | Cave: shadows on; inside, lower `ambient_light_energy` is not needed thanks to the emission |
| Kicker skin | `ramp_snow.glb` (packed snow, blue-ice lip, same footprint as `ramp.glb`, 382 tris) | |
| Hindrances | `ice_patch.glb` (Patch, 6 x 14 m, glossy roughness 0.08, vertex-alpha edge), `snow_drift.glb` (Patch x0.90, 15 x 4 m, 0.36 m), `snow_slough.glb` (Roller, 1.4 m; spin about (0, 0.65, 0)) | Patches: alpha, `render_priority` -1, no shadow |
| Landmarks | `glacier_hut.glb` (9 x 5.9 x 7.6, 1,118 tris; red planks, snow-loaded roof, door faces -Y), `ladder_bridge.glb` (14 m ladders + orange hand ropes over a side crevasse, 1,340 tris), `serac_a/b.glb` (5-8 m melt-rounded ice blocks, 1,100 tris), `mountain_ridge.glb` (1.6 km band of peaks, 4,608 tris; place 600-850 m out, 3 copies) | Ridge: no shadow, `visibility_range_end` 1200, camera far 1200 in this world |
| Scenery near / far | `glacier_boulder.glb` (660 tris) -> `glacier_boulder_card.glb` at 60 m; `serac_a/b` -> `serac_card.glb` at 60 m | |
| Weather | 400 `fx_snowflake` (white 90%, 5-9 cm, slow fall + side drift), 4-8 `fx_spindrift` cards (14 x 5 m, 35%) blowing off the icefall crest; `fx_sun_glare` only when the camera faces the sun (never in the race heading) | <= 450 particles |

**World 3 palette (measured on the mock, my calc):** 60% snow (#7C8AA1 shaded piste to #B6BDC6 sunlit, scan albedo #DFE3ED), 30% sky (#6E859C) and blue ice (#5D829F albedo), 10% racers, red flags, blue dye and the amber pads. The flags use the r1 crimson; if they compete with the player on the phone, shift them to #E04A1A.

### 11.2 World 4 "Askefjellet / Ash Mountain" (volcanic slope, dim orange light)

**Mood:** a black-ash trail under a low, smoky sunset; a cinder cone smokes far off; cooled lava glows red in its cracks behind a steel guardrail; basalt organ pipes and dead charred trees. The light is warm and dim, the ground nearly black, the glow is the only saturated colour besides the racers.

| Layer | Asset | Godot |
|---|---|---|
| Sky | `world4/sky_belfast_sunset_puresky_1k.exr` (Poly Haven belfast_sunset_puresky, pre-tinted x(1.05, 0.80, 0.62) and dimmed 15% for volcanic haze; sun u 0.605, elevation 2 deg) | `sun_rot` (-9, 135, 0) (raised from 2 deg so racer shadows stay short enough to read), colour #FFB27A Color(1.000, 0.698, 0.478), `sun_energy` 1.1; `tonemap_exposure` 1.1 |
| Fog (smoke haze) | begin 25 m, end 520 m, colour #805E45 Color(0.50, 0.37, 0.27), max 0.42 | |
| `trail` | `terrain_ash_trail` (grey packed ash, #564D43 albedo: lighter than the verges so racers read on it), tile 3.2 m | |
| `base` | `terrain_ash`, tile 4 m | |
| `verge` / `patch` | `terrain_ash_soft` (loose grey ash), tile 5 m | |
| `rock` | `terrain_basalt` (ambientCG Rock035, flattened), triplanar 7 m, ridges 34 m+ out | |
| Lava (behind rails only) | `lava_field.glb` (14 x 40 m strip, 720 tris; black crust albedo, glow only in the crack emission map) laid in a basin left of the track, `safety_rail.glb` (4 m W-beam section, 100 tris) every 4 m between it and the track | Lava: `emission_energy_multiplier` 2.5, no shadow; rail: MultiMesh, shadows on Høy |
| Terrain crust layer | `terrain_lava_crust` (cooled crust, glow removed so nothing orange is ever on the track) for crust patches | |
| Signature | `steam_vent.glb` (3.8 x 0.9 x 3.7, 1,080 tris; fumarole mound with a sulphur-crusted throat, rideable). Every 2 s: 12 `fx_steam_puff` particles up 6 m over 1.2 s (white 55%); the launch window is the puff | |
| Kicker skin | `ramp_rock.glb` from World 2 with `albedo_color` Color(0.35, 0.33, 0.32) reads as basalt | |
| Hindrances | `ash_dune.glb` (Patch x0.88, 15 x 4.5 m, 0.3 m, vertex-alpha edge), `falling_rock_a/b.glb` (Roller from the uphill side, 1.0-1.3 m scoria, 500 tris; spin about (0, 0.25, 0) / (0, 0.27, 0)), `lava_crust_ridge.glb` (Hop, 11 x 0.45 x 1.6, ropy pahoehoe crust, no glow) | |
| Landmarks | `crater_cone.glb` (900 m wide, 270 m high, 3,528 tris; place 1,000-1,200 m out, ahead-right) with 3 `fx_smoke_plume` cards (240-340 m tall) above its rim; `basalt_columns.glb` (26 hexagonal columns up to 7 m, 2,176 tris) -> `basalt_columns_card.glb` at 80 m; `research_station.glb` (two instrument modules on stilts, antenna mast, solar frame; 19.8 x 12.5 x 11.2, 1,532 tris) | Cone and plume: no shadow, camera far 1300 in this world |
| Scenery | `scoria_rock.glb` (500 tris) -> `scoria_rock_card.glb` at 60 m; `burnt_snag.glb` (charred fallen trunk, 1,200 tris) | |
| Weather | 260 `fx_ash_flake` (falling, 5-7 cm, Color(0.30, 0.29, 0.28)), 40 `fx_ember` (additive, rising, 4-6 cm, emission 6, under 1 Hz flicker), 8-10 `fx_smoke` haze cards (70 x 26 m, 35%) 60-400 m ahead | <= 350 particles |

**World 4 palette (measured on the mock, my calc):** 60% black ash (#312525 to #4F3B37), 30% smoke haze and sky (#998274, #BAAAA9), 10% lava glow (deep red-orange cracks, emission Color(0.9, 0.16, 0.015) before tonemapping: brighter orange turns yellow-gold on screen), racers, embers and the amber pads. Lava orange appears only behind the rail.

### 11.3 World 5 "Regnskogen / Rainforest" (after rain)

**Mood:** a wet, dark mud trail under a closed canopy, mist hanging between giant trunks, big-leaf undergrowth at the edges, mossy ruins; the track forks: a narrow rope bridge on the left over a deep river, a wide shallow ford on the right.

| Layer | Asset | Godot |
|---|---|---|
| Sky | `world5/sky_rainforest_trail_1k.exr` (Poly Haven rainforest_trail; sun u 0.601, elevation 41 deg) | `sun_rot` (-41, 135, 0), colour #FFF2DE Color(1.000, 0.949, 0.871), `sun_energy` 0.7 (this HDRI has no hard sun, peak 247 vs 75,000-360,000 in the others: light under the canopy is diffuse; the tree-card shadows give a soft dapple); `tonemap_exposure` 1.05 |
| Fog (mist) | begin 18 m, end 260 m, colour #9EAD9E Color(0.62, 0.68, 0.62), max 0.5 | |
| `trail` | `terrain_mud_wet` (roughness x0.55 = wet), tile 3 m | |
| `base` | `terrain_forest_moss`, tile 4 m | |
| `verge` / `patch` | `terrain_mud_leaves` (mud with leaf litter and moss), tile 3.5 m | |
| `rock` | `terrain_mossy_rock`, triplanar 6 m (river banks, ruins ground) | |
| Ford bed | `terrain_river_stones` under `river_ford.glb` | |
| Split path | Bridge route: `rope_bridge.glb` (36 m span, 4.4 m plank deck, 0.9 m sag, A-frame towers 3.4 m clear, 3,144 tris; deck top z 0 at both ends) over the river; ford route: `river_ford.glb` (Patch x0.85 on the bike, board immune; 12 x 18 m shallow water with the stones baked in, roughness 0.05, vertex-alpha edge) | Bridge: shadows on Høy |
| Signature | `waterfall_rock.glb` (32 x 9.6 x 16.6, 864 tris; dry rock lip |x| < 3 m at the origin, falls at 3 < |x| < 12 m, pool 8.4 m down) + `waterfall_water.glb` (two curtains + foam skirt, 264 tris, alpha blend, cull off, UV-scroll v 1.6 tiles/s) + `pool_water.glb` (30 x 34 m, dark glossy) + `fx_spray` particles at the foot | Water: no shadow, `render_priority` 1 |
| Hindrances | `log_hop.glb` (Hop, mossy fallen log 11 m across the track, 0.6 m, 1,400 tris), `branch_pile.glb` (Block, 2.9 x 0.7 x 1.4 m, 1,800 tris), `river_ford.glb` (above) | |
| Landmarks | `buttress_tree.glb` (giant trunk 30 m with 7 plank buttress roots 5-6 m out, moss on the up faces, 948 tris) -> `buttress_tree_card.glb` at 70 m; `stone_ruin.glb` (mossy wall runs, doorway, column drums, fallen blocks; 9.6 x 3.7 x 6.1, 2,600 tris; front -Y); the waterfall and rope bridge | |
| Canopy and undergrowth | `tree_jungle_a/b.glb` (Poly Haven island trees rendered to 4-plane impostors, 22-24 m, 8 tris), `plant_calathea.glb`, `plant_anthurium.glb`, `shrub_jungle.glb` (3-plane cards, 6 tris, 1.4-4.7 m), plus the World 1 `fern.glb` | Trees: MultiMesh per chunk, visibility 160 m Høy / 90 m Lav, cast shadows within 40 m; undergrowth visibility 35 m (Lav 15 m) |
| Weather | 200 `fx_rain_streak` (stretched 6 mm x 35 cm, 18%), 10-14 `fx_mist` banks (30 x 12 m, 28%) along the trail, 3-5 `fx_butterfly` (2-frame flap, 14 cm), `fx_spray` at the waterfall | <= 300 particles |

**World 5 palette (measured on the mock, my calc):** 60% wet mud and leaf litter (#282925 to #454035), 30% canopy and moss greens (#2E321E, #454C31, #575F44), 10% racers, pale mist and river glints.

### 11.4 World 6 "Nattehavna / Night Harbour" (industrial port at night)

**Mood:** a wet asphalt quay at night between container stacks; sodium lamps make warm pools on the black ground, a ship-to-shore crane straddles the track with red aviation lights, an amber air ring hangs under its boom, a lit ferry and a far cable-stayed bridge across the water. Night is dark blue, not black: the sky still separates the cranes from it.

| Layer | Asset | Godot |
|---|---|---|
| Sky | `world6/sky_qwantani_moonrise_puresky_1k.exr` (Poly Haven qwantani_moonrise_puresky; moon u 0.600, elevation 14 deg) | `PanoramaSkyMaterial.energy_multiplier` 0.035; moonlight `sun_rot` (-14, 135, 0), colour #9FB4D8 Color(0.62, 0.71, 0.85), `sun_energy` 0.2, shadows on; `tonemap_exposure` 1.85; glow on Høy (threshold 1.0) |
| Fog | begin 30 m, end 600 m, colour #1A1C24 Color(0.10, 0.11, 0.14), max 0.45 | |
| `trail` | `terrain_asphalt_wet` (roughness x0.45), tile 4 m | |
| `base` | `terrain_quay_concrete`, tile 5 m | |
| `patch` | `terrain_steel_plate`, tile 3 m | |
| `rock` | `terrain_quay_wall` (quay edge drop to the water) | |
| Lights | `sodium_lamp.glb` (12 m mast, two heads, 376 tris) every 32 m both sides, inner head over the track; `fx_sodium_glow` card (1.5 m) on each head beyond 10 m; `fx_light_pool` additive decal (8 x 9 m, 22%) under each lamp ahead; `fx_wet_reflection` streak cards on the wet asphalt; **2 OmniLight3D** (range 14 m, energy 4, Color(1.0, 0.62, 0.30), no shadow) that follow the two lamps nearest the camera | Decals: `Decal` nodes or additive quads, no shadow |
| Signature | `crane_jump_stack.glb` (steel approach ramp onto four containers, rides along their roofs, steel kicker lip at y 31.2 m, z 3.84 m; 10.8 x 4.4 x 31.3, 5,556 tris), `gantry_crane.glb` (legs at x +-15 m, portal 38 m, boom over +Y at 44 m, red aviation lights and sodium floods in emission; 31.6 x 67.7 x 78.6, 1,120 tris), `air_ring.glb` (5.2 m ring, amber LED band = "speed for you", hangs on 12 m cables; 824 tris) | Aviation lights: blink 0.5 Hz with `emission_energy`, never faster than 1 Hz |
| Kicker skin | `ramp_steel.glb` (steel plate, white painted lip, no hazard stripes, 468 tris) | |
| Hindrances | `steel_plate.glb` (Patch, slide like ice; three wet road plates 7.2 x 6.9 m, roughness 0.14), `traffic_cone.glb` (Block x0.95, 0.75 m, 420 tris), `cable_spool.glb` (Roller, 1.6 m wooden drum with cable; axle along Godot Z, spin about (0, 0.8, 0); 2,912 tris) | |
| Landmarks | `container.glb` (40 ft, corrugated geometry, 1,260 tris; neutral paint, colour per instance: red #8E2A1F, blue #1F4E8C, green #2E6B3A, grey #8C9196, orange #B8541E via MultiMesh `use_colors` + `vertex_color_use_as_albedo`) -> `container_far.glb` (12 tris) beyond 40 m; `container_stack_far.glb` (48 boxes, 552 tris) for 150 m+; `ferry.glb` (112 m, lit window rows, 2,752 tris; 120 m+ across the water); `warehouse.glb` (50 x 14 x 25, 166 tris, lit doors); `lit_bridge_far.glb` (1.1 km cable-stayed bridge with deck lights, 1,656 tris; 700-1,500 m out) | Far pieces: no shadow; camera far 1300 here |
| Props | `concrete_barrier.glb` (quay-side jersey barrier, 160 tris, every 1.6 m), `bollard.glb` (192 tris, quay edge every 14 m), `sea_marker.glb` (channel buoy, 1,187 tris) | |
| Water | Harbour basin and the channel: the game's river material (Color(0.05, 0.08, 0.07) -> use Color(0.006, 0.010, 0.014) here, roughness 0.06) with `world5/water_ripple_normal.png` at scale 0.15 | |
| Weather | 260 `fx_drizzle` streaks (2 x 36 cm, warm grey 55%); lamp glows as above | <= 300 particles |

**World 6 palette (measured on the mock, my calc):** 60% night asphalt and quay (#0B0806 to #2B1F14, lamp-lit #71573B), 30% night sky (#212D3A to #2E3D4B) and steel, 10% sodium orange (#FF9C38 pools), container colours, racers, the amber ring and pads. Keep the sky dark blue, never black: it is what separates the crane from the night.

### 11.5 HUD and racer contrast on worlds 3-6 (my calc, WCAG 2.x on the mock pixels behind each element)

| Pair | W3 Glacier | W4 Ash | W5 Rainforest | W6 Night | Need |
|---|---|---|---|---|---|
| Gear disc edge (ink disc / white ring) | 7.4 / 2.4:1 | 8.7 / 2.1:1 | 1.7 / 10.5:1 | 1.4 / 12.5:1 | 3.0 (one edge) |
| Progress bar (ink bar / white track vs background) | 9.1:1 / - | 7.0:1 / - | 2.9:1 / 6.3:1 | 1.6:1 / 11.1:1 | 3.0 (one edge) |
| Place disc (white fill / 5 px ink ring vs background) | 2.0 / 9.0:1 | 2.6 / 6.8:1 | 6.8:1 / - | 11.0:1 / - | 3.0 (one edge) |
| Boost disc (ink disc / white ring vs trail) | 9.0 / 2.0:1 | 2.2 / 8.0:1 | 1.4 / 12.8:1 | 1.1 / 16.3:1 | 3.0 (one edge) |
| White icons and digits on ink, amber on ink | 18.0 and 9.8:1 everywhere | | | | 3.0 / 4.5 |

Every HUD element keeps at least one edge at 3:1 or more because of the rule "ink disc + white ring" (section 5): on snow the ink carries it, in the forest and at night the white ring and the white track do. Never drop either. Racers: on the snow the dark pants give 8.8:1; on black ash (W4) and night asphalt (W6) the dark pants merge with the ground (1.1-1.2:1) and the crimson jersey is 1.2-2.6:1 in luminance, so there the rider reads by hue, the white numbers and the white side trim, plus the ground dust. That is why the W4 trail is a grey packed ash (#564D43 albedo) rather than the black ash of the verges; if a phone screenshot shows riders sinking into the W6 asphalt, add a soft additive `contact_shadow`-shaped light pool under each racer only in W6 (1 draw, the lamps' "bounce").

## 12. Phone budget (Høy = mid-range phone, 60 fps; numbers are my calc for the mock frames)

| Item | Høy ceiling | Estimate, World 1 frame | Estimate, World 2 frame | Lav |
|---|---|---|---|---|
| Draw calls | <= 100 | about 82: racers 6 x 2 = 12, their shadow pass 12, terrain chunks 6, tree MultiMeshes 4 chunks x 3 kinds = 12, grass + fern 8, rocks 3, stakes 2, kit 6, sky 1, particles 3, contact quads 1, HUD about 10, plus 6 spare | about 62 (no trees; bushes 4, rocks 3) | <= 60: shadow pass off (-12), grass off beyond 15 m |
| Visible triangles | <= 200k | about 160k: player rider + bike LOD0 13.1k, 5 rivals at LOD1 about 33k (78.6k worst case all LOD0), terrain 18k, trees 600 x 8 = 4.8k, grass 400 x 6 = 2.4k, rocks 40 x 530 = 21k, ferns 12 x 900 = 11k, stakes 80 x 44 = 3.5k, kit 8k, shadow pass racers about 46k | about 120k | <= 90k (no shadow pass, rivals LOD1, ferns off) |
| Texture memory | <= 150 MB | about 82 MB (ETC2/ASTC with mips; 1024 RGB = 0.67 MB, 2048x1024 RGBA = 2.7 MB): racers 5.3, bikes 4.7, hoverboards 1.5, kit 7.4, trees 16, grass + fern 3.3, rocks 2, terrain layers 14, sky HDRI 16 (half float) + radiance 3, FX 1, HUD + fonts 4, spare 4 | about 70 MB | Same files; set *Lav* `mipmap bias` +1 (halves the sampled size, not the memory). For the 32-bit tablet, re-import the trail textures at 1K if memory runs short |
| Lights | 1 directional with shadows | | | 1 directional, no shadows |
| Transparency | Mud, sand drift, dust, sand streaks, contact quads; trees and grass are alpha *scissor* (opaque pipeline) | | | Same |

Import settings: every albedo / ORM / normal PNG and JPG as VRAM Compressed (ETC2 on Android; `rendering/textures/vram_compression/import_etc2_astc` is already on), mipmaps on, normal maps with *Normal Map* = Enable. The tree and grass atlases: *Fix Alpha Border* on, mipmaps on, alpha scissor material. HDRIs: no VRAM compression.

### 12a. Worlds 3-6 frame estimates (my calc; frame = the mock view, Høy, racers as in section 12)

Shared base in every world: racers 12 draws + their shadow pass 12, terrain 6, kit 3, sky 1, particles 1-3, contact quads 1, HUD 10 = about 47 draws; racers about 46k tris + their shadows 46k + terrain 18k + kit 4k = about 114k tris.

| World | Extra draws (MultiMesh per kind and chunk) | Extra tris in view | Total draws / tris (Høy) | Texture memory added (ETC2, mips) | Lav |
|---|---|---|---|---|---|
| 3 Glacier | flags 1, seracs 2 + card 1, boulders 1 + card 1, cave 1, hut 1, ridge 1, patch/drift/slough 3, dye + cat strips 2, spindrift cards 1, shadow casters 3 = 19 | flags 40 x 160 = 6.4k, seracs 10 x 1.1k = 11k, boulders 15 x 660 = 10k, cave 2.1k, hut 1.1k, ridge 3 x 4.6k = 13.8k, hindrances 2.3k = 47k | **66 / 161k** | about 26 MB (5 terrain sets 9 MB, props 1024 x 6 = 8 MB, cards 3 MB, sky 1k 3 MB, fx 1 MB, ridge 2 MB) | 47 / 82k: no shadows, ridge 1 copy, seracs as cards beyond 40 m |
| 4 Ash | rails 1, lava 1, columns 1 + card 1, scoria 1 + card 1, snags 1, vent 1, dune/ridge/rock 3, station 1, cone 1, plume/haze cards 2, shadow casters 3 = 19 | rails 70 x 100 = 7k, lava 5 x 720 = 3.6k, columns 6 x 2.2k = 13k, scoria 20 x 500 = 10k, snags 5 x 1.2k = 6k, vent 1.1k, hindrances 2.1k, station 1.5k, cone 3.5k = 48k | **66 / 162k** | about 28 MB | 47 / 84k |
| 5 Rainforest | trees 2 kinds x 4 chunks = 8 + their shadows 8, undergrowth 4, fern 1, buttress 1 + card 1, ruin 1, log 1, branches 1, bridge 1, ford 1, water 1, mist/rain/butterflies 2 = 31 | trees 900 x 8 = 7.2k, undergrowth 400 x 6 = 2.4k, ferns 12 x 900 = 11k, buttress 2 x 950 = 1.9k, ruin 2.6k, log 1.4k, branches 1.8k, bridge 3.1k, ford 0.7k, tree shadows 5k = 37k | **78 / 151k** | about 34 MB (two 2048 x 512 tree atlases, three card atlases) | 51 / 70k: no shadows, undergrowth 15 m, ferns off |
| 6 Night Harbour | containers near 1 + far 1, stacks far 1, barriers 1, bollards 1, lamps 1, glow/pool/reflection cards 3, crane 1, jump stack 1, ring 1, plates/cones/spool 3, ferry 1, warehouse 1, bridge 1, buoy 1, water 1, shadow casters 3 = 25 | containers 20 x 1.26k = 25k + 100 x 12 = 1.2k, barriers 60 x 160 = 9.6k, lamps 8 x 376 = 3k, bollards 2k, crane 1.1k, stack 5.6k, ring 0.8k, hindrances 4.8k, ferry 2.8k, bridge 1.7k, far stacks 1.7k = 60k | **72 / 174k** | about 30 MB | 51 / 88k: no shadows, 1 omni, containers all `container_far` beyond 25 m |

Two OmniLight3D in World 6 add per-object light cost, not draws (Mobile renderer, forward+ clustered): keep them at range 14 m so they touch about 15 objects. World 5 is the risk at 120 fps: alpha-scissor foliage near the camera is overdraw, not draws. If the Høy frame time climbs, first drop the undergrowth range to 25 m, then the tree shadow range to 25 m.

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
| Ice-cave inner glow (W3) | Yes: the cave is the signature and would be a black hole without GI | 0 (emission in the atlas) | That is the trick | Yes | **Keep** |
| Real refraction on ice / water (W3, W5) | Would be noticed up close only | Screen texture read, extra pass | Low roughness + sky reflection + baked stones under the ford | Yes | Use the trick |
| Lava light on the surroundings (W4) | A little on the rail and the racers' left side | A real light per lava strip | Emission + glow on the strip only; warm fog | Yes | Use the trick |
| Corrugated container geometry (W6) | Yes within 40 m (silhouette and light rake on the ribs) | 1,260 tris each | `container_far.glb` (12 tris, ribs in the normal map) beyond 40 m | Yes | **Keep near, swap at 40 m** |
| Night lamp light (W6) | Yes: it is the whole look | Each OmniLight costs per lit object | 2 omni near the camera + additive light-pool decals + lamp glow cards for all others | Yes | Use the trick |
| Foliage cards in the rainforest (W5) | Yes as a canopy | Overdraw near the camera | Fewer, larger cards; undergrowth range 35 m | Yes | Keep, watch the 120 fps frame time |
| Far backdrops (mountain ridge, crater cone, mesa ring, lit bridge) | Yes: they close the horizon and fix the HDRI-ground problem | 1 draw, 2-5k tris, no shadow | A painted HDRI band | Yes | **Keep** |

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

Worlds 3-6 and the World 1/2 landmarks (2026-10-06):
```
python3 tools/art/fetch_worlds36.py                         # CC0 downloads (Poly Haven, ambientCG) -> assets/_raw/
python3 tools/art/make_terrain36.py                         # terrain sets world3..6 + world2 canyon_wall
python3 tools/art/make_fx36.py                              # weather/effect sprites, waterfall strip, ripple normal
blender -b --factory-startup -P tools/art/make_skies36.py   # skies (2k hdr + 1k exr), world2 sky-only
blender -b --factory-startup -P tools/art/build_w3.py       # likewise build_w4.py, build_w5.py, build_w6.py
blender -b --factory-startup -P tools/art/build_landmarks12.py
python3 tools/art/glb_slim.py assets/models/world*/*.glb    # opaque PNGs inside the GLBs -> JPEG (disk size only)
python3 tools/art/tex_slim.py assets/textures/world3/*.png   # loose opaque PNGs -> JPEG (RrMats finds .png or .jpg); skip water_ripple_normal.png
blender -b --factory-startup -P tools/art/mock_w36.py -- 3 assets/_raw/build/mock_w3_raw.png
python3 tools/art/hud_overlay.py assets/_raw/build/mock_w3_raw.png docs/mockups/realistic_mock_w3.png --place 4 --progress 0.131 --rivals 0.151,0.143,0.138,0.12,0.108
blender -b --factory-startup -P tools/art/preview36.py -- <hdri> <out_dir> world3/ice_cave ...   # GLB check renders
```
Every GLB the new scripts write passes `tools/art/glb_fix.py` (COLOR_0 = edge-fade alpha, TEXCOORD_0 = baked atlas), so none of them needs `RrMats.UV2_MODELS`. The build scripts append to `assets/_raw/build/w36_report.json` (size, tris, bytes per GLB); `tools/art/sheet36.py` turns preview tiles into a labelled sheet.

## 17. Visual tier and sign-off

Premium realistic 3D. The hero scene is World 1, s 180-320 as in `realistic_mock.png`. The owner signs it off from the builder's **real Godot screenshot** (not this mock) before more track is built; World 2 follows from its own screenshot. What is still below the bar is listed in the graphic-designer's report of 2026-10-06 and in section 18.

## 18. Known gaps (not yet realistic)

- Trees are 4-plane impostors: perfect as a forest wall, but a tree right beside the camera can look flat when the camera yaws fast. Fix later with 2-3 near "hero" pines made of branch cards (about 1.5k tris).
- Rider clothing has no real cloth folds (a noise-based fold normal map only); the jersey reads a little stiff in close-ups. A sculpted fold normal from a cloth sim would lift it.
- Faces are never shown (visor + goggles); the eye port is dark. Fine for racing, weak for a podium close-up.
- Canyon walls are a heightfield with strata steps; they need 3-4 large sandstone cliff meshes for real overhangs and silhouettes.
- Track has no braking bumps, roots or berm geometry in the mesh yet: the texture and the riding-line darkening carry it.
- Mining-town fronts (World 2 finish street) are still not modelled.
- Worlds 3-6 (mocks of 2026-10-06): far backdrops (`mountain_ridge`, `crater_cone`, terrain valley walls) are clean procedural shapes; at full screen they read a little smooth and faceted next to the scanned props. Fix later with 2-3 scanned cliff meshes per world in the middle distance, like `canyon_cliff_a/b`.
- World 4 lava field is a flat 40 m strip of crust with glowing cracks: it reads as lava at 20 m, but it has no flow shapes (lobes, levees). Two or three sculpted lobe meshes would sell it from further away.
- World 5 canopy trees are Poly Haven island trees (temperate-looking crowns) scaled to 23 m; no scanned tropical tree with buttresses and lianas exists in CC0 yet. The buttress tree and the big-leaf undergrowth carry the "rainforest" read; no lianas yet.
- World 5 waterfall (`waterfall_rock` + `waterfall_water` + `pool_water`) was modelled but is not in the mock frame (the frame shows the split path); check it in the first Godot screenshot.
- World 6 lamp reflections on the wet asphalt are additive decals, not real reflections; they do not move with the camera angle the way real ones do.
- World 3 crevasse and ladder bridge, World 4 research station, World 6 warehouse are modelled but outside the mock frames.
- Mocks are Blender EEVEE stand-ins with the game camera; the owner signs off each world from the builder's real Godot screenshot (section 17).

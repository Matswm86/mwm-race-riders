# Credits and licences: MWM Race Riders

Every third-party file below allows commercial use in a paid app. Raw downloads stay out of git (`assets/_raw/`, see `.gitignore`); `tools/art/fetch_polyhaven.py` downloads them again. Everything in `assets/models/` and `assets/textures/` is built from these sources by the scripts in `tools/art/`.

## 3D art (realistic look, 2026-10-06)

### Poly Haven (https://polyhaven.com), licence CC0 1.0 (public domain, no attribution required; credited here anyway)
| Asset | Type | Used for |
|---|---|---|
| `alps_field` | HDRI | World 1 sky and sun light (`assets/textures/world1/sky_alps_field_2k.hdr`) |
| `goegap` | HDRI | World 2 sky and sun light (`assets/textures/world2/sky_goegap_2k.hdr`) |
| `champagne_castle_1` | HDRI | World 1 Pro tracks, evening sky (`assets/textures/world1/sky_champagne_castle_1_1k.exr`) |
| `goegap_road` | HDRI | World 2 Pro tracks, evening sky (`assets/textures/world2/sky_goegap_road_1k.exr`) |
| `rocky_trail_02` | Texture (2K) | World 1 trail surface |
| `rocky_trail` | Texture | World 1 rock outcrops, berm edge |
| `forest_ground_04` | Texture | World 1 forest floor between the trees |
| `forest_leaves_04` | Texture | World 1 pine-needle verge |
| `sparse_grass` | Texture | World 1 grass patches |
| `gravel_floor_02` | Texture | World 1 river road (hoverboard section) |
| `brown_mud_02` | Texture | World 1 mud puddle (`mud_puddle.glb`) |
| `weathered_planks` | Texture | Kicker ramp, fence rails, tape stakes |
| `pine_bark` | Texture | Fence posts, tumbleweed twigs |
| `worn_asphalt` | Texture | Boost-pad mat, hoverboard deck base, World 2 old highway |
| `rusty_metal_02` | Texture | Boost-pad frame, gate feet, water tower |
| `corrugated_iron_02` | Texture | Water-tower roof (World 2) |
| `red_laterite_soil_stones` | Texture (2K) | World 2 trail surface |
| `red_sand` | Texture | World 2 sand floor and `sand_drift.glb` |
| `cliff_side` | Texture | World 2 canyon walls, `ramp_rock.glb` |
| `pine_tree_01` (variants a, b, c) | Model | Rendered into the impostor trees `tree_pine_a/b/c.glb` |
| `rock_moss_set_01` | Model | `rock_a/b/c.glb` (decimated) and their texture `rock_moss_*` |
| `grass_medium_01` | Model | Rendered into `grass_card.glb` |
| `fern_02` | Model | `fern.glb` (decimated) |
| `wild_rooibos_bush` | Model | Rendered into `bush_desert.glb` (World 2) |
| `dead_tree_trunk_02` | Model | `dead_trunk.glb` (World 2, decimated) |

### ambientCG (https://ambientcg.com), licence CC0 1.0
| Asset | Used for |
|---|---|
| `ThatchedRoof001A` (1K) | Straw on `hay_bale.glb` |

### Blender Studio, Human Base Meshes bundle v1.4.1 (https://www.blender.org/download/demo-files/), licence CC0 1.0
| Asset | Used for |
|---|---|
| `GEO-body_male_realistic` | Body of every racer in `rider.glb`, re-shaped into a dressed downhill racer (jersey, pants, gloves, shoes), head removed under the helmet |

### Own work (made for this game in Blender 4.5 by `tools/art/*.py`, same licence as this repository)
- `rider.glb`: clothing shapes, full-face helmet, goggles, skeleton, 9 animations, 6 liveries (`assets/textures/rider/`)
- `bike.glb`: downhill mountain bike, skeleton, 3 animations, 6 liveries (`assets/textures/bike/`)
- `hoverboard.glb`, `boost_pad.glb`, `ramp.glb`, `swap_gate.glb`, `finish_arch.glb` (shared kit, `assets/textures/kit/`)
- `hay_bale.glb`, `mud_puddle.glb`, `fence_rail.glb`, `tape_stake.glb` (World 1), `tumbleweed.glb`, `sand_drift.glb`, `water_tower.glb`, `ramp_rock.glb` (World 2), built from the CC0 textures above
- Number decals, gate icons, chequer, FX sprites (`assets/textures/fx/`), drawn with Python Pillow
- Mock renders in `docs/mockups/` (`realistic_mock.png`, `realistic_mock_w2.png`), rendered in Blender 4.5 EEVEE from the exported GLBs; HUD drawn with Pillow (`tools/art/hud_overlay.py`)

## 3D art for worlds 3-6 and the World 1/2 landmarks (2026-10-06, second pass)

Downloaded again by `tools/art/fetch_worlds36.py` into `assets/_raw/` (not in git). Built by `tools/art/make_terrain36.py`, `make_skies36.py`, `make_fx36.py`, `build_w3.py` ... `build_w6.py` and `build_landmarks12.py`.

### Poly Haven (https://polyhaven.com), licence CC0 1.0
| Asset | Type | Used for |
|---|---|---|
| `horn-koppe_snow` | HDRI | World 3 sky (`assets/textures/world3/sky_horn_koppe_snow_*`) |
| `belfast_sunset_puresky` | HDRI | World 4 sky, warmed and dimmed for volcanic haze (`world4/sky_belfast_sunset_puresky_*`) |
| `rainforest_trail` | HDRI | World 5 sky (`world5/sky_rainforest_trail_*`) |
| `qwantani_moonrise_puresky` | HDRI | World 6 night sky (`world6/sky_qwantani_moonrise_puresky_*`) |
| `goegap` | HDRI | World 2 sky-only version, hills above the horizon painted out (`world2/sky_goegap_skyonly_*`) |
| `snow_02`, `snow_04`, `snow_field_aerial` | Texture | World 3 snow layers, groomed piste, snow-cat tracks, snow props |
| `low_tide_rocks`, `burned_ground_01` | Texture | World 4 ash trail and ash ground |
| `mud_forest`, `brown_mud_leaves_01`, `forest_leaves_02`, `river_small_rocks`, `mossy_rock` | Texture | World 5 ground layers, ruins, ford |
| `bark_brown_02` | Texture | World 5 buttress tree |
| `asphalt_02`, `concrete_floor_worn_001`, `metal_plate`, `concrete_wall_003` | Texture | World 6 wet asphalt, quay, steel plates, quay wall; World 2 gas station walls |
| `container_side`, `factory_wall` | Texture | Research station (World 4), warehouse cladding (World 6) |
| `rock_face_03` | Texture | World 1 rock tunnel |
| `distressed_painted_planks` | Texture | Glacier hut walls (World 3) |
| `leafy_grass` | Texture | Turf roof of the World 1 cabin |
| `painted_concrete` | Texture | Gas station paint band (World 2) |
| `weathered_planks`, `pine_bark`, `rusty_metal_02`, `corrugated_iron_02`, `worn_asphalt`, `red_sand`, `rocky_trail`, `forest_leaves_04` | Texture | Re-used from the first pass (listed above) for bridges, hut, cabin, containers, gas station, cliffs |
| `boulder_01` | Model | `world3/glacier_boulder.glb` (decimated, cooled to grey) |
| `moon_rock_01`, `moon_rock_03`, `moon_rock_05` | Model | `world4/falling_rock_a/b.glb`, `world4/scoria_rock.glb` (decimated, darkened to scoria) |
| `namaqualand_cliff_01`, `namaqualand_cliff_02` | Model | `world2/canyon_cliff_a/b.glb` (decimated, re-skinned with level sandstone strata) |
| `island_tree_01`, `island_tree_02` | Model | Rendered into the impostor trees `world5/tree_jungle_a/b.glb` |
| `pachira_aquatica_01`, `calathea_orbifolia_01`, `anthurium_botany_01` | Model | Rendered into the card plants `world5/shrub_jungle.glb`, `plant_calathea.glb`, `plant_anthurium.glb` |
| `dry_branches_medium_01` | Model | `world5/branch_pile.glb` |
| `dead_tree_trunk` | Model | `world5/log_hop.glb` (stretched to 11 m, moss tint) |
| `dead_tree_trunk_02` | Model | `world4/burnt_snag.glb` (charred tint) |
| `concrete_road_barrier` | Model | `world6/concrete_barrier.glb` |
| `lateral_sea_marker` | Model | `world6/sea_marker.glb` |

### ambientCG (https://ambientcg.com), licence CC0 1.0
| Asset | Used for |
|---|---|
| `Ice003` (1K) | World 3 blue ice: ice patch, seracs, ice cave, crevasse walls, kicker lip |
| `Lava001` (1K) | World 4 lava crust layer (glow removed) and the glowing cracks of `lava_field.glb` (its emission map) |
| `Rock035` (1K) | World 4 basalt |
| `Rock030` (1K) | World 3 glacier rock; World 2 canyon-wall layer (with procedural level strata) |

### Own work (Blender 4.5 / Python, same licence as this repository)
- World 3: `ice_cave`, `crevasse`, `ramp_snow`, `ice_patch`, `snow_drift`, `snow_slough`, `glacier_hut`, `ladder_bridge`, `flag_pole`, `serac_a/b`, `serac_card`, `mountain_ridge`, `glacier_boulder_card`
- World 4: `steam_vent`, `ash_dune`, `lava_crust_ridge`, `crater_cone`, `basalt_columns` (+ card), `research_station`, `lava_field`, `safety_rail`, `scoria_rock_card`
- World 5: `waterfall_rock`, `waterfall_water`, `pool_water`, `river_ford`, `rope_bridge`, `buttress_tree` (+ card), `stone_ruin`
- World 6: `container`, `container_stack_far`, `crane_jump_stack`, `ramp_steel`, `gantry_crane`, `air_ring`, `steel_plate`, `traffic_cone`, `cable_spool`, `sodium_lamp`, `ferry`, `warehouse`, `lit_bridge_far`, `bollard`
- World 1: `cabin`, `river_bridge`, `rock_tunnel_portal`, `rock_tunnel_segment`; World 2: `sandstone_arch`, `gas_station`, `mesa_backdrop`
- Weather and effect sprites `assets/textures/world3..6/fx_*.png`, the waterfall water strip and ripple normal, drawn with Python (NumPy + Pillow)
- Mocks `docs/mockups/realistic_mock_w3.png` ... `realistic_mock_w6.png` (`tools/art/mock_w36.py`) and the World 2 fix check `realistic_mock_w2_fix.png` (`tools/art/mock_w2_fix.py`), Blender 4.5 EEVEE; HUD by `hud_overlay.py`

The retired toy look (models, palette, old mocks and their scripts) is kept on disk in `docs/mockups/old_toy/`, outside git.

## Sound
| Asset | Source | Licence |
|---|---|---|
| Sound effects in `assets/sfx/` | Own synthesis (`tools/render_sfx.py`), layered with samples from Kenney Impact Sounds (https://kenney.nl/assets/impact-sounds): `footstep_grass_000-004`, `impactSoft_heavy_001`, `impactPlank_medium_000`, `impactMetal_light_000`, `impactMetal_light_002` | Own work; Kenney samples CC0 |

## Music
| Asset | Source | Licence |
|---|---|---|
| `assets/music/race_riders_theme.ogg` | Music supplied by the game owner | Used with the owner's permission |

## Fonts
| Font | Use | Licence |
|---|---|---|
| Barlow Condensed (`assets/fonts/BarlowCondensed-*.ttf`), The Barlow Project Authors | HUD place digit, race time, rider numbers on jerseys, bikes and HUD tokens | SIL Open Font License 1.1 (`assets/fonts/BarlowCondensed-OFL.txt`) |

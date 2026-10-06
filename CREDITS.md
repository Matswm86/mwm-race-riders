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

class_name RrBalance
extends RefCounted
## All MWM Race Riders tunables. Source: docs/GDD.md. Sim: tools/pack_sim.py.

# Race (per-world lengths under Unlocks)
const TRACK1_LENGTH_M: float = 1425.0  # = WORLD_LENGTH_M[0]
const RUNOUT_M: float = 90.0
const RIDER_COUNT: int = 6  # player + 5 AI (owner)
const AI_START_GAP_M: float = 4.5  # AI at s 4.5, 9, 13.5, 18, 22.5; player at 0
const AI_LANE_OFFSETS: Array[float] = [-3.0, 3.0, -1.5, 1.5, 0.0]

# Speed
const CRUISE_MPS: float = 30.0  # owner 18:27 (was 20)
const SPEED_MULT_CAP: float = 1.6  # all effects together, 48 m/s top
const ACCEL_UP: float = 10.5  # m/s^2
const ACCEL_DOWN: float = 18.0
const MIN_SPEED_FRAC: float = 0.6  # never below 18 m/s after GO (except a fallen rival)
const STEEP_MULT: float = 1.05  # Bratthenget section
const HOVER_SMOOTH_MULT: float = 1.06
const RUNOUT_MULT: float = 0.5

# Steering
const STEER_LAT_MAX: float = 6.0  # m/s
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
const ASSIST_LAT_MAX: float = 3.0  # m/s toward the kid line
const ASSIST_EASE_S: float = 0.3
const ASSIST_RESUME_S: float = 0.6
const AUTO_BOOST_S_L: float = 2.0  # Lett only; Vanlig = manual

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
const GRAVITY: float = 22.0  # m/s^2, game gravity
const KICKER_AIR_S: Array[float] = [1.0, 1.2, 1.6, 1.0]  # K1-K4, world 1
const KICKER_AIR_S_W2: Array[float] = [1.0, 1.2, 1.8, 0.8]  # K1-K4, world 2 (K3 = mesa gap)
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
const BUMP_MULT_PLAYER: float = 1.0  # owner 12:42: contact never slows the player
const BUMP_MULT_AI: float = 0.90
const BUMP_PAIR_COOLDOWN_S: float = 1.0

# Knock-offs (player hits rival) and nudges (rival hits player)
const KNOCK_DS_M: float = 1.0  # side contact: |ds| below this
const KNOCK_LAT_MIN_L: float = 1.2  # player lateral speed toward rival, m/s
const KNOCK_LAT_MIN_V: float = 1.8
const KNOCK_IMMUNE_S: float = 6.0  # after the rival rides again
const FALL_DECEL: float = 60.0  # m/s^2, 30 m/s to 0 in 0.5 s
const FALL_SLIDE_LAT_MPS: float = 3.0  # slides toward the nearest rail
const FALL_DOWN_S: float = 1.2  # from the hit, incl. the slide
const GETUP_S: float = 0.5
const REJOIN_ACCEL: float = 15.0  # m/s^2
const REJOIN_RB_OFF_FRAC: float = 0.9  # no rubber band until v >= 0.9 x target
const NUDGE_PUSH_MPS: float = 3.0
const NUDGE_PUSH_S: float = 0.25
const RECENTRE_LAT_MPS: float = 2.4
const RECENTRE_MAX_S: float = 1.0
const RIVAL_LEAN_IN_L: float = 0.0
const RIVAL_LEAN_IN_V: float = 0.25  # chance per check when side by side
const RIVAL_LEAN_IN_EVERY_S: float = 2.0
const RIVAL_LEAN_IN_M: float = 1.0
const KNOCK_ICON_S: float = 0.5
const HAY_MULT: float = 0.85  # W1 Block
const HAY_TIME_S: float = 0.5
const MUD_MULT: float = 0.90  # W1 Patch, bike and board
const SAND_MULT_L: float = 0.94  # W2 Patch, hoverboard floats over
const SAND_MULT_V: float = 0.88
const ROLLER_TRIGGER_M: float = 60.0  # roller spawns when the player is this far before it
const ROLLER_LAT_MPS_L: float = 2.0
const ROLLER_LAT_MPS_V: float = 3.0
const ROLLER_DIAM_M: float = 1.2
const ROLLER_NUDGE_MPS: float = 2.0  # sideways, 0.25 s, no speed loss
const ROLLER_NUDGE_S: float = 0.25
const HOP_AIR_S: float = 0.4  # later worlds (logs, lava crust)
const HINDRANCE_MIN_GAP_M: float = 45.0  # any two; same lane 90
const HINDRANCE_SAME_LANE_GAP_M: float = 90.0
const HINDRANCE_VISIBLE_M: float = 60.0  # >= 1.2 s reaction at the 48 m/s cap
const LANDING_CLEAR_AFTER_M: float = 30.0

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
const RB_FADE_FROM_L: float = 1.1  # never fades
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
const GUARD_WINDOW_S: Vector2 = Vector2(0.3, 2.0)  # gear and home two-tap guard
const IDLE_HINT_S: float = 7.0

# Camera
const CAM_OFFSET: Vector3 = Vector3(0.0, 1.8, 3.8)  # GDD 11 speed retune 18:27
const CAM_PITCH_DEG: float = -10.0
const CAM_FOV: float = 70.0  # = CAM_FOV_REST, standstill
const CAM_FOV_CRUISE: float = 75.0
const CAM_FOV_BOOST_ADD: float = 8.0
const CAM_FOV_BOOST: float = 83.0  # cruise 75 + 8
const CAM_FOV_IN_S: float = 0.15
const CAM_FOV_OUT_S: float = 0.4
const CAM_FOLLOW_POS: float = 10.0
const CAM_FOLLOW_YAW: float = 7.0
const CAM_FOLLOW_HEIGHT: float = 4.0
const SPEED_LINES_FROM_MPS: float = 25.0
const SPEED_LINES_FULL_MPS: float = 45.0
const WIND_DB: Vector2 = Vector2(-30.0, -12.0)  # at 0 and at 45 m/s
const WIND_PITCH: Vector2 = Vector2(0.8, 1.3)
const WIND_WHISTLE_FROM_MPS: float = 35.0
const RUMBLE_M: float = 0.02  # dirt/sand/planks, x v/cruise, cap 0.03
const RUMBLE_MAX_M: float = 0.03
const RUMBLE_HZ: float = 12.0
const PROP_NEAR_SPACING_M: Vector2 = Vector2(3.0, 6.0)  # random, both sides
const PROP_MID_SPACING_M: Vector2 = Vector2(6.0, 10.0)
const PROP_CULL_M: float = 150.0
const SPEED_LINES_ALPHA_MAX: float = 0.25

# Feel
const LAND_SQUASH: Vector2 = Vector2(1.10, 0.80)  # xz, y
const LAND_SQUASH_IN_S: float = 0.08
const LAND_SQUASH_OUT_S: float = 0.18
const WOBBLE_DEG: float = 12.0
const WOBBLE_HZ: float = 3.0
const HOVER_HEIGHT_M: float = 0.3
const HOVER_BOB_M: float = 0.05
const HOVER_BOB_HZ: float = 1.5
const KNOCK_DUST_PARTICLES: int = 20  # DESIGN 7: 20 dust puffs + 6 stones
const KNOCK_DUST_S: float = 0.9
const MAX_FLASHES_PER_S: int = 3

# Ghost
const GHOST_HZ: int = 10
const GHOST_ALPHA: float = 0.4
const GHOST_DEFAULT_ON: bool = true
const GHOST_FADE_NEAR_M: float = 4.0  # hidden at or under this distance to the player
const GHOST_FADE_FAR_M: float = 6.0  # full GHOST_ALPHA from here

# Unlocks (total finishes)
const UNLOCK_HOVER: int = 1
const WORLD_COUNT: int = 6
const WORLDS_BUILT: int = 2  # slice: worlds 1-2 have tracks; 3-6 are design only
const WORLD_LENGTH_M: Array[float] = [1425.0, 1470.0, 1500.0, 1470.0, 1500.0, 1575.0]
# World N+1 opens on the first finish of world N (any place).
const FREE_WORLDS: int = 1
const FREE_CARD_FROM_FINISH: int = 1  # at most once per app session

# Audio
const SFX_VOL_DEFAULT: int = 80
const MUSIC_VOL_DEFAULT: int = 60
const MUSIC_UNDER_SFX_DB: float = -6.0
const FINISH_DUCK_DB: float = -4.0

# Builder additions (godot-android-dev): layout and look numbers from DESIGN.md
const DESIGN_W: float = 1080.0
const DESIGN_H: float = 1920.0
const HOME_HIT: float = 216.0  # home disc and gear hit squares
const TOP_ROW_CLEAR: float = 36.0  # safe-area slack before the top row moves
const WRIST_Y: float = 1664.0  # touches starting below this are ignored
const BOOST_CENTER_Y_FROM_BOTTOM: float = 430.0  # GDD 3.1: centre (540, 1490) at 1920
const BOOST_DRAW_R: float = 110.0
const BOOST_HIT_R: float = 140.0
const CAM_FAR: float = 900.0  # DESIGN 8: HDRI mountains and canyon rims
const CAM_FOV_LESS_MOTION: float = 72.0  # GDD 11.1: fixed FOV
const LAND_SHAKE_PX: float = 6.0
const LAND_SHAKE_S: float = 0.12
const PLACE_POP_MIN_S: float = 0.5  # at most one medal change shown per 0.5 s
const AI_TRAFFIC_LOOK_M: float = 4.5  # = AI_TRAFFIC_AHEAD_M
const AI_TRAFFIC_DX_M: float = 1.2
const AI_TRAFFIC_SHIFT_M: float = 1.5
const AI_HAY_SHIFT_M: float = 2.0
const ASSIST_GAIN: float = 2.0  # m/s of assist per metre off the kid line
const AI_LINE_GAIN: float = 3.0
const RUNOUT_STOP_M: float = 82.0  # riders come to rest this far past the line
const BALE_RESPAWN_S: float = 1.5
const KICKER_LIP_M: float = 1.15  # ramp.glb lip height
const KICKER_LEN_M: float = 3.65  # ramp.glb deck length
const SWAP_HOP_M: float = 0.3
const STEER_ARROW_S: float = 0.08
const HINT_LOOP_S: float = 1.6
const IDLE_HINT_SHOW_S: float = 2.0

# Progression v2 (GDD 17.8)
const WORLDS: int = 6
const TRACKS_PER_WORLD: int = 8
const TRACK_LENGTH_STEP_M: float = 25.0  # track k = WORLD_LENGTH_M[w] + 25 * (k - 1)
const PRO_AI_SKILL_ADD: float = 0.01
const PRO_EXTRA_HINDRANCES: int = 2
const LEAGUES: Array[StringName] = [
	&"bronze", &"silver", &"gold", &"platinum", &"diamond", &"champion"
]
const TIERS_PER_LEAGUE: int = 3
const ROUNDS_PER_SEASON: int = 5
const TABLE_RIVALS: int = 11
const LEAGUE_POINTS: Array[int] = [10, 8, 6, 5, 4, 3]
const PROMOTE_TOP: int = 3
const LETT_SAFETY_SEASONS: int = 2
const VANLIG_DEMOTE_BOTTOM: int = 2
const DEMOTION_DEFAULT_ON: bool = false
const RIVAL_SKILL_BASE_L: Array[float] = [
	0.90, 0.91, 0.92, 0.93, 0.94, 0.95, 0.96, 0.97, 0.98, 0.99, 1.00
]
const RIVAL_SKILL_BASE_V: Array[float] = [
	0.89, 0.90, 0.91, 0.92, 0.93, 0.94, 0.95, 0.96, 0.97, 0.98, 0.99
]
const LEAGUE_SKILL_STEP_L: float = 0.006  # per league; a third per tier
const LEAGUE_SKILL_STEP_V: float = 0.01
const RIVAL_HEAT_NOISE: float = 0.025  # seeded rival-only heat
const RIVAL_FORM_STEP: float = 0.01  # -1, 0 or +1 step after an absence
const RIVAL_FORM_AWAY_H: float = 8.0
const BOARD_TIME_NOISE: float = 0.015
const MEDAL_PAR_MULT: Array[float] = [1.01, 1.04, 1.08]  # gold, silver, bronze
const FREE_TRACKS_W1: int = 5  # = Bronze III
const FREE_LEAGUE_TIERS: int = 1
# Builder additions for progression v2
const LEAGUES_BUILT: int = 2  # Bronze (world 1) and Silver (world 2)
const TABLE_SLIDE_S: float = 1.5  # league table rows slide to their new places

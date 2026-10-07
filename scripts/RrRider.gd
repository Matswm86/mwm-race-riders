class_name RrRider
extends RefCounted

## One racer in track space (GDD 4): s along the centre line, x sideways
## (+ = right), h above the surface. Pure state; RrRace moves it and RrAi
## steers the five rivals. Views read it every frame.
## Livery 0-5 = DESIGN 2a racers r1-r6 (r1 = the player).

const BIKE: int = 0
const BOARD: int = 1

var index: int = 0
var is_player: bool = false
var livery: int = 0
var number: int = 7
var team: Color = Color(1, 1, 1)

var s: float = 0.0
var x: float = 0.0
var h: float = 0.0
var v: float = 0.0
var lat_v: float = 0.0
var vy: float = 0.0
var airborne: bool = false
var air_t: float = 0.0
var air_total: float = 0.0
var trick_t: float = -1.0
var trick_len: float = 0.0
var trick_count: int = 0
var on_ramp: bool = false
var reached_floor: bool = false

## Timed speed effects (absolute race time when each ends).
var pad_until: float = -1.0
var pad_mult: float = 1.0
var chain: int = 0
var last_pad_t: float = -99.0
var boost_until: float = -99.0
var land_until: float = -1.0
var hay_until: float = -1.0
## W6 air ring speed (GDD 6.0), absolute race time when it ends.
var ring_until: float = -1.0
var bump_until: float = -1.0
var push_until: float = -1.0
var push_v: float = 0.0
var rail: bool = false
## Patch slow-down this frame (mud, sand), 1.0 outside.
var patch_mult: float = 1.0

## Knock-off (GDD 4.7, rivals only): seconds since the hit, < 0 = riding.
var fall_t: float = -1.0
var fall_dir: float = 1.0
## True from the hit until the rival is back to REJOIN_RB_OFF_FRAC of its
## target speed (no speed floor, no rubber band, no collision while down).
var knocked: bool = false
var immune_until: float = -99.0
var knock_count: int = 0

## Player nudge auto-recentre (GDD 4.7): x to return to, and until when.
var recentre_x: float = 0.0
var recentre_until: float = -99.0

## Boost meter 0..1; fills from GO in BOOST_FIRST_S, refills after each boost.
var meter: float = 0.0
var full_since: float = -1.0
var boost_delay: float = -1.0

var vehicle: int = BIKE
var swap_t: float = -1.0
var finished: bool = false
var finish_time: float = 0.0
var projected: bool = false
var place: int = 6

## Next-element cursors (elements are sorted by s).
var next_pad: int = 0
var next_kick: int = 0
var next_hay: int = 0
var next_gate: int = 0
var next_hop: int = 0
var next_ring: int = 0


## On the ground and still in the knock-off sequence (fall, lie, get up).
func down() -> bool:
	return fall_t >= 0.0 and fall_t < RrBalance.FALL_DOWN_S + RrBalance.GETUP_S


## GDD 4.5: only after GO (QA finding 3: the disc showed "active" pre-race).
func boosting(t: float) -> bool:
	return t >= 0.0 and t < boost_until

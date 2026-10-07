class_name RrWorlds
extends RefCounted

## The worlds (GDD 6, DESIGN 9-10). Cruise 30 m/s (owner 18:27): every
## distance is the 20 m/s design x1.5, so the timings stay the same. Every
## level is a different place with its own track, hindrances, sky, light,
## fog and weather; nothing is reused from one world to the next except the
## racers and the shared kit. Track numbers
## are GDD 6.1 / 6.2 section tables (s in metres from the start line, x in
## metres, + = right). Worlds 1 and 2 have a hand-made track 1 here; worlds
## 3-6 (DESIGN 11) have only their look and kit here: every one of their
## tracks, track 1 included, is data from tools/track_gen.py (tracks/*.json).

const W1: Dictionary = {
	"id": 1,
	"name": "Furuløypa",
	"name_en": "Pine Run",
	"length": 1425.0,
	# [from, to, surface, cruise mult]; "lane" = smooth (hoverboard x1.06).
	"sections":
	[
		[-60.0, 450.0, "dirt", 1.0],
		[450.0, 900.0, "lane", 1.0],
		[900.0, 1320.0, "dirt", 1.05],
		[1320.0, 1425.0, "dirt", 1.0],
		[1425.0, 1580.0, "dirt", 0.5],
	],
	"widths":
	[
		[-60.0, 12.0],
		[0.0, 12.0],
		[60.0, 10.0],
		[804.0, 10.0],
		[816.0, 8.0],
		[864.0, 8.0],
		[876.0, 10.0],
		[900.0, 10.0],
		[909.0, 9.0],
		[1071.0, 9.0],
		[1083.0, 7.0],
		[1152.0, 7.0],
		[1164.0, 9.0],
		[1311.0, 9.0],
		[1329.0, 12.0],
		[1580.0, 12.0],
	],
	"kid_line":
	[
		[-60.0, 0.0],
		[457.0, 0.0],
		[492.0, 2.5],
		[563.0, 2.5],
		[593.0, 0.0],
		[723.0, 0.0],
		[750.0, 1.8],
		[810.0, 1.8],
		[837.0, 0.0],
		[996.0, 0.0],
		[1026.0, 3.0],
		[1073.0, 3.0],
		[1103.0, 0.0],
		[1580.0, 0.0],
	],
	"pads":
	[
		[180.0, 0.0],
		[345.0, -3.0],
		[510.0, 2.5],
		[528.0, 2.5],
		[546.0, 2.5],
		[735.0, -3.0],
		[1050.0, 3.0],
		[1230.0, -3.0],
		[1248.0, -3.0],
		[1266.0, -3.0],
	],
	"kickers": [270.0, 645.0, 1140.0, 1350.0],
	"kicker_air": [1.0, 1.2, 1.6, 1.0],
	"kicker_models": ["ramp", "ramp", "ramp", "ramp"],
	# Block hindrances (hay bales, GDD 4.8): [s, x].
	"blocks":
	[
		[390.0, 2.5],
		[780.0, -0.5],
		[975.0, 2.0],
		[1300.0, 1.5],
	],
	# Patch hindrances: [s0, s1, x0, x1, kind].
	"patches":
	[
		[225.0, 240.0, 2.0, 4.5, "mud"],
		[1028.0, 1043.0, -4.0, -1.5, "mud"],
	],
	# Roller hindrances: [s, direction (+1 = rolls left to right)].
	"rollers": [],
	"gates":
	[
		[450.0, 1],
		[900.0, 0],
	],
	"bends":
	[
		[75.0, 150.0, -1.0 / 90.0],
		[165.0, 240.0, 1.0 / 90.0],
		[308.0, 420.0, 1.0 / 225.0],
		[495.0, 630.0, -1.0 / 300.0],
		[690.0, 810.0, 1.0 / 240.0],
		[930.0, 1050.0, -1.0 / 195.0],
		[1185.0, 1290.0, 1.0 / 330.0],
	],
	"grades":
	[
		[-60.0, 0.05],
		[0.0, 0.15],
		[60.0, 0.08],
		[450.0, 0.06],
		[900.0, 0.2],
		[1320.0, 0.04],
		[1425.0, 0.02],
	],
	# Extra drop [from, to, metres] on top of the grade (W2 mesa gap).
	"drops": [],
	# Track s range with no surface under it (a gorge to jump), or [].
	"gap": [],
	"tunnel": [810.0, 870.0],
	"fence": [1077.0, 1158.0],
	"river": [444.0, 906.0],
	"look":
	{
		"sky": "res://assets/textures/world1/sky_alps_field_1k.exr",
		# Sun behind the camera, over its right shoulder (DESIGN 6 note); yaw
		# found with a sweep on the real build (riders' backs lit, shadows
		# falling forward-left).
		"sun_rot": Vector3(-42.0, 135.0, 0.0),
		"sun_color": Color(1.000, 0.945, 0.863),
		"sun_energy": 1.6,
		"sky_yaw": 0.0,
		"fog_begin": 30.0,
		"fog_end": 450.0,
		"fog_color": Color(0.620, 0.702, 0.780),
		"fog_max": 0.42,
		"dust": Color(0.62, 0.52, 0.42),
		"weather": "pollen",
	},
}

const W2: Dictionary = {
	"id": 2,
	"name": "Ørkenjuvet",
	"name_en": "Red Canyon",
	"length": 1470.0,
	"sections":
	[
		[-60.0, 450.0, "dirt", 1.0],
		[450.0, 930.0, "lane", 1.0],
		[930.0, 1350.0, "dirt", 1.05],
		[1350.0, 1470.0, "dirt", 1.0],
		[1470.0, 1580.0, "dirt", 0.5],
	],
	"widths":
	[
		[-60.0, 12.0],
		[0.0, 12.0],
		[90.0, 10.0],
		[324.0, 10.0],
		[336.0, 8.0],
		[441.0, 8.0],
		[453.0, 11.0],
		[918.0, 11.0],
		[930.0, 10.0],
		[942.0, 9.0],
		[1128.0, 9.0],
		[1140.0, 8.0],
		[1224.0, 8.0],
		[1236.0, 9.0],
		[1341.0, 9.0],
		[1359.0, 12.0],
		[1580.0, 12.0],
	],
	# GDD 6.2 kid line; the ramps start early enough that an idle Lett rider
	# is clear of each sand drift before it begins.
	"kid_line":
	[
		[-60.0, 0.0],
		[170.0, 0.0],
		[195.0, 2.0],
		[255.0, 2.0],
		[275.0, 0.0],
		[465.0, 0.0],
		[495.0, -2.5],
		[590.0, -2.5],
		[615.0, 0.0],
		[815.0, 0.0],
		[840.0, -2.5],
		[900.0, -2.5],
		[925.0, 0.0],
		[945.0, 0.0],
		[975.0, -3.0],
		[1035.0, -3.0],
		[1065.0, 0.0],
		[1290.0, 0.0],
		[1315.0, 1.5],
		[1365.0, 1.5],
		[1380.0, 0.0],
		[1580.0, 0.0],
	],
	"pads":
	[
		[165.0, 0.0],
		[428.0, 2.0],
		[525.0, -2.5],
		[543.0, -2.5],
		[561.0, -2.5],
		[810.0, 3.0],
		[1005.0, -3.0],
		[1275.0, 3.0],
		[1293.0, 3.0],
		[1311.0, 3.0],
	],
	"kickers": [300.0, 720.0, 1170.0, 1395.0],
	"kicker_air": [1.0, 1.2, 1.8, 0.8],
	"kicker_models": ["ramp_rock", "ramp_rock", "ramp_rock", "ramp"],
	"blocks": [],
	"patches":
	[
		[225.0, 248.0, -3.0, 0.5, "sand"],
		[870.0, 893.0, -1.0, 3.5, "sand"],
		[1330.0, 1352.0, -3.5, 0.0, "sand"],
	],
	"rollers":
	[
		[390.0, 1.0],
		[600.0, -1.0],
		[660.0, 1.0],
		[1080.0, -1.0],
	],
	"gates":
	[
		[450.0, 1],
		[930.0, 0],
	],
	"bends":
	[
		[105.0, 195.0, 1.0 / 135.0],
		[225.0, 308.0, -1.0 / 180.0],
		[342.0, 435.0, 1.0 / 112.5],
		[495.0, 675.0, -1.0 / 390.0],
		[750.0, 900.0, 1.0 / 315.0],
		[960.0, 1095.0, -1.0 / 165.0],
		[1245.0, 1320.0, 1.0 / 255.0],
		[1365.0, 1440.0, -1.0 / 240.0],
	],
	"grades":
	[
		[-60.0, 0.05],
		[0.0, 0.22],
		[90.0, 0.08],
		[330.0, 0.1],
		[450.0, 0.06],
		[930.0, 0.18],
		[1185.0, 0.12],
		[1350.0, 0.06],
		[1470.0, 0.02],
	],
	# The mesa gap lands 6 m lower than it takes off (GDD 6.2).
	"drops":
	[
		[1173.0, 1221.0, 9.0],
	],
	"gap": [1174.0, 1199.0],
	"tunnel": [],
	"fence": [],
	"river": [],
	# Canyon set pieces for the ground generator: the slot canyon, the rim
	# highway (= the smooth lane section), the mesa switchbacks and the town.
	"zones": {"slot": [321.0, 453.0], "lane": [450.0, 930.0], "mesa": 930.0, "town": 1350.0},
	"look":
	{
		# DESIGN 10a fix 1: the HDRI hills above the horizon painted out.
		"sky": "res://assets/textures/world2/sky_goegap_skyonly_1k.exr",
		# DESIGN 10a fix 2: the mesa backdrop ring needs a 1100 m far plane.
		"far": 1100.0,
		"sun_rot": Vector3(-46.0, 135.0, 0.0),
		"sun_color": Color(1.000, 0.965, 0.910),
		"sun_energy": 1.9,
		"sky_yaw": 0.0,
		"fog_begin": 50.0,
		"fog_end": 650.0,
		"fog_color": Color(0.820, 0.702, 0.580),
		"fog_max": 0.30,
		"dust": Color(0.70, 0.47, 0.35),
		"weather": "sand",
	},
}

## Worlds 3-6 (GDD 6.0, DESIGN 11): name, base length and look. Their tracks
## come from tracks/w<w>_t<k>.json.
const W3: Dictionary = {
	"id": 3,
	"name": "Isbreen",
	"name_en": "Glacier Run",
	"length": 1500.0,
	"look":
	{
		"sky": "res://assets/textures/world3/sky_horn_koppe_snow_1k.exr",
		"sun_rot": Vector3(-28.0, 135.0, 0.0),
		"sun_color": Color(1.000, 0.965, 0.925),
		"sun_energy": 1.6,
		"sky_yaw": 0.0,
		"exposure": 0.7,
		"fog_begin": 40.0,
		"fog_end": 700.0,
		"fog_color": Color(0.80, 0.86, 0.94),
		"fog_max": 0.35,
		"dust": Color(0.90, 0.93, 0.98),
		"weather": "snow",
		"far": 1200.0,
	},
}

const W4: Dictionary = {
	"id": 4,
	"name": "Askefjellet",
	"name_en": "Ash Mountain",
	"length": 1470.0,
	"look":
	{
		"sky": "res://assets/textures/world4/sky_belfast_sunset_puresky_1k.exr",
		"sun_rot": Vector3(-9.0, 135.0, 0.0),
		"sun_color": Color(1.000, 0.698, 0.478),
		"sun_energy": 1.1,
		"sky_yaw": 0.0,
		"exposure": 1.1,
		"fog_begin": 25.0,
		"fog_end": 520.0,
		"fog_color": Color(0.50, 0.37, 0.27),
		"fog_max": 0.42,
		"dust": Color(0.36, 0.34, 0.32),
		"weather": "ash",
		"far": 1300.0,
	},
}

const W5: Dictionary = {
	"id": 5,
	"name": "Regnskogen",
	"name_en": "Rainforest",
	"length": 1500.0,
	"look":
	{
		"sky": "res://assets/textures/world5/sky_rainforest_trail_1k.exr",
		"sun_rot": Vector3(-41.0, 135.0, 0.0),
		"sun_color": Color(1.000, 0.949, 0.871),
		"sun_energy": 0.7,
		"sky_yaw": 0.0,
		"exposure": 1.05,
		"fog_begin": 18.0,
		"fog_end": 260.0,
		"fog_color": Color(0.62, 0.68, 0.62),
		"fog_max": 0.5,
		"dust": Color(0.27, 0.23, 0.17),
		"weather": "rain",
	},
}

const W6: Dictionary = {
	"id": 6,
	"name": "Nattehavna",
	"name_en": "Night Harbour",
	"length": 1575.0,
	"look":
	{
		"sky": "res://assets/textures/world6/sky_qwantani_moonrise_puresky_1k.exr",
		"sky_energy": 0.035,
		"sun_rot": Vector3(-14.0, 135.0, 0.0),
		"sun_color": Color(0.62, 0.71, 0.85),
		"sun_energy": 0.2,
		"sky_yaw": 0.0,
		"exposure": 1.85,
		"glow_threshold": 1.0,
		"fog_begin": 30.0,
		"fog_end": 600.0,
		"fog_color": Color(0.10, 0.11, 0.14),
		"fog_max": 0.45,
		"dust": Color(0.30, 0.30, 0.32),
		"weather": "drizzle",
		"far": 1300.0,
		"lamps": true,
		"ambient": Color(0.16, 0.19, 0.26),
	},
}

## What each world puts on the track (GDD 6.0 hindrances, DESIGN 9-11 models).
## block / roller / hop: model names under assets/models (world dirs as
## "world5/branch_pile"); block_mult: Block slow-down; patches: patch kind ->
## model; ramp: kicker skin of the small kickers.
const KIT: Dictionary = {
	1: {"block": "hay_bale", "block_mult": 0.85, "roller": "tumbleweed", "hop": ""},
	2: {"block": "hay_bale", "block_mult": 0.85, "roller": "tumbleweed", "hop": ""},
	3: {"block": "", "block_mult": 1.0, "roller": "world3/snow_slough", "hop": ""},
	4:
	{
		"block": "",
		"block_mult": 1.0,
		"roller": "world4/falling_rock_a",
		"hop": "world4/lava_crust_ridge",
	},
	5:
	{
		"block": "world5/branch_pile",
		"block_mult": 0.85,
		"roller": "",
		"hop": "world5/log_hop",
	},
	6:
	{
		"block": "world6/traffic_cone",
		"block_mult": 0.95,
		"roller": "world6/cable_spool",
		"hop": "",
	},
}
## Patch kind -> model (scaled to the patch rectangle by RrWorld).
const PATCH_MODELS: Dictionary = {
	"mud": "mud_puddle",
	"sand": "sand_drift",
	"ice": "world3/ice_patch",
	"snow": "world3/snow_drift",
	"ash": "world4/ash_dune",
	"ford": "world5/river_ford",
	"steel": "world6/steel_plate",
}

## Evening light for the Pro variants (GDD 17.1): a sunset HDRI from the same
## kind of place, a low warm sun behind the camera and warmer, thicker fog.
## Keys override the world's day look.
const EVENING: Dictionary = {
	1:
	{
		"sky": "res://assets/textures/world1/sky_champagne_castle_1_1k.exr",
		"sun_rot": Vector3(-16.0, 140.0, 0.0),
		"sun_color": Color(1.000, 0.700, 0.460),
		"sun_energy": 1.25,
		"sky_energy": 0.9,
		"fog_color": Color(0.780, 0.600, 0.470),
		"fog_max": 0.5,
		"fog_end": 380.0,
	},
	2:
	{
		"sky": "res://assets/textures/world2/sky_goegap_road_1k.exr",
		"sun_rot": Vector3(-14.0, 140.0, 0.0),
		"sun_color": Color(1.000, 0.640, 0.400),
		"sun_energy": 1.4,
		"sky_energy": 0.9,
		"fog_color": Color(0.860, 0.560, 0.400),
		"fog_max": 0.38,
		"fog_end": 560.0,
	},
	# Worlds 3-6 have one sky each (DESIGN 11): evening = the same panorama
	# dimmed, a low warm sun behind the camera and warmer, thicker fog.
	3:
	{
		"sun_rot": Vector3(-12.0, 140.0, 0.0),
		"sun_color": Color(1.000, 0.720, 0.550),
		"sun_energy": 1.3,
		"sky_energy": 0.7,
		"exposure": 0.85,
		"fog_color": Color(0.86, 0.74, 0.70),
		"fog_max": 0.42,
		"fog_end": 600.0,
	},
	4:
	{
		"sun_rot": Vector3(-5.0, 140.0, 0.0),
		"sun_color": Color(1.000, 0.550, 0.350),
		"sun_energy": 0.95,
		"sky_energy": 0.7,
		"exposure": 1.25,
		"fog_color": Color(0.42, 0.28, 0.20),
		"fog_max": 0.5,
		"fog_end": 460.0,
	},
	5:
	{
		"sun_rot": Vector3(-15.0, 140.0, 0.0),
		"sun_color": Color(1.000, 0.750, 0.550),
		"sun_energy": 0.6,
		"sky_energy": 0.75,
		"exposure": 1.15,
		"fog_color": Color(0.58, 0.54, 0.46),
		"fog_max": 0.55,
		"fog_end": 230.0,
	},
	# Night Harbour's "evening" is the last dusk light before the night.
	6:
	{
		"sun_rot": Vector3(-8.0, 140.0, 0.0),
		"sun_color": Color(0.950, 0.620, 0.450),
		"sun_energy": 0.35,
		"sky_energy": 0.12,
		"exposure": 1.6,
		"fog_color": Color(0.20, 0.15, 0.15),
		"fog_max": 0.45,
	},
}


static func get_def(id: int) -> Dictionary:
	match id:
		2:
			return W2
		3:
			return W3
		4:
			return W4
		5:
			return W5
		6:
			return W6
	return W1


## Worlds 1-2 have a hand-made track 1 table (GDD 6.1 / 6.2) here.
static func has_table(id: int) -> bool:
	return id == 1 or id == 2


static func kit(id: int) -> Dictionary:
	return KIT.get(id, KIT[1])


## The world's look, with the evening preset on top for Pro tracks.
static func look_for(id: int, evening: bool) -> Dictionary:
	var l: Dictionary = (get_def(id)["look"] as Dictionary).duplicate()
	if evening and EVENING.has(id):
		var e: Dictionary = EVENING[id]
		for k: String in e:
			l[k] = e[k]
	return l


static func world_name(id: int) -> String:
	var d: Dictionary = get_def(id)
	return "%s / %s" % [d["name"], d["name_en"]]

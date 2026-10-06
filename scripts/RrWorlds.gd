class_name RrWorlds
extends RefCounted

## The worlds (GDD 6, DESIGN 9-10). Cruise 30 m/s (owner 18:27): every
## distance is the 20 m/s design x1.5, so the timings stay the same. Every
## level is a different place with its own track, hindrances, sky, light,
## fog and weather; nothing is reused from one world to the next except the
## racers and the shared kit. Track numbers
## are GDD 6.1 / 6.2 section tables (s in metres from the start line, x in
## metres, + = right). Slice: worlds 1 and 2 have tracks; 3-6 are design only.

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
		"sky": "res://assets/textures/world2/sky_goegap_1k.exr",
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
}


static func get_def(id: int) -> Dictionary:
	return W2 if id == 2 else W1


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

class_name RrWorlds
extends RefCounted

## The worlds (GDD 6, DESIGN 9-10). Every level is a different place with its
## own track, hindrances, sky, light, fog and weather; nothing is reused from
## one world to the next except the racers and the shared kit. Track numbers
## are GDD 6.1 / 6.2 section tables (s in metres from the start line, x in
## metres, + = right). Slice: worlds 1 and 2 have tracks; 3-6 are design only.

const W1: Dictionary = {
	"id": 1,
	"name": "Furuløypa",
	"name_en": "Pine Run",
	"length": 950.0,
	# [from, to, surface, cruise mult]; "lane" = smooth (hoverboard x1.06).
	"sections":
	[
		[-40.0, 300.0, "dirt", 1.00],
		[300.0, 600.0, "lane", 1.00],
		[600.0, 880.0, "dirt", 1.05],
		[880.0, 950.0, "dirt", 1.00],
		[950.0, 1040.0, "dirt", 0.5],
	],
	"widths":
	[
		[-40.0, 12.0],
		[0.0, 12.0],
		[40.0, 10.0],
		[536.0, 10.0],
		[544.0, 8.0],
		[576.0, 8.0],
		[584.0, 10.0],
		[600.0, 10.0],
		[606.0, 9.0],
		[714.0, 9.0],
		[722.0, 7.0],
		[768.0, 7.0],
		[776.0, 9.0],
		[874.0, 9.0],
		[886.0, 12.0],
		[1040.0, 12.0],
	],
	"kid_line":
	[
		[-40.0, 0.0],
		[305.0, 0.0],
		[328.0, 2.5],
		[375.0, 2.5],
		[395.0, 0.0],
		[482.0, 0.0],
		[500.0, 1.8],
		[540.0, 1.8],
		[558.0, 0.0],
		[664.0, 0.0],
		[684.0, 3.0],
		[715.0, 3.0],
		[732.0, 0.0],
		[1040.0, 0.0],
	],
	"pads":
	[
		[120.0, 0.0],
		[210.0, -3.0],
		[340.0, 2.5],
		[352.0, 2.5],
		[364.0, 2.5],
		[470.0, -3.0],
		[700.0, 3.0],
		[800.0, -3.0],
		[812.0, -3.0],
		[824.0, -3.0],
	],
	"kickers": [180.0, 430.0, 760.0, 900.0],
	"kicker_air": [1.0, 1.2, 1.6, 1.0],
	"kicker_models": ["ramp", "ramp", "ramp", "ramp"],
	# Block hindrances (hay bales, GDD 4.8): [s, x].
	"blocks": [[260.0, 2.5], [520.0, -0.5], [650.0, -2.0], [840.0, 1.5]],
	# Patch hindrances: [s0, s1, x0, x1, kind].
	"patches": [[150.0, 160.0, 2.0, 4.5, "mud"], [685.0, 695.0, -4.0, -1.5, "mud"]],
	# Roller hindrances: [s, direction (+1 = rolls left to right)].
	"rollers": [],
	"gates": [[300.0, 1], [600.0, 0]],
	"bends":
	[
		[50.0, 100.0, -1.0 / 60.0],
		[110.0, 160.0, 1.0 / 60.0],
		[205.0, 280.0, 1.0 / 150.0],
		[330.0, 420.0, -1.0 / 200.0],
		[460.0, 540.0, 1.0 / 160.0],
		[620.0, 700.0, -1.0 / 130.0],
		[790.0, 860.0, 1.0 / 220.0],
	],
	"grades":
	[
		[-40.0, 0.05],
		[0.0, 0.15],
		[40.0, 0.08],
		[300.0, 0.06],
		[600.0, 0.20],
		[880.0, 0.04],
		[950.0, 0.02],
	],
	# Extra drop [from, to, metres] on top of the grade (W2 mesa gap).
	"drops": [],
	# Track s range with no surface under it (a gorge to jump), or [].
	"gap": [],
	"tunnel": [540.0, 580.0],
	"fence": [718.0, 772.0],
	"river": [296.0, 604.0],
	"look":
	{
		"sky": "res://assets/textures/world1/sky_alps_field_2k.hdr",
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
	"length": 980.0,
	"sections":
	[
		[-40.0, 300.0, "dirt", 1.00],
		[300.0, 620.0, "lane", 1.00],
		[620.0, 900.0, "dirt", 1.05],
		[900.0, 980.0, "dirt", 1.00],
		[980.0, 1040.0, "dirt", 0.5],
	],
	"widths":
	[
		[-40.0, 12.0],
		[0.0, 12.0],
		[60.0, 10.0],
		[216.0, 10.0],
		[224.0, 8.0],
		[294.0, 8.0],
		[302.0, 11.0],
		[612.0, 11.0],
		[620.0, 10.0],
		[628.0, 9.0],
		[752.0, 9.0],
		[760.0, 8.0],
		[781.0, 8.0],
		[816.0, 8.0],
		[824.0, 9.0],
		[894.0, 9.0],
		[906.0, 12.0],
		[1040.0, 12.0],
	],
	# GDD 6.2 kid line; the ramps start early enough that an idle Lett rider
	# is clear of each sand drift before it begins.
	"kid_line":
	[
		[-40.0, 0.0],
		[118.0, 0.0],
		[136.0, 2.0],
		[170.0, 2.0],
		[182.0, 0.0],
		[318.0, 0.0],
		[335.0, -2.5],
		[385.0, -2.5],
		[400.0, 0.0],
		[552.0, 0.0],
		[570.0, -2.5],
		[600.0, -2.5],
		[612.0, 0.0],
		[640.0, 0.0],
		[656.0, -3.0],
		[686.0, -3.0],
		[700.0, 0.0],
		[846.0, 0.0],
		[862.0, 1.5],
		[890.0, 1.5],
		[902.0, 0.0],
		[1040.0, 0.0],
	],
	"pads":
	[
		[110.0, 0.0],
		[285.0, 2.0],
		[350.0, -2.5],
		[362.0, -2.5],
		[374.0, -2.5],
		[540.0, 3.0],
		[670.0, -3.0],
		[830.0, 3.0],
		[842.0, 3.0],
		[854.0, 3.0],
	],
	"kickers": [200.0, 480.0, 780.0, 930.0],
	"kicker_air": [1.0, 1.2, 1.8, 0.8],
	"kicker_models": ["ramp_rock", "ramp_rock", "ramp_rock", "ramp"],
	"blocks": [],
	"patches":
	[
		[150.0, 165.0, -3.0, 0.5, "sand"],
		[580.0, 595.0, -1.0, 3.5, "sand"],
		[870.0, 885.0, -3.5, 0.0, "sand"],
	],
	"rollers": [[260.0, 1.0], [420.0, -1.0], [440.0, 1.0], [720.0, -1.0]],
	"gates": [[300.0, 1], [620.0, 0]],
	"bends":
	[
		[70.0, 130.0, 1.0 / 90.0],
		[150.0, 205.0, -1.0 / 120.0],
		[228.0, 290.0, 1.0 / 75.0],
		[330.0, 450.0, -1.0 / 260.0],
		[500.0, 600.0, 1.0 / 210.0],
		[640.0, 730.0, -1.0 / 110.0],
		[830.0, 880.0, 1.0 / 170.0],
		[910.0, 960.0, -1.0 / 160.0],
	],
	"grades":
	[
		[-40.0, 0.05],
		[0.0, 0.22],
		[60.0, 0.08],
		[220.0, 0.10],
		[300.0, 0.06],
		[620.0, 0.18],
		[790.0, 0.12],
		[900.0, 0.06],
		[980.0, 0.02],
	],
	# The mesa gap lands 6 m lower than it takes off (GDD 6.2).
	"drops": [[782.0, 814.0, 6.0]],
	"gap": [783.0, 812.0],
	"tunnel": [],
	"fence": [],
	"river": [],
	"look":
	{
		"sky": "res://assets/textures/world2/sky_goegap_2k.hdr",
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


static func get_def(id: int) -> Dictionary:
	return W2 if id == 2 else W1


static func world_name(id: int) -> String:
	var d: Dictionary = get_def(id)
	return "%s / %s" % [d["name"], d["name_en"]]

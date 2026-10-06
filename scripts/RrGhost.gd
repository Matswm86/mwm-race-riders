class_name RrGhost
extends RefCounted

## Local ghost (GDD 10.8): rows of [s, x, h, vehicle] recorded at GHOST_HZ
## from GO. Playback interpolates linearly; the vehicle switches at the row.

var rows: Array = []


func _init(r: Array = []) -> void:
	rows = r


func is_empty() -> bool:
	return rows.size() < 2


func duration() -> float:
	return float(rows.size() - 1) / float(RrBalance.GHOST_HZ)


## [s, x, h, vehicle] at race time t (clamped to the recording).
func sample(t: float) -> Array:
	if rows.is_empty():
		return [0.0, 0.0, 0.0, 0]
	var f: float = clampf(t, 0.0, duration()) * float(RrBalance.GHOST_HZ)
	var i: int = mini(int(f), rows.size() - 2)
	if rows.size() == 1:
		return rows[0]
	var k: float = f - float(i)
	var a: Array = rows[i]
	var b: Array = rows[i + 1]
	return [
		lerpf(float(a[0]), float(b[0]), k),
		lerpf(float(a[1]), float(b[1]), k),
		lerpf(float(a[2]), float(b[2]), k),
		int(a[3]),
	]

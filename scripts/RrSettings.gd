class_name RrSettings
extends Control

## Settings panel (GDD 10.7), adult-facing, opened from the gear in every
## race and on the card. The race is paused while it is open. Rows: Lett /
## Vanlig, effects on/off + volume, music (note icon) on/off + volume, ghost,
## "Mindre bevegelse", Grafikk Høy / Lav (owner). The big play disc at the
## bottom closes it and resumes on release. Inside MWM Play only the two
## volume sliders, the ghost and graphics rows are shown (the shell owns the
## rest), and the rows close up with no gaps (QA finding 10).

signal closed
## The effects slider was let go: the host plays one sample at the new level.
signal sfx_preview

const INK := Color(0.078, 0.090, 0.110)
const WHITE := Color(1, 1, 1)
const DIM := Color(0.0, 0.0, 0.0, 0.55)
const PANEL := Rect2(90, 240, 900, 1416)
const TRACK := Color(1, 1, 1, 0.25)
const KNOB_PX: int = 84
const TOP_Y: float = 340.0

var play_disc: RrDisc
var _lett: Button
var _vanlig: Button
var _sound: Button
var _music: Button
var _ghost: Button
var _motion: Button
var _quality: Button
var _sfx_slider: HSlider
var _music_slider: HSlider
## [controls, height, shell_visible, music icon row]
var _rows: Array = []
var _music_icon_y: float = -1.0


func _ready() -> void:
	size = Vector2(RrBalance.DESIGN_W, RrBalance.DESIGN_H)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var th := Theme.new()
	th.default_font = RrDraw.font("SemiBold")
	th.default_font_size = 46
	theme = th
	_heading("Innstillinger", Vector2(150, 262))
	var diff_label: Label = _label("Vanskelighet (neste løp)")
	_lett = _button("Lett", 360.0)
	_vanlig = _button("Vanlig", 360.0)
	_lett.pressed.connect(func() -> void: _set_easy(true))
	_vanlig.pressed.connect(func() -> void: _set_easy(false))
	_rows.append([[diff_label], 58.0, false, false])
	_rows.append([[_lett, _vanlig], 150.0, false, false])
	_sound = _button("", 360.0)
	_sound.pressed.connect(
		func() -> void:
			RaceRiders.set_sfx_on(not RaceRiders.sfx_on)
			refresh()
	)
	_rows.append([[_label("Lyd"), _sound], 150.0, false, false])
	_sfx_slider = _slider()
	_sfx_slider.value_changed.connect(func(v: float) -> void: RaceRiders.set_sfx_volume(v, false))
	_sfx_slider.drag_ended.connect(
		func(_changed: bool) -> void:
			RaceRiders.save_game()
			sfx_preview.emit()
	)
	_rows.append([[_sfx_slider], 110.0, true, false])
	_music = _button("", 360.0)
	_music.pressed.connect(
		func() -> void:
			RaceRiders.set_music_on(not RaceRiders.music_on)
			refresh()
	)
	_rows.append([[_music], 150.0, false, true])
	_music_slider = _slider()
	_music_slider.value_changed.connect(
		func(v: float) -> void: RaceRiders.set_music_volume(v, false)
	)
	_music_slider.drag_ended.connect(func(_changed: bool) -> void: RaceRiders.save_game())
	_rows.append([[_music_slider], 120.0, true, true])
	_ghost = _button("", 360.0)
	_ghost.pressed.connect(
		func() -> void:
			RaceRiders.set_ghost_on(not RaceRiders.ghost_on)
			refresh()
	)
	_rows.append([[_label("Spøkelse"), _ghost], 150.0, true, false])
	_motion = _button("", 360.0)
	_motion.pressed.connect(
		func() -> void:
			RaceRiders.set_less_motion(not RaceRiders.less_motion)
			refresh()
	)
	_rows.append([[_label("Mindre bevegelse"), _motion], 150.0, false, false])
	_quality = _button("", 360.0)
	_quality.pressed.connect(
		func() -> void:
			RaceRiders.set_quality_high(not RaceRiders.quality_high)
			refresh()
	)
	_rows.append([[_label("Grafikk"), _quality], 150.0, true, false])
	# Close = big play disc, kept above the wrist strip (y < 1664).
	play_disc = RrDisc.new()
	play_disc.icon = "play"
	play_disc.disc_radius = 100.0
	play_disc.size = Vector2(220, 210)
	play_disc.position = Vector2(540 - 110, 1450)
	play_disc.tapped.connect(func() -> void: closed.emit())
	add_child(play_disc)
	visible = false


func open() -> void:
	refresh()
	visible = true
	RrDisc.block_input(int(RrBalance.HOLDOVER_S * 1000.0))


## Lay the visible rows out top to bottom with no gaps.
func _layout() -> void:
	var shell: bool = RaceRiders.in_shell()
	var y: float = TOP_Y
	_music_icon_y = -1.0
	for row: Array in _rows:
		var show: bool = not shell or bool(row[2])
		var ctl: Array = row[0]
		for c: Control in ctl:
			c.visible = show
		if not show:
			continue
		var h: float = row[1]
		var icon_row: bool = bool(row[3]) and _music_icon_y < 0.0
		if icon_row:
			_music_icon_y = y + h * 0.5 - (10.0 if ctl[0] is HSlider else 0.0)
		if ctl.size() == 2 and ctl[0] is Button:
			(ctl[0] as Control).position = Vector2(150, y)
			(ctl[1] as Control).position = Vector2(570, y)
		elif ctl.size() == 2:
			(ctl[0] as Control).position = Vector2(150, y + 34.0)
			(ctl[1] as Control).position = Vector2(570, y)
		elif ctl[0] is HSlider:
			var sl: Control = ctl[0]
			sl.position = Vector2(290 if icon_row else 150, y)
			sl.size = Vector2(640 if icon_row else 780, 90)
		elif ctl[0] is Button:
			(ctl[0] as Control).position = Vector2(570, y)
		else:
			(ctl[0] as Control).position = Vector2(150, y)
		y += h
	queue_redraw()


func refresh() -> void:
	_layout()
	_style(_lett, RaceRiders.easy)
	_style(_vanlig, not RaceRiders.easy)
	_sound.text = "På" if RaceRiders.sfx_on else "Av"
	_style(_sound, RaceRiders.sfx_on)
	_music.text = "På" if RaceRiders.music_on else "Av"
	_style(_music, RaceRiders.music_on)
	_ghost.text = "På" if RaceRiders.ghost_on else "Av"
	_style(_ghost, RaceRiders.ghost_on)
	_motion.text = "På" if RaceRiders.less_motion else "Av"
	_style(_motion, RaceRiders.less_motion)
	_quality.text = "Høy" if RaceRiders.quality_high else "Lav"
	_style(_quality, RaceRiders.quality_high)
	_sfx_slider.set_value_no_signal(RaceRiders.sfx_volume)
	_music_slider.set_value_no_signal(RaceRiders.music_volume)


func _set_easy(on: bool) -> void:
	RaceRiders.set_difficulty(on)
	refresh()


func _heading(t: String, at: Vector2) -> void:
	var l := Label.new()
	l.text = t
	l.add_theme_font_size_override("font_size", 60)
	l.add_theme_color_override("font_color", WHITE)
	l.position = at
	add_child(l)


func _label(t: String) -> Label:
	var l := Label.new()
	l.text = t
	l.add_theme_color_override("font_color", WHITE)
	add_child(l)
	return l


func _button(t: String, w: float) -> Button:
	var b := Button.new()
	b.text = t
	b.size = Vector2(w, 130)
	b.focus_mode = Control.FOCUS_NONE
	add_child(b)
	return b


## Volume slider 0..1: thick track, white fill, a large round knob so a
## thumb can grab it.
func _slider() -> HSlider:
	var s := HSlider.new()
	s.min_value = 0.0
	s.max_value = 1.0
	s.step = 0.05
	s.size = Vector2(780, 90)
	s.focus_mode = Control.FOCUS_NONE
	var track := StyleBoxFlat.new()
	track.bg_color = TRACK
	track.set_corner_radius_all(14)
	track.content_margin_top = 14.0
	track.content_margin_bottom = 14.0
	s.add_theme_stylebox_override("slider", track)
	var fill := StyleBoxFlat.new()
	fill.bg_color = WHITE
	fill.set_corner_radius_all(14)
	fill.content_margin_top = 14.0
	fill.content_margin_bottom = 14.0
	s.add_theme_stylebox_override("grabber_area", fill)
	s.add_theme_stylebox_override("grabber_area_highlight", fill)
	var knob: Texture2D = _knob()
	s.add_theme_icon_override("grabber", knob)
	s.add_theme_icon_override("grabber_highlight", knob)
	add_child(s)
	return s


func _knob() -> Texture2D:
	var img := Image.create(KNOB_PX, KNOB_PX, false, Image.FORMAT_RGBA8)
	var c: float = KNOB_PX * 0.5
	for y: int in KNOB_PX:
		for x: int in KNOB_PX:
			var d: float = Vector2(x + 0.5 - c, y + 0.5 - c).length()
			var col: Color = Color(0, 0, 0, 0)
			if d <= c - 1.0:
				col = WHITE if d > c - 7.0 else INK
			elif d <= c:
				col = Color(WHITE, c - d)
			img.set_pixel(x, y, col)
	return ImageTexture.create_from_image(img)


## On = white with ink text, off = ink with a white ring and white text.
func _style(b: Button, on: bool) -> void:
	for state: String in ["normal", "hover", "pressed", "hover_pressed"]:
		var sb := StyleBoxFlat.new()
		sb.bg_color = WHITE if on else INK
		sb.border_color = WHITE
		sb.set_border_width_all(4)
		sb.set_corner_radius_all(70)
		sb.anti_aliasing = true
		b.add_theme_stylebox_override(state, sb)
	for c: String in [
		"font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color"
	]:
		b.add_theme_color_override(c, INK if on else WHITE)


func _draw() -> void:
	draw_rect(Rect2(Vector2(-2000, -2000), Vector2(6000, 6000)), DIM)
	RrDraw.panel(self, PANEL)
	if _music_icon_y >= 0.0:
		RrDisc.draw_icon(self, "music", Vector2(205, _music_icon_y), 56.0, WHITE)

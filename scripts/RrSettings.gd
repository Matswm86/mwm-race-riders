class_name RrSettings
extends Control

## Settings panel (GDD 10.7), adult-facing, opened from the gear in every
## race and on the card. The race is paused while it is open. Rows: Lett /
## Vanlig, effects on/off + volume, music (note icon) on/off + volume, ghost,
## "Mindre bevegelse", Grafikk Høy / Lav (owner).
## The big play disc at the bottom closes it and resumes
## on release. Inside MWM Play only the two volume sliders and the ghost
## toggle are shown (the shell owns the rest). Copied from NbSettings.

signal closed
## The effects slider was let go: the host plays one sample at the new level.
signal sfx_preview

const CARD := Color(1.000, 0.973, 0.933)
const CARD_EDGE := Color(0.561, 0.514, 0.443)
const INK := Color(0.141, 0.129, 0.114)
const ON := Color(1.0, 0.824, 0.247)
const OFF := Color(1.0, 1.0, 1.0)
const DIM := Color(0.0, 0.0, 0.0, 0.55)
const PANEL := Rect2(90, 240, 900, 1416)
const MUSIC_ICON_AT := Vector2(205, 832)
const TRACK := Color(0.851, 0.820, 0.773)
const KNOB_PX: int = 84

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
var _shell_hidden: Array[Control] = []


func _ready() -> void:
	size = Vector2(RrBalance.DESIGN_W, RrBalance.DESIGN_H)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var th := Theme.new()
	th.default_font = RrDraw.font()
	th.default_font_size = 44
	theme = th
	_heading("Innstillinger", Vector2(150, 262))
	_shell_hidden.append(_label("Vanskelighet (neste løp)", Vector2(150, 338)))
	_lett = _button("Lett", Rect2(150, 395, 360, 130))
	_vanlig = _button("Vanlig", Rect2(570, 395, 360, 130))
	_shell_hidden.append(_lett)
	_shell_hidden.append(_vanlig)
	_lett.pressed.connect(func() -> void: _set_easy(true))
	_vanlig.pressed.connect(func() -> void: _set_easy(false))
	_label("Lyd", Vector2(150, 572))
	_sound = _button("", Rect2(570, 540, 360, 130))
	_shell_hidden.append(_sound)
	_sound.pressed.connect(
		func() -> void:
			RaceRiders.set_sfx_on(not RaceRiders.sfx_on)
			refresh()
	)
	_sfx_slider = _slider(Rect2(150, 675, 780, 90))
	_sfx_slider.value_changed.connect(func(v: float) -> void: RaceRiders.set_sfx_volume(v, false))
	_sfx_slider.drag_ended.connect(
		func(_changed: bool) -> void:
			RaceRiders.save_game()
			sfx_preview.emit()
	)
	_music = _button("", Rect2(570, 770, 360, 130))
	_shell_hidden.append(_music)
	_music.pressed.connect(
		func() -> void:
			RaceRiders.set_music_on(not RaceRiders.music_on)
			refresh()
	)
	_music_slider = _slider(Rect2(150, 905, 780, 90))
	_music_slider.value_changed.connect(
		func(v: float) -> void: RaceRiders.set_music_volume(v, false)
	)
	_music_slider.drag_ended.connect(func(_changed: bool) -> void: RaceRiders.save_game())
	_label("Spøkelse", Vector2(150, 1032))
	_ghost = _button("", Rect2(570, 1000, 360, 130))
	_ghost.pressed.connect(
		func() -> void:
			RaceRiders.set_ghost_on(not RaceRiders.ghost_on)
			refresh()
	)
	_shell_hidden.append(_label("Mindre bevegelse", Vector2(150, 1172)))
	_motion = _button("", Rect2(570, 1140, 360, 130))
	_shell_hidden.append(_motion)
	_motion.pressed.connect(
		func() -> void:
			RaceRiders.set_less_motion(not RaceRiders.less_motion)
			refresh()
	)
	_label("Grafikk", Vector2(150, 1312))
	_quality = _button("", Rect2(570, 1280, 360, 130))
	_quality.pressed.connect(
		func() -> void:
			RaceRiders.set_quality_high(not RaceRiders.quality_high)
			refresh()
	)
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


func refresh() -> void:
	var shell: bool = RaceRiders.in_shell()
	for c: Control in _shell_hidden:
		c.visible = not shell
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
	l.add_theme_font_size_override("font_size", 56)
	l.add_theme_color_override("font_color", INK)
	l.position = at
	add_child(l)


func _label(t: String, at: Vector2) -> Label:
	var l := Label.new()
	l.text = t
	l.add_theme_color_override("font_color", INK)
	l.position = at
	add_child(l)
	return l


func _button(t: String, r: Rect2) -> Button:
	var b := Button.new()
	b.text = t
	b.position = r.position
	b.size = r.size
	b.focus_mode = Control.FOCUS_NONE
	add_child(b)
	return b


## Volume slider 0..1: thick track, sun fill, a large round knob so a thumb
## can grab it.
func _slider(r: Rect2) -> HSlider:
	var s := HSlider.new()
	s.min_value = 0.0
	s.max_value = 1.0
	s.step = 0.05
	s.position = r.position
	s.size = r.size
	s.focus_mode = Control.FOCUS_NONE
	var track := StyleBoxFlat.new()
	track.bg_color = TRACK
	track.set_corner_radius_all(14)
	track.content_margin_top = 14.0
	track.content_margin_bottom = 14.0
	s.add_theme_stylebox_override("slider", track)
	var fill := StyleBoxFlat.new()
	fill.bg_color = ON
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
				col = INK if d > c - 7.0 else OFF
			elif d <= c:
				col = Color(INK, c - d)
			img.set_pixel(x, y, col)
	return ImageTexture.create_from_image(img)


func _style(b: Button, on: bool) -> void:
	for state: String in ["normal", "hover", "pressed", "hover_pressed"]:
		var sb := StyleBoxFlat.new()
		sb.bg_color = ON if on else OFF
		sb.border_color = INK
		sb.set_border_width_all(5)
		sb.set_corner_radius_all(70)
		sb.anti_aliasing = true
		b.add_theme_stylebox_override(state, sb)
	for c: String in [
		"font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color"
	]:
		b.add_theme_color_override(c, INK)


func _draw() -> void:
	draw_rect(Rect2(Vector2(-2000, -2000), Vector2(6000, 6000)), DIM)
	var sb := StyleBoxFlat.new()
	sb.bg_color = CARD
	sb.border_color = CARD_EDGE
	sb.set_border_width_all(4)
	sb.set_corner_radius_all(56)
	sb.anti_aliasing = true
	draw_style_box(sb, PANEL)
	if not RaceRiders.in_shell():
		RrDisc.draw_icon(self, "music", MUSIC_ICON_AT, 56.0, INK)
	else:
		RrDisc.draw_icon(self, "music", Vector2(205, 870), 56.0, INK)

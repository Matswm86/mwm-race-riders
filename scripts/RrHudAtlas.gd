class_name RrHudAtlas
extends RefCounted

## Sprite rects of assets/textures/ui/hud_atlas.png (tools/art/make_hud_atlas.py):
## name -> [Rect2 in the atlas, anchor inside the sprite]. The HUD draws every
## sprite from this one texture, so it batches into a few draw calls.

const PATH := "res://assets/textures/ui/hud_atlas.png"
const SPRITES: Dictionary = {
	"home": [Rect2(0, 0, 184, 188), Vector2(92, 92)],
	"gear": [Rect2(184, 0, 184, 188), Vector2(92, 92)],
	"boost": [Rect2(368, 0, 290, 296), Vector2(145, 145)],
	"boost_full": [Rect2(660, 0, 224, 224), Vector2(112, 112)],
	"place1": [Rect2(0, 300, 150, 154), Vector2(75, 75)],
	"place2": [Rect2(150, 300, 150, 154), Vector2(75, 75)],
	"place3": [Rect2(300, 300, 150, 154), Vector2(75, 75)],
	"place4": [Rect2(450, 300, 150, 154), Vector2(75, 75)],
	"place5": [Rect2(600, 300, 150, 154), Vector2(75, 75)],
	"place6": [Rect2(750, 300, 150, 154), Vector2(75, 75)],
	"bar": [Rect2(0, 460, 600, 60), Vector2(18, 17)],
	"flag": [Rect2(610, 462, 48, 64), Vector2(6, 58)],
	"tok0": [Rect2(0, 530, 40, 40), Vector2(20, 20)],
	"tok1": [Rect2(40, 530, 40, 40), Vector2(20, 20)],
	"tok2": [Rect2(80, 530, 40, 40), Vector2(20, 20)],
	"tok3": [Rect2(120, 530, 40, 40), Vector2(20, 20)],
	"tok4": [Rect2(160, 530, 40, 40), Vector2(20, 20)],
	"tok5": [Rect2(200, 530, 40, 40), Vector2(20, 20)],
	"player0": [Rect2(250, 524, 76, 96), Vector2(38, 36)],
	"knock1": [Rect2(340, 530, 70, 70), Vector2(35, 35)],
	"knock2": [Rect2(410, 530, 70, 70), Vector2(35, 35)],
	"knock3": [Rect2(480, 530, 70, 70), Vector2(35, 35)],
	"knock4": [Rect2(550, 530, 70, 70), Vector2(35, 35)],
	"knock5": [Rect2(620, 530, 70, 70), Vector2(35, 35)],
	"hand": [Rect2(0, 630, 190, 230), Vector2(95, 14)],
	"arrow_l": [Rect2(196, 630, 150, 230), Vector2(75, 115)],
	"arrow_r": [Rect2(350, 630, 150, 230), Vector2(75, 115)],
	"chevron": [Rect2(504, 630, 96, 60), Vector2(48, 30)],
	"star": [Rect2(600, 700, 116, 116), Vector2(58, 58)],
	"lamp_off": [Rect2(720, 630, 100, 100), Vector2(50, 50)],
	"lamp_amber": [Rect2(820, 630, 100, 100), Vector2(50, 50)],
	"lamp_green": [Rect2(920, 630, 100, 100), Vector2(50, 50)],
	"lights_bg": [Rect2(0, 870, 420, 150), Vector2(210, 75)],
	"chip": [Rect2(430, 870, 190, 70), Vector2(95, 35)],
	"dot": [Rect2(640, 870, 16, 16), Vector2(8, 8)],
	"ghost_icon": [Rect2(680, 870, 120, 120), Vector2(60, 60)],
}

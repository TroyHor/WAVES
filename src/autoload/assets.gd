extends Node
## Central registry of every asset path and placeholder color used by the game.
## To swap in final art, change the paths/colors here (or drop files at these
## paths) — no other script should hard-code a res:// asset path.

const ART_DIR := "res://assets/art/"
const FONT_DIR := "res://assets/fonts/"
const AUDIO_DIR := "res://assets/audio/"

## Logical texture ids -> file paths. Missing files fall back to code-drawn placeholders.
const TEXTURES := {
	"card_frame": ART_DIR + "card_frame.png",
	"enemy_default": ART_DIR + "enemy_default.png",
	"player": ART_DIR + "player.png",
	"background_combat": ART_DIR + "background_combat.png",
}

const FONTS := {
	"main": FONT_DIR + "main.ttf",
}

## System fonts used when FONTS["main"] is missing: monospace for the instrument
## look, with an explicit CJK fallback font for Chinese text. (A SystemFont only
## uses the first name it finds, so CJK must be a separate fallback font.)
const FALLBACK_MONO_NAMES := ["Menlo", "Consolas", "DejaVu Sans Mono", "Courier New"]
const FALLBACK_CJK_NAMES := ["Hiragino Sans GB", "Heiti SC", "Microsoft YaHei", "Noto Sans CJK SC", "Noto Sans SC", "WenQuanYi Micro Hei"]

## CRT post-process parameters (src/ui/crt/crt.gdshader). The input remap in
## main.gd reads `curvature` so clicks land where the distorted image shows.
const CRT := {
	"curvature": 0.045,
	"scanline_strength": 0.22,
	"scanline_density": 540.0,
	"aberration": 1.0,
	"vignette": 0.35,
	"noise_strength": 0.045,
	"bloom": 0.45,
	"flicker": 0.02,
	"wobble": 0.0008,
}

const SOUNDS := {
	"card_play": AUDIO_DIR + "card_play.ogg",
	"hit": AUDIO_DIR + "hit.ogg",
	"cancel": AUDIO_DIR + "cancel.ogg",
}

## Oscilloscope palette used by code-drawn visuals: phosphor-green instrument,
## channel colors like a real scope (CH1 amber, CH2 cyan, CH3 magenta, MATH white-green).
const COLORS := {
	"background": Color("030806"),
	"screen": Color("06140e"),
	"panel": Color("0a1c14"),
	"panel_border": Color("24684a"),
	"grid": Color("123a29"),
	"grid_major": Color("1f5e42"),
	"text": Color("7dffb8"),
	"text_dim": Color("3d9a6c"),
	"enemy_ch1": Color("ffb02e"),
	"enemy_ch3": Color("ff5ce1"),
	"player_wave": Color("4fd8ff"),
	"net_wave": Color("d8ffe9"),
	"damage_to_enemy": Color("6dff8a"),
	"damage_to_player": Color("ff4d4d"),
	"cancelled": Color("9fb8ad"),
	"energy": Color("ffd23f"),
	"disabled": Color("2a4a3a"),
}


## Returns the texture for `id`, or null if the file does not exist yet
## (callers must then draw a placeholder).
func texture(id: String) -> Texture2D:
	var path: String = TEXTURES.get(id, "")
	if path != "" and ResourceLoader.exists(path):
		return load(path)
	return null


var _fallback_font: SystemFont


## Returns the bundled font, or a system monospace font with CJK fallback.
func font(id: String) -> Font:
	var path: String = FONTS.get(id, "")
	if path != "" and ResourceLoader.exists(path):
		return load(path)
	if _fallback_font == null:
		var cjk := SystemFont.new()
		cjk.font_names = PackedStringArray(FALLBACK_CJK_NAMES)
		_fallback_font = SystemFont.new()
		_fallback_font.font_names = PackedStringArray(FALLBACK_MONO_NAMES)
		_fallback_font.fallbacks = [cjk]
	return _fallback_font


func sound(id: String) -> AudioStream:
	var path: String = SOUNDS.get(id, "")
	if path != "" and ResourceLoader.exists(path):
		return load(path)
	return null


func color(id: String) -> Color:
	return COLORS.get(id, Color.MAGENTA)

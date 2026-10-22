extends Node
## Central registry of every asset path and placeholder color used by the game.
## To swap in final art, change the paths/colors here (or drop files at these
## paths) — no other script should hard-code a res:// asset path.

## Global UI text scale: every font size in the UI goes through fs().
const FONT_SCALE := 1.3

const ART_DIR := "res://assets/art/"
const FONT_DIR := "res://assets/fonts/"
const AUDIO_DIR := "res://assets/audio/"

## Logical texture ids -> file paths. Missing files fall back to code-drawn placeholders.
## Enemy portraits are referenced from data/enemies/*.json ("figure.texture").
const TEXTURES := {
	"card_frame": ART_DIR + "card_frame.png",
	"player": ART_DIR + "player.png",
	"enemy_drone": ART_DIR + "enemy_drone.png",
	"enemy_shrieker": ART_DIR + "enemy_shrieker.png",
	"enemy_tide_colossus": ART_DIR + "enemy_tide_colossus.png",
	"enemy_twin_crest": ART_DIR + "enemy_twin_crest.png",
	"enemy_twin_trough": ART_DIR + "enemy_twin_trough.png",
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

## Whole-screen finishing pass (src/ui/crt/screen_fx.gdshader). Calm by design:
## bloom, faint fringe, grain, vignette. Impacts add a smooth ripple + shake.
const SCREEN_FX := {
	"curvature": 0.0,
	"bloom": 0.35,
	"aberration": 0.5,
	"vignette": 0.22,
	"grain": 0.018,
}

## CRT tube inside each bench oscilloscope (src/ui/crt/tube.gdshader).
const TUBE := {
	"curvature": 0.07,
	"reflection": 0.08,
	"corner_radius": 22.0,
	"scanline_strength": 0.16,
	"glow": 0.5,
	"vignette": 0.35,
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
	# Your damage to the enemy is blue everywhere (bars, readout, particles).
	"damage_to_enemy": Color("4f8cff"),
	"damage_to_player": Color("ff4d4d"),
	"cancelled": Color("9fb8ad"),
	"energy": Color("ffd23f"),
	"disabled": Color("2a4a3a"),
	# Bench oscilloscope: cream/off-white moulded plastic case.
	"case": Color("e4dccb"),
	"case_dark": Color("c9c0ab"),
	"case_edge": Color("9d947f"),
	"case_print": Color("5a5446"),
	"bezel": Color("0c110e"),
	"knob": Color("1d1d1c"),
	"knob_cap": Color("c9c7c0"),
	"plate": Color("e9e3cf"),
	# CRT phosphor (P31 green) for the result trace and the etched graticule.
	"phosphor": Color("8dffb4"),
	"graticule": Color("a8f0c8"),
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


## Scaled font size for a design-time size (see FONT_SCALE).
func fs(size: float) -> int:
	return maxi(1, roundi(size * FONT_SCALE))


func color(id: String) -> Color:
	return COLORS.get(id, Color.MAGENTA)

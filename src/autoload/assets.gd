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

const SOUNDS := {
	"card_play": AUDIO_DIR + "card_play.ogg",
	"hit": AUDIO_DIR + "hit.ogg",
	"cancel": AUDIO_DIR + "cancel.ogg",
}

## Placeholder palette used by code-drawn visuals.
const COLORS := {
	"background": Color("14182a"),
	"panel": Color("1e2440"),
	"grid": Color("2c3560"),
	"text": Color("e8ecff"),
	"text_dim": Color("8a93c0"),
	"enemy_wave": Color("ff5c7a"),
	"player_wave": Color("4fd1ff"),
	"net_wave": Color("ffe066"),
	"damage_to_enemy": Color("7dff9a"),
	"damage_to_player": Color("ff4040"),
	"blocked": Color("8a93c0"),
	"energy": Color("ffb347"),
}


## Returns the texture for `id`, or null if the file does not exist yet
## (callers must then draw a placeholder).
func texture(id: String) -> Texture2D:
	var path: String = TEXTURES.get(id, "")
	if path != "" and ResourceLoader.exists(path):
		return load(path)
	return null


func font(id: String) -> Font:
	var path: String = FONTS.get(id, "")
	if path != "" and ResourceLoader.exists(path):
		return load(path)
	return null


func sound(id: String) -> AudioStream:
	var path: String = SOUNDS.get(id, "")
	if path != "" and ResourceLoader.exists(path):
		return load(path)
	return null


func color(id: String) -> Color:
	return COLORS.get(id, Color.MAGENTA)

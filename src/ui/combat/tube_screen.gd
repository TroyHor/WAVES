class_name TubeScreen
extends Control
## A small CRT tube: renders `content` in a SubViewport and shows it through
## tube.gdshader (mild barrel, scanlines, glow, rounded glass). Used for the
## receiver (amber) and transmitter (cyan-white) screens. The content's grid
## coordinates are local to this control, same as without the tube.

const TUBE_SHADER := preload("res://src/ui/crt/tube.gdshader")

var content: Control
var glass_tint := Color(0.02, 0.03, 0.03)
var curvature := 0.035
var _vp: SubViewport
var _tex: TextureRect
var _mat: ShaderMaterial


func _init(p_content: Control = null) -> void:
	content = p_content
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _ready() -> void:
	_vp = SubViewport.new()
	_vp.disable_3d = true
	_vp.transparent_bg = false
	_vp.gui_disable_input = true
	add_child(_vp)
	content.theme = ThemeFactory.shared()
	_vp.add_child(content)
	_tex = TextureRect.new()
	_tex.texture = _vp.get_texture()
	_tex.stretch_mode = TextureRect.STRETCH_SCALE
	_tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_tex.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_mat = ShaderMaterial.new()
	_mat.shader = TUBE_SHADER
	for key in Assets.TUBE:
		_mat.set_shader_parameter(key, Assets.TUBE[key])
	_mat.set_shader_parameter("curvature", curvature)
	_mat.set_shader_parameter("corner_radius", 12.0)
	_mat.set_shader_parameter("glass_tint", glass_tint)
	_tex.material = _mat
	add_child(_tex)
	resized.connect(_fit)
	_fit()


func _fit() -> void:
	if _vp == null or size.x < 2.0 or size.y < 2.0:
		return
	_vp.size = Vector2i(size)
	content.size = size
	_tex.size = size
	_mat.set_shader_parameter("tube_size", size)

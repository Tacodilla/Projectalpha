# background.gd — camera-aligned, full-screen tiling (Godot 4)
extends Node2D

@export var texture: Texture2D                  # drag in res://black.png
@export var use_solid_fill: bool = true
@export var fill_color: Color = Color(0, 0, 0, 1)

@export var tile_scale: float = 1.0             # 1.0 = native size (e.g., 256x256)
@export var tint: Color = Color(1, 1, 1, 1)

@export var scroll_px_per_sec: Vector2 = Vector2.ZERO  # e.g., (0, 12) to drift downward
@export var bind_to_camera: bool = true

var _offset: Vector2 = Vector2.ZERO
var _tile_size: Vector2 = Vector2.ZERO

func _ready() -> void:
	z_as_relative = false
	z_index = -100
	_recalc_tile_size()
	if get_viewport():
		get_viewport().size_changed.connect(func(): queue_redraw())
	set_process(true)
	queue_redraw()

func _process(delta: float) -> void:
	# Follow the active Camera2D so our (0,0) = screen's top-left
	if bind_to_camera:
		var cam := get_viewport().get_camera_2d()
		if cam:
			var vp := _vp_size()
			var top_left := (cam.get_screen_center_position() - vp * 0.5).floor()
			global_position = top_left

	# Scroll, if requested
	if scroll_px_per_sec != Vector2.ZERO and _tile_size != Vector2.ZERO:
		_offset += scroll_px_per_sec * delta
		if _tile_size.x > 0.0:
			_offset.x = fposmod(_offset.x, _tile_size.x)
		if _tile_size.y > 0.0:
			_offset.y = fposmod(_offset.y, _tile_size.y)

	queue_redraw()

func _draw() -> void:
	var vp_size := _vp_size()

	# Paint full screen first so there are never gaps
	if use_solid_fill:
		draw_rect(Rect2(Vector2.ZERO, vp_size), fill_color, true)

	if texture == null or _tile_size == Vector2.ZERO:
		return

	var ts := _tile_size
	var start := Vector2(-_offset.x, -_offset.y)

	var cols := int(ceil((vp_size.x - start.x) / ts.x)) + 1
	var rows := int(ceil((vp_size.y - start.y) / ts.y)) + 1

	for y in range(rows):
		for x in range(cols):
			var p := start + Vector2(x * ts.x, y * ts.y)
			draw_texture_rect(texture, Rect2(p, ts), false, tint)

func _vp_size() -> Vector2:
	return get_viewport().get_visible_rect().size

func _recalc_tile_size() -> void:
	if texture != null:
		_tile_size = texture.get_size() * tile_scale
	else:
		_tile_size = Vector2.ZERO

extends Area2D

@export var enemy_scene: PackedScene
@export var spawn_interval: float = 3.0
@export var max_active: int = 4
@export var spawn_on_enter: bool = true
@export var jitter_radius: float = 64.0
@export var player_group: String = "player"

var _active = false
var _timer = 0.0
var _alive = []

func _ready():
	area_entered.connect(_on_area_entered)
	body_entered.connect(_on_body_entered)
	area_exited.connect(_on_area_exited)
	body_exited.connect(_on_body_exited)
	randomize()

func _process(delta):
	for i in range(_alive.size() - 1, -1, -1):
		if not is_instance_valid(_alive[i]):
			_alive.remove_at(i)

	if not _active:
		return

	_timer -= delta
	if _timer <= 0.0 and _alive.size() < max_active:
		_spawn_one()
		_timer = spawn_interval

func _on_area_entered(a):
	if a.is_in_group(player_group):
		_activate()

func _on_body_entered(b):
	if b.is_in_group(player_group):
		_activate()

func _on_area_exited(a):
	if a.is_in_group(player_group):
		_deactivate()

func _on_body_exited(b):
	if b.is_in_group(player_group):
		_deactivate()

func _activate():
	if _active:
		return
	_active = true
	_timer = 0.1
	if spawn_on_enter and _alive.size() < max_active:
		_spawn_one()

func _deactivate():
	_active = false

func _spawn_one():
	if enemy_scene == null:
		push_warning("ProximitySpawner: enemy_scene is not set.")
		return
	var enemy = enemy_scene.instantiate()
	if enemy == null:
		return
	get_parent().add_child(enemy)

	var base_pos = global_position
	var points = _get_spawn_points()
	if points.size() > 0:
		base_pos = points[randi() % points.size()].global_position

	var offset_dir = Vector2(randf_range(-1, 1), randf_range(-1, 1))
	if offset_dir == Vector2.ZERO:
		offset_dir = Vector2.RIGHT
	var offset = offset_dir.normalized() * randf() * jitter_radius

	enemy.global_position = base_pos + offset
	enemy.rotation = randf_range(-PI, PI)
	_alive.append(enemy)

func _get_spawn_points():
	var pts = []
	for c in get_children():
		if c is Marker2D or (c is Node2D and c.name.begins_with("SpawnPoint")):
			pts.append(c)
	return pts

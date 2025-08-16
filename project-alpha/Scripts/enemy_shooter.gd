extends CharacterBody2D

# ---------- Tuning ----------
@export var move_speed: float = 120.0
@export var strafe_speed: float = 90.0
@export var desired_distance: float = 280.0
@export var turn_speed: float = 3.5
@export var health: int = 3

# Shooting
@export var bullet_scene: PackedScene      # assign res://enemy_bullet.tscn
@export var fire_interval: float = 1.2
@export var fire_jitter: float = 0.35
@export var fire_range: float = 700.0
@export var aim_cone_deg: float = 22.0
@export var aim_inaccuracy_deg_base: float = 6.0

# Loot (NEW)
@export var loot_table: StringName = "enemy_basic"

# Internals
var _fire_cd: float = 0.0
var _drop_done: bool = false

func _ready() -> void:
	_reset_cooldown()
	set_physics_process(true)

func _physics_process(delta: float) -> void:
	var player: Node2D = get_tree().get_first_node_in_group("player") as Node2D
	if player == null:
		velocity = Vector2.ZERO
		move_and_slide()
		return

	# Movement: keep a standoff distance and strafe a bit
	var to_p: Vector2 = (player.global_position - global_position)
	var dist: float = to_p.length()
	var dir: Vector2 = to_p.normalized()

	# Face the player smoothly
	var target_angle: float = dir.angle()
	rotation = lerp_angle(rotation, target_angle, clamp(turn_speed * delta, 0.0, 1.0))

	# Advance/retreat to desired_distance
	var forward: float = 0.0
	if dist > desired_distance + 20.0:
		forward = move_speed
	elif dist < desired_distance - 20.0:
		forward = -move_speed * 0.6

	# Strafe perpendicular a little for motion
	var side: Vector2 = Vector2.RIGHT.rotated(rotation)
	var strafe: Vector2 = side * strafe_speed * sin(Time.get_ticks_msec() * 0.002)

	velocity = dir * forward + strafe
	move_and_slide()

	# Firing logic
	if _fire_cd > 0.0:
		_fire_cd -= delta
	else:
		_attempt_fire(player, dist, dir)

func _attempt_fire(player: Node2D, dist: float, dir: Vector2) -> void:
	if bullet_scene == null:
		_reset_cooldown()
		return
	if dist > fire_range:
		_reset_cooldown()
		return

	# Check simple aim cone
	var aim_dot: float = Vector2.RIGHT.rotated(rotation).dot(dir)
	var cone_rad: float = deg_to_rad(aim_cone_deg)
	if acos(clamp(aim_dot, -1.0, 1.0)) > cone_rad:
		_reset_cooldown()
		return

	var bullet: Node = bullet_scene.instantiate()
	if not (bullet is Node2D):
		_reset_cooldown()
		return

	var b2d: Node2D = bullet as Node2D
	get_tree().current_scene.add_child(b2d)
	b2d.global_position = global_position

	var extra_deg: float = clamp((desired_distance - absf(dist - desired_distance)) / desired_distance * 4.0, 0.0, 8.0)
	var spread: float = deg_to_rad(randf_range(-(aim_inaccuracy_deg_base + extra_deg), (aim_inaccuracy_deg_base + extra_deg)))
	b2d.rotation = rotation + spread

	_reset_cooldown()

# --------- Damage / Death ---------
func take_damage(amount: int) -> void:
	health -= amount
	if health <= 0:
		die()

func die() -> void:
	# Real death -> drop, then free
	drop_and_die()

# Off-screen cleanup should NOT drop loot
func _on_VisibleOnScreenNotifier2D_screen_exited() -> void:
	queue_free()

# --------- NEW: drop & free ---------
func drop_and_die() -> void:
	if not _drop_done:
		_drop_done = true
		var world: Node = get_tree().get_first_node_in_group("world")
		if world == null:
			world = get_tree().current_scene
		if world and world.has_method("spawn_loot_from_table"):
			var player: Node2D = get_tree().get_first_node_in_group("player") as Node2D
			var pos: Vector2 = (self as Node2D).global_position if self is Node2D else Vector2.ZERO
			world.spawn_loot_from_table(loot_table, pos, player)
	queue_free()

# --------- cooldown helper ---------
func _reset_cooldown() -> void:
	_fire_cd = max(0.1, fire_interval + randf_range(-fire_jitter, fire_jitter))

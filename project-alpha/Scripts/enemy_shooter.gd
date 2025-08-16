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
@export var inaccuracy_per_pxps: float = 0.02
@export var lead_factor: float = 0.18

# ---------- Internal ----------
var player: Node2D
var strafe_dir: float = 1.0
var _fire_cd: float = 0.0
var _player_prev_pos: Vector2 = Vector2.ZERO
var _player_vel_est: Vector2 = Vector2.ZERO

func _ready() -> void:
	randomize()
	player = get_tree().get_first_node_in_group("player") as Node2D
	if player:
		_player_prev_pos = player.global_position
	_reset_cooldown()

func _physics_process(delta: float) -> void:
	if not player:
		return

	# --- track approximate player velocity (for lead + inaccuracy) ---
	var ppos: Vector2 = player.global_position
	_player_vel_est = (ppos - _player_prev_pos) / max(delta, 0.0001)
	_player_prev_pos = ppos

	# --- facing/turning ---
	var to_player: Vector2 = ppos - global_position
	var target_angle: float = to_player.angle()
	rotation = lerp_angle(rotation, target_angle, turn_speed * delta)

	# --- range keeping + strafing ---
	var distance: float = to_player.length()
	var dir: Vector2 = Vector2.ZERO
	if distance > desired_distance:
		dir += Vector2.RIGHT.rotated(rotation)       # forward
	elif distance < desired_distance - 60.0:
		dir += Vector2.LEFT.rotated(rotation)        # back up

	# random strafe flips
	if randi() % 100 < 2:
		strafe_dir *= -1.0
	dir += Vector2.UP.rotated(rotation) * (strafe_speed / max(1.0, move_speed)) * strafe_dir

	velocity = dir.normalized() * move_speed
	move_and_slide()

	# --- shooting ---
	_fire_cd = max(0.0, _fire_cd - delta)
	if _can_fire(distance, to_player):
		_fire_bullet_at(ppos)

func _can_fire(distance: float, to_player: Vector2) -> bool:
	if bullet_scene == null or _fire_cd > 0.0 or distance > fire_range:
		return false
	var angle_diff: float = abs(wrapf(rotation - to_player.angle(), -PI, PI))
	return angle_diff <= deg_to_rad(aim_cone_deg)

func _fire_bullet_at(target_pos: Vector2) -> void:
	_reset_cooldown()
	var bullet := bullet_scene.instantiate() as Node2D
	if bullet == null:
		return

	get_parent().add_child(bullet)
	bullet.global_position = global_position

	var predicted: Vector2 = target_pos + _player_vel_est * lead_factor
	var angle: float = (predicted - global_position).angle()

	var extra_deg: float = clamp(_player_vel_est.length() * inaccuracy_per_pxps, 0.0, 12.0)
	var spread: float = deg_to_rad(randf_range(-(aim_inaccuracy_deg_base + extra_deg),
											   +(aim_inaccuracy_deg_base + extra_deg)))
	bullet.rotation = angle + spread

func take_damage(amount: int) -> void:
	health -= amount
	if health <= 0:
		die()

func die() -> void:
	queue_free()

func _reset_cooldown() -> void:
	_fire_cd = max(0.1, fire_interval + randf_range(-fire_jitter, fire_jitter))

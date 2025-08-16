extends Node2D

@export var bullet_scene: PackedScene
@export var speed: float = 200.0
@export var max_health: int = 5
var health: int
var is_dead: bool = false

func _ready() -> void:
	health = max_health

func _process(delta: float) -> void:
	if is_dead:
		return

	# Movement
	var input_direction := Vector2(
		Input.get_axis("move_left", "move_right"),
		Input.get_axis("move_up", "move_down")
	)
	position += input_direction.normalized() * speed * delta

	# Shoot
	if Input.is_action_just_pressed("shoot"):
		_shoot()

func _shoot() -> void:
	if bullet_scene == null or is_dead:
		return
	var bullet := bullet_scene.instantiate()
	get_parent().add_child(bullet)
	bullet.global_position = global_position
	# If you later rotate the player, also set: bullet.rotation = rotation

# Called by enemy bullets
func take_damage(amount: int) -> void:
	if is_dead:
		return
	health = max(0, health - int(amount))
	if health <= 0:
		_die()

func _die() -> void:
	if is_dead:
		return
	is_dead = true
	# Quick feedback: hide the ship and stop processing
	visible = false
	set_process(false)
	# Reload the current scene after a short delay
	await get_tree().create_timer(0.6).timeout
	get_tree().reload_current_scene()

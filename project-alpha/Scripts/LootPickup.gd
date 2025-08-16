# LootPickup.gd — self-drawing, physics-optional pickup (Godot 4)
extends Area2D

@export var item_id: StringName
@export var quantity: int = 1

# behavior
@export var vacuum_speed: float = 260.0
@export var pickup_radius: float = 18.0
@export var delay_before_collect: float = 0.12

# look (no PNG needed)
@export var radius: float = 7.0
@export var fill_color: Color = Color(1.0, 0.95, 0.4, 0.95)
@export var rim_color: Color = Color(1.0, 1.0, 1.0, 0.6)
@export var pulse: float = 0.15

var _target: Node2D = null
var _age: float = 0.0
var _base_radius: float

func _ready() -> void:
	_base_radius = radius
	monitoring = true
	monitorable = true
	if has_signal("body_entered"):
		body_entered.connect(_on_body)
	set_physics_process(true)
	z_index = 100   # draw on top

func _physics_process(delta: float) -> void:
	_age += delta
	radius = _base_radius * (1.0 + pulse * sin(_age * 6.0))
	rotation += delta * 3.0
	queue_redraw()

	if _target == null or not is_instance_valid(_target):
		_target = get_tree().get_first_node_in_group("player") as Node2D

	if _target:
		# Home toward player
		global_position = global_position.move_toward(_target.global_position, vacuum_speed * delta)
		# Distance-based auto-collect (works even if physics layers/masks are wrong)
		if _age >= delay_before_collect and global_position.distance_to(_target.global_position) <= pickup_radius:
			_give_to(_target)

func _on_body(b: Node) -> void:
	# Optional physics path (if your player is a PhysicsBody2D and masks match)
	if _age >= delay_before_collect:
		_try_give_to_node(b)

func _draw() -> void:
	# simple glow dot
	draw_circle(Vector2.ZERO, radius, fill_color)
	draw_arc(Vector2.ZERO, radius + 1.5, 0.0, TAU, 24, rim_color, 2.0)

# ------------- helpers -------------
func _give_to(target: Node) -> void:
	_try_give_to_node(target)

func _try_give_to_node(n: Node) -> void:
	if n == null:
		return
	# Player root wrapper (if you added add_item on root)
	if n.is_in_group("player") and n.has_method("add_item"):
		n.call("add_item", item_id, quantity)
		queue_free()
		return
	# Player/Inventory child (works even if root has no wrapper)
	if n.is_in_group("player"):
		var inv := n.get_node_or_null("Inventory")
		if inv and inv.has_method("add_item"):
			inv.call("add_item", item_id, quantity)
			queue_free()
			return

# LootPickup.gd — root: Area2D
extends Area2D

@export var item_id: StringName
@export var quantity: int = 1
@export var vacuum_speed: float = 220.0

var _target: Node2D

func _ready() -> void:
	body_entered.connect(_on_body)
	set_physics_process(true)
	monitoring = true
	monitorable = true

func _physics_process(delta: float) -> void:
	if _target and is_instance_valid(_target):
		global_position = global_position.move_toward(_target.global_position, vacuum_speed * delta)

func set_target(n: Node2D) -> void:
	_target = n

func _on_body(b: Node) -> void:
	if b == null: return
	# Try Player root
	if b.is_in_group("player") and b.has_method("add_item"):
		b.add_item(item_id, quantity)
		queue_free()
		return
	# Try Player/Inventory child
	if b.is_in_group("player"):
		var inv := b.get_node_or_null("Inventory")
		if inv and inv.has_method("add_item"):
			inv.add_item(item_id, quantity)
			queue_free()
			return

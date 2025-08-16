# enemy_bullet.gd
extends Area2D

@export var speed := 600.0
@export var damage := 1

func _ready():
	# Listen to both, in case the player is Area2D (it is) or later becomes a Body.
	if not is_connected("area_entered", _on_area_entered):
		area_entered.connect(_on_area_entered)
	if not is_connected("body_entered", _on_body_entered):
		body_entered.connect(_on_body_entered)

func _process(delta: float) -> void:
	# Move forward along our rotation
	position += Vector2.RIGHT.rotated(rotation) * speed * delta

func _on_area_entered(area: Area2D) -> void:
	# Your player is an Area2D in group "player"
	if area and area.is_in_group("player") and area.has_method("take_damage"):
		area.take_damage(damage)
		queue_free()

func _on_body_entered(body: Node) -> void:
	if body and body.is_in_group("player") and body.has_method("take_damage"):
		body.take_damage(damage)
		queue_free()

func _on_VisibleOnScreenNotifier2D_screen_exited():
	queue_free()

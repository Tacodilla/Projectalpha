# Bullet.gd
extends Area2D

var speed := 700.0

func _ready():
	# Ensure both signals are hooked (works even if scene signals aren't set)
	if not is_connected("area_entered", _on_area_entered):
		area_entered.connect(_on_area_entered)
	if not is_connected("body_entered", _on_body_entered):
		body_entered.connect(_on_body_entered)

func _process(delta):
	# Move forward (up). If you rotate the ship/bullet later, switch to RIGHT.rotated(rotation)
	position.y -= speed * delta

func _on_area_entered(area: Area2D) -> void:
	if area and area.has_method("take_damage"):
		area.take_damage(1)
		queue_free()

func _on_body_entered(body: Node) -> void:
	if body and body.has_method("take_damage"):
		body.take_damage(1)
		queue_free()

func _on_visible_on_screen_notifier_2d_screen_exited():
	queue_free()

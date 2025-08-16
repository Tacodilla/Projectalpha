# PickupProxy.gd — attach to a *child* node under Player if the root already has a script
extends Node

@onready var player := get_parent()
@onready var inv: Node = player.get_node_or_null("Inventory")

func _ready() -> void:
	# Ensure the *Player root* is in the "player" group (pickups check the body that collides).
	if player and not player.is_in_group("player"):
		player.add_to_group("player")
	# Nothing else needed — LootPickup will find player/Inventory automatically.

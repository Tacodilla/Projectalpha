# SpawnTester.gd — add as a child under your World node
# Forces a few loot pickups to spawn next to the player and vacuum in.
extends Node

@export var loot_pickup_scene: PackedScene    # <-- assign res://Scenes/LootPickup.tscn here
@export var table_id: StringName = "enemy_basic"
@export var use_db: bool = true
@export var offset_px: float = 20.0

func _ready() -> void:
	await get_tree().process_frame

	var player: Node2D = get_tree().get_first_node_in_group("player") as Node2D
	if player == null:
		push_error("SpawnTester: No node in group 'player'. Add your Player root to the 'player' group.")
		return

	var loot_scene: PackedScene = loot_pickup_scene
	if loot_scene == null:
		if ResourceLoader.exists("res://LootPickup.tscn"):
			loot_scene = load("res://LootPickup.tscn") as PackedScene
		elif ResourceLoader.exists("res://Scenes/LootPickup.tscn"):
			loot_scene = load("res://Scenes/LootPickup.tscn") as PackedScene
	if loot_scene == null:
		push_error("SpawnTester: LootPickup scene missing. Assign it in the Inspector.")
		return

	var drops: Array = []
	if use_db:
		var db = get_node_or_null("/root/DB")
		if db:
			drops = db.call("roll_loot", table_id)
		else:
			push_warning("SpawnTester: DB autoload not found; using fallback items.")

	if drops.is_empty():
		drops = [
			{"id":"ore_t1","qty":3},
			{"id":"ore_t2","qty":1}
		]

	var n_spawned: int = 0
	for d in drops:
		var lp = loot_scene.instantiate()
		get_tree().current_scene.add_child(lp)
		if lp is Area2D:
			var a2d: Area2D = lp
			a2d.global_position = player.global_position + Vector2(offset_px * (n_spawned + 1), 0)
			a2d.set("item_id", StringName(d["id"]))
			a2d.set("quantity", int(d["qty"]))
			if a2d.has_method("set_target"):
				a2d.call("set_target", player)
		n_spawned += 1

	print("SpawnTester: spawned ", n_spawned, " pickups at ", player.global_position)

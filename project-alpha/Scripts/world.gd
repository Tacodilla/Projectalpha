# world.gd (Godot 4) — backgrounds + loot glue + Inspector-set pickup scene
extends Node2D

# ---- Scene refs (hook these in the Inspector)
@export var background_far_path: NodePath      # optional
@export var background_near_path: NodePath     # optional
@export var player_path: NodePath              # REQUIRED
@export var hud_path: NodePath                 # optional
@export var loot_pickup_scene: PackedScene     # <-- assign res://Scenes/LootPickup.tscn here

# ---- Game options
@export var start_paused: bool = false
@export var player_spawn: Vector2 = Vector2(256, 360)

# ---- Background preset
enum BGMode { STATIC, DRIFT, PARALLAX_SOFT, PARALLAX_DEEP }
@export_enum("Static","Drift","Parallax (Soft)","Parallax (Deep)") var background_mode: int = BGMode.PARALLAX_SOFT

# ---- Background tuning
@export_group("Preset: Drift (single layer)")
@export var drift_speed: Vector2 = Vector2(0, 10)

@export_group("Preset: Parallax Soft")
@export var soft_far_scale: float = 1.0
@export var soft_far_speed: Vector2 = Vector2(0, 6)
@export var soft_near_scale: float = 1.25
@export var soft_near_speed: Vector2 = Vector2(0, 18)

@export_group("Preset: Parallax Deep")
@export var deep_far_scale: float = 0.95
@export var deep_far_speed: Vector2 = Vector2(0, 12)
@export var deep_near_scale: float = 1.35
@export var deep_near_speed: Vector2 = Vector2(0, 36)

# ---- Loot + Debug
@export var spawn_test_loot_on_start: bool = false
@export var test_loot_table: StringName = "enemy_basic"
@export var print_inventory_action: StringName = "inventory"   # bind to B in Input Map

var LootPickupScene: PackedScene = null

@onready var bg_far: Node2D  = get_node_or_null(background_far_path)
@onready var bg_near: Node2D = get_node_or_null(background_near_path)
@onready var player: Node2D  = get_node_or_null(player_path)
@onready var hud: Node       = get_node_or_null(hud_path)

# Runtime DB handle (avoids parser issues)
@onready var DBRef: Node = get_node_or_null("/root/DB")

func _ready() -> void:
	# Tag this node so helpers can find us.
	if not is_in_group("world"):
		add_to_group("world")

	get_tree().paused = start_paused

	# Prefer Inspector-assigned pickup scene; otherwise try common paths.
	if loot_pickup_scene:
		LootPickupScene = loot_pickup_scene
	else:
		if ResourceLoader.exists("res://LootPickup.tscn"):
			LootPickupScene = load("res://LootPickup.tscn") as PackedScene
		elif ResourceLoader.exists("res://Scenes/LootPickup.tscn"):
			LootPickupScene = load("res://Scenes/LootPickup.tscn") as PackedScene
		else:
			push_warning('LootPickup scene not found. Assign one to "loot_pickup_scene" in the Inspector.')

	# Player setup
	if player:
		player.global_position = player_spawn
		if player.has_method("reset"):
			player.reset()
		if player.has_signal("died"):
			player.connect("died", Callable(self, "_on_player_died"))

	# HUD (safe)
	if hud:
		if hud.has_signal("start_pressed"):
			hud.connect("start_pressed", Callable(self, "start_game"))
		if hud.has_signal("restart_pressed"):
			hud.connect("restart_pressed", Callable(self, "restart_level"))
		if hud.has_method("set_score"):
			hud.set_score(0)
		if hud.has_method("show_title"):
			hud.show_title()

	_apply_background_preset()

	# Optional: spawn test loot at player on start
	if spawn_test_loot_on_start and player:
		spawn_loot_from_table(test_loot_table, player.global_position, player)

func _unhandled_input(event: InputEvent) -> void:
	var pressed_inventory: bool = event.is_action_pressed(String(print_inventory_action))
	if not pressed_inventory and event is InputEventKey:
		var ke: InputEventKey = event
		if ke.pressed and not ke.echo and ke.keycode == KEY_B:
			pressed_inventory = true

	if pressed_inventory:
		var inv = _get_inventory()
		if inv:
			var items = inv.call("all_items")
			var credits = int(inv.get("credits"))
			print("CARGO:", items, " | CREDITS:", credits)

# -------------------- Background control --------------------

func _apply_background_preset() -> void:
	if not bg_far and not bg_near:
		return
	if bg_far:
		bg_far.z_as_relative = false
		bg_far.z_index = -110
	if bg_near:
		bg_near.z_as_relative = false
		bg_near.z_index = -100

	match background_mode:
		BGMode.STATIC:
			_use_single_layer(Vector2.ZERO)
		BGMode.DRIFT:
			_use_single_layer(drift_speed)
		BGMode.PARALLAX_SOFT:
			_use_parallax(soft_far_scale, soft_far_speed, soft_near_scale, soft_near_speed)
		BGMode.PARALLAX_DEEP:
			_use_parallax(deep_far_scale, deep_far_speed, deep_near_scale, deep_near_speed)

func _use_single_layer(speed: Vector2) -> void:
	if bg_near:
		bg_near.visible = false
		_try_set(bg_near, "scroll_px_per_sec", Vector2.ZERO)
	if bg_far:
		bg_far.visible = true
		_try_set(bg_far, "use_solid_fill", true)
		_try_set(bg_far, "bind_to_camera", true)
		_try_set(bg_far, "tile_scale", 1.0)
		_try_set(bg_far, "scroll_px_per_sec", speed)

func _use_parallax(far_scale: float, far_speed: Vector2, near_scale: float, near_speed: Vector2) -> void:
	if bg_far:
		bg_far.visible = true
		_try_set(bg_far, "use_solid_fill", true)
		_try_set(bg_far, "bind_to_camera", true)
		_try_set(bg_far, "tile_scale", far_scale)
		_try_set(bg_far, "scroll_px_per_sec", far_speed)
	if bg_near:
		bg_near.visible = true
		_try_set(bg_near, "use_solid_fill", false)
		_try_set(bg_near, "bind_to_camera", true)
		_try_set(bg_near, "tile_scale", near_scale)
		_try_set(bg_near, "scroll_px_per_sec", near_speed)

func _try_set(n: Node, prop: StringName, value) -> void:
	if n == null:
		return
	if _has_property(n, prop):
		n.set(prop, value)

func _has_property(obj: Object, prop: StringName) -> bool:
	for d in obj.get_property_list():
		if typeof(d) == TYPE_DICTIONARY and d.get("name") == String(prop):
			return true
	return false

# -------------------- Loot spawning API --------------------

func spawn_loot_from_table(table_id: String, where: Vector2, attract_to: Node2D = null) -> void:
	if DBRef == null:
		push_warning("DB autoload not found at /root/DB; cannot roll loot.")
		return
	if LootPickupScene == null:
		push_warning("LootPickupScene not loaded; assign it in the Inspector.")
		return

	var drops: Array = DBRef.call("roll_loot", StringName(table_id))
	for d in drops:
		var lp = LootPickupScene.instantiate()
		add_child(lp)
		if lp is Area2D:
			var a2d: Area2D = lp
			a2d.global_position = where + Vector2(randf_range(-10.0, 10.0), randf_range(-10.0, 10.0))
			a2d.set("item_id", StringName(d["id"]))
			a2d.set("quantity", int(d["qty"]))
			if attract_to and a2d.has_method("set_target"):
				a2d.call("set_target", attract_to)
		else:
			lp.set("position", where)

# -------------------- Game flow & helpers --------------------

func start_game() -> void:
	get_tree().paused = false
	_clear_playfield()
	if player:
		player.global_position = player_spawn
		if player.has_method("reset"):
			player.reset()
	if hud and hud.has_method("show_game"):
		hud.show_game()

func _on_player_died() -> void:
	game_over()

func game_over() -> void:
	get_tree().paused = true
	if hud and hud.has_method("show_game_over"):
		hud.show_game_over()

func restart_level() -> void:
	get_tree().paused = false
	get_tree().reload_current_scene()

func _get_inventory():
	if player:
		var inv = player.get_node_or_null("Inventory")
		if inv:
			return inv
	return null

func _clear_playfield() -> void:
	for g in ["bullets", "enemy_bullets", "bullet", "enemy_bullet", "enemies"]:
		_clear_group(g)

func _clear_group(group_name: String) -> void:
	for n in get_tree().get_nodes_in_group(group_name):
		if is_instance_valid(n):
			n.queue_free()

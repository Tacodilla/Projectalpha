# DropOnDeath.gd — attach as a child of an enemy node (Godot 4)
extends Node

@export var loot_table: StringName = "enemy_basic"
@export var health_property_name: StringName = "health"  # set to "hp" if needed
@export var use_health_watch: bool = true
@export var fallback_drop_on_exit: bool = true           # drop if the enemy despawns
@export var min_lifetime_sec: float = 0.25               # ignore instant spawns/despawns
@export var debug_logs: bool = false

var _dropped: bool = false
var _age: float = 0.0
var _last_pos: Vector2 = Vector2.ZERO
var _world: Node = null

@onready var _enemy: Node = get_parent()

func _ready() -> void:
	if _enemy == null:
		return
	# Never run on the player
	if _enemy.is_in_group("player"):
		if debug_logs:
			print("[DropOnDeath] Disabled on player node ", _enemy.name)
		set_process(false)
		return
	if _enemy.has_signal("died"):
		_enemy.connect("died", Callable(self, "_on_parent_died"))
		if debug_logs: print("[DropOnDeath] Connected to 'died' on ", _enemy.name)
	_world = _find_world()
	set_process(use_health_watch or fallback_drop_on_exit)

func _process(delta: float) -> void:
	_age += delta
	if _enemy is Node2D:
		_last_pos = (_enemy as Node2D).global_position
	if not use_health_watch or _dropped or _enemy == null:
		return
	var prop_name: StringName = _resolve_health_property(_enemy)
	if prop_name != StringName():
		var hp: int = int(_enemy.get(prop_name))
		if hp <= 0:
			_drop_now("health_watch")
	elif debug_logs and int(Time.get_ticks_msec()) % 500 < 16:
		print("[DropOnDeath] ", _enemy.name, " has no usable health property.")

func _exit_tree() -> void:
	if fallback_drop_on_exit and not _dropped and _age >= min_lifetime_sec:
		_drop_now("fallback_exit")

func _on_parent_died() -> void:
	_drop_now("signal_died")

func _drop_now(source: String) -> void:
	if _dropped:
		return
	_dropped = true
	if _world == null or not _world.has_method("spawn_loot_from_table"):
		_world = _find_world()
	if _world == null or not _world.has_method("spawn_loot_from_table"):
		if debug_logs: print("[DropOnDeath] No world.spawn_loot_from_table; abort.")
		return
	var player_node: Node2D = null
	var players: Array = get_tree().get_nodes_in_group("player")
	if players.size() > 0 and players[0] is Node2D:
		player_node = players[0] as Node2D
	if debug_logs:
		print("[DropOnDeath] Dropping via ", source, " at ", _last_pos, " table=", loot_table)
	_world.call("spawn_loot_from_table", loot_table, _last_pos, player_node)

# ---------- helpers ----------
func _find_world() -> Node:
	var p: Node = _enemy
	while p != null:
		if p.has_method("spawn_loot_from_table"):
			return p
		p = p.get_parent()
	var ws: Array = get_tree().get_nodes_in_group("world")
	for w in ws:
		if w.has_method("spawn_loot_from_table"):
			return w
	var cs: Node = get_tree().current_scene
	if cs and cs.has_method("spawn_loot_from_table"):
		return cs
	return null

func _resolve_health_property(obj: Object) -> StringName:
	if _has_prop_named(obj, health_property_name):
		return health_property_name
	var candidates: Array = [StringName("health"), StringName("hp"), StringName("hp_current")]
	for c in candidates:
		if _has_prop_named(obj, c):
			health_property_name = c
			return c
	return StringName()

func _has_prop_named(obj: Object, prop_name: StringName) -> bool:
	for d in obj.get_property_list():
		if typeof(d) == TYPE_DICTIONARY and d.get("name") == String(prop_name):
			return true
	return false

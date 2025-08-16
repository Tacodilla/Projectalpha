# DB.gd — Game database (items, loot tables, zones) — Godot 4
extends Node

# ---------------- Types ----------------
enum ItemType { MATERIAL, UPGRADE, QUEST, CURRENCY }

# ---------------- RNG ----------------
var rng: RandomNumberGenerator = RandomNumberGenerator.new()

func _ready() -> void:
	rng.randomize()

# ---------------- Items ----------------
# Each item: { name:String, type:ItemType, tier?:int, value?:int, stack?:int }
var ITEMS: Dictionary = {
	# Materials (T1..T8)
	"ore_t1": {"name":"Basalt Shard", "tier":1, "type":ItemType.MATERIAL, "value":5,   "stack":999},
	"ore_t2": {"name":"Copper Nugget","tier":2, "type":ItemType.MATERIAL, "value":12,  "stack":999},
	"ore_t3": {"name":"Nickel Chunk", "tier":3, "type":ItemType.MATERIAL, "value":25,  "stack":999},
	"ore_t4": {"name":"Silver Ore",   "tier":4, "type":ItemType.MATERIAL, "value":40,  "stack":999},
	"ore_t5": {"name":"Gold Ore",     "tier":5, "type":ItemType.MATERIAL, "value":65,  "stack":999},
	"ore_t6": {"name":"Platinum",     "tier":6, "type":ItemType.MATERIAL, "value":95,  "stack":999},
	"ore_t7": {"name":"Iridium",      "tier":7, "type":ItemType.MATERIAL, "value":140, "stack":999},
	"ore_t8": {"name":"Aetherite",    "tier":8, "type":ItemType.MATERIAL, "value":220, "stack":999},

	# Currency
	"credits": {"name":"Credits", "type":ItemType.CURRENCY, "stack":2147483647},
}

func register_item(id: StringName, data: Dictionary) -> void:
	ITEMS[id] = data

func get_item(id: StringName) -> Dictionary:
	return ITEMS.get(id, {})

func get_item_value(id: StringName) -> int:
	return int(get_item(id).get("value", 0))

# ---------------- Loot Tables ----------------
# Entry: {"id":String, "w":int, "min":int, "max":int, "chance"?:float 0..1}
# Table forms:
#   [entries...]                       # implies rolls = 1
#   {"rolls":N, "entries":[...]}       # explicit rolls
var LOOT_TABLES: Dictionary = {
	"asteroid_t1": {
		"rolls": 2,
		"entries": [
			{"id":"ore_t1","w":100,"min":2,"max":5}
		]
	},

	"enemy_basic": {
		"rolls": 1,
		"entries": [
			{"id":"ore_t1","w":60,"min":1,"max":2},
			{"id":"ore_t2","w":20,"min":1,"max":1}
		]
	},

	"boss_nest_t1": {
		"rolls": 2,
		"entries": [
			{"id":"ore_t2","w":60,"min":3,"max":6},
			{"id":"ore_t3","w":30,"min":2,"max":4}
		]
	}
}

func register_loot_table(id: StringName, table) -> void:
	LOOT_TABLES[id] = table

func roll_loot(table_id: StringName, rolls_override: int = -1) -> Array:
	var t: Dictionary = _normalize_table(LOOT_TABLES.get(table_id))
	if t.is_empty():
		return []

	var entries: Array = t["entries"]
	if entries.is_empty():
		return []

	var total_w: int = 0
	for e in entries:
		total_w += int(e.get("w", 0))
	if total_w <= 0:
		return []

	var rolls: int = rolls_override if rolls_override >= 0 else int(t["rolls"])
	var out: Array = []

	for _i in range(rolls):
		var r: int = rng.randi_range(1, total_w)
		var acc: int = 0
		var picked: Dictionary = {}

		for e in entries:
			acc += int(e.get("w", 0))
			if r <= acc:
				# optional per-entry chance
				if e.has("chance") and rng.randf() > float(e["chance"]):
					break
				var qty_min: int = int(e.get("min", 1))
				var qty_max: int = int(e.get("max", 1))
				var qty: int = rng.randi_range(qty_min, qty_max)
				if qty > 0:
					picked = {"id": e["id"], "qty": qty}
				break

		# merge duplicates
		if picked.size() > 0:
			var merged := false
			for d in out:
				if d.get("id") == picked["id"]:
					d["qty"] = int(d["qty"]) + int(picked["qty"])
					merged = true
					break
			if not merged:
				out.append(picked)

	return out

func _normalize_table(raw) -> Dictionary:
	if raw == null:
		return {}
	if raw is Array:
		return {"rolls": 1, "entries": raw}
	if raw is Dictionary:
		var rolls: int = int(raw.get("rolls", 1))
		var entries = raw.get("entries", raw.get("items", []))
		if entries is Array:
			return {"rolls": rolls, "entries": entries}
	return {}

# Total sell value helper
func value_of_drops(drops: Array) -> int:
	var v: int = 0
	for d in drops:
		v += get_item_value(StringName(d.get("id",""))) * int(d.get("qty", 0))
	return v

# Debug aggregate helper
func debug_rolls(table_id: StringName, N: int = 1000) -> Dictionary:
	var acc: Dictionary = {}
	for _i in range(N):
		for d in roll_loot(table_id):
			var id: StringName = StringName(d["id"])
			acc[id] = int(acc.get(id, 0)) + int(d["qty"])
	return acc

# ---------------- Zones (stub for later Director) ----------------
var ZONES: Dictionary = {
	"zone_1": {
		"name": "Hearth Belt",
		"tiers": [1, 2],
		"asteroid_tables": ["asteroid_t1"],
		"enemy_tables": ["enemy_basic"],
		"boss_table": "boss_nest_t1"
	}
}

func get_zone(id: StringName) -> Dictionary:
	return ZONES.get(id, {})

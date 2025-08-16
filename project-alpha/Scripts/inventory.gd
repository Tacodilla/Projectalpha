# inventory.gd — attach as a child of Player (Godot 4)
extends Node

signal changed
signal credits_changed(new_total: int)

# Must match DB.ItemType order (MATERIAL = 0)
const ITEMTYPE_MATERIAL := 0

var cargo: Dictionary = {}   # item_id -> qty
var credits: int = 0

# Resolve the DB autoload at runtime
@onready var db: Node = get_node_or_null("/root/DB")

func add_item(id: StringName, qty: int = 1) -> void:
	if qty <= 0:
		return
	var current: int = int(cargo.get(id, 0))
	cargo[id] = current + qty
	emit_signal("changed")

func remove_item(id: StringName, qty: int = 1) -> int:
	if qty <= 0:
		return 0
	var have: int = int(cargo.get(id, 0))
	var take: int = min(have, qty)
	if take > 0:
		var left: int = have - take
		if left > 0:
			cargo[id] = left
		else:
			cargo.erase(id)
		emit_signal("changed")
	return take

func count(id: StringName) -> int:
	return int(cargo.get(id, 0))

func all_items() -> Dictionary:
	return cargo.duplicate(true)

func clear() -> void:
	cargo.clear()
	emit_signal("changed")

func add_credits(n: int) -> void:
	credits = max(0, credits + n)
	emit_signal("credits_changed", credits)

func spend_credits(n: int) -> bool:
	if credits >= n:
		credits -= n
		emit_signal("credits_changed", credits)
		return true
	return false

# Sell all MATERIAL items for credits; returns { id -> sold_qty, earned:int }
func sell_all_materials() -> Dictionary:
	var report: Dictionary = {"earned": 0}
	var to_remove: Array = []

	for id in cargo.keys():
		var item: Dictionary = {}
		if db:
			item = db.call("get_item", id)
		var t: int = int(item.get("type", -1))
		if t == ITEMTYPE_MATERIAL:
			var qty: int = int(cargo[id])
			var value: int = 0
			if db:
				value = int(db.call("get_item_value", id))
			report[id] = qty
			report["earned"] = int(report["earned"]) + qty * value
			to_remove.append(id)

	for id in to_remove:
		cargo.erase(id)

	if int(report["earned"]) > 0:
		add_credits(int(report["earned"]))
		emit_signal("changed")

	return report

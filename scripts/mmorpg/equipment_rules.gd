extends RefCounted
## Equipment slots and equip/unequip validation; no item duplication on failures.
const Stats = preload("res://scripts/mmorpg/core_stats.gd")
const Inventory = preload("res://scripts/mmorpg/inventory_system.gd")
const ALLOWED := ["weapon", "head", "chest", "hands", "legs", "feet", "ring", "amulet"]

static func new_equipment() -> Dictionary:
	return {"slots": {}}

static func equip(state: Dictionary, bag: Dictionary, actor: Dictionary, slot: String,
		item: String, bonuses: Dictionary) -> Dictionary:
	if not ALLOWED.has(slot) or item.is_empty():
		return {"ok": false, "reason": "invalid_slot_or_item"}
	# One serialized item is stored per equipment slot. Bonus metadata is server data.
	var before: Dictionary = state["slots"].get(slot, {})
	var proposed_bag: Dictionary = bag.duplicate(true)
	if not Inventory.remove_item(proposed_bag, item, 1):
		return {"ok": false, "reason": "missing_item"}
	if not before.is_empty() and Inventory.add_item(proposed_bag, str(before["id"]), 1) != 0:
		return {"ok": false, "reason": "inventory_full"}
	var proposed_slots: Dictionary = state["slots"].duplicate(true)
	proposed_slots[slot] = {"id": item, "bonuses": bonuses.duplicate(true)}
	var combined := {}
	for equipped in proposed_slots.values():
		for key in equipped.get("bonuses", {}).keys():
			combined[key] = float(combined.get(key, 0.0)) + float(equipped["bonuses"][key])
	bag.clear()
	bag.merge(proposed_bag, true)
	state["slots"] = proposed_slots
	actor["equipment_bonuses"] = combined
	Stats.recalculate(actor)
	return {"ok": true, "slot": slot, "item": item}

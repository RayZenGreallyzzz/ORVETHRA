extends RefCounted
## Minimal quest progress independent of HUD and graphics.
## A kill event may update progress, but can never pay out more than once.
const Inventory = preload("res://scripts/mmorpg/inventory_system.gd")

static func new_log() -> Dictionary:
	return {"entries": {}}

static func accept(log: Dictionary, quest_id: String, target_species: String, amount: int, reward: Dictionary) -> bool:
	if quest_id.is_empty() or target_species.is_empty() or amount < 1 or amount > 1000:
		return false
	var entries: Dictionary = log["entries"]
	if entries.has(quest_id):
		return false
	entries[quest_id] = {"target": target_species, "goal": amount,
		"count": 0, "claimed": false, "reward": reward.duplicate(true)}
	return true

static func register_regular_kill(log: Dictionary, species: String) -> void:
	for quest in log["entries"].values():
		if not bool(quest.get("claimed", false)) and str(quest["target"]) == species:
			quest["count"] = mini(int(quest["goal"]), int(quest["count"]) + 1)

static func claim(log: Dictionary, quest_id: String, bag: Dictionary, actor: Dictionary) -> Dictionary:
	if not log["entries"].has(quest_id):
		return {"ok": false, "reason": "quest_missing"}
	var quest: Dictionary = log["entries"][quest_id]
	if bool(quest["claimed"]) or int(quest["count"]) < int(quest["goal"]):
		return {"ok": false, "reason": "not_claimable"}
	var reward: Dictionary = quest["reward"]
	var item := str(reward.get("item_id", ""))
	var amount := maxi(0, int(reward.get("amount", 0)))
	var proposed: Dictionary = bag.duplicate(true)
	if not item.is_empty() and amount > 0 and Inventory.add_item(proposed, item, amount) != 0:
		return {"ok": false, "reason": "inventory_full"}
	bag.clear()
	bag.merge(proposed, true)
	actor["gold"] = int(actor.get("gold", 0)) + maxi(0, int(reward.get("gold", 0)))
	quest["claimed"] = true
	return {"ok": true, "claimed": quest_id}

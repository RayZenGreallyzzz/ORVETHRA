extends RefCounted
## Composition root for offline simulation and future authoritative zone logic.
## No scene/UI dependency and no trust in arbitrary client-supplied rewards.
const Stats = preload("res://scripts/mmorpg/core_stats.gd")
const Inventory = preload("res://scripts/mmorpg/inventory_system.gd")
const Rewards = preload("res://scripts/mmorpg/reward_rules.gd")
const Pets = preload("res://scripts/mmorpg/pet_system.gd")
const Quests = preload("res://scripts/mmorpg/quest_rules.gd")
const Flight = preload("res://scripts/mmorpg/flight_rules.gd")
const SAVE_VERSION := 1

static func new_game(owner: String) -> Dictionary:
	return {"version": SAVE_VERSION, "owner_id": owner,
		"actor": Stats.make_actor(owner), "inventory": Inventory.make_inventory(),
		"pets": Pets.new_stable(owner), "quests": Quests.new_log(),
		"flight": Flight.new_state(), "silver": 0, "defeated_encounters": {}}

## Idempotency relies on a unique encounter ID, not a reusable species string.
## Training monsters are forcibly zero-reward, even with a malicious loot table.
static func defeat(state: Dictionary, encounter_id: String, enemy: Dictionary,
		rng: RandomNumberGenerator = null) -> Dictionary:
	if encounter_id.is_empty() or state["defeated_encounters"].has(encounter_id):
		return {"ok": false, "reason": "duplicate_encounter"}
	var reward := Rewards.resolve(enemy, int(state["actor"]["level"]), rng)
	if not bool(reward.get("ok", false)):
		return reward
	var proposed_bag: Dictionary = state["inventory"].duplicate(true)
	for drop in reward["drops"]:
		if Inventory.add_item(proposed_bag, str(drop["id"]), int(drop["count"])) != 0:
			return {"ok": false, "reason": "inventory_full"}
	var proposed_actor: Dictionary = state["actor"].duplicate(true)
	var levels := Stats.grant_xp(proposed_actor, int(reward["xp"]))
	# All potentially failing validation occurs BEFORE this commit.
	state["inventory"] = proposed_bag
	state["actor"] = proposed_actor
	state["silver"] = int(state["silver"]) + int(reward["silver"])
	state["defeated_encounters"][encounter_id] = true
	if not bool(reward["training"]):
		Quests.register_regular_kill(state["quests"], str(enemy.get("species", "")))
	return {"ok": true, "xp": reward["xp"], "silver": reward["silver"],
		"drops": reward["drops"], "levels": levels, "training": reward["training"]}

## Capture a bounded, versioned offline snapshot. Production MMO persistence must
## store and validate this on an authenticated server instead of user:// alone.
static func serialize(state: Dictionary) -> String:
	return JSON.stringify(state)

static func parse_offline_snapshot(data: String, expected_owner: String) -> Dictionary:
	if data.length() > 1048576 or data.length() < 2:
		return {"ok": false, "reason": "invalid_size"}
	var parsed = JSON.parse_string(data)
	if not parsed is Dictionary:
		return {"ok": false, "reason": "invalid_json"}
	var obj: Dictionary = parsed
	if int(obj.get("version", -1)) != SAVE_VERSION or str(obj.get("owner_id", "")) != expected_owner:
		return {"ok": false, "reason": "schema_or_owner"}
	for key in ["actor", "inventory", "pets", "quests", "flight", "defeated_encounters"]:
		if not obj.get(key) is Dictionary:
			return {"ok": false, "reason": "missing_section_" + key}
	if str(obj["pets"].get("owner_id", "")) != expected_owner:
		return {"ok": false, "reason": "pet_owner_mismatch"}
	if not obj["pets"].get("cards", {}) is Dictionary:
		return {"ok": false, "reason": "invalid_pet_roster"}
	if obj["pets"]["cards"].size() > Pets.MAX_CARDS:
		return {"ok": false, "reason": "pet_roster_limit"}
	return {"ok": true, "state": obj}

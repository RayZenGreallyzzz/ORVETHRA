extends RefCounted
## ORVETHRA pet domain. This is gameplay foundation, NOT an in-game UI.
## Run mutations on the authoritative server once multiplayer is enabled.
const Inventory = preload("res://scripts/mmorpg/inventory_system.gd")
const MAX_CARDS := 200
const MAX_STAGE := 5
const MAX_LEVEL := 200

static func new_stable(owner_id: String) -> Dictionary:
	return {"owner_id": owner_id, "next_id": 1, "cards": {}, "active_id": "", "pending_tame": {}}

static func _item_count(bag: Dictionary, item_id: String) -> int:
	var total := 0
	for stack in bag.get("stacks", []):
		if str(stack.get("id", "")) == item_id:
			total += int(stack.get("count", 0))
	return total

static func _new_card(stable: Dictionary, species: String, rarity: String) -> String:
	var cards: Dictionary = stable["cards"]
	var new_id := str(stable["owner_id"]) + "_pet_" + str(stable["next_id"])
	stable["next_id"] = int(stable["next_id"]) + 1
	cards[new_id] = {
		"id": new_id, "owner_id": stable["owner_id"], "species": species,
		"rarity": rarity, "tamed": true, "stage": 0,
		"evo": 1, "level": 1, "xp": 0, "jp": 0,
		"spent_jp": 0, "skills": [], "appearance_stage": 0
	}
	return new_id

## Use only after validated taming or in test fixtures; do not expose to clients.
static func grant_tamed(stable: Dictionary, species: String, rarity: String = "basic") -> String:
	if species.is_empty() or stable["cards"].size() >= MAX_CARDS:
		return ""
	return _new_card(stable, species, rarity)

static func begin_tame(stable: Dictionary, bag: Dictionary, target_id: String, species: String, blank_card_item: String, skill_level: int, creature_kind: String) -> Dictionary:
	if creature_kind != "regular" and creature_kind != "boss":
		return {"ok": false, "reason": "training_creatures_cannot_be_tamed"}
	if not stable.get("pending_tame", {}).is_empty():
		return {"ok": false, "reason": "tame_already_pending"}
	if target_id.is_empty() or species.is_empty() or skill_level < 1 or blank_card_item.is_empty():
		return {"ok": false, "reason": "invalid_target_or_skill"}
	if stable["cards"].size() >= MAX_CARDS:
		return {"ok": false, "reason": "stable_full"}
	if _item_count(bag, blank_card_item) < 1:
		return {"ok": false, "reason": "missing_blank_card"}
	stable["pending_tame"] = {"target_id": target_id, "species": species, "blank_card": blank_card_item}
	return {"ok": true, "target_id": target_id}

## Call only after the marked REGULAR creature is defeated. Chance is server config,
## not a value submitted by the player. The blank card is consumed even on failure.
static func finish_tame(stable: Dictionary, bag: Dictionary, defeated_target: String, chance: float, rng: RandomNumberGenerator = null) -> Dictionary:
	var pending: Dictionary = stable.get("pending_tame", {})
	if pending.is_empty() or str(pending.get("target_id", "")) != defeated_target:
		return {"ok": false, "reason": "target_not_marked"}
	if not is_finite(chance) or chance < 0.0 or chance > 1.0:
		return {"ok": false, "reason": "invalid_server_probability"}
	var blank: String = str(pending["blank_card"])
	if _item_count(bag, blank) < 1:
		stable["pending_tame"] = {}
		return {"ok": false, "reason": "blank_card_missing"}
	if stable["cards"].size() >= MAX_CARDS:
		stable["pending_tame"] = {}
		return {"ok": false, "reason": "stable_full"}
	if not Inventory.remove_item(bag, blank, 1):
		return {"ok": false, "reason": "inventory_error"}
	stable["pending_tame"] = {}
	var random := rng
	if random == null:
		random = RandomNumberGenerator.new()
		random.randomize()
	var success := random.randf() < chance
	if not success:
		return {"ok": true, "success": false, "blank_card_spent": true}
	var card_id := _new_card(stable, str(pending["species"]), "basic")
	return {"ok": true, "success": true, "card_id": card_id, "blank_card_spent": true}

static func summon(stable: Dictionary, card_id: String) -> Dictionary:
	if not stable["cards"].has(card_id):
		return {"ok": false, "reason": "card_not_owned"}
	var card: Dictionary = stable["cards"][card_id]
	if not bool(card.get("tamed", false)):
		return {"ok": false, "reason": "card_not_tamed"}
	stable["active_id"] = card_id
	return {"ok": true, "card_id": card_id}

static func unsummon(stable: Dictionary) -> void:
	stable["active_id"] = ""

static func xp_to_next(level: int) -> int:
	return 80 + maxi(0, level - 1) * 35

## Two JP per level ONLY in overbreeding ranges before evolution.
static func grant_pet_xp(stable: Dictionary, card_id: String, amount: int) -> int:
	if amount <= 0 or not stable["cards"].has(card_id):
		return 0
	var card: Dictionary = stable["cards"][card_id]
	var evo: int = int(card["evo"])
	var cap := 60 if evo == 1 else (115 if evo == 2 else MAX_LEVEL)
	if int(card["level"]) >= cap:
		return 0
	card["xp"] = int(card["xp"]) + amount
	var levels := 0
	while int(card["level"]) < cap and int(card["xp"]) >= xp_to_next(int(card["level"])):
		card["xp"] = int(card["xp"]) - xp_to_next(int(card["level"]))
		card["level"] = int(card["level"]) + 1
		var level: int = int(card["level"])
		var bonus := 1 if (evo == 1 and level > 50 and level <= 60) or (evo == 2 and level > 100 and level <= 115) else 0
		card["jp"] = int(card["jp"]) + 1 + bonus
		levels += 1
	if int(card["level"]) >= cap:
		card["xp"] = 0
	return levels

static func evolve(stable: Dictionary, card_id: String) -> Dictionary:
	if not stable["cards"].has(card_id):
		return {"ok": false, "reason": "card_not_owned"}
	var card: Dictionary = stable["cards"][card_id]
	var evo: int = int(card["evo"])
	if evo >= 3:
		return {"ok": false, "reason": "max_evolution"}
	var threshold := 50 if evo == 1 else 100
	if int(card["level"]) < threshold:
		return {"ok": false, "reason": "level_too_low"}
	card["evo"] = evo + 1
	return {"ok": true, "evo": card["evo"], "level": card["level"]}

## Two tamed cards of the same species AND current stage plus catalyst.
## In a failure, main card is preserved; extra card and catalyst are consumed.
## On success stage +1, Lv1, Evo I and skills/JP reset; 8*stage bonus JP.
## This Lv1/Evo I reset is an explicit ORVETHRA rule, not a historical claim.
static func combine(stable: Dictionary, bag: Dictionary, main_id: String, material_id: String,
		catalyst_item: String, stage_chances: Array, rng: RandomNumberGenerator = null) -> Dictionary:
	var cards: Dictionary = stable["cards"]
	if main_id.is_empty() or main_id == material_id or not cards.has(main_id) or not cards.has(material_id):
		return {"ok": false, "reason": "invalid_pair"}
	if str(stable.get("active_id", "")) == main_id or str(stable.get("active_id", "")) == material_id:
		return {"ok": false, "reason": "unsummon_before_combining"}
	var main: Dictionary = cards[main_id]
	var material: Dictionary = cards[material_id]
	if not bool(main.get("tamed", false)) or not bool(material.get("tamed", false)):
		return {"ok": false, "reason": "both_must_be_tamed"}
	if main.get("owner_id") != stable["owner_id"] or material.get("owner_id") != stable["owner_id"]:
		return {"ok": false, "reason": "not_owner"}
	var stage: int = int(main["stage"])
	if stage >= MAX_STAGE or stage < 0:
		return {"ok": false, "reason": "max_stage"}
	if main["species"] != material["species"] or stage != int(material["stage"]):
		return {"ok": false, "reason": "species_or_stage_mismatch"}
	if stage_chances.size() != 6 or not is_finite(float(stage_chances[stage + 1])):
		return {"ok": false, "reason": "invalid_server_balance"}
	var chance := float(stage_chances[stage + 1])
	if chance < 0.0 or chance > 1.0 or catalyst_item.is_empty() or _item_count(bag, catalyst_item) < 1:
		return {"ok": false, "reason": "missing_catalyst_or_probability"}
	if not Inventory.remove_item(bag, catalyst_item, 1):
		return {"ok": false, "reason": "inventory_error"}
	cards.erase(material_id)
	var random := rng
	if random == null:
		random = RandomNumberGenerator.new()
		random.randomize()
	var success := random.randf() < chance
	if not success:
		return {"ok": true, "success": false, "main_preserved": true, "material_spent": true}
	var next_stage := stage + 1
	main["stage"] = next_stage
	main["level"] = 1
	main["xp"] = 0
	main["evo"] = 1
	main["jp"] = next_stage * 8
	main["spent_jp"] = 0
	main["skills"] = []
	main["appearance_stage"] = 3 if next_stage >= 3 else 0
	return {"ok": true, "success": true, "card_id": main_id, "stage": next_stage, "bonus_jp": next_stage * 8}

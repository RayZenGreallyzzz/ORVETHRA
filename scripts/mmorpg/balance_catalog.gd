extends RefCounted
## Authorial balancing defaults: Rappelz-inspired, not claimed historical values.
## The only supported training monster policy: NO loot, XP or silver.
const PET_STAGE_CHANCES := [0.0, 0.85, 0.65, 0.45, 0.30, 0.18]
const PET_RARITY_TAME_CHANCES := {"basic": 0.80, "uncommon": 0.25,
	"rare": 0.07, "very_rare": 0.02}
const CATALYST_ID := "soul_catalyst"

static func tutorial_slime(level: int = 1) -> Dictionary:
	return {"kind": "training", "species": "training_slime", "level": maxi(1, level),
		"xp_reward": 0, "silver_reward": 0, "loot_table": [], "tameable": false}

static func wild_wolf(level: int = 10) -> Dictionary:
	return {"kind": "regular", "species": "forest_wolf", "level": maxi(1, level),
		"xp_reward": 80, "silver_reward": 12, "tameable": true,
		"rarity": "basic", "blank_card_item": "blank_wolf",
		"xp_penalty_per_level": 0.0, "loot_penalty_per_level": 0.0,
		"loot_table": [
			{"id": "wolf_pelt", "chance": 0.35, "min": 1, "max": 2},
			{"id": "blank_wolf", "chance": 0.03, "min": 1, "max": 1}
		]}

static func tame_chance(rarity: String) -> float:
	return float(PET_RARITY_TAME_CHANCES.get(rarity, 0.0))

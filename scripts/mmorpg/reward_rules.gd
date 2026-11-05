extends RefCounted
## Reward policy shared by solo simulation and future authoritative zones.
## Training creatures NEVER grant XP, silver, cards or other loot.
const Loot = preload("res://scripts/mmorpg/loot_system.gd")

static func resolve(enemy: Dictionary, hero_level: int, rng: RandomNumberGenerator = null) -> Dictionary:
	var kind := str(enemy.get("kind", "training"))
	if kind == "training":
		return {"ok": true, "xp": 0, "silver": 0, "drops": [], "training": true}
	if kind != "regular" and kind != "boss":
		return {"ok": false, "reason": "unsupported_monster_kind"}
	var xp := maxi(0, int(enemy.get("xp_reward", 0)))
	var silver := maxi(0, int(enemy.get("silver_reward", 0)))
	var monster_level := maxi(1, int(enemy.get("level", 1)))
	var difference := maxi(0, hero_level - monster_level)
	# Each penalty is independent and server-configurable; no claimed Rappelz rates.
	var xp_penalty := clampf(float(enemy.get("xp_penalty_per_level", 0.0)), 0.0, 1.0)
	var loot_penalty := clampf(float(enemy.get("loot_penalty_per_level", 0.0)), 0.0, 1.0)
	xp = roundi(float(xp) * maxf(0.0, 1.0 - difference * xp_penalty))
	var chance_scale := maxf(0.0, 1.0 - difference * loot_penalty)
	var table: Array = []
	for entry in enemy.get("loot_table", []):
		if not entry is Dictionary:
			continue
		var adjusted: Dictionary = entry.duplicate(true)
		adjusted["chance"] = clampf(float(entry.get("chance", 0.0)) * chance_scale, 0.0, 1.0)
		table.append(adjusted)
	return {"ok": true, "xp": xp, "silver": silver, "drops": Loot.roll(table, rng), "training": false}

extends RefCounted
## Pure companion damage resolver. No 3D model, animation or automatic AI tick.
## Future trusted server must validate skill cooldown, line of sight and range.
const Stats = preload("res://scripts/mmorpg/core_stats.gd")
const Combat = preload("res://scripts/mmorpg/combat_math.gd")
const MAX_ASSIST_DISTANCE := 5.0

static func make_pet_actor(card: Dictionary) -> Dictionary:
	if card.is_empty() or not bool(card.get("tamed", false)):
		return {}
	var level := clampi(int(card.get("level", 1)), 1, 200)
	var stage := clampi(int(card.get("stage", 0)), 0, 5)
	var evo := clampi(int(card.get("evo", 1)), 1, 3)
	# Original ORVETHRA balance defaults, NOT reverse-engineered Rappelz.
	var primary := {"str": 8 + stage * 4 + evo * 3, "vit": 8 + stage * 3 + evo * 2,
		"dex": 9 + stage, "agi": 9 + stage, "int": 7 + stage * 2,
		"wis": 7 + stage * 2, "luk": 7 + stage}
	return Stats.make_actor("companion_" + str(card.get("id", "")), level, primary)

static func assist(stable: Dictionary, target: Dictionary, distance: float,
		rng: RandomNumberGenerator = null) -> Dictionary:
	var active_id := str(stable.get("active_id", ""))
	if active_id.is_empty() or not stable.get("cards", {}).has(active_id):
		return {"ok": false, "reason": "no_summoned_pet"}
	if not is_finite(distance) or distance < 0.0 or distance > MAX_ASSIST_DISTANCE:
		return {"ok": false, "reason": "out_of_range"}
	var card: Dictionary = stable["cards"][active_id]
	var pet := make_pet_actor(card)
	if pet.is_empty():
		return {"ok": false, "reason": "invalid_pet"}
	var result: Dictionary = Combat.resolve(pet, target, {"power": 0.70}, rng)
	if not bool(result.get("ok", false)):
		return result
	var dealt := Combat.apply_damage(target, int(result.get("damage", 0)))
	return {"ok": true, "card_id": active_id, "damage": dealt,
		"hit": result.get("hit", false), "critical": result.get("critical", false)}

extends RefCounted
## Pure, deterministic RPG stats. No character models or AI required.
# Seven core attributes, including LUK, as required by the design report.
const PRIMARY := ["str", "vit", "dex", "agi", "int", "wis", "luk"]
const DEFAULTS := {"str": 10, "vit": 10, "dex": 10, "agi": 10, "int": 10, "wis": 10, "luk": 10}
const MAX_LEVEL := 200

static func experience_to_next(level: int) -> int:
	var n: int = clampi(level, 1, MAX_LEVEL)
	return 100 + 45 * (n - 1) + 12 * (n - 1) * (n - 1)

static func make_actor(id: String, level: int = 1, primary: Dictionary = {}) -> Dictionary:
	var safe_level := clampi(level, 1, MAX_LEVEL)
	var attributes := DEFAULTS.duplicate(true)
	for key in PRIMARY:
		if primary.has(key):
			attributes[key] = clampi(int(primary[key]), 1, 9999)
	var result := {
		"id": id, "level": safe_level, "xp": 0,
		"attributes": attributes, "equipment_bonuses": {},
		"modifiers": [], "gold": 0
	}
	recalculate(result, true)
	return result

static func recalculate(actor: Dictionary, refill: bool = false) -> void:
	var a: Dictionary = actor.get("attributes", DEFAULTS)
	var b: Dictionary = actor.get("equipment_bonuses", {})
	var lv: int = clampi(int(actor.get("level", 1)), 1, MAX_LEVEL)
	var s := _attr(a, b, "str")
	var v := _attr(a, b, "vit")
	var d := _attr(a, b, "dex")
	var ag := _attr(a, b, "agi")
	var iq := _attr(a, b, "int")
	var w := _attr(a, b, "wis")
	var luk := _attr(a, b, "luk")
	var derived := {
		"max_hp": 100 + lv * 15 + v * 12,
		"max_mp": 50 + lv * 8 + iq * 5 + w * 6,
		"physical_attack": 5 + lv * 2 + s * 3,
		"magic_attack": 5 + lv * 2 + iq * 3,
		"physical_defense": lv + v * 2,
		"magic_defense": lv + w * 2,
		"accuracy": 70 + d * 2,
		"evasion": ag * 2,
		# LUK influences crit; DEX remains tied to accuracy.
		"luck": luk,
		"critical_chance": clampf(0.03 + float(luk) * 0.001, 0.0, 0.5),
		"critical_multiplier": 1.5,
		"attack_speed": clampf(1.0 + float(ag) * 0.005, 0.5, 3.0)
	}
	for key in derived.keys():
		if b.has(key):
			derived[key] = float(derived[key]) + float(b[key])
	for modifier in actor.get("modifiers", []):
		if not modifier is Dictionary:
			continue
		var stat: String = str(modifier.get("stat", ""))
		if derived.has(stat):
			derived[stat] = float(derived[stat]) + float(modifier.get("flat", 0.0))
			derived[stat] = float(derived[stat]) * (1.0 + clampf(float(modifier.get("percent", 0.0)), -0.95, 10.0))
	derived["max_hp"] = maxi(1, int(derived["max_hp"]))
	derived["max_mp"] = maxi(0, int(derived["max_mp"]))
	derived["critical_chance"] = clampf(float(derived["critical_chance"]), 0.0, 1.0)
	derived["attack_speed"] = clampf(float(derived["attack_speed"]), 0.1, 5.0)
	actor["stats"] = derived
	if refill or not actor.has("hp"):
		actor["hp"] = derived["max_hp"]
	else:
		actor["hp"] = clampi(int(actor["hp"]), 0, int(derived["max_hp"]))
	if refill or not actor.has("mp"):
		actor["mp"] = derived["max_mp"]
	else:
		actor["mp"] = clampi(int(actor["mp"]), 0, int(derived["max_mp"]))

static func _attr(a: Dictionary, b: Dictionary, key: String) -> int:
	return maxi(1, int(a.get(key, 10)) + int(b.get(key, 0)))

static func grant_xp(actor: Dictionary, amount: int) -> int:
	if amount <= 0:
		return 0
	var levels := 0
	actor["xp"] = maxi(0, int(actor.get("xp", 0))) + amount
	while int(actor["level"]) < MAX_LEVEL and int(actor["xp"]) >= experience_to_next(int(actor["level"])):
		actor["xp"] = int(actor["xp"]) - experience_to_next(int(actor["level"]))
		actor["level"] = int(actor["level"]) + 1
		levels += 1
	if int(actor["level"]) == MAX_LEVEL:
		actor["xp"] = 0
	if levels > 0:
		recalculate(actor, true)
	return levels

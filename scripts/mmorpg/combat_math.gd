extends RefCounted
## Original balance formulas. Do not treat them as extracted Rappelz M internals.
## Supply a seeded RandomNumberGenerator for repeatable combat tests.
static func resolve(attacker: Dictionary, defender: Dictionary, skill: Dictionary = {}, rng: RandomNumberGenerator = null) -> Dictionary:
	var random := rng
	if random == null:
		random = RandomNumberGenerator.new()
		random.randomize()
	var source: Dictionary = attacker.get("stats", {})
	var target: Dictionary = defender.get("stats", {})
	if int(attacker.get("hp", 0)) <= 0 or int(defender.get("hp", 0)) <= 0:
		return {"ok": false, "reason": "actor_dead", "damage": 0}
	var magic: bool = str(skill.get("damage_type", "physical")) == "magic"
	var hit_chance := clampf(0.85 + (float(source.get("accuracy", 70)) - float(target.get("evasion", 0))) * 0.002, 0.05, 0.99)
	if random.randf() > hit_chance:
		return {"ok": true, "hit": false, "critical": false, "damage": 0}
	var attack_key := "magic_attack" if magic else "physical_attack"
	var defense_key := "magic_defense" if magic else "physical_defense"
	var attack := maxf(0.0, float(source.get(attack_key, 0)))
	var defense := maxf(0.0, float(target.get(defense_key, 0)))
	var power := maxf(0.0, float(skill.get("power", 1.0)))
	var flat := maxf(0.0, float(skill.get("flat_damage", 0)))
	var mitigation := 100.0 / (100.0 + defense)
	var critical := random.randf() < clampf(float(source.get("critical_chance", 0.0)), 0.0, 1.0)
	var crit_factor := maxf(1.0, float(source.get("critical_multiplier", 1.5))) if critical else 1.0
	var damage := maxi(1, roundi((attack * power + flat) * mitigation * crit_factor))
	return {"ok": true, "hit": true, "critical": critical, "damage": damage}

static func apply_damage(target: Dictionary, damage: int) -> int:
	var current := maxi(0, int(target.get("hp", 0)))
	var actual := mini(current, maxi(0, damage))
	target["hp"] = current - actual
	return actual

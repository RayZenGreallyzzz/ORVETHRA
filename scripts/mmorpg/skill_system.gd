extends RefCounted
## Skills are plain data: replace IDs, visuals and animations later.
static func can_cast(actor: Dictionary, skill: Dictionary, cooldowns: Dictionary, now_ms: int) -> String:
	if int(actor.get("hp", 0)) <= 0:
		return "actor_dead"
	if str(skill.get("id", "")).is_empty():
		return "invalid_skill"
	if int(actor.get("level", 1)) < int(skill.get("required_level", 1)):
		return "level_locked"
	if int(actor.get("mp", 0)) < maxi(0, int(skill.get("mp_cost", 0))):
		return "not_enough_mp"
	if now_ms < int(cooldowns.get(str(skill["id"]), 0)):
		return "cooldown"
	return ""

static func cast(actor: Dictionary, skill: Dictionary, cooldowns: Dictionary, now_ms: int) -> Dictionary:
	var reason := can_cast(actor, skill, cooldowns, now_ms)
	if not reason.is_empty():
		return {"ok": false, "reason": reason}
	actor["mp"] = int(actor["mp"]) - maxi(0, int(skill.get("mp_cost", 0)))
	cooldowns[str(skill["id"])] = now_ms + maxi(0, int(skill.get("cooldown_ms", 0)))
	return {"ok": true, "skill_id": str(skill["id"]), "mp": actor["mp"]}

static func tick_modifiers(actor: Dictionary, delta_seconds: float) -> void:
	var next: Array = []
	for modifier in actor.get("modifiers", []):
		if not modifier is Dictionary:
			continue
		var remaining := float(modifier.get("remaining", 0.0)) - maxf(0.0, delta_seconds)
		if remaining > 0.0:
			var updated: Dictionary = modifier.duplicate(true)
			updated["remaining"] = remaining
			next.append(updated)
	actor["modifiers"] = next

extends SceneTree
const Zone = preload("res://server/training_zone.gd")

func _initialize() -> void:
	var zone := Zone.new()
	var first: Dictionary = zone.join(42, 10000)
	assert(first.get("ok", false))
	assert(first["monsters"].size() == 3)
	var fake := {"seq": 1, "type": "cast_skill", "payload": {"skill_id": "basic_attack", "target_entity_id": "training_0", "damage": 999999, "xp": 999999, "silver": 999999}}
	var result: Dictionary = zone.command(42, fake, 10000)
	assert(result.get("ok", false))
	assert(int(result["damage"]) < 999999)
	assert(not result.has("xp_gained") or int(result["xp_gained"]) < 999999)
	assert(zone.command(42, fake, 10001).get("reason") == "replayed_sequence")
	var cooldown := zone.command(42, {"seq": 2, "type": "cast_skill", "payload": {"skill_id": "basic_attack", "target_entity_id": "training_0"}}, 10010)
	assert(cooldown.get("reason") == "cooldown")
	var impossible := zone.command(42, {"seq": 3, "type": "move_intent", "payload": {"x": 800, "y": 800}}, 10020)
	assert(impossible.get("reason") == "speed_limit")
	var far := zone.command(42, {"seq": 4, "type": "cast_skill", "payload": {"skill_id": "basic_attack", "target_entity_id": "training_1"}}, 12000)
	assert(far.get("reason") == "out_of_range")
	var hero: Dictionary = zone.players[42]
	hero["position"] = Vector2(15, 19)
	var kills := 0
	for i in range(30):
		var attack := zone.command(42, {"seq": 5 + i, "type": "cast_skill", "payload": {"skill_id": "basic_attack", "target_entity_id": "training_0"}}, 14000 + i * 1100)
		if attack.get("killed", false):
			kills += 1
			break
	assert(kills == 1)
	var silver := int(hero["silver"])
	var dead := zone.command(42, {"seq": 40, "type": "cast_skill", "payload": {"skill_id": "basic_attack", "target_entity_id": "training_0"}}, 50000)
	assert(dead.get("reason") == "target_dead")
	assert(int(hero["silver"]) == silver)
	var revived := zone.tick(100000)
	assert(revived.size() == 1)
	assert(int(zone.monsters["training_0"]["hp"]) > 0)
	print("SERVER_TRAINING_SMOKE_OK")
	quit(0)

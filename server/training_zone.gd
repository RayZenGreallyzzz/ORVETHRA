extends RefCounted
## Authoritative training zone. No client-controlled damage, HP, XP or loot.
const Stats = preload("res://scripts/mmorpg/core_stats.gd")
const Combat = preload("res://scripts/mmorpg/combat_math.gd")
const Loot = preload("res://scripts/mmorpg/loot_system.gd")
const MONSTER_POSITIONS := [Vector2(15, 19), Vector2(24, 25), Vector2(29, 14)]
const MAX_ATTACK_RANGE := 5.5
const ATTACK_COOLDOWN_MS := 1000
const RESPAWN_MS := 9000
const MAX_MOVE_SPEED := 7.0
var players: Dictionary = {}
var monsters: Dictionary = {}
var rng := RandomNumberGenerator.new()
var last_tick_ms: int = 0

func _init() -> void:
	rng.randomize()
	for i in range(3):
		var id := "training_%d" % i
		var rank := 1 if i < 2 else 2
		var mob: Dictionary = Stats.make_actor(id, rank, {"vit": 3 + rank, "str": 3 + rank})
		mob["position"] = MONSTER_POSITIONS[i]
		mob["respawn_at"] = 0
		# Tutorial targets are strictly non-rewarding by game-design decision.
		mob["kind"] = "training"
		mob["xp_reward"] = 0
		mob["silver_reward"] = 0
		mob["loot_table"] = []
		monsters[id] = mob

func join(peer_id: int, now_ms: int) -> Dictionary:
	var hero: Dictionary = Stats.make_actor("player_%d" % peer_id)
	hero["position"] = Vector2(13, 19)
	hero["silver"] = 0
	hero["items"] = {}
	hero["last_attack_ms"] = now_ms - ATTACK_COOLDOWN_MS
	hero["last_move_ms"] = now_ms
	hero["last_seq"] = 0
	players[peer_id] = hero
	return snapshot(peer_id)

func leave(peer_id: int) -> void:
	players.erase(peer_id)

func snapshot(peer_id: int) -> Dictionary:
	if not players.has(peer_id):
		return {"ok": false, "reason": "not_joined"}
	var hero: Dictionary = players[peer_id]
	var mobs: Array = []
	for id in monsters.keys():
		var mob: Dictionary = monsters[id]
		mobs.append({"id": id, "level": mob["level"], "hp": mob["hp"], "max_hp": mob["stats"]["max_hp"], "x": mob["position"].x, "y": mob["position"].y})
	return {"ok": true, "type": "snapshot", "player": {"level": hero["level"], "xp": hero["xp"], "hp": hero["hp"], "mp": hero["mp"], "silver": hero["silver"], "items": hero["items"], "x": hero["position"].x, "y": hero["position"].y}, "monsters": mobs}

func command(peer_id: int, packet: Dictionary, now_ms: int) -> Dictionary:
	if not players.has(peer_id):
		return {"ok": false, "reason": "not_joined"}
	var hero: Dictionary = players[peer_id]
	var seq := int(packet.get("seq", 0))
	if seq <= int(hero["last_seq"]) or seq < 1:
		return {"ok": false, "reason": "replayed_sequence"}
	if seq > int(hero["last_seq"]) + 10000:
		return {"ok": false, "reason": "sequence_gap"}
	var kind := str(packet.get("type", ""))
	if kind != "move_intent" and kind != "cast_skill":
		return {"ok": false, "reason": "unsupported_command"}
	var payload = packet.get("payload", {})
	if not payload is Dictionary:
		return {"ok": false, "reason": "invalid_payload"}
	hero["last_seq"] = seq
	if kind == "move_intent":
		return _move(hero, payload, now_ms)
	return _attack(hero, payload, now_ms)

func _move(hero: Dictionary, payload: Dictionary, now_ms: int) -> Dictionary:
	if not payload.has("x") or not payload.has("y"):
		return {"ok": false, "reason": "invalid_position"}
	var x := float(payload["x"])
	var y := float(payload["y"])
	if not is_finite(x) or not is_finite(y) or absf(x) > 1000.0 or absf(y) > 1000.0:
		return {"ok": false, "reason": "invalid_position"}
	var previous: Vector2 = hero["position"]
	var next := Vector2(x, y)
	var elapsed := clampf(float(now_ms - int(hero["last_move_ms"])) / 1000.0, 0.0, 0.25)
	if previous.distance_to(next) > MAX_MOVE_SPEED * elapsed + 0.2:
		return {"ok": false, "reason": "speed_limit"}
	hero["position"] = next
	hero["last_move_ms"] = now_ms
	return {"ok": true, "type": "moved", "x": x, "y": y}

func _attack(hero: Dictionary, payload: Dictionary, now_ms: int) -> Dictionary:
	if str(payload.get("skill_id", "")) != "basic_attack":
		return {"ok": false, "reason": "unknown_skill"}
	var target_id := str(payload.get("target_entity_id", ""))
	if not monsters.has(target_id):
		return {"ok": false, "reason": "invalid_target"}
	var mob: Dictionary = monsters[target_id]
	if int(mob["hp"]) <= 0:
		return {"ok": false, "reason": "target_dead"}
	if int(hero["hp"]) <= 0:
		return {"ok": false, "reason": "player_dead"}
	if (hero["position"] as Vector2).distance_to(mob["position"]) > MAX_ATTACK_RANGE:
		return {"ok": false, "reason": "out_of_range"}
	if now_ms - int(hero["last_attack_ms"]) < ATTACK_COOLDOWN_MS:
		return {"ok": false, "reason": "cooldown"}
	hero["last_attack_ms"] = now_ms
	var outcome: Dictionary = Combat.resolve(hero, mob, {}, rng)
	var actual := Combat.apply_damage(mob, int(outcome.get("damage", 0)))
	var result := {"ok": true, "type": "combat_event", "target_entity_id": target_id, "damage": actual, "hit": outcome.get("hit", false), "critical": outcome.get("critical", false), "target_hp": mob["hp"], "killed": false}
	if int(mob["hp"]) == 0:
		mob["respawn_at"] = now_ms + RESPAWN_MS
		result["killed"] = true
		# Do not grant rewards based on a tamperable table for tutorial enemies.
		var tutorial := str(mob.get("kind", "training")) == "training"
		result["xp_gained"] = 0 if tutorial else int(mob["xp_reward"])
		result["silver_gained"] = 0 if tutorial else int(mob["silver_reward"])
		if not tutorial:
			Stats.grant_xp(hero, int(mob["xp_reward"]))
			hero["silver"] = int(hero["silver"]) + int(mob["silver_reward"])
		var drops := [] if tutorial else Loot.roll(mob["loot_table"], rng)
		for drop in drops:
			var item_id := str(drop["id"])
			hero["items"][item_id] = int(hero["items"].get(item_id, 0)) + int(drop["count"])
		result["drops"] = drops
		result["player"] = {"level": hero["level"], "xp": hero["xp"], "silver": hero["silver"]}
	return result

func tick(now_ms: int) -> Array:
	var respawned: Array = []
	for id in monsters.keys():
		var mob: Dictionary = monsters[id]
		if int(mob["hp"]) == 0 and now_ms >= int(mob["respawn_at"]):
			mob["hp"] = int(mob["stats"]["max_hp"])
			mob["respawn_at"] = 0
			respawned.append({"id": id, "hp": mob["hp"]})
	last_tick_ms = now_ms
	return respawned

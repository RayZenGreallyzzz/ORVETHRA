extends SceneTree
const Pets = preload("res://scripts/mmorpg/pet_system.gd")
const Inventory = preload("res://scripts/mmorpg/inventory_system.gd")
const Game = preload("res://scripts/mmorpg/gameplay_state.gd")
const Quests = preload("res://scripts/mmorpg/quest_rules.gd")
const Flight = preload("res://scripts/mmorpg/flight_rules.gd")
const Equipment = preload("res://scripts/mmorpg/equipment_rules.gd")
const Classes = preload("res://scripts/mmorpg/class_rules.gd")
const Balance = preload("res://scripts/mmorpg/balance_catalog.gd")
const Economy = preload("res://scripts/mmorpg/economy_rules.gd")
const Stats = preload("res://scripts/mmorpg/core_stats.gd")

func _initialize() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 20261105
	var state := Game.new_game("hero_demo")
	var bag: Dictionary = state["inventory"]
	var stable: Dictionary = state["pets"]
	var quests: Dictionary = state["quests"]
	assert(Quests.accept(quests, "hunt_wolf", "forest_wolf", 1, {"item_id": "potion", "amount": 1, "gold": 2}))
	var training := {"kind": "training", "species": "forest_wolf", "level": 1, "xp_reward": 9999,
		"silver_reward": 9999, "loot_table": [{"id": "legendary", "chance": 1.0}]}
	var tutorial_result: Dictionary = Game.defeat(state, "tutorial_1", training, rng)
	assert(tutorial_result["ok"] and tutorial_result["xp"] == 0)
	assert(tutorial_result["silver"] == 0 and tutorial_result["drops"].is_empty())
	assert(state["actor"]["level"] == 1 and state["silver"] == 0)
	assert(quests["entries"]["hunt_wolf"]["count"] == 0)
	assert(not Game.defeat(state, "tutorial_1", training, rng)["ok"])
	var creature := {"kind": "regular", "species": "forest_wolf", "level": 2,
		"xp_reward": 180, "silver_reward": 7,
		"loot_table": [{"id": "blank_wolf", "chance": 1.0, "min": 1, "max": 1}]}
	var rewarded: Dictionary = Game.defeat(state, "regular_wolf_1", creature, rng)
	assert(rewarded["ok"] and rewarded["xp"] == 180 and rewarded["silver"] == 7)
	assert(quests["entries"]["hunt_wolf"]["count"] == 1)
	assert(not Game.defeat(state, "regular_wolf_1", creature, rng)["ok"])
	assert(Quests.claim(quests, "hunt_wolf", state["inventory"], state["actor"])["ok"])
	assert(not Quests.claim(quests, "hunt_wolf", state["inventory"], state["actor"])["ok"])
	assert(state["actor"]["gold"] == 2)
	assert(not Game.start_tame(state, "practice_slime", Balance.tutorial_slime(), 1)["ok"])
	assert(Pets.begin_tame(stable, state["inventory"], "wild_wolf_9", "forest_wolf", "blank_wolf", 1, "regular")["ok"])
	assert(not Pets.finish_tame(stable, state["inventory"], "another_target", 1.0, rng)["ok"])
	var capture: Dictionary = Pets.finish_tame(stable, state["inventory"], "wild_wolf_9", 1.0, rng)
	assert(capture["ok"] and capture["success"])
	var first: String = capture["card_id"]
	assert(Pets.summon(stable, first)["ok"])
	Pets.unsummon(stable)
	var card: Dictionary = stable["cards"][first]
	card["level"] = 50
	var previous_jp: int = card["jp"]
	assert(Pets.grant_pet_xp(stable, first, Pets.xp_to_next(50)) == 1)
	assert(card["level"] == 51 and card["jp"] == previous_jp + 2)
	assert(Pets.evolve(stable, first)["ok"] and card["evo"] == 2)
	var second := Pets.grant_tamed(stable, "forest_wolf")
	assert(second != "")
	assert(Inventory.add_item(state["inventory"], "soul_catalyst", 2) == 0)
	assert(Pets.combine(stable, state["inventory"], first, first, "soul_catalyst",
		[0,1,1,1,1,1], rng)["reason"] == "invalid_pair")
	var pair: Dictionary = Pets.combine(stable, state["inventory"], first, second, "soul_catalyst",
		[0,1,1,1,1,1], rng)
	assert(pair["ok"] and pair["success"] and card["stage"] == 1)
	assert(card["level"] == 1 and card["evo"] == 1 and card["jp"] == 8)
	assert(not stable["cards"].has(second))
	var third := Pets.grant_tamed(stable, "forest_wolf")
	stable["cards"][third]["stage"] = 1
	var before_card: Dictionary = card.duplicate(true)
	var failed: Dictionary = Pets.combine(stable, state["inventory"], first, third, "soul_catalyst",
		[0,0,0,0,0,0], rng)
	assert(failed["ok"] and not failed["success"])
	assert(card == before_card and not stable["cards"].has(third))
	assert(Classes.new_job("invalid_class").is_empty())
	var job: Dictionary = state["job"]
	assert(Classes.grant_job_xp(job, Classes.job_xp_to_next(1)) == 1)
	assert(int(job["jp"]) == 1 and Classes.learn(job, "warrior_strike", 1, 1))
	assert(not Classes.learn(job, "warrior_strike", 1, 1))
	assert(Balance.tutorial_slime()["loot_table"].is_empty())
	assert(state["actor"]["stats"].has("luck"))
	state["actor"]["attributes"]["luk"] = 40
	Stats.recalculate(state["actor"])
	assert(int(state["actor"]["stats"]["luck"]) == 40)
	assert(not Game.finish_tame(state, "never_defeated", Balance.wild_wolf(), rng)["ok"])
	assert(Inventory.add_item(state["inventory"], "blank_wolf", 1) == 0)
	var live_wolf := Balance.wild_wolf(10)
	assert(Game.start_tame(state, "wild_wolf_99", live_wolf, 1)["ok"])
	assert(not Game.finish_tame(state, "wild_wolf_99", live_wolf, rng)["ok"])
	assert(Game.defeat(state, "wild_wolf_99", live_wolf, rng)["ok"])
	assert(Game.finish_tame(state, "wild_wolf_99", live_wolf, rng)["ok"])
	assert(Game.finish_tame(state, "wild_wolf_99", live_wolf, rng)["reason"] == "target_not_marked")
	var before_silver: int = int(state["silver"])
	assert(Economy.buy(state, {"item_id": "health_potion", "silver_price": 3}, 1)["ok"])
	assert(int(state["silver"]) == before_silver - 3)
	assert(not Economy.buy(state, {"item_id": "very_expensive", "silver_price": 999999}, 1)["ok"])
	assert(Economy.sell(state, {"item_id": "health_potion", "silver_sell_price": 2}, 1)["ok"])
	assert(state["inventory"]["stacks"].size() >= 0)
	assert(Inventory.add_item(state["inventory"], "wood_sword", 1) == 0)
	var equipment := Equipment.new_equipment()
	assert(Equipment.equip(equipment, state["inventory"], state["actor"], "weapon",
		"wood_sword", {"str": 2})["ok"])
	assert(equipment["slots"].has("weapon"))
	assert(not Equipment.equip(equipment, state["inventory"], state["actor"], "weapon",
		"missing_sword", {"str": 4})["ok"])
	var wing: Dictionary = state["flight"]
	assert(not Flight.takeoff(wing, false, 0.0, true)["ok"])
	assert(Flight.takeoff(wing, true, 3.0, true)["ok"])
	Flight.tick(wing, 0.1, false)
	assert(float(wing["energy"]) < Flight.CAPACITY)
	Flight.land(wing)
	var encoded: String = Game.serialize(state)
	assert(Game.parse_offline_snapshot(encoded, "hero_demo")["ok"])
	assert(not Game.parse_offline_snapshot(encoded, "another_owner")["ok"])
	print("MMORPG_FOUNDATION_OK pets=1 rewards=1 no_tutorial_loot=1 stage=1 overbreed=1 quest=1 equip=1 flight=1 save=1")
	quit(0)

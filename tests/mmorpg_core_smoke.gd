extends SceneTree
const Stats = preload("res://scripts/mmorpg/core_stats.gd")
const Combat = preload("res://scripts/mmorpg/combat_math.gd")
const Skills = preload("res://scripts/mmorpg/skill_system.gd")
const Inventory = preload("res://scripts/mmorpg/inventory_system.gd")
const Loot = preload("res://scripts/mmorpg/loot_system.gd")

func _initialize() -> void:
	var hero: Dictionary = Stats.make_actor("hero", 1, {"str": 15, "vit": 12})
	var enemy: Dictionary = Stats.make_actor("enemy", 1)
	assert(int(hero["stats"]["max_hp"]) > 0)
	assert(Stats.grant_xp(hero, Stats.experience_to_next(1)) == 1)
	assert(int(hero["level"]) == 2)
	var rng := RandomNumberGenerator.new()
	rng.seed = 12345
	var result: Dictionary = Combat.resolve(hero, enemy, {"power": 1.2}, rng)
	assert(result.get("ok", false))
	assert(int(result.get("damage", 0)) >= 0)
	var cooldowns := {}
	var skill := {"id": "strike", "mp_cost": 5, "cooldown_ms": 1500}
	assert(Skills.cast(hero, skill, cooldowns, 1000).get("ok", false))
	assert(Skills.can_cast(hero, skill, cooldowns, 1200) == "cooldown")
	assert(Skills.can_cast(hero, skill, cooldowns, 2500) == "")
	var baseline_attack := float(hero["stats"]["physical_attack"])
	hero["modifiers"] = [{"stat": "physical_attack", "flat": 20.0, "remaining": 1.0}]
	Stats.recalculate(hero)
	assert(float(hero["stats"]["physical_attack"]) > baseline_attack)
	Skills.tick_modifiers(hero, 1.1)
	assert(hero["modifiers"].is_empty())
	assert(is_equal_approx(float(hero["stats"]["physical_attack"]), baseline_attack))
	var bag: Dictionary = Inventory.make_inventory(2)
	assert(Inventory.add_item(bag, "potion", 120, 99) == 0)
	assert(not Inventory.remove_item(bag, "potion", 121))
	assert(Inventory.remove_item(bag, "potion", 20))
	var drops := Loot.roll([{"id": "coin", "chance": 1.0, "min": 1, "max": 2}], rng)
	assert(drops.size() == 1)
	print("MMORPG_CORE_SMOKE_OK")
	quit(0)

extends RefCounted
## Independent loot table rolls; chance is in [0, 1].
static func roll(table: Array, rng: RandomNumberGenerator = null) -> Array[Dictionary]:
	var random := rng
	if random == null:
		random = RandomNumberGenerator.new()
		random.randomize()
	var drops: Array[Dictionary] = []
	for entry in table:
		if not entry is Dictionary:
			continue
		var item_id := str(entry.get("id", ""))
		if item_id.is_empty():
			continue
		if random.randf() > clampf(float(entry.get("chance", 0.0)), 0.0, 1.0):
			continue
		var minimum := maxi(1, int(entry.get("min", 1)))
		var maximum := maxi(minimum, int(entry.get("max", minimum)))
		drops.append({"id": item_id, "count": random.randi_range(minimum, maximum)})
	return drops

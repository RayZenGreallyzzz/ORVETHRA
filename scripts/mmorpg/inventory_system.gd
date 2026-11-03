extends RefCounted
## Data-only inventory. Server ownership/transactions will be added later.
static func make_inventory(slots: int = 40) -> Dictionary:
	return {"capacity": clampi(slots, 1, 500), "stacks": []}

static func add_item(inventory: Dictionary, item_id: String, count: int, max_stack: int = 99) -> int:
	if item_id.is_empty() or count <= 0:
		return maxi(0, count)
	var left := count
	var limit := clampi(max_stack, 1, 9999)
	var stacks: Array = inventory.get("stacks", [])
	for stack in stacks:
		if str(stack.get("id", "")) != item_id or int(stack.get("count", 0)) >= limit:
			continue
		var amount := mini(left, limit - int(stack["count"]))
		stack["count"] = int(stack["count"]) + amount
		left -= amount
		if left == 0:
			break
	while left > 0 and stacks.size() < int(inventory.get("capacity", 40)):
		var amount := mini(left, limit)
		stacks.append({"id": item_id, "count": amount})
		left -= amount
	inventory["stacks"] = stacks
	return left

static func remove_item(inventory: Dictionary, item_id: String, count: int) -> bool:
	if count <= 0 or item_id.is_empty():
		return false
	var stacks: Array = inventory.get("stacks", [])
	var available := 0
	for stack in stacks:
		if str(stack.get("id", "")) == item_id:
			available += int(stack.get("count", 0))
	if available < count:
		return false
	var left := count
	for i in range(stacks.size() - 1, -1, -1):
		if str(stacks[i].get("id", "")) != item_id:
			continue
		var amount := mini(left, int(stacks[i]["count"]))
		stacks[i]["count"] = int(stacks[i]["count"]) - amount
		left -= amount
		if int(stacks[i]["count"]) == 0:
			stacks.remove_at(i)
		if left == 0:
			break
	inventory["stacks"] = stacks
	return true

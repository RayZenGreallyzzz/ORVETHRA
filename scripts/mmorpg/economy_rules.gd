extends RefCounted
## Server-catalog priced inventory transactions. Never trust price from an APK.
const Inventory = preload("res://scripts/mmorpg/inventory_system.gd")

static func buy(state: Dictionary, offer: Dictionary, count: int) -> Dictionary:
	var item := str(offer.get("item_id", ""))
	var price := int(offer.get("silver_price", -1))
	if item.is_empty() or price < 0 or price > 100000000 or count < 1 or count > 99:
		return {"ok": false, "reason": "invalid_catalog_offer"}
	var total := price * count
	if int(state.get("silver", 0)) < total:
		return {"ok": false, "reason": "insufficient_silver"}
	var proposed: Dictionary = state["inventory"].duplicate(true)
	if Inventory.add_item(proposed, item, count) != 0:
		return {"ok": false, "reason": "inventory_full"}
	# Commit together: failed inventory operation never spends silver.
	state["silver"] = int(state["silver"]) - total
	state["inventory"] = proposed
	return {"ok": true, "spent": total, "item_id": item, "count": count}

static func sell(state: Dictionary, offer: Dictionary, count: int) -> Dictionary:
	var item := str(offer.get("item_id", ""))
	var price := int(offer.get("silver_sell_price", -1))
	if item.is_empty() or price < 0 or price > 100000000 or count < 1 or count > 99:
		return {"ok": false, "reason": "invalid_catalog_offer"}
	var proposed: Dictionary = state["inventory"].duplicate(true)
	if not Inventory.remove_item(proposed, item, count):
		return {"ok": false, "reason": "not_owned"}
	var total := price * count
	if total > 2147483647 - maxi(0, int(state.get("silver", 0))):
		return {"ok": false, "reason": "wallet_limit"}
	state["silver"] = int(state["silver"]) + total
	state["inventory"] = proposed
	return {"ok": true, "received": total}

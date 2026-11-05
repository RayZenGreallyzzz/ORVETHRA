extends RefCounted
## Pure, device-agnostic glide input rules mirroring the existing city prototype.
## The Android input button and motion animation remain in city_preview.gd.
const MIN_RUN_SPEED := 2.6
const LAUNCH_VELOCITY := 8.2
const FORWARD_SPEED := 8.8
const SINK_SPEED := 0.85
const CAPACITY := 14.0
const RECHARGE_PER_SECOND := 5.0

static func new_state() -> Dictionary:
	return {"gliding": false, "energy": CAPACITY, "vertical_speed": 0.0}

static func takeoff(state: Dictionary, running: bool, ground_speed: float, on_ground: bool) -> Dictionary:
	if bool(state["gliding"]) or not running or not on_ground or ground_speed < MIN_RUN_SPEED:
		return {"ok": false, "reason": "must_run_on_ground"}
	if float(state["energy"]) < 2.0:
		return {"ok": false, "reason": "not_enough_energy"}
	state["gliding"] = true
	state["vertical_speed"] = LAUNCH_VELOCITY
	return {"ok": true, "vertical_speed": LAUNCH_VELOCITY, "forward_speed": FORWARD_SPEED}

static func tick(state: Dictionary, delta: float, on_ground: bool) -> void:
	if not is_finite(delta) or delta <= 0.0:
		return
	var dt := minf(delta, 0.25)
	if bool(state["gliding"]):
		state["energy"] = maxf(0.0, float(state["energy"]) - dt)
		if on_ground or float(state["energy"]) <= 0.0:
			state["gliding"] = false
			state["vertical_speed"] = 0.0
		else:
			state["vertical_speed"] = maxf(-SINK_SPEED, float(state["vertical_speed"]) - 20.0 * dt)
	elif on_ground:
		state["energy"] = minf(CAPACITY, float(state["energy"]) + RECHARGE_PER_SECOND * dt)

static func land(state: Dictionary) -> void:
	state["gliding"] = false
	state["vertical_speed"] = 0.0

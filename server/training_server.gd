extends SceneTree
## Local development server only: unencrypted WebSocket, no authentication or persistence.
## Bind to loopback by default. NEVER expose to the public Internet.
const Zone = preload("res://server/training_zone.gd")
const PORT := 9087
var zone := Zone.new()
var transport := WebSocketMultiplayerPeer.new()
var known: Dictionary = {}

func _initialize() -> void:
	var error := transport.create_server(PORT, "127.0.0.1")
	if error != OK:
		push_error("Training server could not listen: %s" % error)
		quit(1)
		return
	transport.peer_connected.connect(_on_peer_connected)
	transport.peer_disconnected.connect(_on_peer_disconnected)
	print("ORVETHRA_TRAINING_SERVER_READY port=%d loopback_only=true" % PORT)

func _process(_delta: float) -> bool:
	transport.poll()
	var now := Time.get_ticks_msec()
	while transport.get_available_packet_count() > 0:
		var peer_id := transport.get_packet_peer()
		var raw := transport.get_packet().get_string_from_utf8()
		if raw.length() > 4096:
			_send(peer_id, {"ok": false, "reason": "oversized_packet"})
			continue
		var parsed = JSON.parse_string(raw)
		if not parsed is Dictionary:
			_send(peer_id, {"ok": false, "reason": "invalid_json"})
			continue
		_send(peer_id, zone.command(peer_id, parsed, now))
	for mob in zone.tick(now):
		for peer_id in known.keys():
			_send(peer_id, {"ok": true, "type": "respawn", "monster": mob})
	return false

func _on_peer_connected(peer_id: int) -> void:
	if known.has(peer_id):
		return
	known[peer_id] = true
	zone.join(peer_id, Time.get_ticks_msec())
	_send(peer_id, zone.snapshot(peer_id))

func _on_peer_disconnected(peer_id: int) -> void:
	zone.leave(peer_id)
	known.erase(peer_id)

func _send(peer_id: int, message: Dictionary) -> void:
	transport.set_target_peer(peer_id)
	transport.put_packet(JSON.stringify(message).to_utf8_buffer())

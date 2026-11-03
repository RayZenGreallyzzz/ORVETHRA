extends Node
## Isolated online training client. No offline save or combat logic is modified.
signal connection_changed(connected: bool, detail: String)
signal snapshot_received(data: Dictionary)
signal combat_received(data: Dictionary)
signal response_received(data: Dictionary)

@export var server_url: String = "ws://127.0.0.1:9087"
var socket := WebSocketPeer.new()
var sequence: int = 0
var connected: bool = false
var last_error: String = ""
var _connecting: bool = false

func connect_training(url: String = "") -> Error:
	if url != "":
		server_url = url
	if not server_url.begins_with("ws://") and not server_url.begins_with("wss://"):
		last_error = "Unsupported URL scheme"
		return ERR_INVALID_PARAMETER
	disconnect_training()
	socket = WebSocketPeer.new()
	var err := socket.connect_to_url(server_url)
	if err != OK:
		last_error = "Connection failed: %d" % err
		connection_changed.emit(false, last_error)
		return err
	_connecting = true
	return OK

func disconnect_training() -> void:
	if socket.get_ready_state() == WebSocketPeer.STATE_OPEN:
		socket.close(1000, "leaving")
	connected = false
	_connecting = false

func _process(_delta: float) -> void:
	if not _connecting and not connected:
		return
	socket.poll()
	var state := socket.get_ready_state()
	if state == WebSocketPeer.STATE_OPEN:
		if not connected:
			connected = true
			_connecting = false
			connection_changed.emit(true, "Connected")
		while socket.get_available_packet_count() > 0:
			var raw := socket.get_packet().get_string_from_utf8()
			var message = JSON.parse_string(raw)
			if not message is Dictionary:
				continue
			var kind := str(message.get("type", ""))
			if kind == "snapshot":
				snapshot_received.emit(message)
			elif kind == "combat_event":
				combat_received.emit(message)
			response_received.emit(message)
	elif state == WebSocketPeer.STATE_CLOSED:
		if connected or _connecting:
			connected = false
			_connecting = false
			connection_changed.emit(false, "Disconnected")

func attack(target_id: String) -> Error:
	if not connected:
		return ERR_UNCONFIGURED
	return _send_command("cast_skill", {"skill_id": "basic_attack", "target_entity_id": target_id})

func send_position(position: Vector2) -> Error:
	if not connected:
		return ERR_UNCONFIGURED
	return _send_command("move_intent", {"x": position.x, "y": position.y})

func _send_command(kind: String, payload: Dictionary) -> Error:
	sequence += 1
	var message := {"v": 1, "type": kind, "seq": sequence, "request_id": "cmd_%d" % sequence, "payload": payload}
	return socket.send_text(JSON.stringify(message))

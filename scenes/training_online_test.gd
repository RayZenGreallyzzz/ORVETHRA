extends Control
## Standalone online test UI; existing city and training monsters are not changed.
const Client = preload("res://scripts/mmorpg/training_network_client.gd")
var network: Node
var url_input: LineEdit
var status: Label
var log_label: RichTextLabel
var monster_buttons: Array[Button] = []
var selected_id: String = "training_0"

func _ready() -> void:
	network = Client.new()
	add_child(network)
	network.connection_changed.connect(_on_connection)
	network.snapshot_received.connect(_on_snapshot)
	network.combat_received.connect(_on_combat)
	network.response_received.connect(_on_response)
	var background := ColorRect.new()
	background.color = Color("#141c29")
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)
	var panel := VBoxContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.add_theme_constant_override("separation", 12)
	panel.offset_left = 28
	panel.offset_right = -28
	panel.offset_top = 25
	panel.offset_bottom = -24
	add_child(panel)
	var heading := Label.new()
	heading.text = "ORVETHRA  /  ONLINE TRAINING"
	heading.add_theme_font_size_override("font_size", 30)
	panel.add_child(heading)
	var subtitle := Label.new()
	subtitle.text = "Server-authoritative combat test — existing game remains unchanged"
	panel.add_child(subtitle)
	var row := HBoxContainer.new()
	panel.add_child(row)
	url_input = LineEdit.new()
	url_input.text = "ws://127.0.0.1:9087"
	url_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(url_input)
	var connect_button := Button.new()
	connect_button.text = "CONNECT"
	connect_button.pressed.connect(func(): network.connect_training(url_input.text))
	row.add_child(connect_button)
	status = Label.new()
	status.text = "OFFLINE — enter the test server address"
	panel.add_child(status)
	var enemies_title := Label.new()
	enemies_title.text = "TRAINING TARGETS"
	enemies_title.add_theme_font_size_override("font_size", 22)
	panel.add_child(enemies_title)
	for i in range(3):
		var button := Button.new()
		button.text = ("Forest Slime" if i < 2 else "Moss Beetle") + "  |  training_%d" % i
		button.custom_minimum_size.y = 64
		var id := "training_%d" % i
		button.pressed.connect(func(): _select(id))
		panel.add_child(button)
		monster_buttons.append(button)
	var attack_button := Button.new()
	attack_button.text = "⚔ ATTACK SELECTED TARGET"
	attack_button.custom_minimum_size.y = 76
	attack_button.pressed.connect(func(): network.attack(selected_id))
	panel.add_child(attack_button)
	log_label = RichTextLabel.new()
	log_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel.add_child(log_label)
	_log("Test screen only. No real money, no saved progression.")

func _select(id: String) -> void:
	selected_id = id
	_log("Selected: " + id)

func _on_connection(is_connected: bool, detail: String) -> void:
	status.text = ("ONLINE — " if is_connected else "OFFLINE — ") + detail
	_log(status.text)

func _on_snapshot(data: Dictionary) -> void:
	_log("Server snapshot received")
	var mobs: Array = data.get("monsters", [])
	for i in range(mini(mobs.size(), monster_buttons.size())):
		var mob: Dictionary = mobs[i]
		monster_buttons[i].text = "%s  |  HP %s/%s" % [mob.get("id", ""), mob.get("hp", "?"), mob.get("max_hp", "?")]

func _on_combat(data: Dictionary) -> void:
	_log("Server hit: %s damage, target HP: %s" % [data.get("damage", 0), data.get("target_hp", "?")])
	if data.get("killed", false):
		_log("Victory! Server awarded XP and silver.")

func _on_response(data: Dictionary) -> void:
	if not data.get("ok", false):
		_log("Server rejected: " + str(data.get("reason", "unknown")))

func _log(message: String) -> void:
	log_label.append_text(message + "\n")

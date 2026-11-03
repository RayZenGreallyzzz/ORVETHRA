extends Control
## Launcher entry screen. Uses a clean background image when installed.
## Reference artwork is NOT baked into interactive controls.
const BACKGROUND := "res://assets/launcher/entry_background.png"
const MENU_SCENE := "res://scenes/main_menu.tscn"
var status_label: Label

func _ready() -> void:
	var base := ColorRect.new()
	base.color = Color("#151e31")
	base.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(base)
	if ResourceLoader.exists(BACKGROUND):
		var artwork := TextureRect.new()
		artwork.texture = load(BACKGROUND)
		artwork.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		artwork.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		artwork.mouse_filter = Control.MOUSE_FILTER_IGNORE
		artwork.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		add_child(artwork)
	var gradient := ColorRect.new()
	gradient.color = Color(0.01, 0.01, 0.03, 0.42)
	gradient.anchor_top = 0.71
	gradient.anchor_right = 1.0
	gradient.anchor_bottom = 1.0
	gradient.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(gradient)
	var bottom := VBoxContainer.new()
	bottom.anchor_left = 0.5
	bottom.anchor_right = 0.5
	bottom.anchor_top = 0.71
	bottom.anchor_bottom = 0.98
	bottom.offset_left = -270
	bottom.offset_right = 270
	bottom.add_theme_constant_override("separation", 8)
	add_child(bottom)
	var play := _button("ИГРАТЬ", true)
	play.custom_minimum_size.y = 70
	play.pressed.connect(func(): get_tree().change_scene_to_file(MENU_SCENE))
	bottom.add_child(play)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	bottom.add_child(row)
	for entry in [["НАСТРОЙКИ", "settings"], ["ОБНОВЛЕНИЯ", "updates"], ["МАГАЗИН", "shop"], ["ВЫХОД", "exit"]]:
		var btn := _button(entry[0], false)
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.pressed.connect(Callable(self, "_action").bind(entry[1]))
		row.add_child(btn)
	status_label = Label.new()
	status_label.text = "СЕРВЕР: НЕ ПОДКЛЮЧЕН  ·  ВЕРСИЯ 0.33"
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_label.add_theme_font_size_override("font_size", 15)
	status_label.add_theme_color_override("font_color", Color("#f1d69d"))
	bottom.add_child(status_label)

func _button(caption: String, primary: bool) -> Button:
	var button := Button.new()
	button.text = caption
	button.add_theme_font_size_override("font_size", 22 if primary else 15)
	button.add_theme_color_override("font_color", Color("#ffe2a3"))
	for state in ["normal", "hover", "pressed"]:
		var style := StyleBoxFlat.new()
		style.bg_color = Color("#79151b" if primary else "#191b23")
		if state == "hover":
			style.bg_color = Color("#a02626" if primary else "#34303a")
		if state == "pressed":
			style.bg_color = Color("#4a1014" if primary else "#101117")
		style.border_color = Color("#f6d082" if state == "hover" else "#b88942")
		style.set_border_width_all(3 if primary else 2)
		style.set_corner_radius_all(7)
		style.shadow_color = Color(0, 0, 0, 0.7)
		style.shadow_size = 6
		button.add_theme_stylebox_override(state, style)
	button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	button.custom_minimum_size.y = 52
	return button

func _action(kind: String) -> void:
	match kind:
		"exit":
			get_tree().quit()
		"settings":
			_show_notice("Настройки доступны в главном меню игры.")
		"updates":
			_show_notice("Автоматическое обновление пока не подключено.")
		"shop":
			_show_notice("Магазин пока не подключён.")

func _show_notice(message: String) -> void:
	var dialog := AcceptDialog.new()
	dialog.title = "ORVETHRA"
	dialog.dialog_text = message
	add_child(dialog)
	dialog.popup_centered()
	dialog.confirmed.connect(func(): dialog.queue_free())

extends CanvasLayer

# ORVETHRA first playable MMORPG HUD pass. All positions follow the approved
# landscape mock-up; recalculated when the Android viewport rotates.
const JoystickControl = preload("res://scripts/city_joystick.gd")
const MinimapControl = preload("res://scripts/city_minimap.gd")
var game: Node3D
var root: Control
var joystick: Control
var minimap: Control
var title: Label
var stats: Panel
var quest_button: Button
var map_header: Label
var map_button: Button
var menu_button: Button
var chat_button: Button
var chat_label: Label
var attack_button: Button
var target_button: Button
var run_button: Button
var potion_button: Button
var skill_five: Button
var skill_ten: Button
var popup: Panel
var popup_heading: Label
var popup_description: Label
var popup_actions: VBoxContainer
var potion_count := 5
var quest_complete := false
var run_mode := true
var attack_flash := 0.0
var refresh_time := 0.0
var chat_messages: Array[String] = []

func _style(dark: Color, outline: Color, rounded := 7) -> StyleBoxFlat:
    var style := StyleBoxFlat.new()
    style.bg_color = dark
    style.border_color = outline
    style.set_border_width_all(2)
    style.set_corner_radius_all(rounded)
    return style

func _label(text: String, size: int, tint: Color) -> Label:
    var label := Label.new()
    label.text = text
    label.add_theme_font_size_override("font_size", size)
    label.add_theme_color_override("font_color", tint)
    return label

func _button(text: String, circular := false) -> Button:
    var button := Button.new()
    button.text = text
    button.focus_mode = Control.FOCUS_NONE
    button.add_theme_font_size_override("font_size", 18)
    button.add_theme_color_override("font_color", Color("f4dfb6"))
    button.add_theme_stylebox_override("normal", _style(Color(0.09, 0.09, 0.11, 0.82), Color(0.60, 0.54, 0.42, 0.85), 90 if circular else 6))
    button.add_theme_stylebox_override("hover", _style(Color(0.22, 0.20, 0.18, 0.89), Color(0.95, 0.77, 0.46, 1.0), 90 if circular else 6))
    button.add_theme_stylebox_override("pressed", _style(Color(0.35, 0.28, 0.15, 0.94), Color(0.95, 0.77, 0.46, 1.0), 90 if circular else 6))
    button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
    root.add_child(button)
    return button

func _bar(parent: Node, tint: Color, offset: Vector2) -> void:
    var bar := ProgressBar.new()
    bar.position = offset
    bar.size = Vector2(248, 21)
    bar.value = 100
    bar.show_percentage = false
    bar.add_theme_stylebox_override("background", _style(Color(0.06, 0.07, 0.08, 0.95), Color(0.54, 0.47, 0.33, 0.7), 2))
    bar.add_theme_stylebox_override("fill", _style(tint, tint.darkened(0.25), 1))
    parent.add_child(bar)

func _ready() -> void:
    root = Control.new()
    root.name = "CityHUD"
    root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    root.mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_child(root)

    title = _label("O R V E T H R A", 25, Color("edd5ad"))
    root.add_child(title)
    stats = Panel.new()
    stats.add_theme_stylebox_override("panel", _style(Color(0.04, 0.04, 0.05, 0.70), Color(0.38, 0.31, 0.23, 0.62)))
    stats.mouse_filter = Control.MOUSE_FILTER_IGNORE
    root.add_child(stats)
    var lv := _label("Lv. 1   Путник", 19, Color("f5e2c9"))
    lv.position = Vector2(11, 5)
    stats.add_child(lv)
    _bar(stats, Color("a92f29"), Vector2(10, 34))
    _bar(stats, Color("2959a6"), Vector2(10, 60))
    var hp := _label("120 / 120", 14, Color.WHITE)
    hp.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    hp.position = Vector2(11, 34)
    hp.size = Vector2(246, 20)
    stats.add_child(hp)
    var mp := _label("60 / 60", 14, Color.WHITE)
    mp.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    mp.position = Vector2(11, 60)
    mp.size = Vector2(246, 20)
    stats.add_child(mp)
    var exp := _label("EXP   0 / 100", 16, Color("c9c2b8"))
    exp.position = Vector2(10, 88)
    stats.add_child(exp)

    quest_button = _button("!  Первые шаги\nПодойдите к фонтану на площади\n(0/1)")
    quest_button.alignment = HORIZONTAL_ALIGNMENT_LEFT
    quest_button.add_theme_color_override("font_color", Color("e6d1a1"))
    quest_button.pressed.connect(_open_quest)
    quest_button.add_theme_font_size_override("font_size", 16)

    map_header = _label("Стартовый город\n(Центральная площадь)", 16, Color("f5e9d8"))
    map_header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    root.add_child(map_header)
    minimap = MinimapControl.new()
    minimap.name = "LiveMinimap"
    minimap.streets = game.roads
    root.add_child(minimap)
    map_button = _button("")
    map_button.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
    map_button.add_theme_stylebox_override("hover", StyleBoxEmpty.new())
    map_button.add_theme_stylebox_override("pressed", StyleBoxEmpty.new())
    map_button.pressed.connect(func() -> void: game._toggle_overview())
    menu_button = _button("☰")
    menu_button.pressed.connect(_open_menu)

    joystick = JoystickControl.new()
    joystick.name = "AnalogueMovement"
    root.add_child(joystick)

    chat_button = _button("●  Мир  |  Нажмите, чтобы написать…")
    chat_button.add_theme_font_size_override("font_size", 15)
    chat_button.alignment = HORIZONTAL_ALIGNMENT_LEFT
    chat_button.pressed.connect(_open_chat)

    target_button = _button("◎\nВыбрать", true)
    target_button.pressed.connect(_select_target)
    attack_button = _button("⚔\nУдар", true)
    attack_button.add_theme_font_size_override("font_size", 22)
    attack_button.pressed.connect(_attack)
    run_button = _button("➤", true)
    run_button.pressed.connect(_toggle_run)
    potion_button = _button("✦\n5", true)
    potion_button.pressed.connect(_use_potion)
    skill_five = _button("🔒\nLv. 5", true)
    skill_five.pressed.connect(func() -> void: _open_notice("Навык откроется на уровне 5."))
    skill_ten = _button("🔒\nLv. 10", true)
    skill_ten.pressed.connect(func() -> void: _open_notice("Навык откроется на уровне 10."))

    popup = Panel.new()
    popup.add_theme_stylebox_override("panel", _style(Color(0.07, 0.09, 0.11, 0.96), Color("bfa574")))
    popup.visible = false
    popup.mouse_filter = Control.MOUSE_FILTER_STOP
    root.add_child(popup)
    popup_heading = _label("Задания", 25, Color("eed3a4"))
    popup_heading.position = Vector2(22, 18)
    popup.add_child(popup_heading)
    popup_description = _label("", 17, Color("eee3d0"))
    popup_description.position = Vector2(22, 60)
    popup_description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    popup.add_child(popup_description)
    popup_actions = VBoxContainer.new()
    popup_actions.add_theme_constant_override("separation", 10)
    popup.add_child(popup_actions)

    get_viewport().size_changed.connect(_layout)
    _layout()

func _layout() -> void:
    if root == null:
        return
    var screen := get_viewport().get_visible_rect().size
    var compact := screen.x < screen.y
    var inset := 14.0
    title.position = Vector2(22, 7)
    stats.position = Vector2(inset, 51)
    stats.size = Vector2(271, 113)
    quest_button.position = Vector2(inset, 177)
    quest_button.size = Vector2(330 if not compact else minf(330.0, screen.x * 0.61), 98)
    map_header.position = Vector2(screen.x - 270, 8)
    map_header.size = Vector2(217, 43)
    minimap.position = Vector2(screen.x - 208, 61)
    minimap.size = Vector2(180, 180)
    map_button.position = minimap.position
    map_button.size = minimap.size
    menu_button.position = Vector2(screen.x - 55, 7)
    menu_button.size = Vector2(46, 44)
    joystick.position = Vector2(18, screen.y - 206)
    joystick.size = Vector2(184, 184)
    chat_button.position = Vector2(16, screen.y - 48)
    chat_button.size = Vector2(minf(420.0, screen.x * 0.42), 39)
    attack_button.position = Vector2(screen.x - 157, screen.y - 196)
    attack_button.size = Vector2(128, 128)
    target_button.position = Vector2(screen.x - 288, screen.y - 167)
    target_button.size = Vector2(106, 106)
    run_button.position = Vector2(screen.x - 205, screen.y - 76)
    run_button.size = Vector2(65, 65)
    potion_button.position = Vector2(screen.x - 285, screen.y - 303)
    potion_button.size = Vector2(72, 72)
    skill_five.position = Vector2(screen.x - 198, screen.y - 320)
    skill_five.size = Vector2(72, 72)
    skill_ten.position = Vector2(screen.x - 111, screen.y - 320)
    skill_ten.size = Vector2(72, 72)
    var popup_width := minf(440.0, screen.x - 36.0)
    popup.position = Vector2((screen.x - popup_width) * 0.5, maxf(44.0, (screen.y - 360) * 0.5))
    popup.size = Vector2(popup_width, 360)
    popup_description.size = Vector2(popup_width - 44, 132)
    popup_actions.position = Vector2(22, 230)
    popup_actions.size = Vector2(popup_width - 44, 110)
    if compact:
        # Portrait test mode stays playable: shrink the HUD to avoid overlapping the map.
        stats.scale = Vector2(0.84, 0.84)
        quest_button.scale = Vector2(0.84, 0.84)
        minimap.scale = Vector2(0.74, 0.74)
        map_button.scale = Vector2(0.74, 0.74)
        map_header.position = Vector2(screen.x - 215, 8)
        map_header.add_theme_font_size_override("font_size", 13)
        attack_button.scale = Vector2(0.82, 0.82)
        target_button.scale = Vector2(0.82, 0.82)
        joystick.scale = Vector2(0.86, 0.86)
    else:
        stats.scale = Vector2.ONE
        quest_button.scale = Vector2.ONE
        minimap.scale = Vector2.ONE
        map_button.scale = Vector2.ONE
        attack_button.scale = Vector2.ONE
        target_button.scale = Vector2.ONE
        joystick.scale = Vector2.ONE

func _process(delta: float) -> void:
    refresh_time += delta
    if attack_flash > 0.0:
        attack_flash -= delta
        if attack_flash <= 0.0:
            attack_button.text = "⚔\nУдар"
    if refresh_time < 0.12 or game == null or game.player == null:
        return
    refresh_time = 0.0
    minimap.refresh(Vector2(game.player.position.x, game.player.position.z), game.player.rotation.y)
    if not quest_complete and Vector2(game.player.position.x, game.player.position.z).length() < 5.9:
        quest_complete = true
        quest_button.text = "!  Первые шаги\nФонтан найден!\n(1/1)"
        chat_button.text = "●  Мир  |  Задание выполнено: фонтан!"

func _clear_popup_actions() -> void:
    for child in popup_actions.get_children():
        popup_actions.remove_child(child)
        child.queue_free()

func _popup_button(label: String, action: Callable) -> void:
    var button := Button.new()
    button.text = label
    button.custom_minimum_size.y = 42
    button.add_theme_font_size_override("font_size", 18)
    button.pressed.connect(action)
    popup_actions.add_child(button)

func _open_quest() -> void:
    popup.visible = true
    popup_heading.text = "Задания — Первые шаги"
    popup_description.text = "Исследуйте стартовый город. Подойдите к центральному фонтану.\n\nПрогресс: " + ("1 / 1  — выполнено!" if quest_complete else "0 / 1")
    _clear_popup_actions()
    _popup_button("Закрыть", _close_popup)

func _open_menu() -> void:
    popup.visible = true
    popup_heading.text = "ORVETHRA · Меню"
    popup_description.text = "Тестовая прогулка по городу.\nВыберите действие:"
    _clear_popup_actions()
    _popup_button("Обзор карты / Пешком", _switch_map)
    _popup_button("Главное меню", _go_home)
    _popup_button("Закрыть", _close_popup)

func _open_notice(message: String) -> void:
    popup.visible = true
    popup_heading.text = "ORVETHRA"
    popup_description.text = message
    _clear_popup_actions()
    _popup_button("Закрыть", _close_popup)

func _open_chat() -> void:
    popup.visible = true
    popup_heading.text = "Мировой чат"
    popup_description.text = "Тестовый локальный чат (онлайн пока нет).\n" + ("Последнее: " + chat_messages.back() if not chat_messages.is_empty() else "Напишите первое сообщение:")
    _clear_popup_actions()
    _popup_button("Привет всем!", func() -> void: _send_chat("Привет всем!"))
    _popup_button("Исследую город", func() -> void: _send_chat("Исследую город"))
    _popup_button("Закрыть", _close_popup)

func _send_chat(message: String) -> void:
    chat_messages.append(message)
    chat_button.text = "●  Мир  |  Путник: " + message
    _close_popup()

func _switch_map() -> void:
    _close_popup()
    game._toggle_overview()

func _go_home() -> void:
    get_tree().change_scene_to_file("res://scenes/main_menu.tscn")

func _close_popup() -> void:
    popup.visible = false

func _select_target() -> void:
    _open_notice("Выбор боевой цели появится с тренировочными монстрами.\nПока можно исследовать город и фонтан.")

func _attack() -> void:
    attack_button.text = "⚔\nУдар!"
    attack_flash = 0.3
    if game.has_method("_try_attack"):
        game._try_attack()

func _toggle_run() -> void:
    run_mode = not run_mode
    run_button.text = "➤" if run_mode else "Шаг"

func _use_potion() -> void:
    if potion_count < 1:
        _open_notice("Тестовые зелья закончились.")
        return
    potion_count -= 1
    potion_button.text = "✦\n" + str(potion_count)
    _open_notice("Использовано тестовое зелье. Осталось: " + str(potion_count) + ".")

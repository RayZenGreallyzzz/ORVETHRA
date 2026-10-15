extends Control

# ORVETHRA v0.5: menus are functional; Google login and online servers are placeholders.
const SAVE_PATH := "user://orvethra_guest.json"
const PREFERENCES_PATH := "user://orvethra_preferences.json"
const CharacterRoster = preload("res://scripts/character_roster.gd")
const HeroRoster = preload("res://scripts/hero_roster.gd")
var auto_rotation := false
var keyboard_overlay: ColorRect
var keyboard_grid: GridContainer
var keyboard_preview: Label
var keyboard_russian := true
var page := "home"
var character: Dictionary = {}
var char_name: LineEdit
var char_race: OptionButton
var char_class: OptionButton
var quality_high := false
var background: TextureRect
var content: Control
var selected_roster_id := ""
var roster_preview_root: Node3D
var roster_viewport: SubViewport
var roster_selected_label: Label

func _ready() -> void:
    Engine.max_fps = 30
    _load_character()
    _load_preferences()
    get_viewport().size_changed.connect(_on_viewport_size_changed)
    var base := ColorRect.new()
    base.color = Color("192532")
    base.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    add_child(base)
    if ResourceLoader.exists("res://assets/title_cover.jpg"):
        background = TextureRect.new()
        background.texture = load("res://assets/title_cover.jpg")
        background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
        background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
        background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
        add_child(background)
    content = Control.new()
    content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    content.mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_child(content)
    _show_page("home")

func _style(color: Color, stroke: Color) -> StyleBoxFlat:
    var box := StyleBoxFlat.new()
    box.bg_color = color
    box.border_color = stroke
    box.set_border_width_all(2)
    box.set_corner_radius_all(9)
    box.content_margin_left = 10
    box.content_margin_right = 10
    box.content_margin_top = 6
    box.content_margin_bottom = 6
    return box

func _add_button(parent: Node, caption: String, callback: Callable, main := false) -> Button:
    var button := Button.new()
    button.text = caption
    button.custom_minimum_size = Vector2(0, 50)
    button.add_theme_font_size_override("font_size", 20)
    button.add_theme_color_override("font_color", Color("f3dfb4"))
    button.add_theme_stylebox_override("normal", _style(Color("18405e") if main else Color("2c3037"), Color("d5ae62") if main else Color("978364")))
    button.add_theme_stylebox_override("hover", _style(Color("265874"), Color("f1d28e")))
    button.add_theme_stylebox_override("pressed", _style(Color("0e2d46"), Color("d5ae62")))
    button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
    button.pressed.connect(callback)
    parent.add_child(button)
    return button

func _label(parent: Node, caption: String, size := 19) -> void:
    var label := Label.new()
    label.text = caption
    label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    label.add_theme_font_size_override("font_size", size)
    label.add_theme_color_override("font_color", Color("f4e3c6"))
    parent.add_child(label)

func _touch_area(x1: float, y1: float, x2: float, y2: float, callback: Callable) -> void:
    var button := Button.new()
    button.anchor_left = x1
    button.anchor_top = y1
    button.anchor_right = x2
    button.anchor_bottom = y2
    button.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
    button.add_theme_stylebox_override("hover", _style(Color(0.1, 0.35, 0.65, 0.15), Color(0.9, 0.7, 0.4, 0.65)))
    button.add_theme_stylebox_override("pressed", _style(Color(0.1, 0.35, 0.65, 0.25), Color(0.9, 0.7, 0.4, 0.8)))
    button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
    button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
    button.pressed.connect(callback)
    content.add_child(button)

func _show_page(next: String) -> void:
    _close_character_keyboard()
    roster_viewport = null
    roster_preview_root = null
    roster_selected_label = null
    page = next
    for child in content.get_children():
        content.remove_child(child)
        child.queue_free()
    if page == "home":
        if background != null and get_viewport_rect().size.x >= get_viewport_rect().size.y:
            # The approved cover has baked buttons for landscape. In portrait we
            # fall back to real controls because cropping moves those hotspots.
            _touch_area(0.43, 0.63, 0.68, 0.73, func(): _show_page("login"))
            _touch_area(0.475, 0.735, 0.635, 0.793, func(): _show_page("settings"))
            _touch_area(0.475, 0.793, 0.635, 0.853, func(): _show_page("authors"))
            _touch_area(0.475, 0.853, 0.635, 0.912, func(): get_tree().quit())
            return
    if page != "home":
        var veil := ColorRect.new()
        veil.color = Color(0.02, 0.03, 0.06, 0.89)
        veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
        content.add_child(veil)
    var panel := PanelContainer.new()
    panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
    var viewport := get_viewport_rect().size
    if page == "characters":
        var panel_half_w := minf(570.0, viewport.x * 0.475)
        var panel_half_h := minf(330.0, viewport.y * 0.465)
        panel.offset_left = -panel_half_w
        panel.offset_top = -panel_half_h
        panel.offset_right = panel_half_w
        panel.offset_bottom = panel_half_h
    else:
        panel.offset_left = -285
        panel.offset_top = -255
        panel.offset_right = 285
        panel.offset_bottom = 255
    panel.add_theme_stylebox_override("panel", _style(Color("18283a"), Color("bca06b")))
    content.add_child(panel)
    var margin := MarginContainer.new()
    for side in ["left", "right", "top", "bottom"]:
        margin.add_theme_constant_override("margin_" + side, 22)
    panel.add_child(margin)
    var box := VBoxContainer.new()
    box.add_theme_constant_override("separation", 14)
    margin.add_child(box)
    match page:
        "home":
            _label(box, "ORVETHRA", 53)
            _label(box, "Мир забытых легенд", 22)
            _add_button(box, "Начать приключение", func(): _show_page("login"), true)
            _add_button(box, "Настройки", func(): _show_page("settings"))
            _add_button(box, "Авторы", func(): _show_page("authors"))
            _add_button(box, "Выход", func(): get_tree().quit())
        "login":
            _label(box, "Вход в ORVETHRA", 31)
            _label(box, "Войти с аккаунтом Google")
            _add_button(box, "Войти через Google", func(): _notice("Авторизация Google пока не подключена. Необходимы OAuth и серверная проверка."), true)
            _label(box, "Для проверки меню используйте гостевой режим.", 16)
            _add_button(box, "Продолжить как гость (тест)", func(): _show_page("servers"))
            _add_button(box, "← Назад", func(): _show_page("home"))
        "servers":
            _label(box, "Выбор сервера", 31)
            _label(box, "Онлайн-сервер ещё не запущен.")
            _add_button(box, "Локальный мир · офлайн", func(): _show_page("characters"), true)
            _add_button(box, "← Назад", func(): _show_page("login"))
        "characters":
            _show_roster(box)
        "create":
            _label(box, "Создание героя", 29)
            char_name = LineEdit.new()
            char_name.placeholder_text = "Имя персонажа"
            char_name.text = str(character.get("name", ""))
            char_name.custom_minimum_size.y = 47
            char_name.max_length = 18
            char_name.virtual_keyboard_enabled = true
            char_name.focus_mode = Control.FOCUS_ALL
            char_name.focus_entered.connect(func() -> void: call_deferred("_open_character_keyboard"))
            char_name.gui_input.connect(func(event: InputEvent) -> void:
                if event is InputEventScreenTouch and event.pressed:
                    char_name.grab_focus()
                    call_deferred("_open_character_keyboard")
            )
            char_name.text_submitted.connect(func(_value: String) -> void:
                _close_character_keyboard()
                char_name.release_focus()
            )
            box.add_child(char_name)
            var keyboard_actions := HBoxContainer.new()
            keyboard_actions.add_theme_constant_override("separation", 10)
            box.add_child(keyboard_actions)
            var android_button := _add_button(keyboard_actions, "⌨ Android", func(): call_deferred("_open_character_keyboard"))
            android_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
            var game_keyboard_button := _add_button(keyboard_actions, "Клавиатура в игре", func(): _show_game_keyboard())
            game_keyboard_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
            char_race = OptionButton.new()
            for s in ["Человек", "Эльф", "Гном"]:
                char_race.add_item(s)
            char_race.custom_minimum_size.y = 47
            box.add_child(char_race)
            char_class = OptionButton.new()
            for s in ["Воин", "Маг", "Лучник", "Ассасин", "Призыватель", "Жрец"]:
                char_class.add_item(s)
            char_class.custom_minimum_size.y = 47
            box.add_child(char_class)
            _add_button(box, "Сохранить персонажа", func(): _save_character(), true)
            _add_button(box, "← Назад", func(): _show_page("characters"))
        "settings":
            _label(box, "Настройки", 31)
            _label(box, "Для IT-801C рекомендован экономный режим.")
            _add_button(box, "Лимит: " + ("60 FPS" if quality_high else "30 FPS"), func(): _toggle_fps(), true)
            _add_button(box, "Экран: " + ("Автоповорот" if auto_rotation else "Горизонтально"), func(): _toggle_orientation())
            _label(box, "Авто: портретный и горизонтальный режимы.\nГоризонтально: экран закреплён.", 15)
            _add_button(box, "← Назад", func(): _show_page("home"))
        "authors":
            _label(box, "Авторы", 31)
            _label(box, "ORVETHRA — Мир забытых легенд\nНезависимая фэнтези-RPG\nВерсия меню 0.5 · ранний прототип")
            _add_button(box, "← Назад", func(): _show_page("home"))

func _show_roster(box: VBoxContainer) -> void:
    _label(box, "Герои ORVETHRA · тестовый выбор", 29)
    var body := HBoxContainer.new()
    body.add_theme_constant_override("separation", 16)
    body.size_flags_vertical = Control.SIZE_EXPAND_FILL
    box.add_child(body)

    var scroll := ScrollContainer.new()
    scroll.custom_minimum_size.x = minf(380.0, get_viewport_rect().size.x * 0.35)
    scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
    scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
    body.add_child(scroll)
    var list := VBoxContainer.new()
    list.add_theme_constant_override("separation", 6)
    list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    scroll.add_child(list)

    for entry in CharacterRoster.ENTRIES:
        var label := str(entry["title"]) + "  ·  " + str(entry["species"])
        var button := _add_button(list, label, Callable(self, "_select_roster").bind(str(entry["id"])))
        button.custom_minimum_size.y = 44
        button.add_theme_font_size_override("font_size", 16)

    var preview_column := VBoxContainer.new()
    preview_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    preview_column.size_flags_vertical = Control.SIZE_EXPAND_FILL
    body.add_child(preview_column)
    var preview_frame := SubViewportContainer.new()
    preview_frame.stretch = true
    preview_frame.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    preview_frame.size_flags_vertical = Control.SIZE_EXPAND_FILL
    preview_frame.custom_minimum_size = Vector2(240, 245)
    preview_column.add_child(preview_frame)

    roster_viewport = SubViewport.new()
    roster_viewport.size = Vector2i(420, 370)
    roster_viewport.own_world_3d = true
    roster_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
    preview_frame.add_child(roster_viewport)
    var scene_root := Node3D.new()
    scene_root.name = "RosterShowcase"
    roster_viewport.add_child(scene_root)
    roster_preview_root = Node3D.new()
    roster_preview_root.name = "AnimatedHero"
    scene_root.add_child(roster_preview_root)

    var environment := WorldEnvironment.new()
    var env := Environment.new()
    env.background_mode = Environment.BG_COLOR
    env.background_color = Color("101826")
    env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
    env.ambient_light_color = Color("b5bbcc")
    env.ambient_light_energy = 1.1
    environment.environment = env
    scene_root.add_child(environment)
    var key_light := DirectionalLight3D.new()
    key_light.rotation_degrees = Vector3(-45, -28, -15)
    key_light.light_energy = 1.25
    scene_root.add_child(key_light)
    var fill_light := DirectionalLight3D.new()
    fill_light.rotation_degrees = Vector3(-18, 150, 0)
    fill_light.light_energy = 0.58
    scene_root.add_child(fill_light)
    var display_camera := Camera3D.new()
    display_camera.position = Vector3(0.0, 1.4, 4.8)
    display_camera.fov = 48
    scene_root.add_child(display_camera)
    display_camera.look_at(Vector3(0, 1.2, 0), Vector3.UP)
    display_camera.current = true

    roster_selected_label = Label.new()
    roster_selected_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    roster_selected_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    roster_selected_label.add_theme_font_size_override("font_size", 16)
    roster_selected_label.add_theme_color_override("font_color", Color("efd8ad"))
    preview_column.add_child(roster_selected_label)

    _add_button(box, "Войти в город выбранным героем", Callable(self, "_enter_roster"), true)
    _add_button(box, "← Назад", func(): _show_page("servers"))
    var target := str(character.get("model_id", CharacterRoster.default_id()))
    if CharacterRoster.get_entry(target).is_empty():
        target = CharacterRoster.default_id()
    _select_roster(target)


func _select_roster(id: String) -> void:
    var entry := CharacterRoster.get_entry(id)
    if entry.is_empty():
        return
    selected_roster_id = id
    if roster_selected_label != null:
        roster_selected_label.text = str(entry["title"]) + " · " + str(entry["role"]) + " · " + str(entry["gender"])
    if roster_preview_root == null or not is_instance_valid(roster_preview_root):
        return
    for child in roster_preview_root.get_children():
        roster_preview_root.remove_child(child)
        child.queue_free()
    var path := CharacterRoster.model_path(id)
    if not ResourceLoader.exists(path):
        roster_selected_label.text += " · модель загружается"
        return
    var resource := load(path)
    if not resource is PackedScene:
        return
    var scene: Node3D = (resource as PackedScene).instantiate()
    scene.name = str(entry["title"])
    roster_preview_root.add_child(scene)

    # Fit every rig to the same preview frame while keeping original proportions.
    var corners: Array[Vector3] = []
    _collect_preview_points(scene, corners)
    if not corners.is_empty():
        var low := Vector3(INF, INF, INF)
        var high := Vector3(-INF, -INF, -INF)
        for point in corners:
            low = low.min(point)
            high = high.max(point)
        var height := maxf(0.1, high.y - low.y)
        var widest := maxf(high.x - low.x, high.z - low.z)
        var scale_factor := minf(2.5 / height, 2.6 / maxf(0.1, widest))
        scene.scale = Vector3.ONE * scale_factor
        scene.position = Vector3(-(low.x + high.x) * 0.5, -low.y, -(low.z + high.z) * 0.5) * scale_factor
    _start_preview_idle(scene)


func _collect_preview_points(node: Node, corners: Array[Vector3]) -> void:
    if node is MeshInstance3D:
        var mesh_node := node as MeshInstance3D
        if mesh_node.mesh != null:
            var bounds := mesh_node.mesh.get_aabb()
            for ix in range(2):
                for iy in range(2):
                    for iz in range(2):
                        var corner := bounds.position + bounds.size * Vector3(float(ix), float(iy), float(iz))
                        corners.append(mesh_node.global_transform * corner)
    for child in node.get_children():
        _collect_preview_points(child, corners)


func _start_preview_idle(node: Node) -> void:
    if node is AnimationPlayer:
        var actor := node as AnimationPlayer
        for clip in actor.get_animation_list():
            if String(clip).to_lower().ends_with("idle"):
                actor.play(clip)
                return
    for child in node.get_children():
        _start_preview_idle(child)


func _enter_roster() -> void:
    var entry := CharacterRoster.get_entry(selected_roster_id)
    if entry.is_empty():
        return
    var path := CharacterRoster.model_path(selected_roster_id)
    if not ResourceLoader.exists(path):
        _notice("Модель ещё не добавлена в сборку: " + str(entry["title"]))
        return
    character = {"name": entry["title"], "race": entry["species"],
        "class": entry["role"], "model_id": selected_roster_id}
    var save := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
    if save == null:
        _notice("Не удалось сохранить выбранного героя.")
        return
    save.store_string(JSON.stringify(character))
    save.close()
    HeroRoster.save_id(selected_roster_id)
    _enter()


func _open_character_keyboard() -> void:
    if char_name == null or not is_instance_valid(char_name):
        return
    char_name.grab_focus()
    if DisplayServer.has_feature(DisplayServer.FEATURE_VIRTUAL_KEYBOARD):
        var rect := char_name.get_global_rect()
        var cursor := char_name.caret_column
        DisplayServer.virtual_keyboard_show(
            char_name.text,
            rect,
            DisplayServer.KEYBOARD_TYPE_DEFAULT,
            char_name.max_length,
            cursor,
            cursor
        )

func _close_character_keyboard() -> void:
    if DisplayServer.has_feature(DisplayServer.FEATURE_VIRTUAL_KEYBOARD):
        DisplayServer.virtual_keyboard_hide()
    _close_game_keyboard()

func _show_game_keyboard() -> void:
    if char_name == null or not is_instance_valid(char_name):
        return
    _close_character_keyboard()
    keyboard_russian = true
    keyboard_overlay = ColorRect.new()
    keyboard_overlay.name = "InGameNameKeyboard"
    keyboard_overlay.color = Color(0.0, 0.0, 0.0, 0.84)
    keyboard_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
    keyboard_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    content.add_child(keyboard_overlay)

    var keyboard_panel := PanelContainer.new()
    keyboard_panel.anchor_left = 0.5
    keyboard_panel.anchor_top = 0.5
    keyboard_panel.anchor_right = 0.5
    keyboard_panel.anchor_bottom = 0.5
    var panel_half_width := minf(475.0, get_viewport_rect().size.x * 0.47)
    keyboard_panel.offset_left = -panel_half_width
    keyboard_panel.offset_right = panel_half_width
    keyboard_panel.offset_top = -205
    keyboard_panel.offset_bottom = 205
    keyboard_panel.add_theme_stylebox_override("panel", _style(Color("18283a"), Color("bca06b")))
    keyboard_overlay.add_child(keyboard_panel)

    var margin := MarginContainer.new()
    for side in ["left", "right", "top", "bottom"]:
        margin.add_theme_constant_override("margin_" + side, 10)
    keyboard_panel.add_child(margin)
    var column := VBoxContainer.new()
    column.add_theme_constant_override("separation", 5)
    margin.add_child(column)
    keyboard_preview = Label.new()
    keyboard_preview.text = "Имя: " + char_name.text
    keyboard_preview.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    keyboard_preview.add_theme_font_size_override("font_size", 20)
    column.add_child(keyboard_preview)

    keyboard_grid = GridContainer.new()
    keyboard_grid.columns = 11
    keyboard_grid.add_theme_constant_override("h_separation", 3)
    keyboard_grid.add_theme_constant_override("v_separation", 3)
    column.add_child(keyboard_grid)
    _fill_game_keyboard()

    var controls := HBoxContainer.new()
    controls.add_theme_constant_override("separation", 5)
    column.add_child(controls)
    for pair in [["АБВ / ABC", "_toggle_keyboard_language"], ["Пробел", "_keyboard_space"], ["⌫", "_keyboard_backspace"], ["Готово", "_close_game_keyboard"]]:
        var key := _add_button(controls, pair[0], Callable(self, pair[1]))
        key.custom_minimum_size = Vector2(0, 48)
        key.size_flags_horizontal = Control.SIZE_EXPAND_FILL

func _fill_game_keyboard() -> void:
    if keyboard_grid == null or not is_instance_valid(keyboard_grid):
        return
    for child in keyboard_grid.get_children():
        keyboard_grid.remove_child(child)
        child.queue_free()
    var letters := "ЙЦУКЕНГШЩЗХФЫВАПРОЛДЖЭЯЧСМИТЬБЮЁ0123456789" if keyboard_russian else "QWERTYUIOPASDFGHJKLZXCVBNM0123456789"
    for i in range(letters.length()):
        var symbol := letters.substr(i, 1)
        var key := _add_button(keyboard_grid, symbol, Callable(self, "_insert_keyboard_symbol").bind(symbol))
        key.custom_minimum_size = Vector2(41, 42)
        key.add_theme_font_size_override("font_size", 17)

func _insert_keyboard_symbol(symbol: String) -> void:
    if char_name == null or not is_instance_valid(char_name):
        return
    if char_name.text.length() >= char_name.max_length:
        return
    char_name.text += symbol
    _update_keyboard_preview()

func _keyboard_space() -> void:
    _insert_keyboard_symbol(" ")

func _keyboard_backspace() -> void:
    if char_name == null or not is_instance_valid(char_name):
        return
    if not char_name.text.is_empty():
        char_name.text = char_name.text.substr(0, char_name.text.length() - 1)
        _update_keyboard_preview()

func _toggle_keyboard_language() -> void:
    keyboard_russian = not keyboard_russian
    _fill_game_keyboard()

func _update_keyboard_preview() -> void:
    if keyboard_preview != null and is_instance_valid(keyboard_preview):
        keyboard_preview.text = "Имя: " + char_name.text

func _close_game_keyboard() -> void:
    if keyboard_overlay != null and is_instance_valid(keyboard_overlay):
        keyboard_overlay.queue_free()
    keyboard_overlay = null
    keyboard_grid = null
    keyboard_preview = null

func _quick_enter() -> void:
    character = {"name": "Путник", "race": "Человек", "class": "Воин"}
    var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
    if file != null:
        file.store_string(JSON.stringify(character))
        file.close()
    _enter()

func _on_viewport_size_changed() -> void:
    if page == "home":
        call_deferred("_show_page", "home")

func _load_preferences() -> void:
    if FileAccess.file_exists(PREFERENCES_PATH):
        var value: Variant = JSON.parse_string(FileAccess.get_file_as_string(PREFERENCES_PATH))
        if value is Dictionary:
            auto_rotation = bool(value.get("auto_rotation", false))
    _apply_orientation()

func _toggle_orientation() -> void:
    auto_rotation = not auto_rotation
    var file := FileAccess.open(PREFERENCES_PATH, FileAccess.WRITE)
    if file != null:
        file.store_string(JSON.stringify({"auto_rotation": auto_rotation}))
        file.close()
    _apply_orientation()
    _show_page("settings")

func _apply_orientation() -> void:
    if DisplayServer.has_feature(DisplayServer.FEATURE_ORIENTATION):
        DisplayServer.screen_set_orientation(
            DisplayServer.SCREEN_SENSOR if auto_rotation else DisplayServer.SCREEN_LANDSCAPE
        )

func _save_character() -> void:
    _close_character_keyboard()
    var nm := char_name.text.strip_edges()
    if nm.length() < 2 or nm.length() > 18:
        _notice("Имя должно содержать от 2 до 18 символов.")
        return
    character = {"name": nm, "race": char_race.get_item_text(char_race.selected), "class": char_class.get_item_text(char_class.selected)}
    var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
    if file == null:
        _notice("Не удалось сохранить тестового героя.")
        return
    file.store_string(JSON.stringify(character))
    file.close()
    _show_page("characters")

func _load_character() -> void:
    if FileAccess.file_exists(SAVE_PATH):
        var value: Variant = JSON.parse_string(FileAccess.get_file_as_string(SAVE_PATH))
        if value is Dictionary:
            character = value

func _toggle_fps() -> void:
    quality_high = not quality_high
    Engine.max_fps = 60 if quality_high else 30
    _show_page("settings")

func _enter() -> void:
    _close_character_keyboard()
    get_tree().change_scene_to_file("res://scenes/city_preview.tscn")

func _notice(message: String) -> void:
    var dlg := AcceptDialog.new()
    dlg.title = "ORVETHRA"
    dlg.dialog_text = message
    content.add_child(dlg)
    dlg.popup_centered(Vector2i(580, 220))
    dlg.confirmed.connect(func(): dlg.queue_free())

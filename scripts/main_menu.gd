extends Control

# ORVETHRA v0.5: menus are functional; Google login and online servers are placeholders.
const SAVE_PATH := "user://orvethra_guest.json"
var page := "home"
var character: Dictionary = {}
var char_name: LineEdit
var char_race: OptionButton
var char_class: OptionButton
var quality_high := false
var background: TextureRect
var content: Control

func _ready() -> void:
    Engine.max_fps = 30
    _load_character()
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
    page = next
    for child in content.get_children():
        content.remove_child(child)
        child.queue_free()
    if page == "home":
        if background != null:
            # Hotspots follow the buttons baked into the approved cover artwork.
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
            _label(box, "Выбор персонажа", 31)
            if character.is_empty():
                _label(box, "Персонажей пока нет.")
            else:
                _label(box, str(character.get("name","Герой")), 29)
                _label(box, str(character.get("race","Человек")) + " · " + str(character.get("class","Воин")))
                _add_button(box, "Войти в мир", func(): _enter(), true)
            _add_button(box, "Создать персонажа" if character.is_empty() else "Изменить героя", func(): _show_page("create"))
            _add_button(box, "← Назад", func(): _show_page("servers"))
        "create":
            _label(box, "Создание героя", 29)
            char_name = LineEdit.new()
            char_name.placeholder_text = "Имя персонажа"
            char_name.text = str(character.get("name", ""))
            char_name.custom_minimum_size.y = 47
            box.add_child(char_name)
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
            _add_button(box, "← Назад", func(): _show_page("home"))
        "authors":
            _label(box, "Авторы", 31)
            _label(box, "ORVETHRA — Мир забытых легенд\nНезависимая фэнтези-RPG\nВерсия меню 0.5 · ранний прототип")
            _add_button(box, "← Назад", func(): _show_page("home"))

func _save_character() -> void:
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
    get_tree().change_scene_to_file("res://scenes/town.tscn")

func _notice(message: String) -> void:
    var dlg := AcceptDialog.new()
    dlg.title = "ORVETHRA"
    dlg.dialog_text = message
    content.add_child(dlg)
    dlg.popup_centered(Vector2i(580, 220))
    dlg.confirmed.connect(func(): dlg.queue_free())

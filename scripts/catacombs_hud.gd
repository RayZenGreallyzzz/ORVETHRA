extends CanvasLayer

# Lightweight touch UI for the offline catacomb layout test.
const JoystickControl = preload("res://scripts/city_joystick.gd")
var game
var joystick
var run_mode := true
var ui_root: Control
var area_title: Label
var tip: Label
var exit_button: Button
var camera_near: Button
var camera_far: Button

func _ready() -> void:
    ui_root = Control.new()
    ui_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    ui_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_child(ui_root)
    area_title = Label.new()
    area_title.text = "ORVETHRA · Забытые катакомбы"
    area_title.add_theme_font_size_override("font_size", 21)
    area_title.add_theme_color_override("font_color", Color("efd3b1"))
    ui_root.add_child(area_title)
    tip = Label.new()
    tip.text = "Готический лабиринт · 12 комнат · Зал Демоники"
    tip.add_theme_font_size_override("font_size", 15)
    tip.add_theme_color_override("font_color", Color("d2c9ba"))
    ui_root.add_child(tip)
    joystick = JoystickControl.new()
    ui_root.add_child(joystick)
    exit_button = _button("Вернуться в город")
    exit_button.visible = false
    exit_button.pressed.connect(func() -> void:
        if game != null and game._near_exit_marker():
            game._return_to_city()
    )
    camera_near = _button("Камера +")
    camera_near.pressed.connect(func() -> void: game._change_camera_distance(-1))
    camera_far = _button("Камера −")
    camera_far.pressed.connect(func() -> void: game._change_camera_distance(1))
    get_viewport().size_changed.connect(_layout)
    _layout()

func _button(caption: String) -> Button:
    var b := Button.new()
    b.text = caption
    b.focus_mode = Control.FOCUS_NONE
    b.add_theme_font_size_override("font_size", 17)
    ui_root.add_child(b)
    return b

func _layout() -> void:
    if ui_root == null:
        return
    var view := get_viewport().get_visible_rect().size
    area_title.position = Vector2(20, 14)
    area_title.size = Vector2(view.x - 40, 32)
    tip.position = Vector2(20, 48)
    tip.size = Vector2(view.x - 40, 28)
    joystick.position = Vector2(20, view.y - 222)
    joystick.size = Vector2(176, 176)
    var compact := view.x < view.y
    joystick.scale = Vector2(0.85, 0.85) if compact else Vector2.ONE
    exit_button.position = Vector2(view.x - 235, 15)
    exit_button.size = Vector2(214, 46)
    camera_near.position = Vector2(view.x - 220, view.y - 127)
    camera_near.size = Vector2(98, 45)
    camera_far.position = Vector2(view.x - 116, view.y - 127)
    camera_far.size = Vector2(98, 45)

func _process(_delta: float) -> void:
    if game != null and exit_button != null:
        exit_button.visible = game._near_exit_marker()

func is_popup_open() -> bool:
    return false

func show_combat_message(message: String) -> void:
    tip.text = message

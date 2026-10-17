extends CanvasLayer

# Touch-first catacomb HUD with genuinely interactive boss health and attacks.
const JoystickControl = preload("res://scripts/city_joystick.gd")
const MAX_HP := 120
var game
var joystick
var run_mode := true
var ui_root: Control
var area_title: Label
var tip: Label
var exit_button: Button
var camera_near: Button
var camera_far: Button
var attack_button: Button
var potion_button: Button
var health_bar: ProgressBar
var health_text: Label
var boss_bar: ProgressBar
var boss_title: Label
var hero_hp := MAX_HP
var potions := 5
var won := false

func _ready() -> void:
    ui_root = Control.new()
    ui_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    ui_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_child(ui_root)

    area_title = Label.new()
    area_title.text = "ORVETHRA · Забытые катакомбы"
    area_title.add_theme_font_size_override("font_size", 20)
    area_title.add_theme_color_override("font_color", Color("efd3b1"))
    ui_root.add_child(area_title)
    tip = Label.new()
    tip.text = "Зал Асуры: босс патрулирует и атакует с близкого расстояния"
    tip.add_theme_font_size_override("font_size", 15)
    tip.add_theme_color_override("font_color", Color("d2c9ba"))
    ui_root.add_child(tip)

    health_bar = _progress(Color("a72e31"))
    health_text = _label("HP 120 / 120", 17)
    boss_bar = _progress(Color("973342"))
    boss_title = _label("АСУРА · БОСС", 17)
    boss_bar.visible = false
    boss_title.visible = false

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
    attack_button = _button("⚔\nУДАР")
    attack_button.pressed.connect(func() -> void:
        if game != null:
            game._try_attack()
    )
    potion_button = _button("✦\n" + str(potions))
    potion_button.pressed.connect(_drink_potion)

    get_viewport().size_changed.connect(_layout)
    _layout()
    _refresh_health()

func _label(value: String, font_size: int) -> Label:
    var label := Label.new()
    label.text = value
    label.add_theme_font_size_override("font_size", font_size)
    label.add_theme_color_override("font_color", Color("f1e0d0"))
    ui_root.add_child(label)
    return label

func _progress(color: Color) -> ProgressBar:
    var bar := ProgressBar.new()
    bar.min_value = 0.0
    bar.max_value = 100.0
    bar.value = 100.0
    bar.show_percentage = false
    var back := StyleBoxFlat.new()
    back.bg_color = Color(0.1, 0.10, 0.12, 0.9)
    var fill := StyleBoxFlat.new()
    fill.bg_color = color
    bar.add_theme_stylebox_override("background", back)
    bar.add_theme_stylebox_override("fill", fill)
    ui_root.add_child(bar)
    return bar

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
    area_title.position = Vector2(18, 7)
    area_title.size = Vector2(view.x - 40, 30)
    tip.position = Vector2(18, 78)
    tip.size = Vector2(view.x - 36, 29)
    health_bar.position = Vector2(20, 45)
    health_bar.size = Vector2(220, 19)
    health_text.position = Vector2(27, 42)
    health_text.size = Vector2(210, 25)
    boss_title.position = Vector2(view.x * 0.35, 10)
    boss_title.size = Vector2(view.x * 0.3, 25)
    boss_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    boss_bar.position = Vector2(view.x * 0.35, 37)
    boss_bar.size = Vector2(view.x * 0.3, 20)
    joystick.position = Vector2(20, view.y - 222)
    joystick.size = Vector2(176, 176)
    joystick.scale = Vector2(0.83, 0.83) if view.x < view.y else Vector2.ONE
    exit_button.position = Vector2(view.x - 235, 16)
    exit_button.size = Vector2(214, 45)
    camera_near.position = Vector2(view.x - 220, view.y - 71)
    camera_near.size = Vector2(98, 45)
    camera_far.position = Vector2(view.x - 116, view.y - 71)
    camera_far.size = Vector2(98, 45)
    attack_button.position = Vector2(view.x - 137, view.y - 205)
    attack_button.size = Vector2(114, 108)
    potion_button.position = Vector2(view.x - 233, view.y - 173)
    potion_button.size = Vector2(80, 79)

func _process(_delta: float) -> void:
    if game == null:
        return
    if exit_button != null:
        exit_button.visible = game._near_exit_marker()
    if game.player == null or game.asura_boss == null:
        return
    var boss = game.asura_boss
    var player_p := Vector2(game.player.position.x, game.player.position.z)
    var nearby := player_p.distance_to(Vector2(-17.0, -47.5)) < 16.0
    boss_bar.visible = nearby
    boss_title.visible = nearby
    if nearby:
        boss_bar.value = float(boss.hp) * 100.0 / float(boss.MAX_HP)
        boss_title.text = "АСУРА · БОСС  " + str(boss.hp) + "/" + str(boss.MAX_HP)

func _refresh_health() -> void:
    if health_bar != null:
        health_bar.value = float(hero_hp) * 100.0 / float(MAX_HP)
    if health_text != null:
        health_text.text = "HP  " + str(hero_hp) + " / " + str(MAX_HP)

func can_be_attacked() -> bool:
    return hero_hp > 0

func receive_boss_hit(damage: int) -> void:
    if hero_hp <= 0:
        return
    hero_hp = maxi(0, hero_hp - damage)
    _refresh_health()
    if hero_hp <= 0:
        hero_hp = MAX_HP
        _refresh_health()
        if game != null and game.player != null:
            game.player.position = game.DUNGEON_SPAWN
            game.player.velocity = Vector3.ZERO
        show_combat_message("Асура победил! Вы вернулись ко входу в катакомбы.")
    else:
        show_combat_message("Асура нанёс -" + str(damage) + " HP.  Осталось " + str(hero_hp) + "/" + str(MAX_HP))

func _drink_potion() -> void:
    if potions < 1:
        show_combat_message("Зелья закончились.")
        return
    if hero_hp >= MAX_HP:
        show_combat_message("У вас полное здоровье.")
        return
    hero_hp = mini(MAX_HP, hero_hp + 30)
    potions -= 1
    potion_button.text = "✦\n" + str(potions)
    _refresh_health()
    show_combat_message("Зелье: +30 HP. Осталось " + str(potions) + ".")

func on_asura_victory() -> void:
    if won:
        return
    won = true
    show_combat_message("Асура повержен! Босс побеждён.")
    # Loot and quest persistence will be added with the actual dungeon inventory.

func is_popup_open() -> bool:
    return false

func show_combat_message(message: String) -> void:
    if tip != null:
        tip.text = message

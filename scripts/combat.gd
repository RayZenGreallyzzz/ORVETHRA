extends Node3D

# ORVETHRA 0.6 — lightweight offline tab-target combat for the IT-801C smoke test.
# All currency and progress here are local test data, not paid or online balances.
const SAVE_PATH := "user://orvethra_training.json"
const RESPAWN_SECONDS := 9.0
const STRIKE_DISTANCE := 5.5
var hero: CharacterBody3D
var view_camera: Camera3D
var enemies: Array[Dictionary] = []
var selected: int = -1
var hp: int = 100
var max_hp: int = 100
var level: int = 1
var exp_points: int = 0
var silver: int = 0
var elapsed: float = 0.0
var last_attack: float = -9.0
var target_label: Label
var status_label: Label
var tip_label: Label
var attack_button: Button
var event_label: Label
var event_until: float = 0.0

func _ready() -> void:
    hero = get_parent().get("hero") as CharacterBody3D
    view_camera = get_parent().get("camera") as Camera3D
    if hero == null or view_camera == null:
        push_error("ORVETHRA combat requires town hero and camera")
        return
    _load()
    _make_clearing()
    _spawn_enemy(Vector3(15, 0, 19), "Лесной слизень", 1, "527a65")
    _spawn_enemy(Vector3(24, 0, 25), "Лесной слизень", 1, "668557")
    _spawn_enemy(Vector3(29, 0, 14), "Моховой жук", 2, "6f6950")
    _hud()
    _message("Тренировочная поляна справа от улицы — выбери существо.")

func _mat(hex: String) -> StandardMaterial3D:
    var m := StandardMaterial3D.new()
    m.albedo_color = Color(hex)
    m.roughness = 0.92
    return m

func _block(parent: Node3D, pos: Vector3, dims: Vector3, hex: String) -> void:
    var m := MeshInstance3D.new()
    var mesh := BoxMesh.new()
    mesh.size = dims
    m.mesh = mesh
    m.position = pos
    m.material_override = _mat(hex)
    parent.add_child(m)

func _ball(parent: Node3D, pos: Vector3, scale: Vector3, hex: String) -> void:
    var obj := MeshInstance3D.new()
    var mesh := SphereMesh.new()
    mesh.radius = 0.5
    mesh.height = 1.0
    mesh.radial_segments = 10
    mesh.rings = 5
    obj.mesh = mesh
    obj.position = pos
    obj.scale = scale
    obj.material_override = _mat(hex)
    parent.add_child(obj)

func _make_clearing() -> void:
    # No extra lights, shadows or downloaded assets.
    _block(self, Vector3(19, 0.08, 22), Vector3(24, 0.14, 6), "8f8b78")
    _block(self, Vector3(28, 0.08, 20), Vector3(12, 0.14, 18), "728160")
    for z in [12.0, 17.0, 30.0]:
        _block(self, Vector3(35.0, 0.55, z), Vector3(0.19, 1.1, 0.19), "6d5842")
    _block(self, Vector3(35.0, 0.75, 21), Vector3(0.1, 0.13, 20), "6d5842")
    var sign := Label3D.new()
    sign.text = "ТРЕНИРОВОЧНАЯ ПОЛЯНА"
    sign.position = Vector3(22.0, 2.8, 26)
    sign.font_size = 62
    sign.pixel_size = 0.0045
    sign.billboard = BaseMaterial3D.BILLBOARD_ENABLED
    sign.modulate = Color("eee1bb")
    add_child(sign)

func _spawn_enemy(where: Vector3, name_text: String, rank: int, hex: String) -> void:
    var body := Area3D.new()
    body.name = "Enemy_" + str(enemies.size())
    body.position = where + Vector3(0, 0.78, 0)
    body.collision_layer = 2
    body.collision_mask = 0
    add_child(body)
    var shape_node := CollisionShape3D.new()
    var shape := SphereShape3D.new()
    shape.radius = 0.91
    shape_node.shape = shape
    body.add_child(shape_node)
    _ball(body, Vector3.ZERO, Vector3(1.7, 1.15, 1.45), hex)
    _ball(body, Vector3(-0.30, 0.18, -0.58), Vector3(0.21, 0.28, 0.18), "f3e0ac")
    _ball(body, Vector3(0.30, 0.18, -0.58), Vector3(0.21, 0.28, 0.18), "f3e0ac")
    var nameplate := Label3D.new()
    nameplate.text = name_text + " · ур. " + str(rank)
    nameplate.position = Vector3(0, 1.35, 0)
    nameplate.font_size = 48
    nameplate.pixel_size = 0.004
    nameplate.billboard = BaseMaterial3D.BILLBOARD_ENABLED
    nameplate.modulate = Color("ede2cc")
    body.add_child(nameplate)
    var ring := MeshInstance3D.new()
    var ring_mesh := CylinderMesh.new()
    ring_mesh.top_radius = 1.05
    ring_mesh.bottom_radius = 1.05
    ring_mesh.height = 0.06
    ring_mesh.radial_segments = 14
    ring.mesh = ring_mesh
    ring.position = Vector3(0, -0.74, 0)
    ring.visible = false
    ring.material_override = _mat("c9a35d")
    body.add_child(ring)
    var health := 25 + rank * 10
    enemies.append({"node": body, "ring": ring, "name": name_text, "rank": rank, "hp": health, "max_hp": health, "alive": true, "revive": 0.0, "last_hit": -10.0, "home": body.position})

func _styled_button(text_value: String, callback: Callable, highlighted: bool = false) -> Button:
    var btn := Button.new()
    btn.text = text_value
    btn.custom_minimum_size = Vector2(112, 60)
    btn.focus_mode = Control.FOCUS_NONE
    btn.add_theme_font_size_override("font_size", 20)
    var normal := StyleBoxFlat.new()
    normal.bg_color = Color("21475d") if highlighted else Color("373837")
    normal.border_color = Color("d9b77e")
    normal.set_border_width_all(2)
    normal.set_corner_radius_all(10)
    btn.add_theme_stylebox_override("normal", normal)
    btn.add_theme_color_override("font_color", Color("f4e4c4"))
    btn.pressed.connect(callback)
    return btn

func _hud() -> void:
    var layer := CanvasLayer.new()
    add_child(layer)
    var root := Control.new()
    root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    root.mouse_filter = Control.MOUSE_FILTER_IGNORE
    layer.add_child(root)
    status_label = Label.new()
    status_label.position = Vector2(16, 82)
    status_label.add_theme_font_size_override("font_size", 18)
    status_label.add_theme_color_override("font_color", Color("f6e8cb"))
    root.add_child(status_label)
    target_label = Label.new()
    target_label.set_anchors_preset(Control.PRESET_TOP_RIGHT)
    target_label.offset_left = -330
    target_label.offset_right = -10
    target_label.offset_top = 67
    target_label.offset_bottom = 115
    target_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
    target_label.add_theme_font_size_override("font_size", 18)
    target_label.add_theme_color_override("font_color", Color("f2d1a3"))
    root.add_child(target_label)
    tip_label = Label.new()
    tip_label.position = Vector2(16, 113)
    tip_label.text = "Тренировка справа от улицы · цель: нажми на существо"
    tip_label.add_theme_font_size_override("font_size", 14)
    root.add_child(tip_label)
    event_label = Label.new()
    event_label.set_anchors_preset(Control.PRESET_TOP_WIDE)
    event_label.offset_top = 140
    event_label.offset_bottom = 170
    event_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    event_label.add_theme_color_override("font_color", Color("ffdb93"))
    event_label.add_theme_font_size_override("font_size", 20)
    root.add_child(event_label)
    var bar := HBoxContainer.new()
    bar.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
    bar.offset_left = -620
    bar.offset_right = -288
    bar.offset_top = -87
    bar.offset_bottom = -14
    bar.add_theme_constant_override("separation", 8)
    root.add_child(bar)
    bar.add_child(_styled_button("Выбрать", func(): _pick_nearest()))
    attack_button = _styled_button("Удар", func(): _attack(), true)
    bar.add_child(attack_button)
    bar.add_child(_styled_button("Меню", func(): _return_menu()))
    _refresh_labels()

func _unhandled_input(event: InputEvent) -> void:
    if view_camera == null:
        return
    if event is InputEventScreenTouch and event.pressed:
        _pick_screen(event.position)
    elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
        _pick_screen(event.position)

func _pick_screen(screen_position: Vector2) -> void:
    var ray_origin := view_camera.project_ray_origin(screen_position)
    var ray_end := ray_origin + view_camera.project_ray_normal(screen_position) * 150.0
    var query := PhysicsRayQueryParameters3D.create(ray_origin, ray_end, 2)
    query.collide_with_areas = true
    query.collide_with_bodies = false
    var hit := get_world_3d().direct_space_state.intersect_ray(query)
    if hit.is_empty():
        return
    for i in enemies.size():
        if enemies[i]["node"] == hit["collider"] and bool(enemies[i]["alive"]):
            _set_target(i)
            return

func _pick_nearest() -> void:
    var closest := 999999.0
    var found := -1
    for i in enemies.size():
        var mob: Dictionary = enemies[i]
        if not bool(mob["alive"]):
            continue
        var node: Area3D = mob["node"]
        var d := hero.global_position.distance_to(node.global_position)
        if d < closest:
            found = i
            closest = d
    if found >= 0:
        _set_target(found)
    else:
        _message("Пока никого нет. Существа вскоре вернутся.")

func _set_target(idx: int) -> void:
    selected = idx
    for i in enemies.size():
        var ring: MeshInstance3D = enemies[i]["ring"]
        ring.visible = i == selected and bool(enemies[i]["alive"])
    _refresh_labels()

func _attack() -> void:
    if elapsed - last_attack < 0.9:
        return
    if selected < 0 or selected >= enemies.size() or not bool(enemies[selected]["alive"]):
        _pick_nearest()
    if selected < 0 or not bool(enemies[selected]["alive"]):
        return
    var mob: Dictionary = enemies[selected]
    var body: Area3D = mob["node"]
    var d := hero.global_position.distance_to(body.global_position)
    if d > STRIKE_DISTANCE:
        _message("Подойди ближе к цели (не дальше 5 м).")
        return
    last_attack = elapsed
    var damage := 8 + 2 * level
    mob["hp"] = maxi(0, int(mob["hp"]) - damage)
    if int(mob["hp"]) == 0:
        _win(selected)
    else:
        _message("Попадание! Урон: " + str(damage))
    _refresh_labels()

func _win(idx: int) -> void:
    var mob: Dictionary = enemies[idx]
    mob["alive"] = false
    mob["revive"] = elapsed + RESPAWN_SECONDS
    var body: Area3D = mob["node"]
    body.visible = false
    body.monitorable = false
    var earned := 12 + int(mob["rank"]) * 7
    exp_points += earned
    silver += 4 + int(mob["rank"]) * 2
    var levels_up := false
    while exp_points >= level * 40:
        exp_points -= level * 40
        level += 1
        max_hp += 10
        hp = max_hp
        levels_up = true
    _save()
    _message(("Новый уровень! " if levels_up else "Победа! ") + "+" + str(earned) + " опыта, +" + str(4 + int(mob["rank"]) * 2) + " серебра")
    selected = -1

func _message(message: String) -> void:
    if event_label != null:
        event_label.text = message
        event_until = elapsed + 3.6

func _process(delta: float) -> void:
    if hero == null:
        return
    elapsed += delta
    for i in enemies.size():
        var mob: Dictionary = enemies[i]
        var body: Area3D = mob["node"]
        if bool(mob["alive"]):
            var home: Vector3 = mob["home"]
            body.position = home + Vector3(0, sin(elapsed * 2.0 + float(i)) * 0.07, 0)
            if hero.global_position.distance_to(body.global_position) < 2.1 and elapsed - float(mob["last_hit"]) >= 2.6:
                mob["last_hit"] = elapsed
                hp = maxi(0, hp - 7 - int(mob["rank"]))
                if hp == 0:
                    hero.global_position = Vector3(0, 0.3, 24)
                    hp = max_hp
                    _message("Ты вернулся в город и восстановил силы.")
                    selected = -1
        elif elapsed >= float(mob["revive"]):
            mob["hp"] = mob["max_hp"]
            mob["alive"] = true
            body.visible = true
            body.monitorable = true
    if event_label != null and elapsed > event_until:
        event_label.text = ""
    _refresh_labels()

func _refresh_labels() -> void:
    if status_label == null or target_label == null:
        return
    status_label.text = "Ур. %d   HP %d/%d   Опыт %d/%d   Серебро %d" % [level, hp, max_hp, exp_points, level * 40, silver]
    if selected < 0 or selected >= enemies.size() or not bool(enemies[selected]["alive"]):
        target_label.text = "Цель не выбрана"
        return
    var mob: Dictionary = enemies[selected]
    target_label.text = "%s · ур. %d\nHP %d/%d" % [str(mob["name"]), int(mob["rank"]), int(mob["hp"]), int(mob["max_hp"])]

func _save() -> void:
    var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
    if file == null:
        return
    file.store_string(JSON.stringify({"level": level, "xp": exp_points, "silver": silver, "max_hp": max_hp}))
    file.close()

func _load() -> void:
    if not FileAccess.file_exists(SAVE_PATH):
        return
    var result: Variant = JSON.parse_string(FileAccess.get_file_as_string(SAVE_PATH))
    if result is Dictionary:
        level = clampi(int(result.get("level", 1)), 1, 100)
        exp_points = maxi(0, int(result.get("xp", 0)))
        silver = maxi(0, int(result.get("silver", 0)))
        max_hp = clampi(int(result.get("max_hp", 100)), 100, 1100)
        hp = max_hp

func _return_menu() -> void:
    _save()
    get_tree().change_scene_to_file("res://scenes/main_menu.tscn")

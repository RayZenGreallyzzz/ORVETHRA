extends Node3D

# Local/offline ORVETHRA city layout editor. Buildings are saved as transforms,
# not baked into the city scene, so existing roads/quests remain untouched.
const SAVE_PATH := "user://orvethra_city_layout_v1.json"
const PACK_PATH := "res://ORVETHRA_5_Buildings_Android_Optimized.zip"
const ASSET_DIR := "res://assets/city/buildings/"
const LIMIT := 70
const GRID := 0.5
const ORDER := ["auction", "blacksmith", "tavern", "manor", "village"]
const PREFABS := {
    "auction": {"name": "Аукцион", "file": "auction_hall_mobile.glb", "width": 13.0},
    "blacksmith": {"name": "Кузница", "file": "blacksmith_mobile.glb", "width": 11.0},
    "tavern": {"name": "Таверна", "file": "tavern_mobile.glb", "width": 12.0},
    "manor": {"name": "Особняк", "file": "ivyglow_manor_mobile.glb", "width": 12.0},
    "village": {"name": "Деревенские дома", "file": "enchanted_ivy_village_mobile.glb", "width": 13.0}
}
var game
var active := false
var previous_overview := false
var previous_height := 185.0
var previous_center := Vector2.ZERO
var saved: Array[Dictionary] = []
var nodes: Array[Node3D] = []
var history: Array = []
var loaded_scenes := {}
var loaded_bounds := {}
var draft: Node3D
var draft_data: Dictionary = {}
var editing := -1
var is_valid := false
var hud_layer: CanvasLayer
var ui: Control
var palette_panel: PanelContainer
var bottom_panel: PanelContainer
var hint: Label
var press_id := -1
var last_pointer := Vector2.ZERO
var total_drag := 0.0
var tint_ok: StandardMaterial3D
var tint_no: StandardMaterial3D

func _ready() -> void:
    name = "ORVETHRAWorldBuilder"
    tint_ok = _tint(Color(0.10, 0.89, 0.56, 0.27))
    tint_no = _tint(Color(1.0, 0.20, 0.15, 0.38))
    _load_layout()
    _rebuild()
    _create_ui()
    _ui_visible(false)

func _tint(color: Color) -> StandardMaterial3D:
    var mat := StandardMaterial3D.new()
    mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    mat.albedo_color = color
    return mat

func _type_name(key: String) -> String:
    return str(PREFABS[key]["name"]) if PREFABS.has(key) else "Неизвестное здание"

func _scene(key: String):
    if loaded_scenes.has(key):
        return loaded_scenes[key]
    var path := ASSET_DIR + str(PREFABS[key]["file"])
    if ResourceLoader.exists(path):
        var res = load(path)
        if res is PackedScene:
            loaded_scenes[key] = res
            return res
    loaded_scenes[key] = null
    return null

func _mesh_corners(root: Node3D, node: Node, out: Array[Vector3]) -> void:
    if node is MeshInstance3D:
        var item := node as MeshInstance3D
        if item.mesh != null:
            var box := item.mesh.get_aabb()
            var relative := root.global_transform.affine_inverse() * item.global_transform
            for x in range(2):
                for y in range(2):
                    for z in range(2):
                        var p := box.position + Vector3(box.size.x * x, box.size.y * y, box.size.z * z)
                        out.append(relative * p)
    for child in node.get_children():
        _mesh_corners(root, child, out)

func _preview_model(key: String) -> Node3D:
    var source = _scene(key)
    if source is PackedScene:
        var model = source.instantiate()
        if model is Node3D:
            # Compute dimensions only once per prefab, independent of copies.
            if not loaded_bounds.has(key):
                add_child(model)
                var points: Array[Vector3] = []
                _mesh_corners(model, model, points)
                remove_child(model)
                if not points.is_empty():
                    var low: Vector3 = points[0]
                    var high: Vector3 = points[0]
                    for p in points:
                        low = low.min(p)
                        high = high.max(p)
                    loaded_bounds[key] = {"low": low, "high": high}
            if loaded_bounds.has(key):
                var lo: Vector3 = loaded_bounds[key]["low"]
                var hi: Vector3 = loaded_bounds[key]["high"]
                var size: Vector3 = hi - lo
                var factor := clampf(float(PREFABS[key]["width"]) / maxf(0.01, maxf(size.x, size.z)), 0.1, 50.0)
                model.scale = Vector3.ONE * factor
                model.position = Vector3(-(lo.x + hi.x) * 0.5, -lo.y, -(lo.z + hi.z) * 0.5) * factor
            return model
    # Explicitly marked proxy when optional GLBs have not been uploaded yet.
    var fallback := Node3D.new()
    fallback.name = "TEMPORARY_PROXY_" + key
    var w := float(PREFABS[key]["width"])
    var base := MeshInstance3D.new()
    var mesh := BoxMesh.new()
    mesh.size = Vector3(w, w * 0.55, w * 0.75)
    base.mesh = mesh
    base.position.y = mesh.size.y * 0.5
    var stone := StandardMaterial3D.new()
    stone.albedo_color = Color("7b796d")
    base.material_override = stone
    fallback.add_child(base)
    var roof := MeshInstance3D.new()
    var slab := BoxMesh.new()
    slab.size = Vector3(w * 1.09, w * 0.13, w * 0.83)
    roof.mesh = slab
    roof.position.y = w * 0.62
    var roof_mat := StandardMaterial3D.new()
    roof_mat.albedo_color = Color("75554b")
    roof.material_override = roof_mat
    fallback.add_child(roof)
    var label := Label3D.new()
    label.text = "МАКЕТ · " + _type_name(key)
    label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
    label.position.y = w * 0.82
    label.font_size = 21
    label.pixel_size = 0.013
    fallback.add_child(label)
    return fallback

func _highlight(node: Node, material: Material) -> void:
    if node is MeshInstance3D:
        (node as MeshInstance3D).material_overlay = material
    for child in node.get_children():
        _highlight(child, material)

func _new_entry(key: String, p: Vector2, angle: float = 0.0, size: float = 1.0) -> Dictionary:
    return {"type": key, "x": p.x, "z": p.y, "angle": angle, "size": size}

func _make_instance(entry: Dictionary, ghost: bool) -> Node3D:
    var obj := Node3D.new()
    obj.name = "Placed_" + str(entry["type"])
    add_child(obj)
    var model := _preview_model(str(entry["type"]))
    obj.add_child(model)
    # One simple collision hull rather than expensive per-triangle collision.
    var body := StaticBody3D.new()
    body.name = "SimpleBuildingCollision"
    obj.add_child(body)
    var shape := CollisionShape3D.new()
    var hull := BoxShape3D.new()
    var w := float(PREFABS[str(entry["type"])]["width"])
    hull.size = Vector3(w * 0.9, w * 0.55, w * 0.68)
    shape.shape = hull
    shape.position.y = hull.size.y * 0.5
    body.add_child(shape)
    _apply_entry(obj, entry)
    body.collision_layer = 0 if ghost else 1
    body.collision_mask = 0 if ghost else 1
    if ghost:
        _highlight(obj, tint_ok)
    return obj

func _apply_entry(obj: Node3D, entry: Dictionary) -> void:
    obj.position = Vector3(float(entry["x"]), 0.0, float(entry["z"]))
    obj.rotation.y = deg_to_rad(float(entry["angle"]))
    obj.scale = Vector3.ONE * clampf(float(entry["size"]), 0.5, 2.0)

func _load_layout() -> void:
    if not FileAccess.file_exists(SAVE_PATH):
        return
    var parsed = JSON.parse_string(FileAccess.get_file_as_string(SAVE_PATH))
    if not parsed is Dictionary or int(parsed.get("version", 0)) != 1:
        return
    var items = parsed.get("buildings", [])
    if not items is Array:
        return
    for d in items:
        if not d is Dictionary or not PREFABS.has(str(d.get("type", ""))):
            continue
        var x := float(d.get("x", 0.0))
        var z := float(d.get("z", 0.0))
        var a := float(d.get("angle", 0.0))
        var s := float(d.get("size", 1.0))
        if not is_finite(x) or not is_finite(z) or not is_finite(a) or not is_finite(s):
            continue
        if absf(x) > game.MAP_HALF_X - 4.0 or absf(z) > game.MAP_HALF_Z - 4.0:
            continue
        saved.append(_new_entry(str(d["type"]), Vector2(x, z), fposmod(a, 360.0), clampf(s, 0.5, 2.0)))
        if saved.size() >= LIMIT:
            break

func _save_layout() -> bool:
    var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
    if file == null:
        return false
    file.store_string(JSON.stringify({"version": 1, "buildings": saved}, "  "))
    file.close()
    return true

func _rebuild() -> void:
    for obj in nodes:
        if is_instance_valid(obj):
            obj.queue_free()
    nodes.clear()
    for d in saved:
        nodes.append(_make_instance(d, false))

func _push_history() -> void:
    history.append(saved.duplicate(true))
    if history.size() > 16:
        history.pop_front()

func set_active(enabled: bool) -> void:
    if active == enabled:
        return
    cancel()
    active = enabled
    _ui_visible(enabled)
    if game.city_hud != null:
        game.city_hud.root.visible = not enabled
    if enabled:
        previous_overview = game.overview
        previous_height = game.overview_height
        previous_center = game.overview_center
        game.overview = true
        game.overview_center = Vector2(game.player.position.x, game.player.position.z)
        game.overview_height = 65.0
        _say("РЕДАКТОР: выбери здание слева. Нажми на карту для размещения.")
    else:
        game.overview = previous_overview
        game.overview_height = previous_height
        game.overview_center = previous_center
        game.touch_id = -1
    game._update_camera()

func _create_ui() -> void:
    hud_layer = CanvasLayer.new()
    hud_layer.layer = 15
    add_child(hud_layer)
    ui = Control.new()
    ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
    hud_layer.add_child(ui)
    palette_panel = PanelContainer.new()
    ui.add_child(palette_panel)
    var scroll := ScrollContainer.new()
    scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
    palette_panel.add_child(scroll)
    var catalog := VBoxContainer.new()
    catalog.custom_minimum_size.x = 206
    scroll.add_child(catalog)
    for key in ORDER:
        var id: String = key
        _add_button(catalog, _type_name(id), func() -> void: begin(id))
    _add_button(catalog, "Выбрать на карте", func() -> void: _say("Коснись поставленного здания для редактирования."))
    hint = Label.new()
    hint.add_theme_font_size_override("font_size", 18)
    hint.add_theme_color_override("font_color", Color("f7dfb6"))
    hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    ui.add_child(hint)
    bottom_panel = PanelContainer.new()
    ui.add_child(bottom_panel)
    var controls := GridContainer.new()
    controls.columns = 6
    bottom_panel.add_child(controls)
    _add_button(controls, "Повернуть −", func() -> void: rotate_by(-15.0))
    _add_button(controls, "Повернуть +", func() -> void: rotate_by(15.0))
    _add_button(controls, "Размер −", func() -> void: scale_by(-0.1))
    _add_button(controls, "Размер +", func() -> void: scale_by(0.1))
    _add_button(controls, "Камера +", func() -> void: zoom(-10.0))
    _add_button(controls, "Камера −", func() -> void: zoom(10.0))
    _add_button(controls, "✓ Закрепить", confirm)
    _add_button(controls, "Копировать", func() -> void: copy_selected(false))
    _add_button(controls, "Рядом", func() -> void: copy_selected(true))
    _add_button(controls, "Удалить", delete_selected)
    _add_button(controls, "↶ Отменить", undo)
    _add_button(controls, "Сохранить", manual_save)
    _add_button(controls, "Снять выбор", cancel)
    _add_button(controls, "Выйти", func() -> void: set_active(false))
    get_viewport().size_changed.connect(_layout_ui)
    _layout_ui()

func _add_button(parent: Node, title: String, callback: Callable) -> void:
    var b := Button.new()
    b.text = title
    b.custom_minimum_size = Vector2(87.0, 42.0)
    b.add_theme_font_size_override("font_size", 14)
    b.focus_mode = Control.FOCUS_NONE
    b.pressed.connect(callback)
    parent.add_child(b)

func _layout_ui() -> void:
    if ui == null:
        return
    var viewport_size := get_viewport().get_visible_rect().size
    palette_panel.position = Vector2(8.0, 14.0)
    palette_panel.size = Vector2(225.0, maxf(120.0, minf(viewport_size.y - 220.0, 330.0)))
    hint.position = Vector2(239.0, 16.0)
    hint.size = Vector2(maxf(100.0, viewport_size.x - 245.0), 79.0)
    bottom_panel.position = Vector2(4.0, viewport_size.y - 167.0)
    bottom_panel.size = Vector2(viewport_size.x - 8.0, 161.0)

func _ui_visible(value: bool) -> void:
    if hud_layer != null:
        hud_layer.visible = value

func _say(value: String) -> void:
    if hint != null:
        hint.text = value

func _inside(p: Vector2) -> bool:
    return absf(p.x) < game.MAP_HALF_X - 4.0 and absf(p.y) < game.MAP_HALF_Z - 4.0

func _point_segment_distance(p: Vector2, a: Vector2, b: Vector2) -> float:
    var segment := b - a
    var f := clampf((p - a).dot(segment) / maxf(segment.length_squared(), 0.001), 0.0, 1.0)
    return p.distance_to(a + segment * f)

func _position_ok(d: Dictionary, ignore_idx: int = -1) -> bool:
    var p := Vector2(float(d["x"]), float(d["z"]))
    var w := float(PREFABS[str(d["type"])]["width"]) * float(d["size"])
    var radius := w * 0.49
    if absf(p.x) + radius > game.MAP_HALF_X - 1.5 or absf(p.y) + radius > game.MAP_HALF_Z - 1.5:
        return false
    if p.length() < radius + 18.5: # protect central fountain/plaza
        return false
    if p.distance_to(Vector2(90.0, 94.0)) < radius + 10.0: # crypt
        return false
    # Preserve existing cobblestone roads, including side alleys.
    for road in game.roads:
        for i in range(road.size() - 1):
            if _point_segment_distance(p, road[i], road[i + 1]) < radius + 4.7:
                return false
    for i in range(saved.size()):
        if i == ignore_idx:
            continue
        var old: Dictionary = saved[i]
        var other := Vector2(float(old["x"]), float(old["z"]))
        var spacing := float(PREFABS[str(old["type"])]["width"]) * float(old["size"]) * 0.49
        if p.distance_to(other) < radius + spacing + 0.8:
            return false
    return true

func _refresh_preview() -> void:
    if draft == null:
        return
    is_valid = _position_ok(draft_data, editing)
    _apply_entry(draft, draft_data)
    _highlight(draft, tint_ok if is_valid else tint_no)

func begin(key: String) -> void:
    if not PREFABS.has(key):
        return
    cancel()
    if saved.size() >= LIMIT:
        _say("Достигнут предел: " + str(LIMIT) + " зданий.")
        return
    editing = -1
    draft_data = _new_entry(key, Vector2(game.overview_center.x, game.overview_center.y))
    draft = _make_instance(draft_data, true)
    _refresh_preview()
    _say(_type_name(key) + " · касанием укажи место. Зелёный — можно закрепить, красный — нельзя.")

func select_at(p: Vector2) -> void:
    var best := -1
    var distance := INF
    for i in range(saved.size()):
        var d: Dictionary = saved[i]
        var r := float(PREFABS[str(d["type"])]["width"]) * float(d["size"]) * 0.7
        var dist := p.distance_to(Vector2(float(d["x"]), float(d["z"])))
        if dist < minf(r, distance):
            best = i
            distance = dist
    if best < 0:
        _say("Здесь нет здания. Выбери его в каталоге или коснись установленного.")
        return
    cancel()
    editing = best
    draft_data = saved[best].duplicate(true)
    nodes[best].visible = false
    draft = _make_instance(draft_data, true)
    _refresh_preview()
    _say("Выбрано: " + _type_name(str(draft_data["type"])) + ". Двигай, копируй или удали.")

func copy_selected(next_to: bool) -> void:
    if draft == null:
        _say("Сначала выбери здание на карте или в каталоге.")
        return
    if saved.size() >= LIMIT:
        _say("Достигнут предел: " + str(LIMIT) + " зданий.")
        return
    var copy := draft_data.duplicate(true)
    if next_to:
        # Adjacent duplication lays out streets quickly but still requires
        # explicit user confirmation. Never mutate the original building.
        var offset := float(PREFABS[str(copy["type"])]["width"]) * float(copy["size"]) + 2.0
        copy["x"] = clampf(float(copy["x"]) + offset, -game.MAP_HALF_X + 5.0, game.MAP_HALF_X - 5.0)
    else:
        copy["x"] = clampf(float(copy["x"]) + 3.0, -game.MAP_HALF_X + 5.0, game.MAP_HALF_X - 5.0)
        copy["z"] = clampf(float(copy["z"]) + 3.0, -game.MAP_HALF_Z + 5.0, game.MAP_HALF_Z - 5.0)
    cancel()
    editing = -1
    draft_data = copy
    draft = _make_instance(draft_data, true)
    _refresh_preview()
    _say("КОПИЯ · оригинал остался! Перемести и нажми «Закрепить».")

func rotate_by(amount: float) -> void:
    if draft == null:
        _say("Выбери здание, чтобы повернуть.")
        return
    draft_data["angle"] = fposmod(float(draft_data["angle"]) + amount, 360.0)
    _refresh_preview()

func scale_by(amount: float) -> void:
    if draft == null:
        _say("Выбери здание, чтобы изменить размер.")
        return
    draft_data["size"] = snappedf(clampf(float(draft_data["size"]) + amount, 0.5, 2.0), 0.1)
    _refresh_preview()

func zoom(delta: float) -> void:
    game.overview_height = clampf(game.overview_height + delta, 18.0, 210.0)
    game._update_camera()

func confirm() -> void:
    if draft == null:
        _say("Сначала выбери здание.")
        return
    if not is_valid:
        _say("Красная модель: пересекает другое здание, дорогу или выходит за карту.")
        return
    _push_history()
    if editing >= 0:
        saved[editing] = draft_data.duplicate(true)
    else:
        saved.append(draft_data.duplicate(true))
    cancel()
    _rebuild()
    _say("Здание закреплено. " + ("Сохранено автоматически." if _save_layout() else "Не удалось записать файл!"))

func delete_selected() -> void:
    if editing < 0 or editing >= saved.size():
        _say("Чтобы удалить, сначала коснись уже закреплённого здания.")
        return
    _push_history()
    saved.remove_at(editing)
    cancel()
    _rebuild()
    _say("Здание удалено. " + ("Сохранено." if _save_layout() else "Ошибка сохранения."))

func cancel() -> void:
    if draft != null and is_instance_valid(draft):
        draft.queue_free()
    draft = null
    draft_data = {}
    if editing >= 0 and editing < nodes.size() and is_instance_valid(nodes[editing]):
        nodes[editing].visible = true
    editing = -1
    is_valid = false

func undo() -> void:
    cancel()
    if history.is_empty():
        _say("Пока нечего отменять.")
        return
    var previous: Array = history.pop_back()
    saved.clear()
    for d in previous:
        saved.append(d.duplicate(true))
    _rebuild()
    _save_layout()
    _say("Последнее изменение отменено.")

func manual_save() -> void:
    _say("Сохранено " + str(saved.size()) + " зданий." if _save_layout() else "Не удалось сохранить карту.")

func _world_at(screen: Vector2) -> Vector2:
    var cam: Camera3D = game.camera
    if cam == null:
        return Vector2.ZERO
    var plane := Plane(Vector3.UP, 0.0)
    var hit = plane.intersects_ray(cam.project_ray_origin(screen), cam.project_ray_normal(screen))
    if hit is Vector3:
        return Vector2(hit.x, hit.z)
    return Vector2.ZERO

func _tap(p: Vector2) -> void:
    var world := _world_at(p)
    if not _inside(world):
        _say("За границами карты размещать нельзя.")
        return
    if draft != null:
        draft_data["x"] = snappedf(world.x, GRID)
        draft_data["z"] = snappedf(world.y, GRID)
        _refresh_preview()
        _say("Перемещено: X " + str(draft_data["x"]) + " · Z " + str(draft_data["z"]) + (" · ✓ Закрепить" if is_valid else " · Место занято"))
    else:
        select_at(world)

func _pan(delta: Vector2) -> void:
    game.overview_center.x = clampf(game.overview_center.x - delta.x * game.overview_height * 0.0036, -game.MAP_HALF_X, game.MAP_HALF_X)
    game.overview_center.y = clampf(game.overview_center.y - delta.y * game.overview_height * 0.0036, -game.MAP_HALF_Z, game.MAP_HALF_Z)
    game._update_camera()

func _unhandled_input(event: InputEvent) -> void:
    if not active:
        return
    if event is InputEventScreenTouch:
        if event.pressed:
            if press_id == -1:
                press_id = event.index
                last_pointer = event.position
                total_drag = 0.0
        elif event.index == press_id:
            if total_drag < 12.0:
                _tap(event.position)
            press_id = -1
            get_viewport().set_input_as_handled()
    elif event is InputEventScreenDrag and event.index == press_id:
        total_drag += event.relative.length()
        if draft != null:
            var world := _world_at(event.position)
            if _inside(world):
                draft_data["x"] = snappedf(world.x, GRID)
                draft_data["z"] = snappedf(world.y, GRID)
                _refresh_preview()
        else:
            _pan(event.relative)
        last_pointer = event.position
        get_viewport().set_input_as_handled()
    elif event is InputEventMouseButton:
        if event.button_index == MOUSE_BUTTON_LEFT:
            if event.pressed:
                last_pointer = event.position
                total_drag = 0.0
            else:
                if total_drag < 12.0:
                    _tap(event.position)
            get_viewport().set_input_as_handled()
        elif event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_UP:
            zoom(-6.0)
            get_viewport().set_input_as_handled()
        elif event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
            zoom(6.0)
            get_viewport().set_input_as_handled()
    elif event is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
        total_drag += event.relative.length()
        if draft != null:
            var world := _world_at(event.position)
            if _inside(world):
                draft_data["x"] = snappedf(world.x, GRID)
                draft_data["z"] = snappedf(world.y, GRID)
                _refresh_preview()
        else:
            _pan(event.relative)
        get_viewport().set_input_as_handled()

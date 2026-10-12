extends Node3D
# ORVETHRA Map Builder v0.1: landscape Android-first editor.
# Designed to protect low-end 4 GB devices. Not a promise against all driver crashes.
const MAX_OBJECTS := 70
const MAX_CUSTOM_MODELS := 4
const MAX_GLB_BYTES := 8 * 1024 * 1024
const MAX_TRIANGLES := 18000
const AUTOSAVE := "user://orvethra_autosave.json"
const ASSET_DIR := "user://orvethra_assets"
const OUTPUT_DIR := "user://orvethra_exports"
var cam: Camera3D
var objects_root: Node3D
var entries: Array[Dictionary] = []
var cached: Dictionary = {}
var selected := -1
var tool := "select"
var palette := "Дом"
var yaw := 0.68
var pitch := 0.83
var distance := 45.0
var focus := Vector3(0, 0, 0)
var touched: Dictionary = {}
var pressed_at: Dictionary = {}
var overlay: Control
var details: Label
var action_label: Label
var palette_choice: OptionButton
var export_dialog: FileDialog
var import_dialog: FileDialog
var map_dialog: FileDialog
var status_text := "Готово. Выбери объект и коснись земли."
var fps_clock := 0.0
var auto_clock := 0.0
var dirty := false
var exported_file := ""
var imported_asset := ""
var export_mode := "project"

func _ready() -> void:
    Engine.max_fps = 30
    DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_MAXIMIZED)
    DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(ASSET_DIR))
    DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
    _environment()
    objects_root = Node3D.new()
    objects_root.name = "WorldObjects"
    add_child(objects_root)
    cam = Camera3D.new()
    cam.current = true
    cam.fov = 65
    cam.near = 0.1
    cam.far = 180
    add_child(cam)
    _update_cam()
    _build_ui()
    _setup_dialogs()
    if FileAccess.file_exists(AUTOSAVE):
        _load_autosave()
    else:
        _insert("Дом", Vector3(-10, 0, -5))
        _insert("Кузница", Vector3(0, 0, -5))
        _insert("Лавка", Vector3(10, 0, -5))
        _insert("Дорога", Vector3(0, 0, 8))
        _save_auto()
    _refresh()

func _environment() -> void:
    var sky := WorldEnvironment.new()
    var env := Environment.new()
    env.background_mode = Environment.BG_COLOR
    env.background_color = Color("94a6ae")
    env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
    env.ambient_light_color = Color("bec7c2")
    env.ambient_light_energy = 0.85
    sky.environment = env
    add_child(sky)
    var sun := DirectionalLight3D.new()
    sun.rotation_degrees = Vector3(-50, -30, 0)
    sun.light_energy = 0.8
    sun.shadow_enabled = false
    add_child(sun)
    var ground := MeshInstance3D.new()
    var mesh := BoxMesh.new()
    mesh.size = Vector3(130, 0.12, 130)
    ground.mesh = mesh
    ground.material_override = _mat("738765")
    ground.position.y = -0.07
    add_child(ground)
    var grid := Node3D.new()
    grid.name = "GuideGrid"
    add_child(grid)
    for i in range(-12, 13):
        _piece(grid, Vector3(float(i) * 5, 0.01, 0), Vector3(0.035, 0.02, 125), "83927a")
        _piece(grid, Vector3(0, 0.01, float(i) * 5), Vector3(125, 0.02, 0.035), "83927a")

func _mat(value: String) -> StandardMaterial3D:
    var m := StandardMaterial3D.new()
    m.albedo_color = Color(value)
    m.roughness = 0.9
    return m

func _piece(root: Node3D, pos: Vector3, size: Vector3, color: String) -> void:
    var obj := MeshInstance3D.new()
    var mesh := BoxMesh.new()
    mesh.size = size
    obj.mesh = mesh
    obj.material_override = _mat(color)
    obj.position = pos
    root.add_child(obj)

func _create_shape(kind: String) -> Node3D:
    var root := Node3D.new()
    root.name = kind
    match kind:
        "Дом", "Кузница", "Лавка":
            _piece(root, Vector3(0, 1.9, 0), Vector3(6.8, 3.8, 6.3), "bca88e")
            _piece(root, Vector3(0, 4.0, 0), Vector3(7.8, 0.9, 7.1), "46596b" if kind != "Кузница" else "5a4e4b")
            _piece(root, Vector3(0, 1.2, 3.2), Vector3(1.25, 2.3, 0.1), "584a3a")
            for x in [-2.7, 2.7]:
                _piece(root, Vector3(x, 1.9, 3.22), Vector3(1.05, 1.15, 0.12), "83a4b0")
            _piece(root, Vector3(0, 3.6, 3.57), Vector3(3.0, 0.65, 0.15), "836344")
        "Дорога":
            _piece(root, Vector3(0, 0.035, 0), Vector3(7.5, 0.07, 14), "9a9689")
        "Дерево":
            _piece(root, Vector3(0, 1.5, 0), Vector3(0.65, 3.0, 0.7), "665242")
            _piece(root, Vector3(0, 4.0, 0), Vector3(3.7, 3.2, 3.3), "526f55")
        "Камень":
            _piece(root, Vector3(0, 0.6, 0), Vector3(2.0, 1.2, 1.8), "737d78")
        "Забор":
            _piece(root, Vector3(-1.9, 0.7, 0), Vector3(0.28, 1.4, 0.28), "775d47")
            _piece(root, Vector3(1.9, 0.7, 0), Vector3(0.28, 1.4, 0.28), "775d47")
            _piece(root, Vector3(0, 0.82, 0), Vector3(4.0, 0.23, 0.18), "82684b")
        "Ворота":
            for x in [-3.4, 3.4]:
                _piece(root, Vector3(x, 2.8, 0), Vector3(2.25, 5.6, 2.3), "959b9b")
            _piece(root, Vector3(0, 5.1, 0), Vector3(8.8, 1.4, 2.5), "858c8f")
        "Фонарь":
            _piece(root, Vector3(0, 1.6, 0), Vector3(0.2, 3.2, 0.2), "4f4d43")
            _piece(root, Vector3(0, 3.4, 0), Vector3(0.75, 0.65, 0.75), "e5bb78")
    return root

func _add_rendered(kind: String, asset: String, pos: Vector3, rot: float, scl: float) -> bool:
    if entries.size() >= MAX_OBJECTS:
        _notify("Ограничение %d объектов. Сохрани карту и раздели большую локацию на части." % MAX_OBJECTS)
        return false
    var instance: Node3D
    if kind == "GLB":
        if not cached.has(asset):
            if not _cache_asset(asset):
                return false
        instance = (cached[asset] as Node3D).duplicate()
    else:
        instance = _create_shape(kind)
    instance.position = pos
    instance.rotation.y = rot
    instance.scale = Vector3.ONE * scl
    objects_root.add_child(instance)
    entries.append({"kind": kind, "asset": asset, "pos": [pos.x, pos.y, pos.z], "yaw": rot, "scale": scl, "node": instance})
    _dirty()
    return true

func _insert(kind: String, pos: Vector3) -> void:
    var asset := imported_asset if kind == "GLB" else ""
    if _add_rendered(kind, asset, pos, 0.0, 1.0):
        selected = entries.size() - 1
        _refresh()

func _save_auto() -> void:
    var record := {"format": "ORVETHRA-MAP", "version": 1, "objects": []}
    for entry in entries:
        record["objects"].append({"kind": entry["kind"], "asset": entry["asset"], "pos": entry["pos"], "yaw": entry["yaw"], "scale": entry["scale"]})
    var file := FileAccess.open(AUTOSAVE, FileAccess.WRITE)
    if file != null:
        file.store_string(JSON.stringify(record))
        file.close()
        dirty = false

func _load_autosave() -> void:
    var value: Variant = JSON.parse_string(FileAccess.get_file_as_string(AUTOSAVE))
    if not value is Dictionary or value.get("format", "") != "ORVETHRA-MAP":
        _notify("Неверный файл автосохранения.")
        return
    _load_data(value)

func _load_data(value: Dictionary) -> void:
    for child in objects_root.get_children():
        objects_root.remove_child(child)
        child.queue_free()
    entries.clear()
    selected = -1
    for entry in value.get("objects", []):
        if not entry is Dictionary or entries.size() >= MAX_OBJECTS:
            break
        var loc: Array = entry.get("pos", [0, 0, 0])
        if loc.size() != 3:
            continue
        var position := Vector3(clampf(float(loc[0]), -60, 60), clampf(float(loc[1]), -10, 10), clampf(float(loc[2]), -60, 60))
        _add_rendered(str(entry.get("kind", "Дом")), str(entry.get("asset", "")), position, float(entry.get("yaw", 0.0)), clampf(float(entry.get("scale", 1)), 0.2, 3))
    _save_auto()
    _refresh()

func _dirty() -> void:
    dirty = true
    auto_clock = 0.0

func _count_triangles(node: Node) -> int:
    var total := 0
    if node is MeshInstance3D:
        var mi := node as MeshInstance3D
        if mi.mesh != null:
            for i in mi.mesh.get_surface_count():
                var arrays := mi.mesh.surface_get_arrays(i)
                var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
                total += int(indices.size() / 3) if not indices.is_empty() else int((arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).size() / 3)
    for c in node.get_children():
        total += _count_triangles(c)
    return total

func _cache_asset(asset: String) -> bool:
    var local := ASSET_DIR + "/" + asset
    if not FileAccess.file_exists(local):
        _notify("Файл модели отсутствует: " + asset)
        return false
    var size := FileAccess.get_file_as_bytes(local).size()
    if size == 0 or size > MAX_GLB_BYTES:
        _notify("Модель должна быть не больше 8 МБ.")
        return false
    var doc := GLTFDocument.new()
    var state := GLTFState.new()
    var err := doc.append_from_file(local, state)
    if err != OK:
        _notify("Не удалось открыть GLB: " + error_string(err))
        return false
    var source := doc.generate_scene(state)
    if source == null or not source is Node3D:
        _notify("В GLB не найдена 3D-сцена.")
        return false
    var tris := _count_triangles(source)
    if tris > MAX_TRIANGLES:
        source.free()
        _notify("Модель слишком сложная (%d треугольников). Максимум %d." % [tris, MAX_TRIANGLES])
        return false
    cached[asset] = source
    return true

func _import_glb(path: String) -> void:
    var f := FileAccess.open(path, FileAccess.READ)
    if f == null:
        _notify("Не удалось прочитать файл модели.")
        return
    var size := f.get_length()
    if size <= 0 or size > MAX_GLB_BYTES:
        f.close()
        _notify("Ограничение: одна GLB-модель не больше 8 МБ.")
        return
    var bytes := f.get_buffer(size)
    f.close()
    var hasher := HashingContext.new()
    hasher.start(HashingContext.HASH_SHA256)
    hasher.update(bytes)
    var name: String = hasher.finish().hex_encode().substr(0, 16) + ".glb"
    if not FileAccess.file_exists(ASSET_DIR + "/" + name):
        if cached.size() >= MAX_CUSTOM_MODELS:
            _notify("Пока поддерживается до 4 разных пользовательских моделей.")
            return
        var out := FileAccess.open(ASSET_DIR + "/" + name, FileAccess.WRITE)
        if out == null:
            _notify("Нет доступа к внутреннему хранилищу.")
            return
        out.store_buffer(bytes)
        out.close()
    if not _cache_asset(name):
        return
    imported_asset = name
    palette = "GLB"
    var found := palette_choice.get_item_count() - 1
    palette_choice.select(found)
    tool = "place"
    _notify("Модель принята. Коснись места на карте.")
    _refresh()

func _make_project(path: String) -> bool:
    _save_auto()
    var zip := ZIPPacker.new()
    var err := zip.open(path)
    if err != OK:
        _notify("Не удалось начать упаковку карты.")
        return false
    zip.start_file("world.json")
    zip.write_file(FileAccess.get_file_as_bytes(AUTOSAVE))
    zip.close_file()
    var found: Dictionary = {}
    for entry in entries:
        if entry["kind"] == "GLB":
            found[entry["asset"]] = true
    for name in found:
        zip.start_file("assets/" + name)
        zip.write_file(FileAccess.get_file_as_bytes(ASSET_DIR + "/" + name))
        zip.close_file()
    zip.close()
    return true

func _make_glb(path: String) -> bool:
    var state := GLTFState.new()
    var doc := GLTFDocument.new()
    var err := doc.append_from_scene(objects_root, state)
    if err != OK:
        _notify("Ошибка подготовки GLB: " + error_string(err))
        return false
    err = doc.write_to_filesystem(state, path)
    if err != OK:
        _notify("Ошибка сохранения GLB: " + error_string(err))
        return false
    return true

func _export(kind: String) -> void:
    export_mode = kind
    _save_auto()
    if kind == "project":
        exported_file = OUTPUT_DIR + "/ORVETHRA_World.orvmap"
        if not _make_project(exported_file):
            return
        export_dialog.filters = PackedStringArray(["*.orvmap ; ORVETHRA Map"])
        export_dialog.current_file = "ORVETHRA_World.orvmap"
    else:
        exported_file = OUTPUT_DIR + "/ORVETHRA_World.glb"
        if not _make_glb(exported_file):
            return
        export_dialog.filters = PackedStringArray(["*.glb ; GLB 3D model"])
        export_dialog.current_file = "ORVETHRA_World.glb"
    export_dialog.popup_centered_ratio(0.75)

func _on_export_path(path: String) -> void:
    var file := FileAccess.open(path, FileAccess.WRITE)
    if file == null:
        _notify("Нет доступа к выбранному месту сохранения. Оригинал остаётся внутри приложения.")
        return
    var bytes := FileAccess.get_file_as_bytes(exported_file)
    file.store_buffer(bytes)
    file.close()
    _notify("Экспорт завершён: " + path.get_file())

func _open_project(path: String) -> void:
    var f := FileAccess.open(path, FileAccess.READ)
    if f == null or f.get_length() > 45 * 1024 * 1024:
        _notify("Не удалось открыть карту или архив слишком велик.")
        return
    var bytes := f.get_buffer(f.get_length())
    f.close()
    var local := OUTPUT_DIR + "/incoming.orvmap"
    var outfile := FileAccess.open(local, FileAccess.WRITE)
    outfile.store_buffer(bytes)
    outfile.close()
    var zip := ZIPReader.new()
    if zip.open(local) != OK:
        _notify("Файл карты повреждён.")
        return
    if not zip.get_files().has("world.json"):
        zip.close()
        _notify("Нет world.json в файле.")
        return
    var data: Variant = JSON.parse_string(zip.read_file("world.json").get_string_from_utf8())
    if not data is Dictionary or data.get("format","") != "ORVETHRA-MAP":
        zip.close()
        _notify("Неподдерживаемая карта.")
        return
    var model_count := 0
    for filename in zip.get_files():
        if filename.begins_with("assets/") and filename.ends_with(".glb") and not filename.contains(".."):
            var raw := zip.read_file(filename)
            if raw.size() > MAX_GLB_BYTES:
                continue
            model_count += 1
            if model_count > MAX_CUSTOM_MODELS:
                break
            var out := FileAccess.open(ASSET_DIR + "/" + filename.get_file(), FileAccess.WRITE)
            if out:
                out.store_buffer(raw)
                out.close()
    zip.close()
    cached.clear()
    _load_data(data)
    _notify("Карта открыта. Все изменения автосохраняются.")

func _setup_dialogs() -> void:
    import_dialog = FileDialog.new()
    import_dialog.use_native_dialog = true
    import_dialog.access = FileDialog.ACCESS_FILESYSTEM
    import_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
    import_dialog.filters = PackedStringArray(["*.glb ; GLB 3D Model"])
    import_dialog.file_selected.connect(_import_glb)
    add_child(import_dialog)
    export_dialog = FileDialog.new()
    export_dialog.use_native_dialog = true
    export_dialog.access = FileDialog.ACCESS_FILESYSTEM
    export_dialog.file_mode = FileDialog.FILE_MODE_SAVE_FILE
    export_dialog.file_selected.connect(_on_export_path)
    add_child(export_dialog)
    map_dialog = FileDialog.new()
    map_dialog.use_native_dialog = true
    map_dialog.access = FileDialog.ACCESS_FILESYSTEM
    map_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
    map_dialog.filters = PackedStringArray(["*.orvmap ; ORVETHRA Map"])
    map_dialog.file_selected.connect(_open_project)
    add_child(map_dialog)

func _ui_button(parent: Node, title: String, call: Callable, color := "263b4f") -> Button:
    var b := Button.new()
    b.text = title
    b.custom_minimum_size = Vector2(0, 48)
    b.add_theme_font_size_override("font_size", 16)
    var sb := StyleBoxFlat.new()
    sb.bg_color = Color(color)
    sb.border_color = Color("c3a577")
    sb.set_border_width_all(1)
    sb.set_corner_radius_all(8)
    b.add_theme_stylebox_override("normal", sb)
    b.add_theme_color_override("font_color", Color("eee0ca"))
    b.pressed.connect(call)
    parent.add_child(b)
    return b

func _panel(pos: Vector2, size: Vector2) -> VBoxContainer:
    var panel := PanelContainer.new()
    panel.position = pos
    panel.custom_minimum_size = size
    var sb := StyleBoxFlat.new()
    sb.bg_color = Color(0.08, 0.11, 0.14, 0.93)
    sb.border_color = Color("98856a")
    sb.set_border_width_all(1)
    sb.set_corner_radius_all(10)
    panel.add_theme_stylebox_override("panel", sb)
    overlay.add_child(panel)
    var margin := MarginContainer.new()
    for edge in ["left","right","top","bottom"]:
        margin.add_theme_constant_override("margin_" + edge, 9)
    panel.add_child(margin)
    var col := VBoxContainer.new()
    col.add_theme_constant_override("separation", 5)
    margin.add_child(col)
    return col

func _text(parent: Node, label: String) -> Label:
    var item := Label.new()
    item.text = label
    item.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    item.add_theme_color_override("font_color", Color("f2e4c6"))
    item.add_theme_font_size_override("font_size", 16)
    parent.add_child(item)
    return item

func _build_ui() -> void:
    var layer := CanvasLayer.new()
    add_child(layer)
    overlay = Control.new()
    overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
    layer.add_child(overlay)
    var top := _panel(Vector2(12, 8), Vector2(1000, 56))
    var buttons := HBoxContainer.new()
    top.add_child(buttons)
    _ui_button(buttons, "ORVETHRA", func(): _notify("Редактор миров • v0.1"))
    _ui_button(buttons, "Модель GLB", func(): import_dialog.popup_centered_ratio(0.75))
    _ui_button(buttons, "Сохранить", func(): _save_auto(); _notify("Автосохранение обновлено"))
    _ui_button(buttons, "Открыть карту", func(): map_dialog.popup_centered_ratio(0.75))
    _ui_button(buttons, "Экспорт карты", func(): _export("project"), "32534a")
    _ui_button(buttons, "Экспорт GLB", func(): _export("glb"), "32534a")
    var left := _panel(Vector2(12, 88), Vector2(208, 390))
    _text(left, "БИБЛИОТЕКА")
    palette_choice = OptionButton.new()
    for item in ["Дом","Кузница","Лавка","Дорога","Дерево","Камень","Забор","Ворота","Фонарь","GLB"]:
        palette_choice.add_item(item)
    palette_choice.item_selected.connect(func(index: int): palette = palette_choice.get_item_text(index))
    left.add_child(palette_choice)
    _ui_button(left, "＋ Поставить", func(): tool = "place"; _refresh())
    _ui_button(left, "◎ Выбрать", func(): tool = "select"; _refresh())
    _ui_button(left, "↔ Переместить", func(): tool = "move"; _refresh())
    _ui_button(left, "Новая карта", func(): _clear_map())
    var right := _panel(Vector2(1037, 88), Vector2(220, 390))
    _text(right, "ОБЪЕКТ")
    details = _text(right, "Не выбран")
    _ui_button(right, "⟲ Повернуть −15°", func(): _adjust(0, -PI/12.0, 0))
    _ui_button(right, "⟳ Повернуть +15°", func(): _adjust(0, PI/12.0, 0))
    _ui_button(right, "Уменьшить", func(): _adjust(0, 0, -0.1))
    _ui_button(right, "Увеличить", func(): _adjust(0, 0, 0.1))
    _ui_button(right, "Копировать", func(): _duplicate())
    _ui_button(right, "Удалить", func(): _delete())
    var bottom := _panel(Vector2(12, 626), Vector2(1130, 69))
    action_label = _text(bottom, "Один палец — крутить камеру • два пальца — приблизить")
    action_label.add_theme_font_size_override("font_size", 15)

func _notify(message: String) -> void:
    status_text = message
    _refresh()

func _refresh() -> void:
    if details != null:
        if selected >= 0 and selected < entries.size():
            var selected_object: Dictionary = entries[selected]
            details.text = str(selected_object["kind"]) + "\n№ " + str(selected + 1) + " из " + str(entries.size()) + "\nМасштаб: " + ("%.1f" % float(selected_object["scale"]))
        else:
            details.text = "Не выбран\nОбъектов: " + str(entries.size())
    if action_label != null:
        action_label.text = status_text + "\nРежим: " + tool + " · Объектов: " + str(entries.size()) + "/" + str(MAX_OBJECTS)

func _clear_map() -> void:
    for child in objects_root.get_children():
        objects_root.remove_child(child)
        child.queue_free()
    entries.clear()
    selected = -1
    _save_auto()
    _notify("Новая карта создана. Автосохранение включено.")

func _adjust(dummy: int, rotation: float, growth: float) -> void:
    if selected < 0 or selected >= entries.size():
        _notify("Выбери объект на карте.")
        return
    var e: Dictionary = entries[selected]
    e["yaw"] = float(e["yaw"]) + rotation
    e["scale"] = clampf(float(e["scale"]) + growth, 0.2, 3.0)
    var n: Node3D = e["node"]
    n.rotation.y = e["yaw"]
    n.scale = Vector3.ONE * e["scale"]
    _dirty()
    _refresh()

func _duplicate() -> void:
    if selected < 0 or selected >= entries.size():
        return
    var e: Dictionary = entries[selected]
    var new_pos: Array = e["pos"]
    _add_rendered(e["kind"], e["asset"], Vector3(float(new_pos[0]) + 2, float(new_pos[1]), float(new_pos[2]) + 2), e["yaw"], e["scale"])
    selected = entries.size() - 1
    _refresh()

func _delete() -> void:
    if selected < 0 or selected >= entries.size():
        return
    var node: Node3D = entries[selected]["node"]
    objects_root.remove_child(node)
    node.queue_free()
    entries.remove_at(selected)
    selected = -1
    _dirty()
    _refresh()

func _update_cam() -> void:
    if cam == null:
        return
    pitch = clampf(pitch, 0.18, 1.47)
    distance = clampf(distance, 7, 94)
    cam.position = focus + Vector3(sin(yaw) * cos(pitch), sin(pitch), cos(yaw) * cos(pitch)) * distance
    cam.look_at(focus, Vector3.UP)

func _plane_hit(screen: Vector2) -> Variant:
    var from := cam.project_ray_origin(screen)
    var v := cam.project_ray_normal(screen)
    if absf(v.y) < 0.01:
        return null
    var t := -from.y / v.y
    if t <= 0:
        return null
    var point := from + v * t
    point.x = clampf(point.x, -60, 60)
    point.z = clampf(point.z, -60, 60)
    point.y = 0
    return point

func _pick(screen: Vector2) -> void:
    var best := 55.0
    var index := -1
    for i in entries.size():
        var e: Dictionary = entries[i]
        var n: Node3D = e["node"]
        var center := n.global_position + Vector3.UP * 1.5 * float(e["scale"])
        if cam.is_position_behind(center):
            continue
        var p := cam.unproject_position(center)
        var d := screen.distance_to(p)
        if d < best:
            best = d
            index = i
    selected = index
    _refresh()

func _tap(screen: Vector2) -> void:
    if tool == "select":
        _pick(screen)
        return
    var hit: Variant = _plane_hit(screen)
    if hit == null:
        return
    if tool == "place":
        if palette == "GLB" and imported_asset == "":
            _notify("Сначала импортируй модель GLB.")
            return
        _insert(palette, hit)
    elif tool == "move" and selected >= 0 and selected < entries.size():
        var e: Dictionary = entries[selected]
        var n: Node3D = e["node"]
        n.position = hit
        e["pos"] = [hit.x, hit.y, hit.z]
        _dirty()
        _refresh()

func _unhandled_input(event: InputEvent) -> void:
    if event is InputEventScreenTouch:
        if event.pressed:
            touched[event.index] = event.position
            pressed_at[event.index] = event.position
        else:
            if touched.has(event.index) and pressed_at.has(event.index):
                if (pressed_at[event.index] as Vector2).distance_to(event.position) < 17 and touched.size() == 1:
                    _tap(event.position)
            touched.erase(event.index)
            pressed_at.erase(event.index)
    elif event is InputEventScreenDrag:
        if touched.has(event.index):
            if touched.size() >= 2:
                var indices := touched.keys()
                var other_idx: int = indices[0] if indices[0] != event.index else indices[1]
                var other: Vector2 = touched[other_idx]
                var before: float = (touched[event.index] as Vector2).distance_to(other)
                var after: float = event.position.distance_to(other)
                distance -= (after - before) * 0.07
            else:
                yaw -= event.relative.x * 0.005
                pitch += event.relative.y * 0.005
            touched[event.index] = event.position
            _update_cam()
    elif event is InputEventMouseMotion:
        if Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
            yaw -= event.relative.x * 0.005
            pitch += event.relative.y * 0.005
            _update_cam()
    elif event is InputEventMouseButton:
        if event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
            distance *= 0.89
            _update_cam()
        elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
            distance *= 1.12
            _update_cam()
        elif event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
            _tap(event.position)

func _process(delta: float) -> void:
    if dirty:
        auto_clock += delta
        if auto_clock >= 1.5:
            _save_auto()
    fps_clock += delta
    if fps_clock >= 3.0:
        fps_clock = 0
        if Engine.get_frames_per_second() < 19 and entries.size() > 35:
            status_text = "Нагрузка высокая. Уменьши число объектов; изменения сохранены."
            _refresh()

func _notification(what: int) -> void:
    if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_APPLICATION_PAUSED:
        _save_auto()

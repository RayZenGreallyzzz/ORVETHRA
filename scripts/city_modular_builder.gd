extends Node3D

# ORVETHRA modular house editor v0.33.
# Runtime-generated original meshes; no external GLBs or network required.
# MultiMesh groups keep repeated parts inexpensive on Android Compatibility.
const TILE := 3.0
const STOREY := 3.2
const MAX_STOREY := 5
const MAX_PIECES := 360
const SAVE_FILE := "user://orvethra_modular_city_v1.json"
const PARTS := {
    "foundation": {"name": "Фундамент", "group": "Основание", "slot": "deck"},
    "stone_floor": {"name": "Пол · камень", "group": "Основание", "slot": "deck"},
    "wood_floor": {"name": "Пол · доски", "group": "Основание", "slot": "deck"},
    "ceiling": {"name": "Потолок", "group": "Основание", "slot": "ceiling"},
    "balcony": {"name": "Балкон · площадка", "group": "Основание", "slot": "deck"},
    "stone_wall": {"name": "Стена · камень", "group": "Стены", "slot": "wall"},
    "timber_wall": {"name": "Стена · фахверк", "group": "Стены", "slot": "wall"},
    "window_wall": {"name": "Стена с окном", "group": "Стены", "slot": "wall"},
    "door_wall": {"name": "Стена с дверью", "group": "Стены", "slot": "wall"},
    "arch": {"name": "Арка", "group": "Стены", "slot": "wall"},
    "railing": {"name": "Перила", "group": "Стены", "slot": "wall"},
    "roof_slope": {"name": "Крыша · скат", "group": "Крыша", "slot": "roof"},
    "roof_flat": {"name": "Крыша · плоская", "group": "Крыша", "slot": "roof"},
    "roof_ridge": {"name": "Крыша · конёк", "group": "Крыша", "slot": "ridge"},
    "stair": {"name": "Лестница", "group": "Детали", "slot": "stair"},
    "pillar": {"name": "Колонна", "group": "Детали", "slot": "pillar"},
    "chimney": {"name": "Дымоход", "group": "Детали", "slot": "chimney"}
}
const MATERIAL_COLORS := [
    "8b8779", "5a574f", "69452e", "d3bd94",
    "384a60", "77a9c1", "d1a866"
]
var game
var host
var active := false
var items: Array[Dictionary] = []
var history: Array = []
var future: Array = []
var mesh_cache := {}
var materials: Array[StandardMaterial3D] = []
var preview: MeshInstance3D
var candidate: Dictionary = {}
var editing := -1
var acceptable := false
var floor_level := 0
var show_only_current := false
var show_roof := true
var graphics: Node3D
var hud_layer: CanvasLayer
var ui: Control
var palette: PanelContainer
var buttons: GridContainer
var status: Label
var counter: Label
var ghost_green: StandardMaterial3D
var ghost_red: StandardMaterial3D
var finger := -1
var drag_distance := 0.0
var cursor := Vector2.ZERO

func _ready() -> void:
    name = "ModularHouseEditor"
    graphics = Node3D.new()
    graphics.name = "BatchedModularBuildings"
    add_child(graphics)
    for code in MATERIAL_COLORS:
        var mat := StandardMaterial3D.new()
        mat.albedo_color = Color("e8e8e4") # Neutral untextured construction shells; decoration comes later.
        mat.roughness = 0.82
        materials.append(mat)
    ghost_green = StandardMaterial3D.new()
    ghost_green.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    ghost_green.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    ghost_green.albedo_color = Color(0.13, 1.0, 0.45, 0.43)
    ghost_red = ghost_green.duplicate()
    ghost_red.albedo_color = Color(1.0, 0.18, 0.13, 0.52)
    _load()
    _make_ui()
    _rebuild()
    _set_ui(false)

# Geometry is assembled in memory as six-sided boxes, grouped by material.
# This produces 1 MeshInstance per ghost and one MultiMesh draw per part type.
func _block(blocks: Array, color_id: int, center: Vector3, size: Vector3, angle: Vector3 = Vector3.ZERO) -> void:
    blocks.append([color_id, center, size, angle])

func _quad(surface: SurfaceTool, p: Array[Vector3], center: Vector3, basis: Basis) -> void:
    var n := (p[1] - p[0]).cross(p[2] - p[0]).normalized()
    var uvs: Array[Vector2] = [Vector2.ZERO, Vector2(1, 0), Vector2.ONE, Vector2(0, 1)]
    for idx in [0, 1, 2, 0, 2, 3]:
        surface.set_normal(basis * n)
        surface.set_uv(uvs[idx])
        surface.add_vertex(center + basis * p[idx])

func _box_geometry(s: SurfaceTool, center: Vector3, size: Vector3, basis: Basis) -> void:
    var x := size.x * 0.5
    var y := size.y * 0.5
    var z := size.z * 0.5
    _quad(s, [Vector3(-x, -y, z), Vector3(x, -y, z), Vector3(x, y, z), Vector3(-x, y, z)], center, basis)
    _quad(s, [Vector3(x, -y, -z), Vector3(-x, -y, -z), Vector3(-x, y, -z), Vector3(x, y, -z)], center, basis)
    _quad(s, [Vector3(x, -y, z), Vector3(x, -y, -z), Vector3(x, y, -z), Vector3(x, y, z)], center, basis)
    _quad(s, [Vector3(-x, -y, -z), Vector3(-x, -y, z), Vector3(-x, y, z), Vector3(-x, y, -z)], center, basis)
    _quad(s, [Vector3(-x, y, z), Vector3(x, y, z), Vector3(x, y, -z), Vector3(-x, y, -z)], center, basis)
    _quad(s, [Vector3(-x, -y, -z), Vector3(x, -y, -z), Vector3(x, -y, z), Vector3(-x, -y, z)], center, basis)

func _make_mesh(type_id: String) -> ArrayMesh:
    if mesh_cache.has(type_id):
        return mesh_cache[type_id]
    var b: Array = []
    var wall_h := STOREY
    match type_id:
        "foundation":
            _block(b, 1, Vector3(0, -0.15, 0), Vector3(3.02, 0.34, 3.02))
            for i in range(3):
                _block(b, 0, Vector3(-1.0 + float(i), 0.035, 0), Vector3(0.94, 0.08, 3.04))
        "stone_floor":
            _block(b, 1, Vector3(0, 0.025, 0), Vector3(3.02, 0.18, 3.02))
            for x in range(3):
                for z in range(3):
                    _block(b, 0, Vector3(-1.0 + x, 0.134, -1.0 + z), Vector3(0.93, 0.03, 0.93))
        "wood_floor", "balcony":
            _block(b, 2, Vector3(0, -0.035, 0), Vector3(3.08, 0.16, 3.08))
            for i in range(6):
                _block(b, 3, Vector3(-1.245 + 0.498 * i, 0.067, 0), Vector3(0.445, 0.035, 3.04))
            if type_id == "balcony":
                for v in [-1.35, 1.35]:
                    _block(b, 2, Vector3(v, -0.2, 0), Vector3(0.18, 0.22, 3.0))
        "ceiling":
            _block(b, 3, Vector3(0, -0.10, 0), Vector3(3.03, 0.16, 3.03))
            for i in [-1.0, 0.0, 1.0]:
                _block(b, 2, Vector3(i, -0.21, 0), Vector3(0.15, 0.13, 3.02))
        "stone_wall":
            _block(b, 0, Vector3(0, wall_h * 0.5, 0), Vector3(3.0, wall_h, 0.24))
            for row in range(1, 8):
                _block(b, 1, Vector3(0, row * 0.4, 0.129), Vector3(3.04, 0.027, 0.018))
            _block(b, 1, Vector3(0, 0.15, 0), Vector3(3.04, 0.3, 0.34))
        "timber_wall":
            _block(b, 3, Vector3(0, wall_h * 0.5, 0), Vector3(2.98, wall_h, 0.20))
            for x in [-1.43, 0.0, 1.43]:
                _block(b, 2, Vector3(x, 1.6, 0.16), Vector3(0.19, wall_h, 0.15))
            for y in [0.10, 1.70, 3.12]:
                _block(b, 2, Vector3(0, y, 0.18), Vector3(3.06, 0.16, 0.17))
            _block(b, 2, Vector3(-0.71, 0.95, 0.18), Vector3(0.14, 1.72, 0.14), Vector3(0, 0, -0.68))
            _block(b, 2, Vector3(0.71, 2.41, 0.18), Vector3(0.14, 1.72, 0.14), Vector3(0, 0, 0.68))
        "window_wall":
            for side in [-1.16, 1.16]:
                _block(b, 3, Vector3(side, 1.60, 0), Vector3(0.68, 3.2, 0.22))
                _block(b, 2, Vector3(side * 1.23, 1.6, 0.14), Vector3(0.16, 3.2, 0.13))
            _block(b, 3, Vector3(0, 0.43, 0), Vector3(1.67, 0.86, 0.22))
            _block(b, 3, Vector3(0, 2.82, 0), Vector3(1.67, 0.76, 0.22))
            _block(b, 5, Vector3(0, 1.68, 0), Vector3(1.62, 1.63, 0.075))
            _block(b, 2, Vector3(0, 1.69, 0.15), Vector3(0.09, 1.80, 0.13))
            _block(b, 2, Vector3(0, 1.69, 0.15), Vector3(1.81, 0.09, 0.13))
            _block(b, 2, Vector3(0, 2.56, 0.14), Vector3(1.84, 0.16, 0.23))
            _block(b, 2, Vector3(0, 0.84, 0.14), Vector3(1.84, 0.15, 0.23))
        "door_wall":
            for side in [-1.16, 1.16]:
                _block(b, 0, Vector3(side, 1.60, 0), Vector3(0.68, 3.2, 0.24))
                _block(b, 2, Vector3(side * 0.75, 1.22, 0.15), Vector3(0.12, 2.45, 0.17))
            _block(b, 0, Vector3(0, 2.82, 0), Vector3(1.66, 0.76, 0.24))
            _block(b, 6, Vector3(0, 2.47, 0.17), Vector3(1.70, 0.13, 0.12))
            # Opening remains empty; player can walk through it.
        "arch":
            for side in [-1.20, 1.20]:
                _block(b, 0, Vector3(side, 1.57, 0), Vector3(0.58, 3.14, 0.36))
            _block(b, 0, Vector3(0, 2.95, 0), Vector3(2.95, 0.49, 0.37))
            _block(b, 6, Vector3(0, 2.67, 0.0), Vector3(1.83, 0.10, 0.40))
        "railing":
            for x in [-1.42, -0.48, 0.48, 1.42]:
                _block(b, 2, Vector3(x, 0.57, 0), Vector3(0.14, 1.14, 0.16))
            for y in [0.18, 1.13]:
                _block(b, 2, Vector3(0, y, 0), Vector3(3.02, 0.13, 0.17))
        "roof_slope":
            _block(b, 4, Vector3(0, 0.85, 0), Vector3(3.28, 0.15, 3.32), Vector3(0.48, 0, 0))
            for x in [-1.52, 0.0, 1.52]:
                _block(b, 2, Vector3(x, 0.85, 0), Vector3(0.09, 0.22, 3.37), Vector3(0.48, 0, 0))
        "roof_flat":
            _block(b, 4, Vector3(0, 0.17, 0), Vector3(3.22, 0.24, 3.22))
            for x in [-1.47, 1.47]:
                _block(b, 2, Vector3(x, 0.33, 0), Vector3(0.13, 0.17, 3.22))
        "roof_ridge":
            _block(b, 4, Vector3(0, 1.50, 0), Vector3(3.22, 0.26, 0.36))
            _block(b, 6, Vector3(0, 1.65, 0), Vector3(3.18, 0.07, 0.18))
        "stair":
            for step in range(8):
                var depth := TILE / 8.0
                var rise := STOREY / 8.0
                _block(b, 2, Vector3(0, (step + 1) * rise * 0.5, -TILE * 0.5 + (step + 0.5) * depth), Vector3(2.35, (step + 1) * rise, depth + 0.02))
                _block(b, 3, Vector3(0, (step + 1) * rise + 0.025, -TILE * 0.5 + (step + 0.5) * depth), Vector3(2.39, 0.06, depth + 0.02))
        "pillar":
            _block(b, 0, Vector3(0, 1.6, 0), Vector3(0.48, 2.94, 0.48))
            for y in [0.16, 3.04]:
                _block(b, 6, Vector3(0, y, 0), Vector3(0.74, 0.32, 0.74))
        "chimney":
            _block(b, 1, Vector3(0, 1.16, 0), Vector3(0.86, 2.32, 0.86))
            for y in [0.20, 0.80, 1.40, 2.20]:
                _block(b, 0, Vector3(0, y, 0), Vector3(0.99, 0.14, 0.99))
            _block(b, 2, Vector3(0, 2.47, 0), Vector3(1.07, 0.22, 1.07))
    var mesh := ArrayMesh.new()
    for mat_index in range(materials.size()):
        var s := SurfaceTool.new()
        s.begin(Mesh.PRIMITIVE_TRIANGLES)
        var any_blocks := false
        for box in b:
            if int(box[0]) != mat_index:
                continue
            var location: Vector3 = box[1]
            var dimensions: Vector3 = box[2]
            var rotation: Vector3 = box[3]
            _box_geometry(s, location, dimensions, Basis.from_euler(rotation))
            any_blocks = true
        if any_blocks:
            s.commit(mesh)
            mesh.surface_set_material(mesh.get_surface_count() - 1, materials[mat_index])
    mesh_cache[type_id] = mesh
    return mesh

func _entry(type_id: String, gx: int, gz: int, level: int, rot: int = 0) -> Dictionary:
    return {"type": type_id, "gx": gx, "gz": gz, "level": level, "rot": posmod(rot, 4)}

func _slot(d: Dictionary) -> String:
    var key := str(d["type"])
    var slot: String = PARTS[key]["slot"]
    var x := int(d["gx"])
    var z := int(d["gz"])
    var f := int(d["level"])
    if slot == "wall":
        var r := int(d["rot"])
        var edge_x := x * 2 + (1 if r == 1 else (-1 if r == 3 else 0))
        var edge_z := z * 2 + (-1 if r == 0 else (1 if r == 2 else 0))
        return "wall:%d:%d:%d" % [edge_x, edge_z, f]
    return "%s:%d:%d:%d" % [slot, x, z, f]

func _position(d: Dictionary) -> Vector3:
    var p := Vector3(int(d["gx"]) * TILE, int(d["level"]) * STOREY, int(d["gz"]) * TILE)
    var slot: String = PARTS[str(d["type"])]["slot"]
    if slot == "wall":
        match int(d["rot"]):
            0: p.z -= TILE * 0.5
            1: p.x += TILE * 0.5
            2: p.z += TILE * 0.5
            3: p.x -= TILE * 0.5
    if slot == "ceiling":
        p.y += STOREY
    if slot == "roof" or slot == "ridge" or slot == "chimney":
        p.y += STOREY
    return p

func _transform(d: Dictionary) -> Transform3D:
    var heading := float(d["rot"]) * PI * 0.5
    return Transform3D(Basis(Vector3.UP, heading), _position(d))

func _position_ok(d: Dictionary, ignore: int = -1) -> bool:
    if not PARTS.has(str(d.get("type", ""))):
        return false
    if int(d.get("level", -1)) < 0 or int(d["level"]) > MAX_STOREY:
        return false
    var p := _position(d)
    var margin := 2.5
    if absf(p.x) + margin > game.MAP_HALF_X or absf(p.z) + margin > game.MAP_HALF_Z:
        return false
    if Vector2(p.x, p.z).length() < 18.0:
        return false
    var pos2 := Vector2(p.x, p.z)
    for road in game.roads:
        for i in range(road.size() - 1):
            if host._point_segment_distance(pos2, road[i], road[i + 1]) < 5.85:
                return false
    for old in host.saved:
        var other := Vector2(float(old["x"]), float(old["z"]))
        var radius := float(host.PREFABS[str(old["type"])]["width"]) * float(old["size"]) * 0.5
        if pos2.distance_to(other) < radius + 2.1:
            return false
    var slot := _slot(d)
    for i in range(items.size()):
        if i != ignore and _slot(items[i]) == slot:
            return false
    return true

func _safe_data(data) -> Dictionary:
    if not data is Dictionary:
        return {}
    var type_id := str(data.get("type", ""))
    if not PARTS.has(type_id):
        return {}
    var gx := int(data.get("gx", 0))
    var gz := int(data.get("gz", 0))
    var level := int(data.get("level", 0))
    var rot := int(data.get("rot", 0))
    if abs(gx) > 50 or abs(gz) > 50 or level < 0 or level > MAX_STOREY:
        return {}
    return _entry(type_id, gx, gz, level, rot)

func _load() -> void:
    if not FileAccess.file_exists(SAVE_FILE):
        return
    var data = JSON.parse_string(FileAccess.get_file_as_string(SAVE_FILE))
    if not data is Dictionary or int(data.get("version", 0)) != 1:
        return
    var parts = data.get("parts", [])
    if not parts is Array:
        return
    for row in parts:
        var clean := _safe_data(row)
        if not clean.is_empty():
            items.append(clean)
        if items.size() >= MAX_PIECES:
            break

func _save() -> bool:
    var f := FileAccess.open(SAVE_FILE, FileAccess.WRITE)
    if f == null:
        return false
    f.store_string(JSON.stringify({"version": 1, "parts": items}, "  "))
    f.close()
    return true

func _push_undo() -> void:
    history.append(items.duplicate(true))
    if history.size() > 25:
        history.pop_front()
    future.clear()

func _rebuild() -> void:
    if graphics == null:
        return
    for child in graphics.get_children():
        child.queue_free()
    var grouped := {}
    for i in range(items.size()):
        if i == editing:
            continue
        var d: Dictionary = items[i]
        var level := int(d["level"])
        if show_only_current and level != floor_level:
            continue
        if not show_only_current and level > floor_level:
            continue
        if not show_roof and ["roof", "ridge"].has(str(PARTS[str(d["type"])]["slot"])):
            continue
        var type_id := str(d["type"])
        if not grouped.has(type_id):
            grouped[type_id] = []
        grouped[type_id].append(d)
        _add_collider(d)
    for type_id in grouped:
        var entries: Array = grouped[type_id]
        var batch := MultiMesh.new()
        batch.transform_format = MultiMesh.TRANSFORM_3D
        batch.mesh = _make_mesh(type_id)
        batch.instance_count = entries.size()
        for j in range(entries.size()):
            batch.set_instance_transform(j, _transform(entries[j]))
        var view := MultiMeshInstance3D.new()
        view.name = "Batch_" + type_id
        view.multimesh = batch
        view.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
        graphics.add_child(view)
    _status("Этаж %d/%d · элементов %d/%d" % [floor_level + 1, MAX_STOREY + 1, items.size(), MAX_PIECES])

func _add_shape(body: StaticBody3D, center: Vector3, dimensions: Vector3) -> void:
    var collider := CollisionShape3D.new()
    var box := BoxShape3D.new()
    box.size = dimensions
    collider.shape = box
    collider.position = center
    body.add_child(collider)

func _add_collider(d: Dictionary) -> void:
    var type_id := str(d["type"])
    var slot: String = PARTS[type_id]["slot"]
    if slot == "ridge" or slot == "chimney":
        return
    var body := StaticBody3D.new()
    body.name = "BuildCollision"
    body.transform = _transform(d)
    graphics.add_child(body)
    match slot:
        "wall":
            if type_id == "door_wall" or type_id == "arch":
                for side in [-1.20, 1.20]:
                    _add_shape(body, Vector3(side, 1.56, 0), Vector3(0.58, 3.12, 0.30))
                _add_shape(body, Vector3(0, 2.94, 0), Vector3(1.85, 0.45, 0.30))
            elif type_id == "window_wall":
                _add_shape(body, Vector3(0, 0.43, 0), Vector3(3.0, 0.86, 0.26))
                _add_shape(body, Vector3(0, 2.8, 0), Vector3(3.0, 0.8, 0.26))
                for side in [-1.16, 1.16]:
                    _add_shape(body, Vector3(side, 1.62, 0), Vector3(0.68, 3.20, 0.26))
            else:
                var h := 1.2 if type_id == "railing" else STOREY
                _add_shape(body, Vector3(0, h * 0.5, 0), Vector3(3.0, h, 0.24))
        "roof":
            _add_shape(body, Vector3(0, 0.80 if type_id == "roof_slope" else 0.17, 0), Vector3(3.0, 0.16, 3.0))
        "deck", "ceiling":
            _add_shape(body, Vector3(0, -0.06, 0), Vector3(3.0, 0.22, 3.0))
        "stair":
            # Collision stepping will get a dedicated stair-navigation pass.
            for step in range(8):
                _add_shape(body, Vector3(0, (step + 1) * 0.20, -1.5 + (step + 0.5) * (TILE / 8.0)), Vector3(2.35, (step + 1) * 0.4, TILE / 8.0))
        "pillar":
            _add_shape(body, Vector3(0, 1.6, 0), Vector3(0.6, 3.2, 0.6))

func set_active(value: bool) -> void:
    active = value
    finger = -1
    if not active:
        cancel()
    _set_ui(value)
    if active:
        floor_level = 0
        _rebuild()
        _status("Выбери фундамент, пол или стену. Поставь касанием и нажми «Закрепить».")

func _set_ui(value: bool) -> void:
    if hud_layer != null:
        hud_layer.visible = value

func _make_ui() -> void:
    hud_layer = CanvasLayer.new()
    hud_layer.layer = 17
    add_child(hud_layer)
    ui = Control.new()
    ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
    hud_layer.add_child(ui)
    palette = PanelContainer.new()
    ui.add_child(palette)
    var scroll := ScrollContainer.new()
    scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
    palette.add_child(scroll)
    var choices := VBoxContainer.new()
    choices.custom_minimum_size.x = 204.0
    scroll.add_child(choices)
    var title := Label.new()
    title.text = "🏰 БЕЛЫЕ МОДУЛИ"
    title.add_theme_font_size_override("font_size", 17)
    choices.add_child(title)
    _button(choices, "🏠 Белый жилой дом", func() -> void: build_white_building("house"))
    _button(choices, "⚒ Белая кузница", func() -> void: build_white_building("smith"))
    _button(choices, "🍺 Белая таверна", func() -> void: build_white_building("tavern"))
    _button(choices, "⚖ Белый аукцион", func() -> void: build_white_building("auction"))
    for category in ["Основание", "Стены", "Крыша", "Детали"]:
        var label := Label.new()
        label.text = "── " + category + " ──"
        label.add_theme_font_size_override("font_size", 15)
        choices.add_child(label)
        for id in PARTS.keys():
            if str(PARTS[id]["group"]) == category:
                var key: String = id
                _button(choices, str(PARTS[id]["name"]), func() -> void: begin(key))
    status = Label.new()
    status.add_theme_font_size_override("font_size", 17)
    status.add_theme_color_override("font_color", Color("fff1d4"))
    status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    ui.add_child(status)
    counter = Label.new()
    counter.add_theme_font_size_override("font_size", 16)
    counter.add_theme_color_override("font_color", Color("e8ce94"))
    ui.add_child(counter)
    var toolbar := PanelContainer.new()
    toolbar.name = "ModularActionBar"
    ui.add_child(toolbar)
    buttons = GridContainer.new()
    buttons.columns = 5
    toolbar.add_child(buttons)
    _button(buttons, "◀ Повернуть", func() -> void: rotate_piece(-1))
    _button(buttons, "Повернуть ▶", func() -> void: rotate_piece(1))
    _button(buttons, "Этаж −", func() -> void: change_floor(-1))
    _button(buttons, "Этаж +", func() -> void: change_floor(1))
    _button(buttons, "🔍 Камера", func() -> void: zoom(-10.0))
    _button(buttons, "✓ Закрепить", confirm)
    _button(buttons, "Копировать", duplicate_piece)
    _button(buttons, "Удалить", erase)
    _button(buttons, "↶ Отменить", undo)
    _button(buttons, "↷ Вернуть", redo)
    _button(buttons, "Снять выбор", cancel)
    _button(buttons, "Этаж/Все", toggle_floor_view)
    _button(buttons, "Крыша вкл/выкл", toggle_roof)
    _button(buttons, "Сохранить", manual_save)
    _button(buttons, "Готовые здания", exit_to_prefabs)
    _button(buttons, "− Отдалить", func() -> void: zoom(10.0))
    _button(buttons, "На карте", func() -> void: _status("Коснись установленной детали, чтобы выбрать её."))
    _button(buttons, "Очистить выбор", cancel)
    _button(buttons, "Сохранить план", manual_save)
    _button(buttons, "Выйти из редактора", func() -> void: host.set_active(false))
    get_viewport().size_changed.connect(_layout)
    _layout()

func _button(parent: Node, value: String, action: Callable) -> void:
    var b := Button.new()
    b.text = value
    b.custom_minimum_size = Vector2(105, 36)
    b.add_theme_font_size_override("font_size", 14)
    b.focus_mode = Control.FOCUS_NONE
    b.pressed.connect(action)
    parent.add_child(b)

func _layout() -> void:
    if ui == null:
        return
    var view := get_viewport().get_visible_rect().size
    palette.position = Vector2(8, 8)
    palette.size = Vector2(225, maxf(125, view.y - 16))
    status.position = Vector2(241, 8)
    status.size = Vector2(maxf(120, view.x - 249), 70)
    counter.position = Vector2(241, 76)
    counter.size = Vector2(maxf(120, view.x - 249), 28)
    var toolbar: PanelContainer = ui.get_node("ModularActionBar")
    toolbar.position = Vector2(238, maxf(90, view.y - 195))
    toolbar.size = Vector2(maxf(500, view.x - 246), 187)

func _status(msg: String) -> void:
    if status != null:
        status.text = msg
    if counter != null:
        counter.text = "Этаж %d/%d   ·   деталей %d/%d" % [floor_level + 1, MAX_STOREY + 1, items.size(), MAX_PIECES]

func _refresh_ghost() -> void:
    if preview == null:
        return
    acceptable = _position_ok(candidate, editing)
    preview.transform = _transform(candidate)
    preview.material_overlay = ghost_green if acceptable else ghost_red

func begin(type_id: String) -> void:
    if not PARTS.has(type_id):
        return
    cancel()
    if items.size() >= MAX_PIECES:
        _status("Достигнут предел %d деталей. Удали лишние перед строительством." % MAX_PIECES)
        return
    var center: Vector2 = game.overview_center
    candidate = _entry(type_id, roundi(center.x / TILE), roundi(center.y / TILE), floor_level)
    _new_preview()
    _status(str(PARTS[type_id]["name"]) + " · касанием выбери клетку; поворот — кнопками.")

func _new_preview() -> void:
    preview = MeshInstance3D.new()
    preview.name = "GreenRedBuildPreview"
    preview.mesh = _make_mesh(str(candidate["type"]))
    preview.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    add_child(preview)
    _refresh_ghost()

func select_at(world: Vector2) -> void:
    var best := -1
    var distance := 1.9
    for i in range(items.size() - 1, -1, -1):
        var d: Dictionary = items[i]
        if int(d["level"]) != floor_level:
            continue
        var p := _position(d)
        var dist := world.distance_to(Vector2(p.x, p.z))
        if dist < distance:
            distance = dist
            best = i
    if best == -1:
        _status("Здесь нет детали. Выбери элемент слева.")
        return
    cancel()
    editing = best
    candidate = items[best].duplicate(true)
    _rebuild()
    _new_preview()
    _status("Выбрано: " + str(PARTS[str(candidate["type"])]["name"]) + ". Перемести, поверни, копируй.")

func duplicate_piece() -> void:
    if preview == null:
        _status("Выбери установленную деталь или элемент из каталога.")
        return
    if items.size() >= MAX_PIECES:
        _status("Лимит деталей достигнут.")
        return
    var copy := candidate.duplicate(true)
    copy["gx"] = int(copy["gx"]) + 1
    cancel()
    candidate = copy
    _new_preview()
    _status("Копия создана. Оригинал на месте. Передвинь копию и закрепи.")

func rotate_piece(steps: int) -> void:
    if preview == null:
        _status("Сначала выбери деталь.")
        return
    candidate["rot"] = posmod(int(candidate["rot"]) + steps, 4)
    _refresh_ghost()

func change_floor(amount: int) -> void:
    floor_level = clampi(floor_level + amount, 0, MAX_STOREY)
    if preview != null:
        candidate["level"] = floor_level
        _refresh_ghost()
    _rebuild()
    _status("Этаж %d. Теперь детали ставятся на этой высоте." % (floor_level + 1))

func toggle_floor_view() -> void:
    show_only_current = not show_only_current
    _rebuild()
    _status("Показан только текущий этаж." if show_only_current else "Показаны текущий и нижние этажи.")

func toggle_roof() -> void:
    show_roof = not show_roof
    _rebuild()
    _status("Крыша видна." if show_roof else "Крыша скрыта для редактирования.")

func zoom(amount: float) -> void:
    game.overview_height = clampf(game.overview_height + amount, 15.0, 205.0)
    game._update_camera()

func confirm() -> void:
    if preview == null:
        _status("Сначала выбери деталь.")
        return
    _refresh_ghost()
    if not acceptable:
        _status("Красная деталь: занято, слишком близко к дороге или за границей карты.")
        return
    _push_undo()
    if editing >= 0:
        items[editing] = candidate.duplicate(true)
    else:
        items.append(candidate.duplicate(true))
    cancel()
    _rebuild()
    _status("Закреплено · " + ("сохранено." if _save() else "ошибка записи файла!"))

func erase() -> void:
    if editing < 0 or editing >= items.size():
        _status("Для удаления коснись ранее закреплённой детали.")
        return
    _push_undo()
    items.remove_at(editing)
    cancel()
    _rebuild()
    _save()
    _status("Удалено. Изменения сохранены.")

func cancel() -> void:
    if preview != null and is_instance_valid(preview):
        preview.queue_free()
    preview = null
    candidate = {}
    editing = -1
    acceptable = false
    _rebuild()

func undo() -> void:
    if history.is_empty():
        _status("Нечего отменять.")
        return
    cancel()
    future.append(items.duplicate(true))
    var old: Array = history.pop_back()
    items.clear()
    for d in old:
        items.append(d.duplicate(true))
    _rebuild()
    _save()
    _status("Последнее действие отменено.")

func redo() -> void:
    if future.is_empty():
        _status("Нечего возвращать.")
        return
    cancel()
    history.append(items.duplicate(true))
    var newer: Array = future.pop_back()
    items.clear()
    for d in newer:
        items.append(d.duplicate(true))
    _rebuild()
    _save()
    _status("Действие возвращено.")

func manual_save() -> void:
    _status("План сохранён: %d деталей." % items.size() if _save() else "Ошибка сохранения!")

func exit_to_prefabs() -> void:
    host.close_modular()
    _status("Режим готовых зданий.")

func _project(screen: Vector2) -> Vector2:
    var cam: Camera3D = game.camera
    var plane := Plane(Vector3.UP, floor_level * STOREY)
    var hit = plane.intersects_ray(cam.project_ray_origin(screen), cam.project_ray_normal(screen))
    if hit is Vector3:
        return Vector2(hit.x, hit.z)
    return Vector2(9999, 9999)

func _tap(screen: Vector2) -> void:
    var p := _project(screen)
    if absf(p.x) > game.MAP_HALF_X or absf(p.y) > game.MAP_HALF_Z:
        _status("За пределами карты.")
        return
    if preview != null:
        candidate["gx"] = roundi(p.x / TILE)
        candidate["gz"] = roundi(p.y / TILE)
        _refresh_ghost()
        _status("X=%d · Z=%d · %s" % [int(candidate["gx"]), int(candidate["gz"]), "✓ Закрепить" if acceptable else "место занято"])
    else:
        select_at(p)

func _pan(delta: Vector2) -> void:
    game.overview_center.x = clampf(game.overview_center.x - delta.x * game.overview_height * 0.0036, -game.MAP_HALF_X, game.MAP_HALF_X)
    game.overview_center.y = clampf(game.overview_center.y - delta.y * game.overview_height * 0.0036, -game.MAP_HALF_Z, game.MAP_HALF_Z)
    game._update_camera()

func _drag(pointer: Vector2, movement: Vector2) -> void:
    drag_distance += movement.length()
    if preview == null:
        _pan(movement)
    else:
        var p := _project(pointer)
        if absf(p.x) <= game.MAP_HALF_X and absf(p.y) <= game.MAP_HALF_Z:
            candidate["gx"] = roundi(p.x / TILE)
            candidate["gz"] = roundi(p.y / TILE)
            _refresh_ghost()

func _unhandled_input(event: InputEvent) -> void:
    if not active:
        return
    if event is InputEventScreenTouch:
        if event.pressed and finger == -1:
            finger = event.index
            drag_distance = 0.0
        elif not event.pressed and event.index == finger:
            if drag_distance < 13:
                _tap(event.position)
            finger = -1
            get_viewport().set_input_as_handled()
    elif event is InputEventScreenDrag and event.index == finger:
        _drag(event.position, event.relative)
        get_viewport().set_input_as_handled()
    elif event is InputEventMouseButton:
        if event.button_index == MOUSE_BUTTON_LEFT:
            if event.pressed:
                drag_distance = 0
            elif drag_distance < 12:
                _tap(event.position)
            get_viewport().set_input_as_handled()
        elif event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_UP:
            zoom(-7)
            get_viewport().set_input_as_handled()
        elif event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
            zoom(7)
            get_viewport().set_input_as_handled()
    elif event is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
        _drag(event.position, event.relative)
        get_viewport().set_input_as_handled()



# Original, undecorated MMO town shells. Each building is made of editable
# 3m modules, with walkable openings and separate upper-floor decks.
# Do not touch existing saved layouts or import old compressed GLB buildings.
func _white_building_parts(kind: String, ox: int, oz: int) -> Array[Dictionary]:
    var width := 3
    var depth := 3
    var storeys := 1
    match kind:
        "smith":
            width = 4
            depth = 3
        "tavern":
            width = 4
            depth = 4
            storeys = 2
        "auction":
            width = 5
            depth = 4
            storeys = 2
    var result: Array[Dictionary] = []
    for level in range(storeys):
        for z in range(depth):
            for x in range(width):
                result.append(_entry("foundation" if level == 0 else "stone_floor", ox + x, oz + z, level))
                if level == storeys - 1:
                    result.append(_entry("roof_flat", ox + x, oz + z, level))
        for x in range(width):
            var front_type := "window_wall"
            if level == 0 and x == int(width / 2):
                front_type = "door_wall"
            elif level == 0 and kind == "auction" and x == int(width / 2) - 1:
                front_type = "arch"
            result.append(_entry(front_type, ox + x, oz, level, 0))
            result.append(_entry("window_wall" if x % 2 == 1 else "stone_wall", ox + x, oz + depth - 1, level, 2))
        for z in range(depth):
            result.append(_entry("stone_wall" if z % 2 == 0 else "window_wall", ox, oz + z, level, 3))
            result.append(_entry("stone_wall" if z % 2 == 0 else "window_wall", ox + width - 1, oz + z, level, 1))
    # Parapet is a separate wall-slot tier above the roof, leaving the roof deck intact.
    if kind == "auction":
        for x in range(width):
            result.append(_entry("railing", ox + x, oz, storeys, 0))
            result.append(_entry("railing", ox + x, oz + depth - 1, storeys, 2))
        for z in range(depth):
            result.append(_entry("railing", ox, oz + z, storeys, 3))
            result.append(_entry("railing", ox + width - 1, oz + z, storeys, 1))
    # Roof chimney is a separate accessory, not a wall or deck replacement.
    if kind == "smith" or kind == "tavern":
        result.append(_entry("chimney", ox + width - 1, oz + depth - 1, storeys - 1))
    return result

func build_white_building(kind: String) -> void:
    if not ["house", "smith", "tavern", "auction"].has(kind):
        return
    cancel()
    var origin := Vector2i(999, 999)
    var chosen: Array[Dictionary] = []
    # Leave roads, the fountain and previously placed player buildings alone.
    for gz in range(-27, 28, 3):
        if origin.x != 999:
            break
        for gx in range(-32, 33, 3):
            var planned := _white_building_parts(kind, gx, gz)
            if items.size() + planned.size() > MAX_PIECES:
                _status("Не хватает лимита модулей для нового здания.")
                return
            var valid := true
            for d in planned:
                if not _position_ok(d):
                    valid = false
                    break
            if valid:
                origin = Vector2i(gx, gz)
                chosen = planned
                break
    if origin.x == 999:
        _status("Не найден свободный участок для здания. Проверь дороги и границы карты.")
        return
    _push_undo()
    items.append_array(chosen)
    floor_level = 0
    _rebuild()
    var saved_ok := _save()
    _status("Белое здание: %d модулей, X=%d Z=%d. %s" % [chosen.size(), origin.x, origin.y, "Сохранено." if saved_ok else "Ошибка сохранения!"])

func build_white_house() -> void:
    build_white_building("house")

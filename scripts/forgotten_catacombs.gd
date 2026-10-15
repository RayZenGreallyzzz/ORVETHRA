extends "res://scripts/city_preview.gd"

# ORVETHRA / Forgotten Catacombs: approved 5 small, 7 large, 1 boss layout.
# One Godot unit = one metre. Corridors are 3m wide and 4–5m long.
# Static stone geometry is deliberately lightweight until approved Meshy GLBs
# are decimated and uploaded as actual mobile-ready assets.
const PASSAGE_WIDTH := 3.0
const WALL_HEIGHT := 4.5
const WALL_THICKNESS := 0.46
const DUNGEON_SPAWN := Vector3(0.0, 0.2, 75.0)
const CELL := 0.5

# Single mandatory S-shaped progression: every room is on the boss route.
# Deliberate lateral offsets prevent a rigid grid and force 90-degree turns.
const ROOMS := [
    {"id":"small1", "pos":Vector2(0.0,75.0), "width":7.0, "name":"Малая 1"},
    {"id":"big1", "pos":Vector2(4.0,61.0), "width":12.0, "name":"Большая 1"},
    {"id":"big2", "pos":Vector2(-12.5,56.5), "width":12.0, "name":"Большая 2"},
    {"id":"small2", "pos":Vector2(-16.0,42.0), "width":7.0, "name":"Малая 2"},
    {"id":"big3", "pos":Vector2(-19.0,28.0), "width":12.0, "name":"Большая 3"},
    {"id":"big4", "pos":Vector2(-1.0,23.5), "width":15.0, "name":"Большая 4"},
    {"id":"small3", "pos":Vector2(3.0,7.5), "width":7.0, "name":"Малая 3"},
    {"id":"big5", "pos":Vector2(-1.0,-8.0), "width":15.0, "name":"Большая 5"},
    {"id":"big6", "pos":Vector2(21.0,-12.0), "width":20.0, "name":"Большая 6"},
    {"id":"small4", "pos":Vector2(25.0,-29.5), "width":7.0, "name":"Малая 4"},
    {"id":"big7", "pos":Vector2(21.0,-47.5), "width":20.0, "name":"Большая 7"},
    {"id":"small5", "pos":Vector2(3.0,-44.5), "width":7.0, "name":"Малая 5"},
    {"id":"boss", "pos":Vector2(-17.0,-47.5), "width":25.0, "name":"Зал Демоники"}
]
const LINKS := [
    ["small1","big1"], ["big1","big2"], ["big2","small2"],
    ["small2","big3"], ["big3","big4"], ["big4","small3"],
    ["small3","big5"], ["big5","big6"], ["big6","small4"],
    ["small4","big7"], ["big7","small5"], ["small5","boss"]
]

var stone: StandardMaterial3D
var border_stone: StandardMaterial3D
var red_stone: StandardMaterial3D
var ember: StandardMaterial3D
var floor_mat: ShaderMaterial
var room_by_id: Dictionary = {}
var walkable: Dictionary = {}

const FLOOR_PATTERN := """
shader_type spatial;
render_mode cull_disabled;
varying vec3 world_pos;
float noise2(vec2 p) { return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453); }
void vertex() { world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
void fragment() {
    vec2 p = world_pos.xz * 1.25;
    p.x += mod(floor(p.y), 2.0) * 0.4;
    vec2 t = floor(p);
    vec2 q = fract(p);
    float variation = noise2(t);
    float joint = smoothstep(0.455, 0.49, max(abs(q.x - 0.5), abs(q.y - 0.5)));
    float cracks = noise2(floor(world_pos.xz * 19.0)) * 0.06;
    vec3 stone_color = mix(vec3(0.20,0.205,0.22),vec3(0.32,0.305,0.29),variation);
    ALBEDO = mix(stone_color + cracks, vec3(0.085,0.082,0.09), joint);
    ROUGHNESS = 0.98;
}
"""

func _ready() -> void:
    Engine.max_fps = 30
    _load_camera_distance()
    camera_distance = clampf(camera_distance, 4.0, 7.5)
    _dungeon_light()
    _prepare_materials()
    _build_map()
    _player()
    player.position = DUNGEON_SPAWN
    city_hud = preload("res://scripts/catacombs_hud.gd").new()
    city_hud.game = self
    add_child(city_hud)
    _update_camera()

func _dungeon_light() -> void:
    var environment_node := WorldEnvironment.new()
    var environment := Environment.new()
    environment.background_mode = Environment.BG_COLOR
    environment.background_color = Color("090c12")
    environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
    environment.ambient_light_color = Color("aaa7a0")
    environment.ambient_light_energy = 0.68
    environment_node.environment = environment
    add_child(environment_node)
    var fill := DirectionalLight3D.new()
    fill.rotation_degrees = Vector3(-63, -25, 0)
    fill.light_color = Color("b6c0d1")
    fill.light_energy = 0.43
    fill.shadow_enabled = false
    add_child(fill)

func _prepare_materials() -> void:
    stone = _plain("504d4c")
    border_stone = _plain("302d32")
    red_stone = _plain("5a3037")
    ember = _plain("a53c35")
    ember.emission_enabled = true
    ember.emission = Color("b84d43")
    ember.emission_energy_multiplier = 1.6
    floor_mat = _make_shader(FLOOR_PATTERN)

func _add_box(at: Vector3, dimensions: Vector3, mat: Material, collide: bool = true) -> Node3D:
    var mesh_node := MeshInstance3D.new()
    var box_mesh := BoxMesh.new()
    box_mesh.size = dimensions
    mesh_node.mesh = box_mesh
    mesh_node.material_override = mat
    mesh_node.position = at
    mesh_node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    add_child(mesh_node)
    if collide:
        var solid := StaticBody3D.new()
        var shape := CollisionShape3D.new()
        var cube := BoxShape3D.new()
        cube.size = dimensions
        shape.shape = cube
        solid.position = at
        solid.add_child(shape)
        add_child(solid)
    return mesh_node

func _build_map() -> void:
    # One continuous corridor graph (not a hub with shortcuts).
    # Rasterize overlapping floor rectangles at 0.5m: outer walls are
    # generated only at the boundary of their union. This leaves clean
    # doorways and corners automatically, without invisible blockers.
    for room in ROOMS:
        room_by_id[room["id"]] = room
        _build_room(room)
    for link in LINKS:
        _build_corridor(room_by_id[link[0]], room_by_id[link[1]])
    _build_perimeter_walls()
    for room in ROOMS:
        _room_accents(room)
    _boss_details()
    _exit_marker()

func _paint_floor(at: Vector2, extent: Vector2) -> void:
    _add_box(Vector3(at.x, -0.13, at.y),
        Vector3(extent.x, 0.24, extent.y), floor_mat)
    var ix0 := roundi((at.x - extent.x * 0.5) / CELL)
    var ix1 := roundi((at.x + extent.x * 0.5) / CELL)
    var iz0 := roundi((at.y - extent.y * 0.5) / CELL)
    var iz1 := roundi((at.y + extent.y * 0.5) / CELL)
    for ix in range(ix0, ix1):
        for iz in range(iz0, iz1):
            walkable[Vector2i(ix, iz)] = true

func _build_room(room: Dictionary) -> void:
    var center: Vector2 = room["pos"]
    var width: float = room["width"]
    _paint_floor(center, Vector2(width, width))

func _build_corridor(a: Dictionary, b: Dictionary) -> void:
    var p: Vector2 = a["pos"]
    var q: Vector2 = b["pos"]
    var a_half: float = float(a["width"]) * 0.5
    var b_half: float = float(b["width"]) * 0.5
    var horizontal := absf(p.x - q.x) > absf(p.y - q.y)
    var route: Array[Vector2] = []
    if horizontal:
        var direction := 1.0 if q.x > p.x else -1.0
        var start := Vector2(p.x + direction * a_half, p.y)
        var finish := Vector2(q.x - direction * b_half, q.y)
        var midpoint := (start.x + finish.x) * 0.5
        route = [start, Vector2(midpoint, p.y),
            Vector2(midpoint, q.y), finish]
    else:
        var direction := 1.0 if q.y > p.y else -1.0
        var start := Vector2(p.x, p.y + direction * a_half)
        var finish := Vector2(q.x, q.y - direction * b_half)
        var midpoint := (start.y + finish.y) * 0.5
        route = [start, Vector2(p.x, midpoint),
            Vector2(q.x, midpoint), finish]
    # 3m-wide L/S-jog corridors, 4–5m between room boundaries.
    # Every link bends because paired room centres are offset 3–4.5m.
    for i in range(route.size() - 1):
        var first: Vector2 = route[i]
        var second: Vector2 = route[i + 1]
        if is_equal_approx(first.x, second.x):
            _paint_floor((first + second) * 0.5,
                Vector2(PASSAGE_WIDTH, absf(first.y - second.y) + PASSAGE_WIDTH))
        else:
            _paint_floor((first + second) * 0.5,
                Vector2(absf(first.x - second.x) + PASSAGE_WIDTH, PASSAGE_WIDTH))

func _build_perimeter_walls() -> void:
    var north_south: Dictionary = {}
    var east_west: Dictionary = {}
    for key in walkable:
        var tile: Vector2i = key
        if not walkable.has(tile + Vector2i(-1, 0)):
            _add_edge(north_south, tile.x, tile.y)
        if not walkable.has(tile + Vector2i(1, 0)):
            _add_edge(north_south, tile.x + 1, tile.y)
        if not walkable.has(tile + Vector2i(0, -1)):
            _add_edge(east_west, tile.y, tile.x)
        if not walkable.has(tile + Vector2i(0, 1)):
            _add_edge(east_west, tile.y + 1, tile.x)
    _emit_edges(north_south, false)
    _emit_edges(east_west, true)

func _add_edge(groups: Dictionary, edge: int, index: int) -> void:
    if not groups.has(edge):
        groups[edge] = []
    var segments: Array = groups[edge]
    segments.append(index)

func _emit_edges(groups: Dictionary, horizontal: bool) -> void:
    for edge in groups:
        var segments: Array = groups[edge]
        segments.sort()
        if segments.is_empty():
            continue
        var start: int = segments[0]
        var last: int = start
        for i in range(1, segments.size()):
            var tile: int = segments[i]
            if tile == last + 1:
                last = tile
            else:
                _emit_wall_segment(edge, start, last, horizontal)
                start = tile
                last = tile
        _emit_wall_segment(edge, start, last, horizontal)

func _emit_wall_segment(edge: int, first: int, last: int, horizontal: bool) -> void:
    var span := float(last - first + 1) * CELL
    var along := float(first + last + 1) * 0.5 * CELL
    var wall_line := float(edge) * CELL
    var location := Vector3(along, WALL_HEIGHT * 0.5, wall_line) if horizontal else Vector3(wall_line, WALL_HEIGHT * 0.5, along)
    var boss_center := Vector2(-17.0, -47.5)
    var near_boss := Vector2(location.x, location.z).distance_to(boss_center) < 18.0
    _wall_part(location, span, horizontal, red_stone if near_boss else stone)

func _wall_part(at: Vector3, span: float, horizontal: bool, material: Material) -> void:
    var dimensions := Vector3(span, WALL_HEIGHT, WALL_THICKNESS) if horizontal else Vector3(WALL_THICKNESS, WALL_HEIGHT, span)
    _add_box(at, dimensions, material)

func _room_accents(room: Dictionary) -> void:
    var pos: Vector2 = room["pos"]
    var size: float = float(room["width"])
    var half := size * 0.5
    # Decorative pillars stay very close to walls; central combat area is free.
    if size >= 12.0:
        for sx in [-1.0, 1.0]:
            for sz in [-1.0, 1.0]:
                _add_box(Vector3(pos.x + sx * (half - 0.9), 1.48, pos.y + sz * (half - 0.9)),
                    Vector3(0.85, 2.95, 0.85), border_stone)
    if room["id"] == "big5" or room["id"] == "small3":
        _add_box(Vector3(pos.x - half + 1.05, 0.47, pos.y - half + 1.1), Vector3(1.3, 0.95, 2.0), stone)

func _boss_details() -> void:
    var pos := Vector3(-17, -0.003, -47.5)
    var ring := MeshInstance3D.new()
    var disc := CylinderMesh.new()
    disc.top_radius = 6.4
    disc.bottom_radius = 6.4
    disc.height = 0.045
    disc.radial_segments = 40
    ring.mesh = disc
    ring.position = pos
    ring.material_override = red_stone
    add_child(ring)
    # The centre is empty so a later imported Demonica can fight here.
    _add_box(Vector3(-17, 0.48, -59.0), Vector3(4.6, 0.95, 1.65), border_stone)
    var boss_spot := Label3D.new()
    boss_spot.text = "DEMONICA  ·  ЗАЛ БОССА"
    boss_spot.font_size = 42
    boss_spot.pixel_size = 0.012
    boss_spot.billboard = BaseMaterial3D.BILLBOARD_ENABLED
    boss_spot.position = Vector3(-17, 2.75, -53)
    boss_spot.modulate = Color("eebcb8")
    add_child(boss_spot)
    var light := OmniLight3D.new()
    light.position = Vector3(-17, 3, -50)
    light.omni_range = 16.0
    light.light_energy = 0.85
    light.light_color = Color("d06360")
    light.shadow_enabled = false
    add_child(light)

func _exit_marker() -> void:
    var plaque := Label3D.new()
    plaque.text = "Выход в ORVETHRA"
    plaque.font_size = 40
    plaque.pixel_size = 0.012
    plaque.billboard = BaseMaterial3D.BILLBOARD_ENABLED
    plaque.position = Vector3(0, 2.4, 77.0)
    plaque.modulate = Color("edd2a0")
    add_child(plaque)

func _return_to_city() -> void:
    # Restore the hero just outside the crypt instead of at the fountain.
    get_tree().set_meta("orvethra_return_from_catacombs", true)
    get_tree().change_scene_to_file("res://scenes/city_preview.tscn")

extends "res://scripts/city_preview.gd"

# ORVETHRA / Forgotten Catacombs: approved 5 small, 7 large, 1 boss layout.
# One Godot unit = one metre. Corridors are 3m wide and 4–5m long.
# Static stone geometry is deliberately lightweight until approved Meshy GLBs
# are decimated and uploaded as actual mobile-ready assets.
const PASSAGE_WIDTH := 3.0
const WALL_HEIGHT := 4.5
const WALL_THICKNESS := 0.46
const DUNGEON_SPAWN := Vector3(0.0, 0.2, 53.5)

const ROOMS := [
    {"id": "small1", "pos": Vector2(0, 53.5), "width": 7.0, "name": "Малая 1"},
    {"id": "big1", "pos": Vector2(0, 39), "width": 12.0, "name": "Большая 1"},
    {"id": "big2", "pos": Vector2(-17, 39), "width": 12.0, "name": "Большая 2"},
    {"id": "big3", "pos": Vector2(17, 39), "width": 12.0, "name": "Большая 3"},
    {"id": "big4", "pos": Vector2(0, 21.5), "width": 15.0, "name": "Большая 4"},
    {"id": "big5", "pos": Vector2(-20, 21.5), "width": 15.0, "name": "Большая 5"},
    {"id": "big6", "pos": Vector2(22.5, 21.5), "width": 20.0, "name": "Большая 6"},
    {"id": "small2", "pos": Vector2(40, 21.5), "width": 7.0, "name": "Малая 2"},
    {"id": "small3", "pos": Vector2(-35, 21.5), "width": 7.0, "name": "Малая 3"},
    {"id": "big7", "pos": Vector2(0, 0), "width": 20.0, "name": "Большая 7"},
    {"id": "small4", "pos": Vector2(17.5, 0), "width": 7.0, "name": "Малая 4"},
    {"id": "small5", "pos": Vector2(-17.5, 0), "width": 7.0, "name": "Малая 5"},
    {"id": "boss", "pos": Vector2(0, -27.5), "width": 25.0, "name": "Зал Демоники"}
]
const LINKS := [
    ["small1", "big1"], ["big1", "big2"], ["big1", "big3"],
    ["big1", "big4"], ["big4", "big5"], ["big4", "big6"],
    ["big5", "small3"], ["big6", "small2"], ["big4", "big7"],
    ["big7", "small4"], ["big7", "small5"], ["big7", "boss"]
]

var stone: StandardMaterial3D
var border_stone: StandardMaterial3D
var red_stone: StandardMaterial3D
var ember: StandardMaterial3D
var floor_mat: ShaderMaterial
var room_by_id: Dictionary = {}
var openings: Dictionary = {}

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
    for room in ROOMS:
        room_by_id[room["id"]] = room
        openings[room["id"]] = []
    for link in LINKS:
        var a: Dictionary = room_by_id[link[0]]
        var b: Dictionary = room_by_id[link[1]]
        var a_pos: Vector2 = a["pos"]
        var b_pos: Vector2 = b["pos"]
        var horizontal := absf(a_pos.x - b_pos.x) > absf(a_pos.y - b_pos.y)
        if horizontal:
            _open_side(a["id"], "E" if b_pos.x > a_pos.x else "W")
            _open_side(b["id"], "W" if b_pos.x > a_pos.x else "E")
        else:
            _open_side(a["id"], "S" if b_pos.y > a_pos.y else "N")
            _open_side(b["id"], "N" if b_pos.y > a_pos.y else "S")
    for room in ROOMS:
        _build_room(room)
    for link in LINKS:
        _build_corridor(room_by_id[link[0]], room_by_id[link[1]])
    _boss_details()
    _exit_marker()

func _open_side(room_id: String, side: String) -> void:
    var sides: Array = openings[room_id]
    sides.append(side)
    openings[room_id] = sides

func _build_room(room: Dictionary) -> void:
    var center: Vector2 = room["pos"]
    var width: float = room["width"]
    var half := width * 0.5
    var boss_room: bool = room["id"] == "boss"
    _add_box(Vector3(center.x, -0.13, center.y), Vector3(width, 0.24, width), floor_mat)
    for side in ["N", "S", "E", "W"]:
        var has_door := (openings[room["id"]] as Array).has(side)
        if side == "N" or side == "S":
            var wall_z := center.y + (-half if side == "N" else half)
            _place_wall(Vector3(center.x, WALL_HEIGHT * 0.5, wall_z), width, true, has_door, red_stone if boss_room else stone)
        else:
            var wall_x := center.x + (-half if side == "W" else half)
            _place_wall(Vector3(wall_x, WALL_HEIGHT * 0.5, center.y), width, false, has_door, red_stone if boss_room else stone)
    _room_accents(room)

func _place_wall(center: Vector3, span: float, horizontal: bool, has_door: bool, material: Material) -> void:
    if not has_door:
        _wall_part(center, span, horizontal, material)
        return
    var side_len := (span - PASSAGE_WIDTH - 0.2) * 0.5
    if side_len <= 0.0:
        return
    var offset := PASSAGE_WIDTH * 0.5 + 0.1 + side_len * 0.5
    var axis := Vector3(1, 0, 0) if horizontal else Vector3(0, 0, 1)
    _wall_part(center - axis * offset, side_len, horizontal, material)
    _wall_part(center + axis * offset, side_len, horizontal, material)

func _wall_part(at: Vector3, span: float, horizontal: bool, material: Material) -> void:
    var dims := Vector3(span, WALL_HEIGHT, WALL_THICKNESS) if horizontal else Vector3(WALL_THICKNESS, WALL_HEIGHT, span)
    _add_box(at, dims, material)

func _build_corridor(a: Dictionary, b: Dictionary) -> void:
    var p: Vector2 = a["pos"]
    var q: Vector2 = b["pos"]
    var a_half: float = float(a["width"]) * 0.5
    var b_half: float = float(b["width"]) * 0.5
    if absf(p.x - q.x) > absf(p.y - q.y):
        var left := minf(p.x + (a_half if p.x < q.x else b_half), q.x + (b_half if q.x < p.x else a_half))
        var right := maxf(p.x - (a_half if p.x > q.x else b_half), q.x - (b_half if q.x > p.x else a_half))
        # Explicit edge-to-edge distance, regardless of link ordering.
        left = (p.x + a_half) if p.x < q.x else (q.x + b_half)
        right = (q.x - b_half) if p.x < q.x else (p.x - a_half)
        var length := right - left
        var mid := (left + right) * 0.5
        _add_box(Vector3(mid, -0.13, p.y), Vector3(length + 0.2, 0.24, PASSAGE_WIDTH), floor_mat)
        for side in [-1.0, 1.0]:
            _wall_part(Vector3(mid, WALL_HEIGHT * 0.5, p.y + side * (PASSAGE_WIDTH * 0.5 + 0.21)), length, true, stone)
    else:
        var near := (p.y + a_half) if p.y < q.y else (q.y + b_half)
        var far := (q.y - b_half) if p.y < q.y else (p.y - a_half)
        var length := far - near
        var mid := (near + far) * 0.5
        _add_box(Vector3(p.x, -0.13, mid), Vector3(PASSAGE_WIDTH, 0.24, length + 0.2), floor_mat)
        for side in [-1.0, 1.0]:
            _wall_part(Vector3(p.x + side * (PASSAGE_WIDTH * 0.5 + 0.21), WALL_HEIGHT * 0.5, mid), length, false, stone)

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
    var pos := Vector3(0, -0.003, -27.5)
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
    _add_box(Vector3(0, 0.48, -39.0), Vector3(4.6, 0.95, 1.65), border_stone)
    var boss_spot := Label3D.new()
    boss_spot.text = "DEMONICA  ·  ЗАЛ БОССА"
    boss_spot.font_size = 42
    boss_spot.pixel_size = 0.012
    boss_spot.billboard = BaseMaterial3D.BILLBOARD_ENABLED
    boss_spot.position = Vector3(0, 2.75, -33)
    boss_spot.modulate = Color("eebcb8")
    add_child(boss_spot)
    var light := OmniLight3D.new()
    light.position = Vector3(0, 3, -31)
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
    plaque.position = Vector3(0, 2.4, 56.2)
    plaque.modulate = Color("edd2a0")
    add_child(plaque)

func _return_to_city() -> void:
    get_tree().change_scene_to_file("res://scenes/city_preview.tscn")

extends "res://scripts/city_preview.gd"

const WallArtwork = preload("res://scripts/catacombs_wall_art.gd")

# ORVETHRA / Forgotten Catacombs: approved 5 small, 7 large, 1 boss layout.
# One Godot unit = one metre. 4m gross = ~3.5m clear with perimeter colliders.
# Real Meshy pieces are the visible architecture, the procedural stone is only
# textured mortar/backing around joints and sections without a GLB model.
const PASSAGE_WIDTH := 4.0 # 4m floor, >3.5m clear between 0.46m collision walls
const WALL_HEIGHT := 5.0
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

# The dungeon is textured 2.5D architecture: two flat wall images and one
# floor image mapped onto simple collision boxes. No Meshy 3D architecture.
const WALL_STONE_TILE := "res://assets/catacombs/tiles/wall_stone_mobile.webp"
const WALL_GUARD_TILE := "res://assets/catacombs/tiles/wall_guard_mobile.webp"
const FLOOR_STONE_TILE := "res://assets/catacombs/tiles/floor_stone_mobile.webp"

var room_by_id: Dictionary = {}
var walkable: Dictionary = {}
var floor_mat: ShaderMaterial
var masonry_mat: ShaderMaterial
var guard_mat: StandardMaterial3D
var wall_art_helper

const STONE_WALL_SHADER := """
shader_type spatial;
render_mode cull_disabled;
uniform sampler2D tile_tex : source_color, repeat_enable, filter_linear_mipmap;
varying vec3 world_pos;
varying vec3 wall_normal;
void vertex() {
    world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
    wall_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}
void fragment() {
    vec2 uv = abs(wall_normal.z) > abs(wall_normal.x)
        ? vec2(world_pos.x, -world_pos.y)
        : vec2(world_pos.z, -world_pos.y);
    if (abs(wall_normal.y) > 0.8) uv = world_pos.xz;
    ALBEDO = texture(tile_tex, uv / 3.0).rgb;
    ROUGHNESS = 0.98;
}
"""

const STONE_FLOOR_SHADER := """
shader_type spatial;
render_mode cull_disabled;
uniform sampler2D tile_tex : source_color, repeat_enable, filter_linear_mipmap;
varying vec3 world_pos;
void vertex() { world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
void fragment() {
    ALBEDO = texture(tile_tex, world_pos.xz / 3.2).rgb;
    ROUGHNESS = 0.97;
}
"""

func _ready() -> void:
    Engine.max_fps = 30
    _load_camera_distance()
    camera_distance = clampf(camera_distance, 4.0, 7.5)
    _dungeon_light()
    _prepare_materials()
    wall_art_helper = WallArtwork.new()
    _build_map()
    _player()
    player.position = DUNGEON_SPAWN
    city_hud = preload("res://scripts/catacombs_hud.gd").new()
    city_hud.game = self
    add_child(city_hud)
    _update_camera()

func _update_camera() -> void:
    if camera == null or player == null:
        return
    if overview:
        super._update_camera()
        return
    var focus := player.global_position + Vector3(0, 1.45, 0)
    var direction := Vector3(sin(yaw) * cos(pitch), sin(pitch), cos(yaw) * cos(pitch))
    var desired := focus + direction * camera_distance
    var query := PhysicsRayQueryParameters3D.create(focus, desired)
    query.exclude = [player.get_rid()]
    var collision := get_world_3d().direct_space_state.intersect_ray(query)
    if not collision.is_empty():
        var hit: Vector3 = collision["position"]
        desired = hit - direction * 0.34
        if desired.distance_to(focus) < 0.65:
            desired = focus + direction * 0.65
    camera.global_position = desired
    camera.look_at(focus, Vector3.UP)


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
    var wall_texture := load(WALL_STONE_TILE) as Texture2D
    var floor_texture := load(FLOOR_STONE_TILE) as Texture2D
    var guard_texture := load(WALL_GUARD_TILE) as Texture2D
    masonry_mat = _make_shader(STONE_WALL_SHADER)
    masonry_mat.set_shader_parameter("tile_tex", wall_texture)
    floor_mat = _make_shader(STONE_FLOOR_SHADER)
    floor_mat.set_shader_parameter("tile_tex", floor_texture)
    guard_mat = StandardMaterial3D.new()
    guard_mat.albedo_texture = guard_texture
    guard_mat.roughness = 1.0
    guard_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
    guard_mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS


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
    wall_art_helper.decorate_boss(self)
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
    # 4m gross width preserves more than 3.5m walking clearance after collision.
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
    # All walls are solid and visible now, including behind the boss room.
    # No throne mesh / GLB niche / hidden collider blocking visual textures.
    var dimensions := Vector3(span, WALL_HEIGHT, WALL_THICKNESS) if horizontal else Vector3(WALL_THICKNESS, WALL_HEIGHT, span)
    _add_box(location, dimensions, masonry_mat)
    _decorate_guard_tile(location, span, horizontal)


func _has_adjacent_room(point: Vector2) -> bool:
    for room in ROOMS:
        var pos: Vector2 = room["pos"]
        var half: float = float(room["width"]) * 0.5
        if absf(point.x - pos.x) <= half + 0.4 and absf(point.y - pos.y) <= half + 0.4:
            return true
    return false


func _interior_normal(at: Vector3, horizontal: bool) -> Vector3:
    var offset := Vector2(0.0, 0.36) if horizontal else Vector2(0.36, 0.0)
    var right := Vector2(at.x, at.z) + offset
    var cell := Vector2i(floori(right.x / CELL), floori(right.y / CELL))
    if walkable.has(cell):
        return Vector3(0, 0, 1) if horizontal else Vector3(1, 0, 0)
    return Vector3(0, 0, -1) if horizontal else Vector3(-1, 0, 0)


func _decorate_guard_tile(location: Vector3, span: float, horizontal: bool) -> void:
    if span < 5.5 or not _has_adjacent_room(Vector2(location.x, location.z)):
        return
    var inward := _interior_normal(location, horizontal)
    wall_art_helper.decorate_room_section(self, location, inward, horizontal, span)


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

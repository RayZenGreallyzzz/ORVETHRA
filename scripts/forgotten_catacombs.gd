extends "res://scripts/city_preview.gd"

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

var stone: StandardMaterial3D
var border_stone: StandardMaterial3D
var red_stone: StandardMaterial3D
var ember: StandardMaterial3D
var statue_stone: StandardMaterial3D
var floor_mat: ShaderMaterial
var masonry_mat: ShaderMaterial
var room_by_id: Dictionary = {}
var walkable: Dictionary = {}
# Optional shared Meshy resources. Absent GLBs fall back to lightweight geometry.
const NORMAL_WALL_GLB := "res://assets/catacombs/torchlit_gothic_wall_mobile.glb"
const STATUE_WALL_GLB := "res://assets/catacombs/torchlit_statue_wall_mobile.glb"
const CITADEL_WALL_GLB := "res://assets/catacombs/citadel_wall_mobile.glb"
const THRONE_GLB := "res://assets/catacombs/demonica_throne_mobile.glb"
var meshy_normal: PackedScene
var meshy_statue: PackedScene
var meshy_citadel: PackedScene
var meshy_throne: PackedScene
var installed_wall_bays := 0
var regular_wall_bays := 0
var boss_wall_bays := 0
const MAX_GLB_WALL_BAYS := 72
const MAX_BOSS_WALL_BAYS := 18

const MASONRY_PATTERN := """
shader_type spatial;
render_mode cull_disabled;
varying vec3 wp;
float rand2(vec2 p) {return fract(sin(dot(p,vec2(17.1,91.37)))*43758.5453);}
void vertex() { wp=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz; }
void fragment(){
    vec2 uv;
    // Material appears on both wall orientations, with 1m-ish stone blocks.
    if(abs(NORMAL.z)>abs(NORMAL.x)) uv=vec2(wp.x,wp.y);
    else uv=vec2(wp.z,wp.y);
    uv*=vec2(1.25,1.55);
    uv.x+=mod(floor(uv.y),2.0)*0.53;
    vec2 tile=floor(uv);
    vec2 f=fract(uv);
    float mortar=smoothstep(0.035,0.065,min(min(f.x,1.0-f.x),min(f.y,1.0-f.y)));
    float speck=rand2(tile)*0.10+rand2(floor(uv*20.0))*0.02;
    vec3 brick=mix(vec3(0.22,0.19,0.18),vec3(0.38,0.33,0.30),rand2(tile));
    ALBEDO=mix(vec3(0.065,0.064,0.070),brick+speck,mortar);
    ROUGHNESS=1.0;
}
"""
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
    _load_mobile_meshes()
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
    stone = _plain("504d4c")
    border_stone = _plain("302d32")
    red_stone = _plain("5a3037")
    statue_stone = _plain("81776c")
    ember = _plain("a53c35")
    ember.emission_enabled = true
    ember.emission = Color("b84d43")
    ember.emission_energy_multiplier = 1.6
    floor_mat = _make_shader(FLOOR_PATTERN)
    masonry_mat = _make_shader(MASONRY_PATTERN)

func _load_mobile_meshes() -> void:
    if ResourceLoader.exists(NORMAL_WALL_GLB):
        meshy_normal = load(NORMAL_WALL_GLB) as PackedScene
    if ResourceLoader.exists(STATUE_WALL_GLB):
        meshy_statue = load(STATUE_WALL_GLB) as PackedScene
    if ResourceLoader.exists(CITADEL_WALL_GLB):
        meshy_citadel = load(CITADEL_WALL_GLB) as PackedScene
    if ResourceLoader.exists(THRONE_GLB):
        meshy_throne = load(THRONE_GLB) as PackedScene

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
    var boss_center := Vector2(-17.0, -47.5)
    var near_boss := Vector2(location.x, location.z).distance_to(boss_center) < 18.0
    # The throne extends through the north/back wall. Leave a 14m visual
    # opening to display its full Meshy architecture; keep an invisible collider
    # across that boundary so the player cannot leave the 25m room.
    if horizontal and span > 20.0 and absf(location.z + 60.0) < 0.3:
        _add_invisible_wall(location, Vector3(span, WALL_HEIGHT, WALL_THICKNESS))
        var side_span := (span - 14.0) * 0.5
        var side_offset := 7.0 + side_span * 0.5
        for sign in [-1.0, 1.0]:
            var wing := location + Vector3(sign * side_offset, 0, 0)
            _add_box(wing, Vector3(side_span, WALL_HEIGHT, WALL_THICKNESS), masonry_mat, false)
            _decorate_wall_segment(wing, side_span, true, true)
        return
    # Textured stone backing covers joins, while Meshy faces stand proud of it.
    # Collision is kept on the perimeter and independent from the model meshes.
    _wall_part(location, span, horizontal, masonry_mat)
    _decorate_wall_segment(location, span, horizontal, near_boss)

func _add_invisible_wall(at: Vector3, dimensions: Vector3) -> void:
    var wall := StaticBody3D.new()
    var shape := CollisionShape3D.new()
    var collider := BoxShape3D.new()
    collider.size = dimensions
    shape.shape = collider
    wall.position = at
    wall.add_child(shape)
    add_child(wall)


func _has_adjacent_room(point: Vector2) -> bool:
    for room in ROOMS:
        var pos: Vector2 = room["pos"]
        var half: float = float(room["width"]) * 0.5
        if absf(point.x - pos.x) <= half + 0.4 and absf(point.y - pos.y) <= half + 0.4:
            return true
    return false

func _interior_normal(at: Vector3, horizontal: bool) -> Vector3:
    # The float near the centre of each wall identifies its playable side.
    var offset := Vector2(0.0, 0.36) if horizontal else Vector2(0.36, 0.0)
    var right := Vector2(at.x, at.z) + offset
    var cell := Vector2i(floori(right.x / CELL), floori(right.y / CELL))
    if walkable.has(cell):
        return Vector3(0, 0, 1) if horizontal else Vector3(1, 0, 0)
    return Vector3(0, 0, -1) if horizontal else Vector3(-1, 0, 0)

func _decorative_mesh(mesh: Mesh, position_3d: Vector3, mat: Material, rotation := Vector3.ZERO) -> void:
    var visual := MeshInstance3D.new()
    visual.mesh = mesh
    visual.position = position_3d
    visual.rotation = rotation
    visual.material_override = mat
    visual.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    add_child(visual)

func _decorate_wall_segment(location: Vector3, span: float, horizontal: bool, near_boss: bool) -> void:
    # Short corridor junctions use a detailed brick shader and no giant statue.
    # Longer room boundaries are populated by real mobile Meshy wall modules.
    if span < 3.6 or not _has_adjacent_room(Vector2(location.x, location.z)):
        return
    var inward := _interior_normal(location, horizontal)
    var tangent := Vector3(1, 0, 0) if horizontal else Vector3(0, 0, 1)
    var count := maxi(1, int(round(span / 4.25)))
    var step := span / float(count)
    for index in range(count):
        var offset := (float(index) + 0.5) * step - span * 0.5
        var bay := location + tangent * offset
        var is_statue := (installed_wall_bays + index) % 3 == 1
        var budget_available := boss_wall_bays < MAX_BOSS_WALL_BAYS if near_boss else regular_wall_bays < MAX_GLB_WALL_BAYS
        if budget_available and _place_meshy_wall_bay(bay, inward, step, is_statue, near_boss):
            installed_wall_bays += 1
            if near_boss:
                boss_wall_bays += 1
            else:
                regular_wall_bays += 1
        else:
            # Models unavailable or mobile draw budget reached: masonry remains
            # visible and collision-solid, never an untextured grey blocker.
            var frame := red_stone if near_boss else border_stone
            var dimensions := Vector3(step * 0.77, 0.22, 0.14) if horizontal else Vector3(0.14, 0.22, step * 0.77)
            _add_box(bay + inward * 0.255 + Vector3.UP * 1.65, dimensions, frame, false)


func _place_meshy_wall_bay(at: Vector3, inward: Vector3, width: float, is_statue: bool, near_boss: bool) -> bool:
    var model_scene: PackedScene = meshy_statue if is_statue else meshy_normal
    var raw_w := 1.825 if is_statue else 1.900
    var raw_h := 1.679 if is_statue else 0.749
    var raw_d := 1.855 if is_statue else 0.271
    if near_boss and not is_statue and meshy_citadel != null:
        model_scene = meshy_citadel
        raw_w = 1.902
        raw_h = 0.703
        raw_d = 0.262
    if model_scene == null:
        return false

    # Uniform scaling only. Standard walls stack vertically to cover a five
    # metre perimeter; ornate statuary fills almost the entire height.
    var rows := 1 if is_statue else 3
    var scale_factor := minf((width - 0.06) / raw_w, (WALL_HEIGHT - 0.1) / (raw_h * float(rows)))
    if scale_factor < 0.6:
        return false
    var front_depth := raw_d * scale_factor * 0.5
    # Imported asset faces +Z. Turn it into the room, not through the wall.
    var orientation := atan2(inward.x, inward.z)
    for row_index in range(rows):
        var piece := model_scene.instantiate() as Node3D
        piece.name = "MeshyWall_%d_%d" % [installed_wall_bays, row_index]
        piece.rotation.y = orientation
        piece.scale = Vector3.ONE * scale_factor
        # All GLBs are centred at Y=0. Their bottom must touch ground.
        # The front face protrudes 0.43m into the playable area, past the
        # 0.23m collision half-wall and the recessed brick backing.
        piece.position = Vector3(at.x, raw_h * scale_factor * (float(row_index) + 0.5) + 0.015, at.z)
        piece.position += inward * (0.43 - front_depth)
        add_child(piece)
    return true


func _stone_statue(at: Vector3, inward: Vector3, near_boss: bool) -> void:
    # Low-poly sculpted guardian set back into a shallow gothic niche.
    # Meshes are decorative (no collision), the solid wall keeps physics.
    var shell := red_stone if near_boss else border_stone
    var wall_face := at + inward * 0.34
    _add_box(wall_face - Vector3.UP * 1.72, Vector3(0.88, 0.42, 0.84),
        shell, false)
    var torso := CapsuleMesh.new()
    torso.radius = 0.31
    torso.height = 1.3
    torso.radial_segments = 7
    torso.rings = 3
    _decorative_mesh(torso, wall_face - Vector3.UP * 0.6, statue_stone)
    var head := SphereMesh.new()
    head.radius = 0.23
    head.height = 0.46
    head.radial_segments = 8
    head.rings = 4
    _decorative_mesh(head, wall_face + Vector3.UP * 0.38, statue_stone)
    var halo := CylinderMesh.new()
    halo.top_radius = 0.31
    halo.bottom_radius = 0.42
    halo.height = 0.22
    halo.radial_segments = 8
    _decorative_mesh(halo, wall_face + Vector3.UP * 0.65, shell)
    # The statue's carved frame shares the original wall plane.
    _add_box(at + inward * 0.22 + Vector3.UP * 1.55,
        Vector3(1.03, 0.20, 0.28) if absf(inward.z) > 0.5 else Vector3(0.28, 0.20, 1.03),
        shell, false)

func _wall_part(at: Vector3, span: float, horizontal: bool, material: Material) -> void:
    var dimensions := Vector3(span, WALL_HEIGHT, WALL_THICKNESS) if horizontal else Vector3(WALL_THICKNESS, WALL_HEIGHT, span)
    _add_box(at, dimensions, material)

func _room_accents(room: Dictionary) -> void:
    # Old oversized grey placeholder pillars are only for the no-GLB fallback.
    if meshy_normal != null:
        return
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
    # A thin rune outline instead of an opaque red disc over the floor.
    var center := Vector3(-17.0, 0.045, -47.5)
    for i in range(32):
        var a := TAU * float(i) / 32.0
        var rune := MeshInstance3D.new()
        var brick := BoxMesh.new()
        brick.size = Vector3(1.28, 0.025, 0.095)
        rune.mesh = brick
        rune.material_override = ember
        rune.position = center + Vector3(cos(a) * 6.1, 0, sin(a) * 6.1)
        rune.rotation.y = -a - PI * 0.5
        rune.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
        add_child(rune)
    # Keep a completely open fighting centre; the imported hall is a
    # scaled prop at the back, not a replacement for the 25x25m arena.
    if meshy_throne != null:
        var throne := meshy_throne.instantiate() as Node3D
        throne.name = "MeshyDemonicaThrone"
        # Original GLB bounds 1.862 x 1.016 x 1.898. 6.4x gives a
        # 12m-wide/6.5m-high structure, partially behind the far wall.
        # Its front begins at Z=-54, leaving a free central battle arena.
        throne.scale = Vector3.ONE * 6.4
        throne.position = Vector3(-17, 3.25, -60.0)
        add_child(throne)
    else:
        # The centre is empty so a later imported Demonica can fight here.
        # Spacious 25x25m boss chamber: high throne at the far wall, with
        # side pillars and three raised steps. Central fighting area is free.
        for step_idx in range(3):
            var step_depth := 1.7 + float(step_idx) * 0.3
            var step_width := 6.5 - float(step_idx) * 0.5
            _add_box(Vector3(-17, 0.18 + float(step_idx) * 0.18, -57.2 - float(step_idx) * 0.58),
                Vector3(step_width, 0.36 + float(step_idx) * 0.36, step_depth),
                border_stone)
        _add_box(Vector3(-17, 1.85, -59.0), Vector3(2.1, 3.2, 0.95), red_stone)
        _add_box(Vector3(-17, 3.6, -59.0), Vector3(3.2, 0.65, 1.05), statue_stone, false)
        for sign in [-1.0, 1.0]:
            _add_box(Vector3(-17 + sign * 5.5, 2.3, -57.3),
                Vector3(0.95, 4.6, 0.95), red_stone)
            var crown := CylinderMesh.new()
            crown.top_radius = 0.65
            crown.bottom_radius = 0.85
            crown.height = 0.5
            crown.radial_segments = 10
            _decorative_mesh(crown, Vector3(-17 + sign * 5.5, 4.7, -57.3), statue_stone)
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

extends Node3D

# ORVETHRA — walkable old-town street layout review, before placing buildings.
# No 19k x 17k PNG: road ribbons are geometry and pavement is world-space tiled.
const MAP_HALF_X := 107.0
const MAP_HALF_Z := 93.0
const HERO_SCENE_PATH := "res://assets/characters/ORVETHRA_NeonAlleycat_Animated_Mobile.glb"
const FountainMobile = preload("res://scripts/fountain_mobile.gd")
var player: CharacterBody3D
var camera: Camera3D
var yaw := 0.0
var pitch := 0.48
var overview := false
var overview_height := 185.0
var overview_center := Vector2.ZERO
var touch_id := -1
var city_hud
var camera_follow := Vector3.ZERO
var moving_speed := 0.0
const CHARACTER_WALK_SPEED := 3.0
const CHARACTER_RUN_SPEED := 5.65
var roads: Array[PackedVector2Array] = []
var hero_visual: Node3D
var hero_anim: AnimationPlayer
var hero_animation := ""

const STONE_SHADER := """
shader_type spatial;
render_mode cull_disabled;
varying vec3 world_pos;
float random2(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
void vertex() { world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
void fragment() {
    vec2 p = world_pos.xz * 1.55;
    p.x += mod(floor(p.y), 2.0) * 0.43;
    vec2 c = floor(p);
    vec2 q = fract(p);
    float n = random2(c);
    float n2 = random2(c + 13.3);
    vec2 d = abs(q - 0.5);
    float facet = max(d.x * (0.92 + 0.12 * n), d.y * (0.95 + 0.13 * n2));
    float grain = random2(floor(world_pos.xz * 48.0)) - 0.5;
    float vein = sin(world_pos.x * 31.0 + world_pos.z * 13.0 + n * 7.0) * 0.027;
    float joint = smoothstep(0.424, 0.477, facet + grain * 0.007);
    vec3 rock_a = vec3(0.48, 0.475, 0.438);
    vec3 rock_b = vec3(0.65, 0.619, 0.551);
    vec3 rock = mix(rock_a, rock_b, n);
    rock += (grain * 0.095 + vein) * vec3(1.0, 0.96, 0.9);
    float bevel = 1.0 - smoothstep(0.34, 0.43, facet);
    rock += bevel * 0.055;
    vec3 mortar = mix(vec3(0.235, 0.23, 0.20), vec3(0.24, 0.29, 0.19), n2 * 0.55);
    ALBEDO = mix(rock, mortar, joint);
    ROUGHNESS = 0.98;
}
"""
const GRASS_SHADER := """
shader_type spatial;
render_mode cull_disabled;
varying vec3 world_pos;
float h(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
void vertex() { world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
void fragment() {
    vec2 p = world_pos.xz;
    float n = h(floor(p * 4.5));
    float lo = h(floor(p * 0.85));
    float blades = sin(p.x * 43.0 + p.y * 18.0) * sin(p.x * 11.0 - p.y * 37.0);
    vec3 base = mix(vec3(0.25, 0.36, 0.21), vec3(0.40, 0.44, 0.27), lo);
    ALBEDO = base + vec3(0.10, 0.09, 0.045) * (n - 0.5) + blades * 0.017;
    ROUGHNESS = 1.0;
}
"""

func _ready() -> void:
    Engine.max_fps = 30
    _lighting()
    _ground()
    _layout()
    FountainMobile.add_to(self)
    _player()
    _interface()
    _update_camera()

func _make_shader(code: String) -> ShaderMaterial:
    var shader := Shader.new()
    shader.code = code
    var material := ShaderMaterial.new()
    material.shader = shader
    return material

func _plain(hex: String) -> StandardMaterial3D:
    var mat := StandardMaterial3D.new()
    mat.albedo_color = Color(hex)
    mat.roughness = 1.0
    return mat

func _lighting() -> void:
    var world := WorldEnvironment.new()
    var env := Environment.new()
    env.background_mode = Environment.BG_COLOR
    env.background_color = Color("b8cbd0")
    env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
    env.ambient_light_color = Color("d7d5c5")
    env.ambient_light_energy = 0.85
    world.environment = env
    add_child(world)
    var sun := DirectionalLight3D.new()
    sun.rotation_degrees = Vector3(-54, -30, 0)
    sun.light_color = Color("fff0d7")
    sun.light_energy = 1.05
    sun.shadow_enabled = false
    add_child(sun)

func _ground() -> void:
    var floor := MeshInstance3D.new()
    var mesh := PlaneMesh.new()
    mesh.size = Vector2(2.0 * MAP_HALF_X + 12.0, 2.0 * MAP_HALF_Z + 12.0)
    floor.mesh = mesh
    floor.position.y = -0.055
    floor.material_override = _make_shader(GRASS_SHADER)
    floor.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    add_child(floor)
    var body := StaticBody3D.new()
    body.position = Vector3(0, -0.22, 0)
    var box := CollisionShape3D.new()
    var shape := BoxShape3D.new()
    shape.size = Vector3(2.0 * MAP_HALF_X + 12.0, 0.30, 2.0 * MAP_HALF_Z + 12.0)
    box.shape = shape
    body.add_child(box)
    add_child(body)

func _smooth(route: PackedVector2Array) -> PackedVector2Array:
    var result := PackedVector2Array()
    if route.size() < 2:
        return route
    for i in range(route.size() - 1):
        var p0: Vector2 = route[maxi(i - 1, 0)]
        var p1: Vector2 = route[i]
        var p2: Vector2 = route[i + 1]
        var p3: Vector2 = route[mini(i + 2, route.size() - 1)]
        for step in range(10):
            var t := float(step) / 10.0
            var point: Vector2 = 0.5 * ((2.0 * p1) + (-p0 + p2) * t + (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t * t + (-p0 + 3.0 * p1 - 3.0 * p2 + p3) * t * t * t)
            result.append(point)
    result.append(route[route.size() - 1])
    return result

func _ribbon(route: PackedVector2Array, width: float, y: float, material: Material) -> void:
    var path := _smooth(route)
    var vertices := PackedVector3Array()
    var indices := PackedInt32Array()
    for i in range(path.size()):
        var prev: Vector2 = path[maxi(0, i - 1)]
        var next: Vector2 = path[mini(path.size() - 1, i + 1)]
        var tangent: Vector2 = (next - prev).normalized()
        var normal := Vector2(-tangent.y, tangent.x)
        var p: Vector2 = path[i]
        vertices.append(Vector3(p.x + normal.x * width * 0.5, y, p.y + normal.y * width * 0.5))
        vertices.append(Vector3(p.x - normal.x * width * 0.5, y, p.y - normal.y * width * 0.5))
        if i > 0:
            var ix: int = i * 2
            indices.append_array(PackedInt32Array([ix - 2, ix - 1, ix, ix - 1, ix + 1, ix]))
    var arrays: Array = []
    arrays.resize(Mesh.ARRAY_MAX)
    arrays[Mesh.ARRAY_VERTEX] = vertices
    arrays[Mesh.ARRAY_INDEX] = indices
    var mesh := ArrayMesh.new()
    mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
    var obj := MeshInstance3D.new()
    obj.mesh = mesh
    obj.material_override = material
    obj.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    add_child(obj)

func _disc(radius: float, y: float, material: Material) -> void:
    var vertices := PackedVector3Array()
    var indices := PackedInt32Array()
    vertices.append(Vector3(0, y, 0))
    for i in range(65):
        var a := TAU * float(i) / 64.0
        vertices.append(Vector3(sin(a) * radius, y, cos(a) * radius))
        if i > 0:
            indices.append_array(PackedInt32Array([0, i, i + 1]))
    var arrays: Array = []
    arrays.resize(Mesh.ARRAY_MAX)
    arrays[Mesh.ARRAY_VERTEX] = vertices
    arrays[Mesh.ARRAY_INDEX] = indices
    var mesh := ArrayMesh.new()
    mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
    var obj := MeshInstance3D.new()
    obj.mesh = mesh
    obj.material_override = material
    obj.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    add_child(obj)

func _ring(radius: float, width: float, y: float, material: Material) -> void:
    var vertices := PackedVector3Array()
    var indices := PackedInt32Array()
    for i in range(65):
        var a := TAU * float(i) / 64.0
        var sn := sin(a)
        var cs := cos(a)
        vertices.append(Vector3(sn * (radius - width * 0.5), y, cs * (radius - width * 0.5)))
        vertices.append(Vector3(sn * (radius + width * 0.5), y, cs * (radius + width * 0.5)))
        if i > 0:
            var ix: int = i * 2
            indices.append_array(PackedInt32Array([ix - 2, ix - 1, ix, ix - 1, ix + 1, ix]))
    var arrays: Array = []
    arrays.resize(Mesh.ARRAY_MAX)
    arrays[Mesh.ARRAY_VERTEX] = vertices
    arrays[Mesh.ARRAY_INDEX] = indices
    var mesh := ArrayMesh.new()
    mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
    var obj := MeshInstance3D.new()
    obj.mesh = mesh
    obj.material_override = material
    obj.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    add_child(obj)

func _layout() -> void:
    var cobble := _make_shader(STONE_SHADER)
    var kerb := _plain("77796f")
    kerb.cull_mode = BaseMaterial3D.CULL_DISABLED
    # Winding old-town road graph based on the approved radial, irregular sketch:
    # broad central square, branching alleys, no modern rectangular grid.
    roads = [
        PackedVector2Array([Vector2(-108,-30),Vector2(-82,-30),Vector2(-60,-35),Vector2(-41,-23),Vector2(-14,-9),Vector2(0,0)]),
        PackedVector2Array([Vector2(-108,-4),Vector2(-79,-4),Vector2(-56,-7),Vector2(-35,-3),Vector2(-12,0),Vector2(0,0)]),
        PackedVector2Array([Vector2(-105,51),Vector2(-76,48),Vector2(-56,39),Vector2(-31,28),Vector2(-13,10),Vector2(0,0)]),
        PackedVector2Array([Vector2(-29,-96),Vector2(-26,-70),Vector2(-17,-47),Vector2(-21,-29),Vector2(-13,-14),Vector2(0,0)]),
        PackedVector2Array([Vector2(72,-96),Vector2(64,-70),Vector2(57,-47),Vector2(40,-29),Vector2(21,-13),Vector2(0,0)]),
        PackedVector2Array([Vector2(108,-28),Vector2(80,-18),Vector2(66,-8),Vector2(42,-13),Vector2(22,-3),Vector2(0,0)]),
        PackedVector2Array([Vector2(108,48),Vector2(84,44),Vector2(66,37),Vector2(43,31),Vector2(21,14),Vector2(0,0)]),
        PackedVector2Array([Vector2(42,97),Vector2(35,73),Vector2(23,54),Vector2(8,34),Vector2(8,16),Vector2(0,0)]),
        PackedVector2Array([Vector2(-52,-96),Vector2(-52,-76),Vector2(-44,-61),Vector2(-57,-46),Vector2(-60,-35)]),
        PackedVector2Array([Vector2(106,-64),Vector2(90,-53),Vector2(72,-51),Vector2(57,-47)]),
        PackedVector2Array([Vector2(-108,25),Vector2(-90,22),Vector2(-73,25),Vector2(-56,39)]),
        PackedVector2Array([Vector2(108,10),Vector2(94,13),Vector2(78,25),Vector2(66,37)]),
        PackedVector2Array([Vector2(-71,94),Vector2(-64,70),Vector2(-76,48)]),
        PackedVector2Array([Vector2(-10,95),Vector2(-18,77),Vector2(-29,56),Vector2(-31,28)]),
        PackedVector2Array([Vector2(90,94),Vector2(78,78),Vector2(84,44)])
    ]
    for path in roads:
        _ribbon(path, 10.0, -0.005, kerb)
        _ribbon(path, 8.8, 0.008, cobble)
    _disc(17.4, 0.014, kerb)
    _disc(16.7, 0.022, cobble)
    _ring(12.4, 0.75, 0.034, kerb)
    _ring(6.9, 0.55, 0.035, kerb)
    _disc(6.0, 0.037, cobble)

func _character_material(hex: String) -> StandardMaterial3D:
    return _plain(hex)

func _find_animation_player(node: Node):
    if node is AnimationPlayer:
        return node
    for child in node.get_children():
        var found = _find_animation_player(child)
        if found != null:
            return found
    return null

func _resolve_hero_animation(wanted: String) -> StringName:
    if hero_anim == null:
        return &""
    var target := wanted.to_lower()
    for anim_name in hero_anim.get_animation_list():
        var candidate := String(anim_name)
        var lower := candidate.to_lower()
        if lower == target or lower.ends_with("/" + target) or lower.ends_with(target):
            return anim_name
    return &""

func _play_hero(wanted: String) -> void:
    if hero_anim == null or hero_animation == wanted:
        return
    var resolved := _resolve_hero_animation(wanted)
    if resolved == &"":
        return
    hero_anim.play(resolved, 0.14)
    hero_animation = wanted

func _prepare_hero_animations() -> void:
    if hero_anim == null:
        return
    # Baked FBX clips are commonly ONCE animations. When Run ends after one
    # cycle physics continues moving but the mesh freezes and 'skates'.
    for animation_name in hero_anim.get_animation_list():
        var animation := hero_anim.get_animation(animation_name)
        if animation == null:
            continue
        animation.loop_mode = Animation.LOOP_LINEAR
        # Leave the hip bob (Y) intact, but remove excessive baked X/Z
        # root displacement so movement is controlled by CharacterBody3D.
        for track in range(animation.get_track_count()):
            if animation.track_get_type(track) != Animation.TYPE_POSITION_3D:
                continue
            var path := str(animation.track_get_path(track)).to_lower()
            if not path.contains("hips") and not path.contains("root"):
                continue
            if animation.track_get_key_count(track) < 2:
                continue
            var first_value = animation.track_get_key_value(track, 0)
            if not first_value is Vector3:
                continue
            var furthest := 0.0
            for key in range(animation.track_get_key_count(track)):
                var value = animation.track_get_key_value(track, key)
                if value is Vector3:
                    furthest = maxf(furthest, Vector2(value.x - first_value.x, value.z - first_value.z).length())
            if furthest > 0.22:
                for key in range(animation.track_get_key_count(track)):
                    var value = animation.track_get_key_value(track, key)
                    if value is Vector3:
                        value.x = first_value.x
                        value.z = first_value.z
                        animation.track_set_key_value(track, key, value)

func _lowest_mesh_y(node: Node, relative_to_hero: Transform3D) -> float:
    var bottom := INF
    if node is MeshInstance3D:
        var mesh_node: MeshInstance3D = node as MeshInstance3D
        if mesh_node.mesh != null:
            var box: AABB = mesh_node.mesh.get_aabb()
            var rel: Transform3D = relative_to_hero * mesh_node.global_transform
            for ix in range(2):
                for iy in range(2):
                    for iz in range(2):
                        var point: Vector3 = box.position + Vector3(box.size.x * float(ix), box.size.y * float(iy), box.size.z * float(iz))
                        bottom = minf(bottom, (rel * point).y)
    for child in node.get_children():
        bottom = minf(bottom, _lowest_mesh_y(child, relative_to_hero))
    return bottom

func _disable_hero_shadows(node: Node) -> void:
    if node is GeometryInstance3D:
        node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    for child in node.get_children():
        _disable_hero_shadows(child)

func _player() -> void:
    player = CharacterBody3D.new()
    player.name = "CityExplorer"
    player.position = Vector3(0, 0.12, 11)
    player.floor_snap_length = 0.35
    add_child(player)

    var collision := CollisionShape3D.new()
    var shape := CapsuleShape3D.new()
    shape.radius = 0.35
    shape.height = 1.8
    collision.shape = shape
    collision.position.y = 0.93
    player.add_child(collision)

    var hero_scene = load(HERO_SCENE_PATH)
    if hero_scene is PackedScene:
        hero_visual = hero_scene.instantiate()
        hero_visual.name = "NeonAlleycat"
        hero_visual.position.y = 0.0
        player.add_child(hero_visual)
        _disable_hero_shadows(hero_visual)
        var lowest := _lowest_mesh_y(hero_visual, hero_visual.global_transform.affine_inverse())
        # Align the actual mesh bounding box instead of assuming 0.95m.
        hero_visual.position.y = (-lowest + 0.055) if lowest != INF else 0.95
        hero_anim = _find_animation_player(hero_visual)
        _prepare_hero_animations()
        _play_hero("Idle")

    camera = Camera3D.new()
    camera.current = true
    camera.fov = 67
    add_child(camera)

func _input(event: InputEvent) -> void:
    if event is InputEventScreenTouch:
        if event.pressed and event.position.x > get_viewport().get_visible_rect().size.x * 0.49 and touch_id == -1:
            touch_id = event.index
        elif not event.pressed and event.index == touch_id:
            touch_id = -1
    elif event is InputEventScreenDrag and event.index == touch_id:
        _drag_view(event.relative)
    elif event is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
        _drag_view(event.relative)
    elif event is InputEventMouseButton and event.pressed and overview:
        if event.button_index == MOUSE_BUTTON_WHEEL_UP:
            overview_height = maxf(75.0, overview_height - 18.0)
        elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
            overview_height = minf(290.0, overview_height + 18.0)

func _drag_view(diff: Vector2) -> void:
    if overview:
        overview_center.x = clampf(overview_center.x - diff.x * overview_height * 0.004, -MAP_HALF_X, MAP_HALF_X)
        overview_center.y = clampf(overview_center.y - diff.y * overview_height * 0.004, -MAP_HALF_Z, MAP_HALF_Z)
    else:
        yaw -= diff.x * 0.004
        pitch = clampf(pitch + diff.y * 0.004, 0.15, 0.92)

func _move_direction() -> Vector2:
    var keyboard := Vector2(
        float(int(Input.is_action_pressed("move_right")) - int(Input.is_action_pressed("move_left"))),
        float(int(Input.is_action_pressed("move_back")) - int(Input.is_action_pressed("move_forward")))
    )
    var analog := Vector2.ZERO
    if city_hud != null and city_hud.joystick != null:
        analog = city_hud.joystick.value
    return (keyboard + analog).limit_length(1.0)

func _physics_process(delta: float) -> void:
    var stick := _move_direction()
    if overview:
        overview_center += stick * (75.0 * delta)
        overview_center.x = clampf(overview_center.x, -MAP_HALF_X, MAP_HALF_X)
        overview_center.y = clampf(overview_center.y, -MAP_HALF_Z, MAP_HALF_Z)
        player.velocity = Vector3.ZERO
        _play_hero("Idle")
    else:
        var forward := Vector3(-sin(yaw), 0.0, -cos(yaw))
        var right := Vector3(cos(yaw), 0.0, -sin(yaw))
        var direction := (right * stick.x - forward * stick.y).limit_length(1.0)
        var pace := CHARACTER_RUN_SPEED if city_hud == null or city_hud.run_mode else CHARACTER_WALK_SPEED
        var wanted := direction * pace
        var acceleration := 27.0 if stick.length() > 0.11 else 46.0
        player.velocity.x = move_toward(player.velocity.x, wanted.x, acceleration * delta)
        player.velocity.z = move_toward(player.velocity.z, wanted.z, acceleration * delta)
        moving_speed = Vector2(player.velocity.x, player.velocity.z).length()
        if stick.length() > 0.11:
            var desired_yaw := atan2(-direction.x, -direction.z)
            player.rotation.y = lerp_angle(player.rotation.y, desired_yaw, minf(1.0, 15.0 * delta))
            _play_hero("Run")
            if hero_anim != null:
                hero_anim.speed_scale = clampf(moving_speed / 4.8, 0.70, 1.25)
        else:
            _play_hero("Idle")
            if hero_anim != null:
                hero_anim.speed_scale = 1.0

        if not player.is_on_floor():
            player.velocity.y -= 20.0 * delta
        else:
            player.velocity.y = -0.3
        player.move_and_slide()
        player.position.x = clampf(player.position.x, -MAP_HALF_X, MAP_HALF_X)
        player.position.z = clampf(player.position.z, -MAP_HALF_Z, MAP_HALF_Z)
    _update_camera()

func _update_camera() -> void:
    if overview:
        camera.position = Vector3(overview_center.x, overview_height, overview_center.y + 0.01)
        camera.look_at(Vector3(overview_center.x, 0, overview_center.y), Vector3.FORWARD)
    else:
        var focus := player.global_position + Vector3(0, 1.4, 0)
        var direction := Vector3(sin(yaw) * cos(pitch), sin(pitch), cos(yaw) * cos(pitch))
        camera.global_position = focus + direction * 10.5
        camera.look_at(focus, Vector3.UP)

func _interface() -> void:
    city_hud = preload("res://scripts/city_hud.gd").new()
    city_hud.game = self
    add_child(city_hud)

func _toggle_overview() -> void:
    overview = not overview
    if overview:
        overview_center = Vector2(player.position.x, player.position.z)

func _try_attack() -> void:
    # Animation-only preview: attack FBXs are not yet included in the mobile GLB.
    var punch := _resolve_hero_animation("Punch")
    if punch != &"" and hero_anim != null:
        hero_anim.play(punch, 0.12)
        hero_animation = "Punch"

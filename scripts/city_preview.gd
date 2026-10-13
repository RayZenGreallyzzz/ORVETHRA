extends Node3D

# ORVETHRA — walkable old-town street layout review, before placing buildings.
# No 19k x 17k PNG: road ribbons are geometry and pavement is world-space tiled.
const MAP_HALF_X := 107.0
const MAP_HALF_Z := 93.0
const HERO_SCENE_PATH := "res://assets/characters/ORVETHRA_NeonAlleycat_Animated_Mobile.glb"\nconst FountainMobile = preload("res://scripts/fountain_mobile.gd")
var player: CharacterBody3D
var camera: Camera3D
var yaw := 0.0
var pitch := 0.48
var overview := false
var overview_height := 185.0
var overview_center := Vector2.ZERO
var touch_id := -1
var held_forward := false
var held_back := false
var held_left := false
var held_right := false
var frame_time := 0.0
var status: Label
var overview_button: Button
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
    hero_anim.play(resolved, 0.16)
    hero_animation = wanted

func _disable_hero_shadows(node: Node) -> void:
    if node is GeometryInstance3D:
        node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    for child in node.get_children():
        _disable_hero_shadows(child)

func _player() -> void:
    player = CharacterBody3D.new()
    player.name = "CityExplorer"
    player.position = Vector3(0, 0.12, 11)
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
        # The converted FBX mesh is centred vertically; lift its feet to street level.
        hero_visual.position.y = 0.95
        player.add_child(hero_visual)
        _disable_hero_shadows(hero_visual)
        hero_anim = _find_animation_player(hero_visual)
        _play_hero("Idle")

    camera = Camera3D.new()
    camera.current = true
    camera.fov = 67
    add_child(camera)

func _input(event: InputEvent) -> void:
    if event is InputEventScreenTouch:
        if event.pressed and event.position.x > get_viewport().get_visible_rect().size.x * 0.48:
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
    var x := int(Input.is_action_pressed("move_right")) - int(Input.is_action_pressed("move_left")) + int(held_right) - int(held_left)
    var z := int(Input.is_action_pressed("move_back")) - int(Input.is_action_pressed("move_forward")) + int(held_back) - int(held_forward)
    return Vector2(float(x), float(z)).limit_length(1.0)

func _physics_process(delta: float) -> void:
    var stick := _move_direction()
    if overview:
        overview_center += stick * (75.0 * delta)
        overview_center.x = clampf(overview_center.x, -MAP_HALF_X, MAP_HALF_X)
        overview_center.y = clampf(overview_center.y, -MAP_HALF_Z, MAP_HALF_Z)
        player.velocity = Vector3.ZERO
        _play_hero("Idle")
    else:
        var forward := Vector3(-sin(yaw), 0, -cos(yaw))
        var right := Vector3(cos(yaw), 0, -sin(yaw))
        var direction := right * stick.x - forward * stick.y
        player.velocity.x = direction.x * 6.0
        player.velocity.z = direction.z * 6.0

        if direction.length_squared() > 0.01:
            # The supplied FBX set contains Idle, Run and StrafeRight.
            # Right strafe keeps the body facing forward; normal travel turns into movement.
            if stick.x > 0.35 and absf(stick.x) > absf(stick.y):
                player.rotation.y = yaw
                _play_hero("StrafeRight")
            else:
                player.rotation.y = atan2(-direction.x, -direction.z)
                _play_hero("Run")
        else:
            _play_hero("Idle")

        if not player.is_on_floor():
            player.velocity.y -= 20.0 * delta
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

func _make_button(parent: Control, caption: String, pos: Vector2, dims: Vector2) -> Button:
    var b := Button.new()
    b.text = caption
    b.position = pos
    b.size = dims
    b.focus_mode = Control.FOCUS_NONE
    b.add_theme_font_size_override("font_size", 20)
    parent.add_child(b)
    return b

func _interface() -> void:
    var layer := CanvasLayer.new()
    add_child(layer)
    var root := Control.new()
    root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    root.mouse_filter = Control.MOUSE_FILTER_IGNORE
    layer.add_child(root)
    var title := Label.new()
    title.text = "ORVETHRA  ·  Старый город"
    title.position = Vector2(15, 11)
    title.add_theme_color_override("font_color", Color("f6e5c1"))
    title.add_theme_font_size_override("font_size", 23)
    root.add_child(title)
    status = Label.new()
    status.position = Vector2(15, 48)
    status.add_theme_font_size_override("font_size", 15)
    status.add_theme_color_override("font_color", Color("f1e2c9"))
    status.text = "Город · Neon Alleycat · Idle / Run / Strafe"
    root.add_child(status)
    var pads := Control.new()
    pads.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
    pads.position = Vector2(18, -197)
    pads.size = Vector2(212, 180)
    pads.mouse_filter = Control.MOUSE_FILTER_IGNORE
    root.add_child(pads)
    var up := _make_button(pads, "▲", Vector2(72, 0), Vector2(65, 55))
    var down := _make_button(pads, "▼", Vector2(72, 58), Vector2(65, 55))
    var left := _make_button(pads, "◀", Vector2(0, 58), Vector2(65, 55))
    var right := _make_button(pads, "▶", Vector2(144, 58), Vector2(65, 55))
    up.button_down.connect(func() -> void: held_forward = true)
    up.button_up.connect(func() -> void: held_forward = false)
    down.button_down.connect(func() -> void: held_back = true)
    down.button_up.connect(func() -> void: held_back = false)
    left.button_down.connect(func() -> void: held_left = true)
    left.button_up.connect(func() -> void: held_left = false)
    right.button_down.connect(func() -> void: held_right = true)
    right.button_up.connect(func() -> void: held_right = false)
    var actions := Control.new()
    actions.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
    actions.position = Vector2(-325, -87)
    actions.size = Vector2(315, 77)
    actions.mouse_filter = Control.MOUSE_FILTER_IGNORE
    root.add_child(actions)
    overview_button = _make_button(actions, "Обзор сверху", Vector2(0, 0), Vector2(155, 63))
    overview_button.pressed.connect(_toggle_overview)
    var back := _make_button(actions, "Меню", Vector2(162, 0), Vector2(146, 63))
    back.pressed.connect(func() -> void: get_tree().change_scene_to_file("res://scenes/main_menu.tscn"))
    var zoom := _make_button(root, "−  /  +", Vector2(16, 93), Vector2(96, 43))
    zoom.pressed.connect(func() -> void: overview_height = 150.0 if overview_height > 160.0 else 235.0)

func _toggle_overview() -> void:
    overview = not overview
    if overview:
        overview_center = Vector2.ZERO
    overview_button.text = "Пешком" if overview else "Обзор сверху"

func _process(delta: float) -> void:
    frame_time += delta
    if frame_time > 0.8 and status != null:
        frame_time = 0.0
        if overview:
            status.text = "Обзор города · фонтан в центре · пока без домов"
        else:
            status.text = "Neon Alleycat · Idle / Run / StrafeRight · свайп справа — камера"

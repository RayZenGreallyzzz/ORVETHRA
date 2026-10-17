extends Node3D

# Mobile-friendly, genuinely interactive training clearing.
# One blended ground mesh, nine shared low-poly slime meshes, no rigid bodies
# per slime, no dynamic shadows. Moves only while near the player.
const CENTER := Vector3(99.0, 0.0, 70.0)
const ARENA_RADIUS := 12.0
const GROUND_TEXTURE := "res://assets/city/training_grass_earth_mobile.webp"
const WORN_TEXTURE := "res://assets/city/training_worn_gravel_mobile.webp"
const PLAYER_AGGRO := 5.6
const PLAYER_ATTACK_RANGE := 1.55
const LEASH_RADIUS := 9.8
const MAX_CHASERS := 3
const HOP_DURATION := 0.52
const TRAINING_SHADER := """
shader_type spatial;
render_mode cull_disabled;
uniform sampler2D grass_earth : source_color, repeat_enable, filter_linear_mipmap;
uniform sampler2D worn_gravel : source_color, repeat_enable, filter_linear_mipmap;
uniform vec2 clearing_center = vec2(99.0, 70.0);
varying vec2 world_xz;
void vertex() {
    world_xz = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xz;
}
void fragment() {
    vec3 grass = texture(grass_earth, world_xz * 0.34).rgb;
    vec3 gravel = texture(worn_gravel, world_xz * 0.41).rgb;
    float d = distance(world_xz, clearing_center);
    float variation = texture(grass_earth, world_xz * 0.071).r;
    float worn = 1.0 - smoothstep(4.3, 8.9, d + (variation - 0.5) * 1.35);
    ALBEDO = mix(grass, gravel, clamp(worn * 0.92, 0.0, 1.0));
    ROUGHNESS = 1.0;
}
"""

var game
var slimes: Array[Dictionary] = []
var selected := -1
var clock := 0.0
var marker: MeshInstance3D
var arena_floor: MeshInstance3D
var rng := RandomNumberGenerator.new()

func _material(hex: String) -> StandardMaterial3D:
    var mat := StandardMaterial3D.new()
    mat.albedo_color = Color(hex)
    mat.roughness = 0.77
    mat.cull_mode = BaseMaterial3D.CULL_DISABLED
    return mat

func _training_material() -> Material:
    var grass := load(GROUND_TEXTURE) as Texture2D if ResourceLoader.exists(GROUND_TEXTURE) else null
    var gravel := load(WORN_TEXTURE) as Texture2D if ResourceLoader.exists(WORN_TEXTURE) else null
    if grass == null or gravel == null:
        push_warning("ORVETHRA training tiles missing; use dirt material")
        return _material("85765c")
    var shader := Shader.new()
    shader.code = TRAINING_SHADER
    var mat := ShaderMaterial.new()
    mat.shader = shader
    mat.set_shader_parameter("grass_earth", grass)
    mat.set_shader_parameter("worn_gravel", gravel)
    mat.set_shader_parameter("clearing_center", Vector2(CENTER.x, CENTER.z))
    return mat

func _ready() -> void:
    name = "TrainingClearing"
    # Fixed world seed gives natural, consistent distribution between launches.
    rng.seed = 20261017
    _make_clearing()
    _make_slimes()
    set_process(true)

func _make_clearing() -> void:
    arena_floor = MeshInstance3D.new()
    arena_floor.name = "TrainingGroundGrassAndGravel"
    var earth := CylinderMesh.new()
    earth.top_radius = ARENA_RADIUS
    earth.bottom_radius = ARENA_RADIUS
    earth.height = 0.045
    earth.radial_segments = 40
    arena_floor.mesh = earth
    arena_floor.position = CENTER + Vector3(0.0, -0.014, 0.0)
    arena_floor.material_override = _training_material()
    arena_floor.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    add_child(arena_floor)

    var post_mat := _material("51402b")
    var shared_post := CylinderMesh.new()
    shared_post.top_radius = 0.12
    shared_post.bottom_radius = 0.16
    shared_post.height = 0.85
    shared_post.radial_segments = 7
    for i in range(14):
        if i >= 7 and i <= 9:
            continue # entrance is left open beside the lane
        var angle := TAU * float(i) / 14.0
        var post := MeshInstance3D.new()
        post.mesh = shared_post
        post.position = CENTER + Vector3(cos(angle) * 12.3, 0.45, sin(angle) * 12.3)
        post.material_override = post_mat
        post.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
        add_child(post)

    var signpost := MeshInstance3D.new()
    var pole := BoxMesh.new()
    pole.size = Vector3(0.28, 2.5, 0.28)
    signpost.mesh = pole
    signpost.material_override = post_mat
    signpost.position = CENTER + Vector3(-7.4, 1.23, -9.6)
    signpost.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    add_child(signpost)
    var sign := Label3D.new()
    sign.text = "ТРЕНИРОВОЧНАЯ ПОЛЯНА\nСЛИЗНИ  Lv.1 / Lv.5 / Lv.10"
    sign.font_size = 42
    sign.pixel_size = 0.008
    sign.outline_size = 8
    sign.modulate = Color("f0d6aa")
    sign.position = CENTER + Vector3(-7.4, 2.65, -9.6)
    sign.billboard = BaseMaterial3D.BILLBOARD_ENABLED
    add_child(sign)

    marker = MeshInstance3D.new()
    var marker_mesh := CylinderMesh.new()
    marker_mesh.top_radius = 0.63
    marker_mesh.bottom_radius = 0.63
    marker_mesh.height = 0.018
    marker_mesh.radial_segments = 18
    marker.mesh = marker_mesh
    var gold := _material("eec453")
    gold.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    marker.material_override = gold
    marker.visible = false
    marker.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    add_child(marker)

func _pick_spawn(existing: Array[Vector2]) -> Vector2:
    for attempt in range(90):
        var angle := rng.randf_range(0.0, TAU)
        var radius := sqrt(rng.randf()) * 8.6
        var p := Vector2(cos(angle), sin(angle)) * radius
        # Keep slimes on the playable part of the clearing by the city edge.
        if p.x > 6.5 or p.length() > LEASH_RADIUS:
            continue
        var clear := true
        for other in existing:
            if p.distance_squared_to(other) < 2.7 * 2.7:
                clear = false
                break
        if clear:
            return p
    return Vector2(-3.0 + float(existing.size() % 3) * 2.8,
        -4.0 + float(existing.size() / 3) * 2.8)

func _make_slimes() -> void:
    var colors := ["7cce67", "67bcbd", "9376c9"]
    var levels := [1, 5, 10]
    var used: Array[Vector2] = []
    var shared_blob := SphereMesh.new()
    shared_blob.radius = 1.0
    shared_blob.height = 2.0
    shared_blob.radial_segments = 12
    shared_blob.rings = 6
    var shared_eye := SphereMesh.new()
    shared_eye.radius = 0.11
    shared_eye.height = 0.22
    shared_eye.radial_segments = 7
    shared_eye.rings = 4
    var eye_material := _material("132a27")
    for group in range(3):
        var slime_mat := _material(colors[group])
        for member in range(3):
            var lv: int = levels[group]
            var place := _pick_spawn(used)
            used.append(place)
            var spot := CENTER + Vector3(place.x, 0.07, place.y)
            var size := rng.randf_range(0.45, 0.58)
            if lv == 10:
                size += 0.045
            var slime := Node3D.new()
            slime.name = "Slime_L" + str(lv) + "_" + str(member + 1)
            slime.position = spot
            add_child(slime)

            var body := MeshInstance3D.new()
            body.mesh = shared_blob
            body.scale = Vector3(size, size * 0.80, size)
            body.position.y = size * 0.80 + 0.04
            body.material_override = slime_mat
            body.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
            slime.add_child(body)
            for side in [-1.0, 1.0]:
                var eye := MeshInstance3D.new()
                eye.mesh = shared_eye
                eye.position = Vector3(side * size * 0.35, size * 0.98, -size * 0.78)
                eye.material_override = eye_material
                eye.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
                slime.add_child(eye)

            var info := Label3D.new()
            info.name = "NameAndHealth"
            info.position = Vector3(0, 1.31, 0)
            info.font_size = 36
            info.pixel_size = 0.0065
            info.outline_size = 6
            info.billboard = BaseMaterial3D.BILLBOARD_ENABLED
            slime.add_child(info)
            var max_hp := 3 if lv == 1 else (6 if lv == 5 else 10)
            slimes.append({
                "node": slime, "body": body, "label": info, "level": lv,
                "hp": max_hp, "max_hp": max_hp, "size": size,
                "spawn": Vector2(spot.x, spot.z),
                "base_y": spot.y, "respawn": -1.0,
                "hopping": false, "hop_t": 0.0,
                "hop_delay": rng.randf_range(0.15, 0.95),
                "attack_cd": rng.randf_range(0.4, 1.3),
                "wander_target": Vector2(spot.x, spot.z)
            })
            _update_label(slimes.size() - 1)

func _eligible_for_combat() -> bool:
    if game == null or game.player == null or game.overview:
        return false
    if game.city_hud == null or game.city_hud.is_popup_open():
        return false
    if game.city_hud.hero_hp <= 0:
        return false
    var player_pos := Vector2(game.player.global_position.x, game.player.global_position.z)
    return player_pos.distance_to(Vector2(CENTER.x, CENTER.z)) < ARENA_RADIUS + 0.6

func _process(delta: float) -> void:
    clock += delta
    var player_ok := _eligible_for_combat()
    var player_pos := Vector2.ZERO
    var chasers: Array[Dictionary] = []
    if player_ok:
        player_pos = Vector2(game.player.global_position.x, game.player.global_position.z)
        for i in range(slimes.size()):
            var s: Dictionary = slimes[i]
            if int(s["hp"]) <= 0:
                continue
            var node: Node3D = s["node"]
            var here := Vector2(node.position.x, node.position.z)
            var d := here.distance_to(player_pos)
            if d < PLAYER_AGGRO and player_pos.distance_to(s["spawn"]) < LEASH_RADIUS:
                chasers.append({"index": i, "distance": d})
        chasers.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
            return float(a["distance"]) < float(b["distance"]))
    var active: Dictionary = {}
    for i in range(mini(MAX_CHASERS, chasers.size())):
        active[int(chasers[i]["index"])] = true

    for i in range(slimes.size()):
        var s: Dictionary = slimes[i]
        var node: Node3D = s["node"]
        if int(s["hp"]) <= 0:
            if clock >= float(s["respawn"]):
                s["hp"] = s["max_hp"]
                s["respawn"] = -1.0
                s["hopping"] = false
                s["hop_delay"] = 0.6
                var home: Vector2 = s["spawn"]
                node.position = Vector3(home.x, float(s["base_y"]), home.y)
                node.visible = true
                _update_label(i)
            else:
                node.visible = false
            continue

        s["attack_cd"] = maxf(0.0, float(s["attack_cd"]) - delta)
        if not bool(s["hopping"]):
            s["hop_delay"] = float(s["hop_delay"]) - delta
            if float(s["hop_delay"]) <= 0.0:
                s["hopping"] = true
                s["hop_t"] = 0.0
                s["hop_delay"] = rng.randf_range(0.25, 0.75)
        if bool(s["hopping"]):
            s["hop_t"] = float(s["hop_t"]) + delta / HOP_DURATION
            var hop_t := minf(1.0, float(s["hop_t"]))
            var here := Vector2(node.position.x, node.position.z)
            var destination: Vector2 = s["spawn"]
            var chasing := active.has(i)
            if chasing:
                destination = player_pos
            else:
                if here.distance_to(s["spawn"]) < 2.3:
                    if here.distance_to(s["wander_target"]) < 0.45:
                        s["wander_target"] = s["spawn"] + Vector2(
                            rng.randf_range(-2.0, 2.0), rng.randf_range(-2.0, 2.0))
                    destination = s["wander_target"]
            var offset := destination - here
            if offset.length() > 0.28:
                var step := (2.65 if chasing else 0.95) * delta
                var new_point := here + offset.normalized() * minf(step, offset.length())
                if new_point.distance_to(Vector2(CENTER.x, CENTER.z)) <= LEASH_RADIUS and new_point.x <= CENTER.x + 7.0:
                    node.position.x = new_point.x
                    node.position.z = new_point.y
                    var angle := atan2(-offset.x, -offset.y)
                    node.rotation.y = lerp_angle(node.rotation.y, angle, minf(1.0, delta * 9.0))
            node.position.y = float(s["base_y"]) + sin(hop_t * PI) * 0.30
            var body: MeshInstance3D = s["body"]
            var sz := float(s["size"])
            body.scale.y = sz * 0.80 * (1.0 - 0.14 * sin(hop_t * TAU))
            if hop_t >= 1.0:
                s["hopping"] = false
                node.position.y = float(s["base_y"])
                body.scale.y = sz * 0.80
                # Damage only on landing and only while in actual attack range.
                if chasing and player_ok and float(s["attack_cd"]) <= 0.0:
                    var landed := Vector2(node.position.x, node.position.z)
                    if landed.distance_to(player_pos) <= PLAYER_ATTACK_RANGE:
                        s["attack_cd"] = 1.65 + rng.randf_range(0.0, 0.45)
                        if game.has_method("_on_training_slime_attack"):
                            game._on_training_slime_attack(1, int(s["level"]))
        else:
            node.position.y = float(s["base_y"])

    if selected >= 0 and selected < slimes.size() and int(slimes[selected]["hp"]) > 0:
        var target: Node3D = slimes[selected]["node"]
        marker.visible = true
        marker.position = Vector3(target.position.x, 0.065, target.position.z)
    else:
        marker.visible = false

func _update_label(index: int) -> void:
    var s: Dictionary = slimes[index]
    var info: Label3D = s["label"]
    info.text = "Лесной слизень Lv." + str(s["level"]) + "\nHP " + str(s["hp"]) + " / " + str(s["max_hp"])
    info.modulate = Color("f6d695") if selected == index else Color("faf2dd")

func select_nearest(from: Vector3) -> String:
    var nearest := 11.0
    var chosen := -1
    for i in range(slimes.size()):
        var s: Dictionary = slimes[i]
        if int(s["hp"]) <= 0:
            continue
        var node: Node3D = s["node"]
        var distance := Vector2(from.x - node.position.x, from.z - node.position.z).length()
        if distance < nearest:
            nearest = distance
            chosen = i
    selected = chosen
    for i in range(slimes.size()):
        _update_label(i)
    if selected == -1:
        return "Подойдите ближе к тренировочным слизням."
    return "Цель: лесной слизень Lv." + str(slimes[selected]["level"]) + " · " + str(snappedf(nearest, 0.1)) + " м"

func hit_target(from: Vector3) -> String:
    if selected < 0 or selected >= slimes.size() or int(slimes[selected]["hp"]) <= 0:
        var message := select_nearest(from)
        if selected < 0:
            return message
    var s: Dictionary = slimes[selected]
    var target: Node3D = s["node"]
    var distance := Vector2(from.x - target.position.x, from.z - target.position.z).length()
    if distance > 3.0:
        return "Подойдите к выбранному слизню ближе (до 3 м)."
    var damage := 2
    var remaining := maxi(0, int(s["hp"]) - damage)
    s["hp"] = remaining
    _update_label(selected)
    if remaining > 0:
        return "Удар: -" + str(damage) + " HP · Слизень Lv." + str(s["level"]) + " · " + str(remaining) + " HP"
    s["respawn"] = clock + 8.0
    var level: int = s["level"]
    target.visible = false
    selected = -1
    if game != null and game.has_method("_on_training_slime_defeated"):
        game._on_training_slime_defeated(level)
    return "Победа! Слизень Lv." + str(level) + " · появится через 8 секунд."

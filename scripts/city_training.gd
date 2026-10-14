extends Node3D

# Lightweight training clearing at the end of the north-eastern lane.
# Nine stylized 3D slimes: three each at levels 1, 5 and 10.
const CENTER := Vector3(91.0, 0.0, 70.0)
const ARENA_RADIUS := 12.0
var game
var slimes: Array[Dictionary] = []
var selected := -1
var clock := 0.0
var marker: MeshInstance3D
var arena_floor: MeshInstance3D

func _material(hex: String, transparent := false) -> StandardMaterial3D:
    var m := StandardMaterial3D.new()
    m.albedo_color = Color(hex)
    m.roughness = 0.66
    m.metallic = 0.02
    m.cull_mode = BaseMaterial3D.CULL_DISABLED
    if transparent:
        m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    return m

func _ready() -> void:
    name = "TrainingClearing"
    _make_clearing()
    _make_slimes()
    set_process(true)

func _make_clearing() -> void:
    arena_floor = MeshInstance3D.new()
    arena_floor.name = "TrainingEarth"
    var earth := CylinderMesh.new()
    earth.top_radius = ARENA_RADIUS
    earth.bottom_radius = ARENA_RADIUS
    earth.height = 0.06
    earth.radial_segments = 40
    arena_floor.mesh = earth
    arena_floor.position = CENTER + Vector3(0.0, -0.015, 0.0)
    arena_floor.material_override = _material("85765c")
    arena_floor.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    add_child(arena_floor)

    var post_mat := _material("51402b")
    # Sparse wooden posts (no houses and no closed fence blocking the road).
    for i in range(14):
        var angle := TAU * float(i) / 14.0
        if i >= 7 and i <= 9:
            continue # open entrance by the cobbled lane
        var p := CENTER + Vector3(cos(angle) * 12.3, 0.45, sin(angle) * 12.3)
        var post := MeshInstance3D.new()
        var stick := CylinderMesh.new()
        stick.top_radius = 0.12
        stick.bottom_radius = 0.16
        stick.height = 0.85
        post.mesh = stick
        post.position = p
        post.material_override = post_mat
        post.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
        add_child(post)

    var signpost := MeshInstance3D.new()
    var pole := BoxMesh.new()
    pole.size = Vector3(0.28, 2.5, 0.28)
    signpost.mesh = pole
    signpost.material_override = post_mat
    signpost.position = Vector3(83.6, 1.23, 60.4)
    add_child(signpost)
    var sign := Label3D.new()
    sign.text = "ТРЕНИРОВОЧНАЯ ПОЛЯНА\nСЛИЗНИ  Lv.1 / Lv.5 / Lv.10"
    sign.font_size = 42
    sign.pixel_size = 0.008
    sign.outline_size = 8
    sign.modulate = Color("f0d6aa")
    sign.position = Vector3(83.6, 2.65, 60.4)
    sign.billboard = BaseMaterial3D.BILLBOARD_ENABLED
    add_child(sign)

    marker = MeshInstance3D.new()
    var marker_mesh := CylinderMesh.new()
    marker_mesh.top_radius = 0.94
    marker_mesh.bottom_radius = 0.94
    marker_mesh.height = 0.025
    marker_mesh.radial_segments = 24
    marker.mesh = marker_mesh
    var gold := _material("eec453")
    gold.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    marker.material_override = gold
    marker.visible = false
    add_child(marker)

func _make_slimes() -> void:
    var colors := ["7cce67", "67bcbd", "9376c9"]
    var levels := [1, 5, 10]
    for group in range(3):
        for member in range(3):
            var lv: int = levels[group]
            var spot := CENTER + Vector3(float(member - 1) * 6.1, 0.13, float(group - 1) * 6.0)
            var slime := Node3D.new()
            slime.name = "Slime_L" + str(lv) + "_" + str(member + 1)
            slime.position = spot
            add_child(slime)

            var body := MeshInstance3D.new()
            var blob := SphereMesh.new()
            blob.radius = 1.0
            blob.height = 2.0
            blob.radial_segments = 14
            blob.rings = 8
            body.mesh = blob
            body.scale = Vector3(0.80, 0.55, 0.80)
            body.position.y = 0.46
            body.material_override = _material(colors[group])
            body.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
            slime.add_child(body)

            var eye_material := _material("132a27")
            for side in [-1.0, 1.0]:
                var eye := MeshInstance3D.new()
                var ball := SphereMesh.new()
                ball.radius = 0.12
                ball.height = 0.24
                ball.radial_segments = 8
                ball.rings = 4
                eye.mesh = ball
                eye.position = Vector3(side * 0.25, 0.67, -0.62)
                eye.material_override = eye_material
                eye.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
                slime.add_child(eye)

            var info := Label3D.new()
            info.name = "NameAndHealth"
            info.text = "Лесной слизень Lv." + str(lv)
            info.position = Vector3(0, 1.85, 0)
            info.font_size = 42
            info.pixel_size = 0.007
            info.outline_size = 7
            info.billboard = BaseMaterial3D.BILLBOARD_ENABLED
            slime.add_child(info)

            var max_hp: int = 3 if lv == 1 else (6 if lv == 5 else 10)
            slimes.append({"node": slime, "label": info, "level": lv, "hp": max_hp, "max_hp": max_hp, "base_y": spot.y, "respawn": -1.0})

func _process(delta: float) -> void:
    clock += delta
    for i in range(slimes.size()):
        var s: Dictionary = slimes[i]
        var node: Node3D = s["node"]
        if int(s["hp"]) <= 0:
            if clock >= float(s["respawn"]):
                s["hp"] = s["max_hp"]
                s["respawn"] = -1.0
                node.visible = true
                _update_label(i)
            else:
                node.visible = false
            continue
        node.position.y = float(s["base_y"]) + sin(clock * 2.2 + float(i)) * 0.085
        var mesh: Node3D = node.get_child(0) as Node3D
        mesh.scale.y = 0.55 + sin(clock * 2.2 + float(i)) * 0.028
    if selected >= 0 and selected < slimes.size() and int(slimes[selected]["hp"]) > 0:
        var target_node: Node3D = slimes[selected]["node"]
        marker.visible = true
        marker.position = Vector3(target_node.position.x, 0.075, target_node.position.z)
    else:
        marker.visible = false

func _update_label(index: int) -> void:
    var s: Dictionary = slimes[index]
    var label: Label3D = s["label"]
    label.text = "Лесной слизень Lv." + str(s["level"]) + "\nHP " + str(s["hp"]) + " / " + str(s["max_hp"])
    label.modulate = Color("f6d695") if selected == index else Color("faf2dd")

func select_nearest(from: Vector3) -> String:
    var best := 14.0
    var chosen := -1
    for i in range(slimes.size()):
        var s: Dictionary = slimes[i]
        if int(s["hp"]) <= 0:
            continue
        var node: Node3D = s["node"]
        var distance := Vector2(from.x - node.position.x, from.z - node.position.z).length()
        if distance < best:
            best = distance
            chosen = i
    selected = chosen
    for i in range(slimes.size()):
        _update_label(i)
    if selected == -1:
        return "Подойдите ближе к тренировочным слизням."
    return "Цель: лесной слизень Lv." + str(slimes[selected]["level"]) + " · " + str(snappedf(best, 0.1)) + " м"

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
    var new_hp: int = maxi(0, int(s["hp"]) - damage)
    s["hp"] = new_hp
    _update_label(selected)
    if new_hp > 0:
        return "Удар: -" + str(damage) + " HP · Слизень Lv." + str(s["level"]) + " · " + str(new_hp) + " HP"
    s["respawn"] = clock + 7.0
    var level: int = s["level"]
    target.visible = false
    selected = -1
    if game != null and game.has_method("_on_training_slime_defeated"):
        game._on_training_slime_defeated(level)
    return "Победа! Слизень Lv." + str(level) + " · появится через 7 секунд."

extends Node3D

# Asura Baby: a room-bound dungeon boss with patrol, pauses, aggro, melee hits
# and a leash. No navigation mesh or extra collision bodies on Android.
const MODEL_PATH := "res://assets/catacombs/boss/asura_baby_mobile.glb"
const HOME := Vector3(-17.0, 0.03, -47.5)
const MAX_HP := 120
const DETECT_RADIUS := 7.4
const ATTACK_RANGE := 2.6
const RETREAT_RADIUS := 11.0
const ROAM_SPEED := 1.2
const CHASE_SPEED := 2.4
const ATTACK_DAMAGE := 6
const DAMAGE_COOLDOWN := 2.4
const PATROL_POINTS := [
    Vector2(-17.0, -47.5),
    Vector2(-21.5, -50.2),
    Vector2(-22.0, -44.5),
    Vector2(-17.3, -42.7),
    Vector2(-12.8, -48.5),
    Vector2(-15.5, -53.0)
]
var game
var hp := MAX_HP
var aggro := false
var dead := false
var visual: Node3D
var animator: AnimationPlayer
var animation_state := ""
var model_installed := false
var roam_index := 0
var pause_time := 2.0
var attack_cd := 0.0
var attack_time := 0.0
var damage_pending := false
var death_time := 0.0
var rng := RandomNumberGenerator.new()
var name_label: Label3D

func _ready() -> void:
    name = "AsuraBoss"
    position = HOME
    rng.seed = 20261017
    _create_visual()
    set_process(true)

func _material(hex: String) -> StandardMaterial3D:
    var mat := StandardMaterial3D.new()
    mat.albedo_color = Color(hex)
    mat.roughness = 0.85
    return mat

func _create_visual() -> void:
    if ResourceLoader.exists(MODEL_PATH):
        var scene = load(MODEL_PATH)
        if scene is PackedScene:
            visual = scene.instantiate()
            visual.name = "AsuraBabyRig"
            visual.scale = Vector3.ONE * 1.65
            visual.rotation.y = PI
            add_child(visual)
            model_installed = true
            animator = _find_animator(visual)
            _configure_animations()
    if visual == null:
        # Explicit fallback: working gameplay even before the user uploads
        # ORVETHRA_Asura_Boss_Android.zip into the GitHub repository root.
        visual = Node3D.new()
        visual.name = "TemporaryAsuraVisual"
        add_child(visual)
        var body := MeshInstance3D.new()
        var armor := CapsuleMesh.new()
        armor.radius = 0.84
        armor.height = 2.6
        body.mesh = armor
        body.material_override = _material("602c36")
        body.position.y = 1.34
        body.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
        visual.add_child(body)
        for side in [-1.0, 1.0]:
            var horn := MeshInstance3D.new()
            var cone := CylinderMesh.new()
            cone.top_radius = 0.03
            cone.bottom_radius = 0.16
            cone.height = 0.66
            horn.mesh = cone
            horn.position = Vector3(side * 0.42, 2.83, 0.0)
            horn.material_override = _material("c5ab8b")
            horn.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
            visual.add_child(horn)
    name_label = Label3D.new()
    name_label.name = "AsuraBossNameHP"
    name_label.text = "АСУРА · БОСС\nHP " + str(hp) + " / " + str(MAX_HP)
    name_label.font_size = 44
    name_label.pixel_size = 0.009
    name_label.position = Vector3(0.0, 3.5, 0.0)
    name_label.outline_size = 9
    name_label.modulate = Color("f3b9a6")
    name_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
    add_child(name_label)
    _play_motion("Idle")

func _find_animator(node: Node) -> AnimationPlayer:
    if node is AnimationPlayer:
        return node as AnimationPlayer
    for child in node.get_children():
        var found = _find_animator(child)
        if found != null:
            return found
    return null

func _resolve_motion(key: String) -> StringName:
    if animator == null:
        return &""
    var lookup := key.to_lower()
    for anim in animator.get_animation_list():
        var normalized := String(anim).to_lower()
        if normalized == lookup or normalized.ends_with("/" + lookup) or normalized.begins_with(lookup):
            return anim
    if lookup == "run":
        return _resolve_motion("Walk")
    return &""

func _configure_animations() -> void:
    if animator == null:
        return
    for key in animator.get_animation_list():
        var track_anim := animator.get_animation(key)
        if track_anim == null:
            continue
        var lower := String(key).to_lower()
        track_anim.loop_mode = Animation.LOOP_LINEAR if (lower.ends_with("idle") or lower.ends_with("walk") or lower.begins_with("138_")) else Animation.LOOP_NONE
        # Movement comes from Node3D navigation. Never let a baked Mixamo
        # root-translation track carry the boss through a dungeon wall.
        for track in range(track_anim.get_track_count()):
            if track_anim.track_get_type(track) != Animation.TYPE_POSITION_3D:
                continue
            var track_path := str(track_anim.track_get_path(track)).to_lower()
            if not track_path.contains("hips") and not track_path.contains("root"):
                continue
            if track_anim.track_get_key_count(track) < 2:
                continue
            var original = track_anim.track_get_key_value(track, 0)
            if not original is Vector3:
                continue
            for k in range(track_anim.track_get_key_count(track)):
                var current = track_anim.track_get_key_value(track, k)
                if current is Vector3:
                    current.x = original.x
                    current.z = original.z
                    track_anim.track_set_key_value(track, k, current)

func _play_motion(key: String) -> void:
    if animation_state == key:
        return
    animation_state = key
    var clip := _resolve_motion(key)
    if animator != null and clip != &"":
        animator.play(clip, 0.16)

func _player_point() -> Vector2:
    if game == null or game.player == null:
        return Vector2(99999.0, 99999.0)
    return Vector2(game.player.position.x, game.player.position.z)

func _inside_boss_room(p: Vector2) -> bool:
    # 25x25 hall; do not chase down the corridor on its eastern side.
    return p.x > -28.5 and p.x < -6.3 and p.y > -58.5 and p.y < -36.5

func _move_towards(p: Vector2, speed: float, delta: float) -> void:
    var here := Vector2(position.x, position.z)
    var displacement := p - here
    if displacement.length() < 0.08:
        return
    var length := minf(speed * delta, displacement.length())
    var next := here + displacement.normalized() * length
    if next.distance_to(Vector2(HOME.x, HOME.z)) > RETREAT_RADIUS or not _inside_boss_room(next):
        return
    position.x = next.x
    position.z = next.y
    # Imported model visually faces -Z at character root.
    rotation.y = lerp_angle(rotation.y, atan2(-displacement.x, -displacement.y), minf(1.0, delta * 6.0))

func _process(delta: float) -> void:
    if dead:
        death_time += delta
        if visual != null:
            visual.rotation.z = lerpf(visual.rotation.z, -1.3, minf(1.0, delta * 2.2))
        if death_time > 2.0 and visual != null:
            visual.visible = false
        return
    attack_cd = maxf(0.0, attack_cd - delta)
    var player_position := _player_point()
    var here := Vector2(position.x, position.z)
    var distance := here.distance_to(player_position)
    var player_near := _inside_boss_room(player_position)
    if game != null and game.city_hud != null and game.city_hud.has_method("can_be_attacked"):
        player_near = player_near and game.city_hud.can_be_attacked()
    if not player_near or player_position.distance_to(Vector2(HOME.x, HOME.z)) > RETREAT_RADIUS:
        aggro = false
    elif distance <= DETECT_RADIUS:
        aggro = true
    if attack_time > 0.0:
        attack_time -= delta
        if damage_pending and attack_time <= 0.60:
            damage_pending = false
            if aggro and distance < ATTACK_RANGE + 0.25 and game != null:
                game._on_asura_attack(ATTACK_DAMAGE)
        if attack_time <= 0.0:
            _play_motion("Idle")
        return
    if aggro:
        pause_time = 0.0
        if distance < ATTACK_RANGE and attack_cd <= 0.0:
            _begin_attack()
            return
        if distance > ATTACK_RANGE * 0.76:
            _move_towards(player_position, CHASE_SPEED, delta)
            _play_motion("Run")
        else:
            _play_motion("Idle")
        return
    # The boss walks the chamber, pauses to watch the room, then resumes.
    var home := Vector2(HOME.x, HOME.z)
    if here.distance_to(home) > 7.5:
        _move_towards(home, ROAM_SPEED, delta)
        _play_motion("Walk")
        return
    if pause_time > 0.0:
        pause_time -= delta
        _play_motion("Idle")
        return
    var waypoint: Vector2 = PATROL_POINTS[roam_index]
    if here.distance_to(waypoint) < 0.48:
        roam_index = (roam_index + 1) % PATROL_POINTS.size()
        pause_time = rng.randf_range(1.2, 3.1)
        _play_motion("Idle")
    else:
        _move_towards(waypoint, ROAM_SPEED, delta)
        _play_motion("Walk")

func _begin_attack() -> void:
    attack_cd = DAMAGE_COOLDOWN
    attack_time = 1.35
    damage_pending = true
    var strike := "Attack"
    if model_installed and rng.randf() < 0.35:
        strike = "043_" if rng.randf() < 0.5 else "050_"
    _play_motion(strike)
    if game != null and game.city_hud != null:
        game.city_hud.show_combat_message("Асура замахивается оружием!")

func receive_damage(amount: int) -> String:
    if dead:
        return "Босс уже побеждён."
    if not _inside_boss_room(_player_point()):
        return "Войдите в зал босса."
    if _player_point().distance_to(Vector2(position.x, position.z)) > 3.5:
        return "Подойдите к Асуре ближе (до 3,5 м)."
    hp = maxi(0, hp - amount)
    if name_label != null:
        name_label.text = "АСУРА · БОСС\nHP " + str(hp) + " / " + str(MAX_HP)
    aggro = true
    if hp == 0:
        dead = true
        attack_time = 0.0
        damage_pending = false
        _play_motion("Idle") # No death clip in the supplied 6-clip GLB.
        return "Асура повержен! Зал босса очищен."
    return "Удар по Асуре: -" + str(amount) + " HP (" + str(hp) + "/" + str(MAX_HP) + ")."

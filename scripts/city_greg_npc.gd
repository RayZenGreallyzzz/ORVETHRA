extends CharacterBody3D

# Greg is the BadBoy NPC, never a playable hero. Unlike a static shopkeeper
# he walks the city's road network, pauses, and visits the plaza intermittently.
# Escort quest uses a REAL 3-hour local-clock cooldown saved across restarts.
const CharacterRoster = preload("res://scripts/character_roster.gd")
const BADBOY_MODEL := "res://assets/characters/roster/badboy_mobile.glb"
const SAVE_PATH := "user://orvethra_greg_quest.json"
const FOUNTAIN_STOP := Vector2(7.5, 1.3)
const ESCORT_DESTINATION := Vector2(78.0, 78.0)
const QUEST_INTERVAL_SECONDS := 10800.0
const WALK_SPEED := 2.35
const ESCORT_SPEED := 3.75
# Fountain collider radius is 3.65m. Leave extra clearance for Greg's capsule.
const FOUNTAIN_KEEP_OUT := 5.15
const FOUNTAIN_RING_RADIUS := 6.50
const FOUNTAIN_RING_STEPS := 24

var game
var rng := RandomNumberGenerator.new()
var road_nodes: Array[Vector2] = []
var connections: Dictionary = {}
var travel_path: Array[Vector2] = []
var travel_index := 0
var waypoint_goal := Vector2.ZERO
var rest_time := 0.0
var fountain_due := 0.0
var going_to_fountain := false
var escort_active := false
var next_quest_time := 0.0
var completed_escorts := 0
var anim_player: AnimationPlayer
var active_clip := ""
var quest_mark: Label3D
var model: Node3D
var follow_repath := 0.0
var follow_last_target := Vector2.ZERO

func _ready() -> void:
    name = "GregWanderingQuestNPC"
    position = Vector3(FOUNTAIN_STOP.x, 0.09, FOUNTAIN_STOP.y)
    floor_snap_length = 0.4
    rng.randomize()
    var collider := CollisionShape3D.new()
    var capsule := CapsuleShape3D.new()
    capsule.height = CharacterRoster.target_height_metres()
    capsule.radius = 0.32
    collider.shape = capsule
    collider.position.y = capsule.height * 0.5
    add_child(collider)
    if ResourceLoader.exists(BADBOY_MODEL):
        var packed := load(BADBOY_MODEL) as PackedScene
        if packed != null:
            model = packed.instantiate() as Node3D
            model.name = "GregBadBoyRig"
            model.rotation.y = PI
            model.scale = Vector3.ONE * CharacterRoster.world_scale("badboy")
            model.position.y = 0.08
            add_child(model)
            anim_player = _find_animation_player(model)
            if anim_player != null:
                for clip in anim_player.get_animation_list():
                    var anim := anim_player.get_animation(clip)
                    if anim != null:
                        anim.loop_mode = Animation.LOOP_LINEAR
            _play_animation("Idle")
    else:
        push_warning("Greg model missing: " + BADBOY_MODEL)

    var label := Label3D.new()
    label.text = "Грег"
    label.font_size = 40
    label.pixel_size = 0.0065
    label.modulate = Color("ffe2a9")
    label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
    label.no_depth_test = true
    label.position.y = 2.10
    add_child(label)

    quest_mark = Label3D.new()
    quest_mark.text = "!"
    quest_mark.font_size = 76
    quest_mark.pixel_size = 0.007
    quest_mark.modulate = Color("ffd059")
    quest_mark.billboard = BaseMaterial3D.BILLBOARD_ENABLED
    quest_mark.position.y = 2.48
    add_child(quest_mark)

    _load_quest_state()
    _create_road_graph()
    fountain_due = rng.randf_range(160.0, 290.0)
    rest_time = rng.randf_range(3.0, 9.0)
    _update_quest_mark()

func _find_animation_player(node: Node) -> AnimationPlayer:
    if node is AnimationPlayer:
        return node as AnimationPlayer
    for child in node.get_children():
        var found := _find_animation_player(child)
        if found != null:
            return found
    return null

func _play_animation(kind: String) -> void:
    if anim_player == null or active_clip == kind:
        return
    for clip in anim_player.get_animation_list():
        if String(clip).to_lower().ends_with(kind.to_lower()):
            anim_player.play(clip, 0.18)
            active_clip = kind
            return
    if kind == "Walk":
        for clip in anim_player.get_animation_list():
            if String(clip).to_lower().ends_with("run"):
                anim_player.play(clip, 0.18)
                active_clip = kind
                return

func _load_quest_state() -> void:
    if not FileAccess.file_exists(SAVE_PATH):
        return
    var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(SAVE_PATH))
    if data is Dictionary:
        next_quest_time = float(data.get("next_offer", 0.0))
        escort_active = bool(data.get("escort_active", false))
        completed_escorts = int(data.get("completed_escorts", 0))

func _save_quest_state() -> void:
    var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
    if file != null:
        file.store_string(JSON.stringify({
            "next_offer": next_quest_time,
            "escort_active": escort_active,
            "completed_escorts": completed_escorts
        }))
        file.close()

func _update_quest_mark() -> void:
    if quest_mark != null:
        quest_mark.visible = can_offer_quest()

func can_offer_quest() -> bool:
    return not escort_active and Time.get_unix_time_from_system() >= next_quest_time

func can_interact(player_at: Vector3) -> bool:
    return Vector2(player_at.x - global_position.x, player_at.z - global_position.z).length() < 3.4

func can_give_quest(player_at: Vector3) -> bool:
    return can_interact(player_at) and can_offer_quest()

func cooldown_text() -> String:
    var seconds := maxi(0, ceili(next_quest_time - Time.get_unix_time_from_system()))
    if seconds <= 0:
        return "У меня снова есть поручение."
    var hours := seconds / 3600
    var minutes := (seconds % 3600 + 59) / 60
    return "Новое поручение через %d ч %d мин." % [hours, minutes]

func accept_quest(player_at: Vector3) -> bool:
    if not can_give_quest(player_at):
        return false
    escort_active = true
    next_quest_time = Time.get_unix_time_from_system() + QUEST_INTERVAL_SECONDS
    travel_path.clear()
    travel_index = 0
    going_to_fountain = false
    follow_repath = 0.0
    _save_quest_state()
    _update_quest_mark()
    return true

func _finish_escort() -> void:
    escort_active = false
    completed_escorts += 1
    rest_time = rng.randf_range(2.0, 6.0)
    fountain_due = rng.randf_range(180.0, 320.0)
    travel_path.clear()
    travel_index = 0
    _save_quest_state()
    _update_quest_mark()
    if game != null and game.has_method("_on_greg_escort_complete"):
        game._on_greg_escort_complete()

func _node_id(point: Vector2) -> int:
    for idx in range(road_nodes.size()):
        if road_nodes[idx].distance_to(point) < 0.65:
            return idx
    var id := road_nodes.size()
    road_nodes.append(point)
    connections[id] = []
    return id

func _link_points(a: int, b: int) -> void:
    if a == b:
        return
    var av: Array = connections[a]
    var bv: Array = connections[b]
    if not av.has(b):
        av.append(b)
    if not bv.has(a):
        bv.append(a)
    connections[a] = av
    connections[b] = bv

func _create_road_graph() -> void:
    if game == null:
        return
    road_nodes.clear()
    connections.clear()
    # City road spokes used to meet INSIDE the fountain collision at (0, 0).
    # Replace those straight shortcuts with a walkable loop around the basin.
    var ring_ids: Array[int] = []
    for i in range(FOUNTAIN_RING_STEPS):
        var angle := TAU * float(i) / float(FOUNTAIN_RING_STEPS)
        ring_ids.append(_node_id(Vector2(cos(angle), sin(angle)) * FOUNTAIN_RING_RADIUS))
    for i in range(ring_ids.size()):
        _link_points(ring_ids[i], ring_ids[(i + 1) % ring_ids.size()])
    for road in game.roads:
        var previous := -1
        for point in road:
            if point.length() < FOUNTAIN_KEEP_OUT:
                if previous >= 0:
                    _link_points(previous, _nearest_ring_node(road_nodes[previous], ring_ids))
                previous = -1
                continue
            var current := _node_id(point)
            if previous >= 0:
                _link_points(previous, current)
            previous = current

func _nearest_ring_node(point: Vector2, ring_ids: Array[int]) -> int:
    var best_id := ring_ids[0]
    var best_distance := INF
    for id in ring_ids:
        var distance := point.distance_squared_to(road_nodes[id])
        if distance < best_distance:
            best_distance = distance
            best_id = id
    return best_id

func _direct_path_clear(target: Vector2) -> bool:
    # Respect real StaticBody3D obstacles before running straight at the player.
    var start := global_position + Vector3.UP * 0.75
    var end := Vector3(target.x, global_position.y + 0.75, target.y)
    var query := PhysicsRayQueryParameters3D.create(start, end)
    var excluded: Array[RID] = [get_rid()]
    if game != null and game.player != null:
        excluded.append(game.player.get_rid())
    query.exclude = excluded
    return get_world_3d().direct_space_state.intersect_ray(query).is_empty()

func _nearest_node(p: Vector2) -> int:
    var nearest := -1
    var distance := INF
    for idx in range(road_nodes.size()):
        var d := road_nodes[idx].distance_squared_to(p)
        if d < distance:
            distance = d
            nearest = idx
    return nearest

func _plan_road_path(destination: Vector2) -> bool:
    if road_nodes.is_empty():
        return false
    var current := Vector2(position.x, position.z)
    var begin := _nearest_node(current)
    var end := _nearest_node(destination)
    if begin < 0 or end < 0:
        return false
    var dist: Dictionary = {begin: 0.0}
    var parent: Dictionary = {}
    var seen: Dictionary = {}
    while true:
        var u := -1
        var best := INF
        for node_id in dist:
            if not seen.has(node_id) and float(dist[node_id]) < best:
                best = float(dist[node_id])
                u = int(node_id)
        if u < 0 or u == end:
            break
        seen[u] = true
        for v in connections.get(u, []):
            var alt := best + road_nodes[u].distance_to(road_nodes[int(v)])
            if alt < float(dist.get(v, INF)):
                dist[v] = alt
                parent[v] = u
    if not dist.has(end):
        return false
    var reverse_path: Array[int] = [end]
    var node := end
    while node != begin:
        if not parent.has(node):
            return false
        node = int(parent[node])
        reverse_path.append(node)
    reverse_path.reverse()
    travel_path.clear()
    travel_index = 0
    for v in reverse_path:
        var point := road_nodes[v]
        if current.distance_to(point) > 1.0 or not travel_path.is_empty():
            travel_path.append(point)
    if destination.distance_to(road_nodes[end]) > 0.5:
        travel_path.append(destination)
    return true

func _choose_next_roam() -> void:
    if road_nodes.is_empty():
        rest_time = 4.0
        return
    if fountain_due <= 0.0:
        going_to_fountain = _plan_road_path(FOUNTAIN_STOP)
        if going_to_fountain:
            return
    going_to_fountain = false
    for attempt in range(16):
        # Long-range destinations encourage city-wide walks, not a tiny loop.
        var choice := road_nodes[rng.randi_range(0, road_nodes.size() - 1)]
        if choice.distance_to(Vector2(position.x, position.z)) < 18.0:
            continue
        if _plan_road_path(choice):
            return
    rest_time = rng.randf_range(3.0, 8.0)

func _move_towards(target: Vector2, speed: float, delta: float) -> void:
    var offset := target - Vector2(position.x, position.z)
    if offset.length() <= 0.55:
        velocity.x = move_toward(velocity.x, 0.0, 14.0 * delta)
        velocity.z = move_toward(velocity.z, 0.0, 14.0 * delta)
        _play_animation("Idle")
        return
    var dir := offset.normalized()
    velocity.x = move_toward(velocity.x, dir.x * speed, 8.0 * delta)
    velocity.z = move_toward(velocity.z, dir.y * speed, 8.0 * delta)
    rotation.y = lerp_angle(rotation.y, atan2(-dir.x, -dir.y), minf(1.0, delta * 7.0))
    _play_animation("Walk")

func _wander(delta: float) -> void:
    fountain_due -= delta
    if rest_time > 0.0:
        rest_time -= delta
        velocity.x = move_toward(velocity.x, 0.0, 12.0 * delta)
        velocity.z = move_toward(velocity.z, 0.0, 12.0 * delta)
        _play_animation("Idle")
        return
    if travel_index >= travel_path.size():
        if going_to_fountain:
            going_to_fountain = false
            fountain_due = rng.randf_range(170.0, 360.0)
            rest_time = rng.randf_range(7.0, 16.0)
        else:
            rest_time = rng.randf_range(2.0, 11.0)
        travel_path.clear()
        travel_index = 0
        _choose_next_roam()
        return
    var destination := travel_path[travel_index]
    if Vector2(position.x, position.z).distance_to(destination) < 0.9:
        travel_index += 1
        if travel_index >= travel_path.size():
            return
        destination = travel_path[travel_index]
    _move_towards(destination, WALK_SPEED, delta)

func _follow_escort(delta: float) -> void:
    if game == null or game.player == null:
        _play_animation("Idle")
        velocity.x = 0.0
        velocity.z = 0.0
        return
    var player_pos := Vector2(game.player.global_position.x, game.player.global_position.z)
    var here := Vector2(position.x, position.z)
    if player_pos.distance_to(ESCORT_DESTINATION) < 5.0 and here.distance_to(ESCORT_DESTINATION) < 5.5:
        _finish_escort()
        return
    var separation := here.distance_to(player_pos)
    if separation < 2.1 or separation > 28.0:
        velocity.x = move_toward(velocity.x, 0.0, 12.0 * delta)
        velocity.z = move_toward(velocity.z, 0.0, 12.0 * delta)
        _play_animation("Idle")
        return
    # Follow the real road graph when distant. Near the player, approach
    # directly for a natural companion position instead of cutting corners.
    if separation < 8.0 and _direct_path_clear(player_pos):
        follow_repath = 0.0
        _move_towards(player_pos, ESCORT_SPEED, delta)
        return
    follow_repath -= delta
    if follow_repath <= 0.0 or follow_last_target.distance_to(player_pos) > 3.0:
        follow_repath = 1.0
        follow_last_target = player_pos
        if not _plan_road_path(player_pos):
            velocity.x = 0.0
            velocity.z = 0.0
            _play_animation("Idle")
            return
    if travel_index < travel_path.size():
        var next := travel_path[travel_index]
        if here.distance_to(next) < 1.05:
            travel_index += 1
        if travel_index < travel_path.size():
            _move_towards(travel_path[travel_index], ESCORT_SPEED, delta)
            return
    # Do not cut through solid geometry after the last road waypoint.
    if _direct_path_clear(player_pos):
        _move_towards(player_pos, ESCORT_SPEED, delta)
    else:
        follow_repath = 0.0
        velocity.x = 0.0
        velocity.z = 0.0
        _play_animation("Idle")

func _physics_process(delta: float) -> void:
    if escort_active:
        _follow_escort(delta)
    else:
        _wander(delta)
    if not is_on_floor():
        velocity.y -= 20.0 * delta
    else:
        velocity.y = -0.2
    move_and_slide()
    _update_quest_mark()

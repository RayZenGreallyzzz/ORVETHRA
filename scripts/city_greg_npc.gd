extends CharacterBody3D

# Greg is the former playable BadBoy model. A stationary idle quest NPC
# beside the fountain. The user requested he never leave this spot.
const CharacterRoster = preload("res://scripts/character_roster.gd")
const BADBOY_MODEL := "res://assets/characters/roster/badboy_mobile.glb"
const FOUNTAIN_STOP := Vector2(7.5, 1.3)
const WALK_SPEED := 2.1
const ROUTE := [
    Vector2(7.5, 1.3),
    Vector2(14.0, 8.7),
    Vector2(21.0, 14.0),
    Vector2(30.0, 23.0),
    Vector2(21.0, 14.0),
    Vector2(13.0, 8.0),
    Vector2(7.5, 1.3),
    Vector2(13.0, -6.0),
    Vector2(21.0, -13.0),
    Vector2(31.0, -21.0),
    Vector2(21.0, -13.0),
    Vector2(12.5, -5.8)
]

var route_index := 1
var rest_seconds := 16.0
var resting_at_fountain := true
var quest_taken := false
var anim_player: AnimationPlayer
var active_clip := ""
var quest_mark: Label3D
var model: Node3D

func _ready() -> void:
    name = "GregFountainQuestNPC"
    position = Vector3(FOUNTAIN_STOP.x, 0.09, FOUNTAIN_STOP.y)
    floor_snap_length = 0.4
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
            model.name = "BadBoyRig"
            model.rotation.y = PI
            # Rigged mesh is already measured in world metres. Never use
            # imported 0.019m AABBs or magnify it 100x.
            model.scale = Vector3.ONE * CharacterRoster.world_scale("badboy")
            # Measured animated toe bones are already at local Y=0.
            # City road artwork is ~0.08m higher than the physics ground.
            # Do not add half the NPC's body height (caused the floating Greg).
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
        push_warning("Greg/BadBoy model missing: " + BADBOY_MODEL)

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


func _find_animation_player(node: Node) -> AnimationPlayer:
    if node is AnimationPlayer:
        return node as AnimationPlayer
    for child in node.get_children():
        var result := _find_animation_player(child)
        if result != null:
            return result
    return null


func _play_animation(kind: String) -> void:
    if anim_player == null or active_clip == kind:
        return
    var desired := kind.to_lower()
    for clip in anim_player.get_animation_list():
        if String(clip).to_lower().ends_with(desired):
            anim_player.play(clip, 0.18)
            active_clip = kind
            return
    # Some animal/anthro rigs have a Run clip instead of Walk.
    if kind == "Walk":
        for clip in anim_player.get_animation_list():
            if String(clip).to_lower().ends_with("run"):
                anim_player.play(clip, 0.18)
                active_clip = kind
                return


func _physics_process(delta: float) -> void:
    # Greg stays beside the fountain. No random patrol or drifting away.
    resting_at_fountain = true
    velocity.x = 0.0
    velocity.z = 0.0
    if not is_on_floor():
        velocity.y -= 20.0 * delta
    else:
        velocity.y = -0.2
    move_and_slide()
    _play_animation("Idle")
    if quest_mark != null:
        quest_mark.visible = not quest_taken


func can_give_quest(player_at: Vector3) -> bool:
    return (not quest_taken
        and Vector2(position.x, position.z).distance_to(FOUNTAIN_STOP) < 1.1
        and Vector2(player_at.x, player_at.z).distance_to(Vector2(position.x, position.z)) < 3.3)


func accept_quest(player_at: Vector3) -> bool:
    if not can_give_quest(player_at):
        return false
    quest_taken = true
    quest_mark.visible = false
    return true

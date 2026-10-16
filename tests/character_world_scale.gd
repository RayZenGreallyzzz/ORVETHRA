extends SceneTree

# CI smoke test: every imported playable rig must exist, expose Idle +
# Walk/Run and retain its declared 1.9 metre source-scale contract.
const CharacterRoster = preload("res://scripts/character_roster.gd")

func _initialize() -> void:
    call_deferred("_validate_roster")

func _find_anim(node: Node) -> AnimationPlayer:
    if node is AnimationPlayer:
        return node as AnimationPlayer
    for child in node.get_children():
        var found := _find_anim(child)
        if found != null:
            return found
    return null

func _validate_roster() -> void:
    var failures := 0
    var checked := 0
    for entry in CharacterRoster.ENTRIES:
        var id := str(entry["id"])
        var path := CharacterRoster.model_path(id)
        var nominal := float(CharacterRoster.SOURCE_HEIGHT_METRES.get(id, 0.0))
        var corrected_height := nominal * CharacterRoster.world_scale(id)
        if nominal <= 0.0 or corrected_height < 1.8 or corrected_height > 2.0:
            push_error("Hero size outside 1.8-2m: " + id + " " + str(corrected_height))
            failures += 1
        var ratio := CharacterRoster.world_scale(id)
        if ratio < 0.90 or ratio > 1.10:
            push_error("Unexpected 100x character magnification: " + id + ": " + str(ratio))
            failures += 1
        if not ResourceLoader.exists(path):
            push_error("GLB missing: " + path)
            failures += 1
            continue
        var pack := load(path) as PackedScene
        if pack == null:
            push_error("Not an imported 3D scene: " + path)
            failures += 1
            continue
        var rig := pack.instantiate()
        root.add_child(rig)
        var anim := _find_anim(rig)
        if anim == null:
            push_error("No AnimationPlayer: " + id)
            failures += 1
        else:
            var available: Array[String] = []
            for n in anim.get_animation_list():
                available.append(String(n).to_lower())
            var has_idle := false
            for clip in available:
                if clip.ends_with("idle"):
                    has_idle = true
            if not has_idle:
                push_error("Missing Idle: " + id)
                failures += 1
            if not available.has("walk") and not available.has("run"):
                push_error("Missing Walk/Run: " + id)
                failures += 1
        checked += 1
        print("TEST_RIG_OK id=",id," world_height=",corrected_height," scale=",ratio)
        rig.queue_free()
    print("ROSTER_TEST_TOTAL checked=",checked," failures=",failures)
    quit(0 if failures == 0 and checked == CharacterRoster.ENTRIES.size() else 1)

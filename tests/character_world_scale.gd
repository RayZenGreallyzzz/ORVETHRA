extends SceneTree

# CI smoke test: every imported playable rig must exist, expose Idle +
# Walk/Run and remain 1.70–1.80 metres tall in the playable world.
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

func _toe_min_world(node: Node) -> float:
    var low := INF
    if node is Skeleton3D:
        var skeleton := node as Skeleton3D
        for index in range(skeleton.get_bone_count()):
            var name := String(skeleton.get_bone_name(index)).to_lower()
            if name.contains("toe"):
                var p: Vector3 = skeleton.to_global(skeleton.get_bone_global_pose(index).origin)
                low = minf(low, p.y)
    for child in node.get_children():
        low = minf(low, _toe_min_world(child))
    return low


func _validate_roster() -> void:
    var failures := 0
    var checked := 0
    for entry in CharacterRoster.ENTRIES:
        var id := str(entry["id"])
        var path := CharacterRoster.model_path(id)
        var nominal := float(CharacterRoster.SOURCE_HEIGHT_METRES.get(id, 0.0))
        var corrected_height := nominal * CharacterRoster.world_scale(id)
        if nominal <= 0.0 or corrected_height < 1.7 or corrected_height > 1.8:
            push_error("Hero size outside 1.7-1.8m: " + id + " " + str(corrected_height))
            failures += 1
        var ratio := CharacterRoster.world_scale(id)
        if ratio < 0.80 or ratio > 1.10:
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
        if anim != null:
            for clip in anim.get_animation_list():
                if String(clip).to_lower().ends_with("idle"):
                    anim.play(clip)
                    anim.seek(0.30, true)
                    break
        # True animated ground-contact test, not just metadata arithmetic:
        # physics street floor is y=-0.07 and its cobbles render at y=+0.008.
        # Toe bones must land on the visible surface once corrected.
        rig.scale = Vector3.ONE * ratio
        rig.position.y = -0.07 + 0.08
        var lowest_toe := _toe_min_world(rig)
        if not is_finite(lowest_toe) or absf(lowest_toe - 0.008) > 0.075:
            push_error("Hero feet floating: " + id + " toe_y=" + str(lowest_toe))
            failures += 1
        else:
            print("GROUND_CONTACT_OK id=", id, " toe_y=", lowest_toe)
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
    # BadBoy is no longer selectable, but must still be included as Greg,
    # the 1.75m roaming quest NPC by the town fountain.
    var greg_path := CharacterRoster.model_path("badboy")
    if not ResourceLoader.exists(greg_path):
        push_error("Greg/BadBoy NPC GLB missing")
        failures += 1
    else:
        var greg_pack := load(greg_path) as PackedScene
        if greg_pack == null:
            failures += 1
        else:
            var greg := greg_pack.instantiate()
            root.add_child(greg)
            var npc_anim := _find_anim(greg)
            if npc_anim != null:
                for clip in npc_anim.get_animation_list():
                    if String(clip).to_lower().ends_with("idle"):
                        npc_anim.play(clip)
                        npc_anim.seek(0.30, true)
                        break
            greg.scale = Vector3.ONE * CharacterRoster.world_scale("badboy")
            greg.position.y = -0.07 + 0.08
            var greg_toes := _toe_min_world(greg)
            if not is_finite(greg_toes) or absf(greg_toes - 0.008) > 0.075:
                push_error("Greg NPC feet floating: y=" + str(greg_toes))
                failures += 1
            else:
                print("GROUND_CONTACT_OK id=greg toe_y=", greg_toes)
            if npc_anim == null:
                push_error("Greg NPC has no animation player")
                failures += 1
            else:
                var clips: Array[String] = []
                for n in npc_anim.get_animation_list():
                    clips.append(String(n).to_lower())
                if not clips.has("idle") or not (clips.has("walk") or clips.has("run")):
                    push_error("Greg is missing Idle/Walk")
                    failures += 1
            greg.queue_free()
    print("ROSTER_TEST_TOTAL checked=",checked," failures=",failures)
    quit(0 if failures == 0 and checked == CharacterRoster.ENTRIES.size() else 1)

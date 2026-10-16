extends SceneTree

const Roster = preload("res://scripts/character_roster.gd")

func _initialize() -> void:
    call_deferred("_probe")

func _find_anim(node: Node) -> AnimationPlayer:
    if node is AnimationPlayer:
        return node as AnimationPlayer
    for child in node.get_children():
        var found := _find_anim(child)
        if found != null:
            return found
    return null

func _find_skeletons(node: Node, result: Array[Skeleton3D]) -> void:
    if node is Skeleton3D:
        result.append(node as Skeleton3D)
    for child in node.get_children():
        _find_skeletons(child, result)

func _probe() -> void:
    var ids := ["neonalleycat", "badboy", "bunny", "kwnips", "meerkat_baby"]
    for id in ids:
        var path := Roster.model_path(id)
        var packed := load(path) as PackedScene
        if packed == null:
            print("PROBE_FAIL missing ", id)
            continue
        var actor := packed.instantiate() as Node3D
        root.add_child(actor)
        var anim := _find_anim(actor)
        if anim != null:
            var clip := ""
            for name in anim.get_animation_list():
                if String(name).to_lower().ends_with("idle"):
                    clip = String(name)
                    break
            if clip != "":
                anim.play(clip)
                anim.seek(0.30, true)
        var skels: Array[Skeleton3D] = []
        _find_skeletons(actor, skels)
        print("PROBE ", id, " skeletons=", skels.size(), " actor=", actor.global_position)
        for sk in skels:
            print("PROBE_SK ",id," sk_scale=", sk.scale, " sk_origin=",sk.global_position," bones=",sk.get_bone_count())
            for bone_index in range(sk.get_bone_count()):
                var name := sk.get_bone_name(bone_index)
                var lower := name.to_lower()
                if lower.contains("foot") or lower.contains("toe") or lower.contains("head") or lower.contains("hips"):
                    var bp := sk.to_global(sk.get_bone_global_pose(bone_index).origin)
                    print("PROBE_BONE ", id, " name=",name," y=",bp.y," pos=",bp)
        var seen := 0
        var queue: Array[Node] = [actor]
        while not queue.is_empty():
            var node: Node = queue.pop_back()
            if node is MeshInstance3D and seen < 2:
                var mesh_node := node as MeshInstance3D
                if mesh_node.mesh != null:
                    var aabb := mesh_node.mesh.get_aabb()
                    print("PROBE_MESH ",id," node=",str(mesh_node.get_path())," gl_scale=",mesh_node.global_transform.basis.get_scale(), " aabb=",aabb)
                    seen += 1
            for child in node.get_children():
                queue.append(child)
        actor.queue_free()
    quit(0)

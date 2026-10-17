extends SceneTree

# Headless smoke test: materials and all nine randomly distributed slimes.
func _initialize() -> void:
    call_deferred("_run_training_test")

func _run_training_test() -> void:
    var actor_script = load("res://scripts/city_training.gd")
    var arena = actor_script.new()
    root.add_child(arena)
    await process_frame
    assert(arena.slimes.size() == 9, "Expected nine slimes")
    assert(arena.arena_floor != null)
    assert(arena.arena_floor.material_override is ShaderMaterial,
        "Training ground textures must both be installed")
    var seen: Array[Vector2] = []
    for entry in arena.slimes:
        var actor: Node3D = entry["node"]
        assert(int(entry["hp"]) > 0)
        var point := Vector2(actor.position.x, actor.position.z)
        assert(point.distance_to(Vector2(99.0, 70.0)) <= 9.8)
        for other in seen:
            assert(point.distance_to(other) > 2.2, "Slimes overlap")
        seen.append(point)
    print("TRAINING_ARENA_OK count=", arena.slimes.size())
    quit()

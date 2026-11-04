extends SceneTree

# Editor v0.32: choose, lock, duplicate as independent transform and undo.
func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    var city = load("res://scenes/city_preview.tscn").instantiate()
    root.add_child(city)
    await process_frame
    var editor = city.world_builder
    assert(editor != null, "City editor not present")
    assert(not editor.active)
    if FileAccess.file_exists("res://ORVETHRA_5_Buildings_Android_Optimized.zip"):
        for key in editor.ORDER:
            assert(editor._scene(key) != null, "Missing optimized GLB: " + str(key))
    editor.set_active(true)
    assert(city.overview and editor.active, "Editor must enable overhead camera")
    editor.begin("auction")
    assert(editor.draft != null, "Prefab preview missing")
    var first: Vector2 = _free_plot(editor, Vector2(91.0, -79.0))
    assert(first.x != 9999.0, "No free plot for the first building")
    editor.draft_data["x"] = first.x
    editor.draft_data["z"] = first.y
    editor.rotate_by(30.0)
    editor._refresh_preview()
    assert(editor.is_valid, "Expected empty placement plot")
    var previous: int = editor.saved.size()
    editor.confirm()
    assert(editor.saved.size() == previous + 1, "Lock must add a building")
    editor.select_at(first)
    assert(editor.editing == previous, "Must select existing building")
    editor.copy_selected(false)
    assert(editor.editing == -1 and editor.saved.size() == previous + 1, "Copy must not replace source")
    assert(float(editor.draft_data["angle"]) == 30.0, "Copy must preserve rotation")
    var second: Vector2 = _free_plot(editor, Vector2(45.0, -83.0))
    assert(second.x != 9999.0, "No free plot for duplicated building")
    editor.draft_data["x"] = second.x
    editor.draft_data["z"] = second.y
    editor._refresh_preview()
    assert(editor.is_valid, "Expected second building location")
    editor.confirm()
    assert(editor.saved.size() == previous + 2, "Copied building must be independent")
    editor.undo()
    assert(editor.saved.size() == previous + 1, "Undo must restore previous layout")
    editor.set_active(false)
    assert(not editor.active, "Exit must restore game mode")
    print("WORLD_BUILDER_TEST_OK buildings=", editor.saved.size())
    quit()

func _free_plot(editor: Node, preferred: Vector2) -> Vector2:
    var best := Vector2(9999.0, 9999.0)
    var best_dist := INF
    for z in range(-80, 81, 4):
        for x in range(-92, 93, 4):
            var point := Vector2(float(x), float(z))
            var candidate: Dictionary = editor._new_entry("auction", point)
            if not editor._position_ok(candidate):
                continue
            var dist := point.distance_squared_to(preferred)
            if dist < best_dist:
                best = point
                best_dist = dist
    return best

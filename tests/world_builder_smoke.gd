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
    editor.draft_data["x"] = 91.0
    editor.draft_data["z"] = -79.0
    editor.rotate_by(30.0)
    editor._refresh_preview()
    assert(editor.is_valid, "Expected empty placement plot")
    var previous: int = editor.saved.size()
    editor.confirm()
    assert(editor.saved.size() == previous + 1, "Lock must add a building")
    editor.select_at(Vector2(91.0, -79.0))
    assert(editor.editing == previous, "Must select existing building")
    editor.copy_selected(false)
    assert(editor.editing == -1 and editor.saved.size() == previous + 1, "Copy must not replace source")
    assert(float(editor.draft_data["angle"]) == 30.0, "Copy must preserve rotation")
    editor.draft_data["x"] = 45.0
    editor.draft_data["z"] = -83.0
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

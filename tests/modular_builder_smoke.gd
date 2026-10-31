extends SceneTree

# Godot headless regression for the actual modular manor editor.
func _initialize() -> void:
    call_deferred("_run")

func _assert(value: bool, description: String) -> void:
    if not value:
        push_error("MODULAR BUILDER: " + description)
        quit(1)
        assert(value, description)

func _run() -> void:
    var city = load("res://scenes/city_preview.tscn").instantiate()
    root.add_child(city)
    await process_frame
    var host = city.world_builder
    _assert(host != null, "City World Builder is missing")
    host.open_modular()
    var editor = host.modular_editor
    _assert(editor != null and editor.active, "Modular tab did not open")
    _assert(editor.PARTS.size() >= 16, "Expected at least 16 modular pieces")
    for key in editor.PARTS.keys():
        var mesh: ArrayMesh = editor._make_mesh(key)
        _assert(mesh.get_surface_count() >= 1, "No visual geometry for " + str(key))
    editor.floor_level = 0
    var found := false
    var gx := 0
    var gz := 0
    for x in range(-29, 30):
        if found:
            break
        for z in range(-24, 24):
            var base = editor._entry("foundation", x, z, 0)
            var wall = editor._entry("window_wall", x, z, 0)
            var wall2 = editor._entry("door_wall", x, z, 0, 1)
            if editor._position_ok(base) and editor._position_ok(wall) and editor._position_ok(wall2):
                gx = x
                gz = z
                found = true
                break
    _assert(found, "No valid modular house site discovered on city map")
    var start: int = editor.items.size()
    editor.begin("foundation")
    editor.candidate["gx"] = gx
    editor.candidate["gz"] = gz
    editor._refresh_ghost()
    _assert(editor.acceptable, "Foundation rejected valid site")
    editor.confirm()
    _assert(editor.items.size() == start + 1, "Foundation did not lock")
    editor.begin("window_wall")
    editor.candidate["gx"] = gx
    editor.candidate["gz"] = gz
    editor._refresh_ghost()
    _assert(editor.acceptable, "Wall rejected valid site")
    editor.confirm()
    _assert(editor.items.size() == start + 2, "Wall did not lock")
    editor.begin("door_wall")
    editor.candidate["gx"] = gx
    editor.candidate["gz"] = gz
    editor._refresh_ghost()
    _assert(not editor.acceptable, "Overlapping walls must be rejected")
    editor.rotate_piece(1)
    _assert(editor.acceptable, "Door on adjacent wall edge must be allowed")
    editor.confirm()
    _assert(editor.items.size() == start + 3, "Door was not placed")
    editor.select_at(Vector2(gx * editor.TILE, gz * editor.TILE - editor.TILE * 0.5))
    _assert(editor.editing == start + 1, "Window wall selection failed")
    editor.duplicate_piece()
    _assert(editor.editing == -1 and editor.items.size() == start + 3, "Copy must preserve original")
    _assert(str(editor.candidate["type"]) == "window_wall", "Copy changed module")
    var copied := false
    for x in range(-29, 30):
        if copied:
            break
        for z in range(-24, 24):
            editor.candidate["gx"] = x
            editor.candidate["gz"] = z
            if editor._position_ok(editor.candidate):
                copied = true
                break
    _assert(copied, "No valid location for duplicated wall")
    editor._refresh_ghost()
    editor.confirm()
    _assert(editor.items.size() == start + 4, "Copy not independently placed")
    editor.undo()
    _assert(editor.items.size() == start + 3, "Undo failed")
    editor.redo()
    _assert(editor.items.size() == start + 4, "Redo failed")
    var saved: int = editor.items.size()
    _assert(editor._save(), "Plan cannot be saved")
    editor.items.clear()
    editor._load()
    _assert(editor.items.size() == saved, "Saved blueprint was not restored")
    editor.change_floor(1)
    _assert(editor.floor_level == 1, "Second floor selector failed")
    host.set_active(false)
    _assert(not host.active and not editor.active, "Builder did not restore play mode")
    print("MODULAR_BUILDER_TEST_OK parts=", saved, " variants=", editor.PARTS.size())
    quit()

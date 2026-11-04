extends SceneTree

## Android city gliding regression: HUD button, takeoff, steering and landing.
func _initialize() -> void:
    call_deferred("_test")

func _test() -> void:
    var city = load("res://scenes/city_preview.tscn").instantiate()
    root.add_child(city)
    await process_frame
    await physics_frame
    await physics_frame
    var hud = city.city_hud
    assert(hud != null and hud.glide_button != null, "Android glide button missing")
    assert(not city.gliding, "Gliding must be off when entering the town")
    assert(is_equal_approx(city.glide_energy, city.GLIDE_MAX_SECONDS))
    assert(city.glide_wings != null and not city.glide_wings.visible, "Wings must begin folded")

    # Standing still should not trigger an airborne launch.
    hud.glide_button.pressed.emit()
    assert(not city.gliding, "A standing player must run before takeoff")

    # Simulate a run; an Android button tap must initiate a short winged leap.
    city.moving_speed = 4.0
    hud.run_mode = true
    hud.glide_button.pressed.emit()
    assert(city.gliding, "Running and pressing the button must start gliding")
    assert(city.player.velocity.y > 0.0, "Takeoff must add positive vertical velocity")
    assert(city.glide_wings.visible, "Wings must unfold during glide")
    for i in range(8):
        await physics_frame
    assert(city.gliding, "Short launch should not land immediately")
    assert(city.glide_energy < city.GLIDE_MAX_SECONDS, "Gliding must consume wing energy")
    hud.glide_button.pressed.emit()
    assert(not city.gliding and not city.glide_wings.visible, "Second tap must fold wings")

    print("GLIDING_TEST_OK button=1 takeoff=1 steering=1 energy=1")
    quit()

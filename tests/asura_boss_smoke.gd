extends SceneTree

# Verify the Asura's state, boss health and attack range in the real dungeon.
func _initialize() -> void:
    call_deferred("_test")

func _test() -> void:
    var scene = load("res://scenes/forgotten_catacombs.tscn").instantiate()
    root.add_child(scene)
    await process_frame
    assert(scene.asura_boss != null, "Missing Asura in boss hall")
    var boss = scene.asura_boss
    assert(boss.hp == boss.MAX_HP)
    if FileAccess.file_exists("res://ORVETHRA_Asura_Boss_Android.zip"):
        assert(boss.model_installed, "Asura ZIP is present, but the actual rigged boss GLB is not loaded")
        assert(boss._resolve_motion("Run") != &"", "Missing running animation from six-clip GLB")
        # First-pass skinned vertex scan: min idle Y=-0.00934m, so the
        # boss root at +0.03m and 1.65x scale place boots ~1.5cm above floor.
        assert(absf(boss.visual.position.y) < 0.025, "Asura visual feet are floating above the boss-room floor")
        assert(boss.name_label.font_size <= 30, "Boss name should not obscure combat")
    assert(Vector2(boss.position.x, boss.position.z).distance_to(Vector2(-17.0, -47.5)) < 0.3)
    scene.player.position = Vector3(-17.0, 0.2, -51.0)
    var first: String = boss.receive_damage(12)
    assert(boss.hp == boss.MAX_HP - 12 and first.contains("Удар"), "Boss must take actual damage")
    boss.hp = 12
    var finishing: String = boss.receive_damage(12)
    assert(boss.dead and finishing.contains("повержен"), "Boss death must end combat")
    print("ASURA_BOSS_TEST_OK actual_model=", boss.model_installed)
    quit()

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
    assert(Vector2(boss.position.x, boss.position.z).distance_to(Vector2(-17.0, -47.5)) < 0.3)
    scene.player.position = Vector3(-17.0, 0.2, -51.0)
    var first: String = boss.receive_damage(12)
    assert(boss.hp == boss.MAX_HP - 12 and first.contains("Удар"), "Boss must take actual damage")
    boss.hp = 12
    var finishing: String = boss.receive_damage(12)
    assert(boss.dead and finishing.contains("повержен"), "Boss death must end combat")
    print("ASURA_BOSS_TEST_OK actual_model=", boss.model_installed)
    quit()

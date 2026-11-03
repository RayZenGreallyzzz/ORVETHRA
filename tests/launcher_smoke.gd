extends SceneTree

func _initialize() -> void:
	var config := ConfigFile.new()
	assert(config.load("res://project.godot") == OK)
	assert(config.get_value("application", "run/main_scene") == "res://scenes/launcher_entry.tscn")
	var scene := load("res://scenes/launcher_entry.tscn")
	assert(scene is PackedScene)
	var node: Node = scene.instantiate()
	assert(node != null)
	assert(node.get_script() != null)
	node.free()
	print("LAUNCHER_SMOKE_OK")
	quit(0)

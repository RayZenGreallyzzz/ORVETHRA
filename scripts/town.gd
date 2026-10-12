extends Node3D

# First Android smoke test: lightweight real geometry, no downloaded art assets.
var hero: CharacterBody3D
var camera: Camera3D
var sunlight: DirectionalLight3D
var roof_zones: Array = []
var yaw: float = 0.0
var pitch: float = 0.34
var quality_high: bool = false
var touch_id: int = -1
var up_held := false
var down_held := false
var left_held := false
var right_held := false
var jump_held := false
var fps_label: Label
var place_label: Label
var timer: float = 0.0

func _ready() -> void:
	Engine.max_fps = 30
	_world()
	_town()
	_player()
	_ui()
	_set_quality(false)

func _material(hex: String, alpha: float = 1.0, emissive: bool = false) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(hex)
	mat.albedo_color.a = alpha
	mat.roughness = 0.9
	if alpha < 1.0:
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	if emissive:
		mat.emission_enabled = true
		mat.emission = Color(hex)
		mat.emission_energy_multiplier = 0.6
	return mat

func _box(parent: Node3D, pos: Vector3, size: Vector3, color: String, solid: bool = false) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	instance.mesh = mesh
	instance.position = pos
	instance.material_override = _material(color)
	parent.add_child(instance)
	if solid:
		var body := StaticBody3D.new()
		body.position = pos
		var collision := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = size
		collision.shape = shape
		body.add_child(collision)
		parent.add_child(body)
	return instance

func _cylinder(parent: Node3D, pos: Vector3, radius: float, height: float, hex: String) -> void:
	var instance := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 8
	instance.mesh = mesh
	instance.position = pos
	instance.material_override = _material(hex)
	parent.add_child(instance)

func _world() -> void:
	var sky := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("a1acac")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("c2c7c0")
	env.ambient_light_energy = 0.75
	sky.environment = env
	add_child(sky)
	sunlight = DirectionalLight3D.new()
	sunlight.rotation_degrees = Vector3(-52, -26, 0)
	sunlight.light_color = Color("eadbc1")
	sunlight.light_energy = 1.0
	add_child(sunlight)

func _tree(x: float, z: float) -> void:
	_cylinder(self, Vector3(x, 1.2, z), 0.24, 2.5, "635448")
	var leaves := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 1.5
	sphere.height = 2.7
	sphere.radial_segments = 8
	sphere.rings = 5
	leaves.mesh = sphere
	leaves.material_override = _material("637657")
	leaves.position = Vector3(x, 3.3, z)
	add_child(leaves)

func _house(title: String, x: float, z: float, roof_hex: String) -> void:
	var building := Node3D.new()
	building.position = Vector3(x, 0, z)
	add_child(building)
	_box(building, Vector3(0, 0.08, 0), Vector3(8.4, 0.16, 8.4), "87847a")
	# Four walls: front door opening faces the street (+Z).
	_box(building, Vector3(-4, 1.85, 0), Vector3(0.35, 3.7, 8.2), "a59c8c", true)
	_box(building, Vector3(4, 1.85, 0), Vector3(0.35, 3.7, 8.2), "a59c8c", true)
	_box(building, Vector3(0, 1.85, -4), Vector3(8.2, 3.7, 0.35), "a59c8c", true)
	_box(building, Vector3(-2.6, 1.85, 4), Vector3(3, 3.7, 0.35), "a59c8c", true)
	_box(building, Vector3(2.6, 1.85, 4), Vector3(3, 3.7, 0.35), "a59c8c", true)
	_box(building, Vector3(0, 3.35, 4), Vector3(2.3, 0.7, 0.35), "a59c8c", true)
	# Wooden beams, simple windows and a sign.
	for sx in [-3.8, 3.8]:
		_box(building, Vector3(sx, 1.9, 3.82), Vector3(0.2, 3.7, 0.25), "5b4c40")
	_box(building, Vector3(0, 3.7, 3.83), Vector3(8, 0.23, 0.24), "5b4c40")
	for wx in [-2.1, 2.1]:
		_box(building, Vector3(wx, 2.2, 4.20), Vector3(0.9, 0.9, 0.09), "738e94")
	_box(building, Vector3(0, 0.5, -2.2), Vector3(3.2, 0.8, 0.85), "594737")
	_box(building, Vector3(2.4, 0.65, -1.0), Vector3(1.15, 1.2, 1.15), "776249")
	_box(building, Vector3(-2.4, 0.42, -1.0), Vector3(1.5, 0.8, 1.1), "6e5b49")
	var sign := Label3D.new()
	sign.text = title
	sign.font_size = 72
	sign.pixel_size = 0.0048
	sign.outline_size = 8
	sign.modulate = Color("e8d6b1")
	sign.position = Vector3(0, 3.9, 4.45)
	sign.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	building.add_child(sign)
	var roof_mat := _material(roof_hex)
	roof_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	roof_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	for side in [-1, 1]:
		var roof := MeshInstance3D.new()
		var shape := BoxMesh.new()
		shape.size = Vector3(5.0, 0.3, 9.3)
		roof.mesh = shape
		roof.position = Vector3(float(side) * 1.92, 4.62, 0)
		roof.rotation_degrees.z = float(side) * 25.0
		roof.material_override = roof_mat
		building.add_child(roof)
	roof_zones.append({"root": building, "roof": roof_mat, "label": title})

func _town() -> void:
	_box(self, Vector3(0, -0.25, 0), Vector3(125, 0.5, 125), "657551", true)
	_box(self, Vector3(0, 0.01, 9), Vector3(37, 0.08, 22), "88867b")
	_box(self, Vector3(0, 0.055, 22), Vector3(8, 0.10, 9), "8c8b83")
	for x in [-11.0, 0.0, 11.0]:
		_box(self, Vector3(x, 0.055, 3), Vector3(3.2, 0.10, 14), "938f82")
	_house("Таверна", -11.0, -8.0, "485a68")
	_house("Кузница", 0.0, -8.0, "5d514d")
	_house("Магическая лавка", 11.0, -8.0, "515c68")
	for x in [-23.0, -19.0, 19.0, 23.0]:
		for z in [-18.0, 3.0, 18.0]:
			_tree(x, z)
	for x in [-16.0, -6.0, 6.0, 16.0]:
		_cylinder(self, Vector3(x, 1.15, 8.0), 0.16, 2.3, "514638")
		_box(self, Vector3(x, 2.42, 8.0), Vector3(0.68, 0.5, 0.68), "d8bb83")
	# Muted blue crystal in small open square.
	_cylinder(self, Vector3(0, 0.4, 9.0), 2.1, 0.8, "a29d8f")
	var crystal := _box(self, Vector3(0, 1.8, 9.0), Vector3(1.3, 2.8, 1.3), "5c99ad")
	crystal.rotation_degrees.z = 20.0
	crystal.material_override = _material("5b9eb6", 1.0, true)

func _player() -> void:
	hero = CharacterBody3D.new()
	hero.name = "Player"
	hero.position = Vector3(0, 0.3, 24)
	add_child(hero)
	var collision := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.35
	capsule.height = 1.8
	collision.shape = capsule
	collision.position.y = 0.95
	hero.add_child(collision)
	_cylinder(hero, Vector3(0, 1.0, 0), 0.40, 1.18, "3c536a")
	var head := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.31
	sphere.height = 0.62
	sphere.radial_segments = 9
	head.mesh = sphere
	head.position = Vector3(0, 1.88, 0)
	head.material_override = _material("b99e82")
	hero.add_child(head)
	_box(hero, Vector3(0, 1.0, 0.34), Vector3(0.75, 1.4, 0.13), "435a77")
	camera = Camera3D.new()
	camera.current = true
	camera.fov = 68.0
	add_child(camera)
	_update_camera()

func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed and event.position.x > get_viewport().get_visible_rect().size.x * 0.48:
			touch_id = event.index
		elif not event.pressed and event.index == touch_id:
			touch_id = -1
	elif event is InputEventScreenDrag and event.index == touch_id:
		_rotate_camera(event.relative.x, event.relative.y, 0.004)
	elif event is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
		_rotate_camera(event.relative.x, event.relative.y, 0.004)

func _rotate_camera(dx: float, dy: float, amount: float) -> void:
	yaw -= dx * amount
	pitch = clampf(pitch + dy * amount, 0.14, 0.85)

func _physics_process(delta: float) -> void:
	var h := int(Input.is_action_pressed("move_right")) - int(Input.is_action_pressed("move_left")) + int(right_held) - int(left_held)
	var v := int(Input.is_action_pressed("move_back")) - int(Input.is_action_pressed("move_forward")) + int(down_held) - int(up_held)
	var stick := Vector2(float(h), float(v)).limit_length(1.0)
	var forward := Vector3(-sin(yaw), 0, -cos(yaw))
	var right := Vector3(cos(yaw), 0, -sin(yaw))
	var desired := (right * stick.x - forward * stick.y) * 5.8
	hero.velocity.x = desired.x
	hero.velocity.z = desired.z
	if not hero.is_on_floor():
		hero.velocity.y -= 20.0 * delta
	elif Input.is_action_just_pressed("jump") or jump_held:
		hero.velocity.y = 6.1
	hero.move_and_slide()
	_update_camera()

func _update_camera() -> void:
	var dir := Vector3(sin(yaw) * cos(pitch), sin(pitch), cos(yaw) * cos(pitch))
	var focus := hero.global_position + Vector3(0, 1.4, 0)
	camera.global_position = focus + dir * 8.5
	camera.look_at(focus, Vector3.UP)

func _process(delta: float) -> void:
	var area := "Улица ремесленников"
	for entry in roof_zones:
		var home: Node3D = entry["root"]
		var local_pos := home.to_local(hero.global_position)
		var inside := absf(local_pos.x) < 3.8 and absf(local_pos.z) < 3.8 and local_pos.y < 3.5
		var mat: StandardMaterial3D = entry["roof"]
		var rgba := mat.albedo_color
		rgba.a = move_toward(rgba.a, 0.08 if inside else 1.0, 2.4 * delta)
		mat.albedo_color = rgba
		if inside:
			area = entry["label"]
	place_label.text = area
	timer += delta
	if timer >= 0.7:
		timer = 0.0
		fps_label.text = "%d FPS  ·  %s" % [int(Performance.get_monitor(Performance.TIME_FPS)), "Эконом" if not quality_high else "Красиво"]

func _set_quality(high: bool) -> void:
	quality_high = high
	Engine.max_fps = 60 if high else 30
	sunlight.shadow_enabled = high

func _button(parent: Control, caption: String, pos: Vector2, size: Vector2) -> Button:
	var b := Button.new()
	b.text = caption
	b.position = pos
	b.size = size
	b.focus_mode = Control.FOCUS_NONE
	parent.add_child(b)
	return b

func _ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(root)
	var headline := Label.new()
	headline.text = "ORVETHRA  ·  3D Android Test"
	headline.position = Vector2(16, 12)
	headline.add_theme_color_override("font_color", Color("eed9a9"))
	headline.add_theme_font_size_override("font_size", 23)
	root.add_child(headline)
	place_label = Label.new()
	place_label.position = Vector2(16, 47)
	place_label.add_theme_font_size_override("font_size", 17)
	root.add_child(place_label)
	fps_label = Label.new()
	fps_label.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	fps_label.offset_left = -220
	fps_label.offset_right = -12
	fps_label.offset_top = 16
	fps_label.offset_bottom = 50
	fps_label.text = "30 FPS · Эконом"
	fps_label.add_theme_font_size_override("font_size", 20)
	root.add_child(fps_label)
	var buttons := Control.new()
	buttons.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	buttons.position = Vector2(20, -200)
	buttons.size = Vector2(210, 180)
	buttons.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(buttons)
	var up := _button(buttons, "▲", Vector2(69, 0), Vector2(66, 54))
	var left := _button(buttons, "◀", Vector2(0, 58), Vector2(66, 54))
	var down := _button(buttons, "▼", Vector2(69, 58), Vector2(66, 54))
	var right := _button(buttons, "▶", Vector2(138, 58), Vector2(66, 54))
	up.button_down.connect(func() -> void: up_held = true)
	up.button_up.connect(func() -> void: up_held = false)
	left.button_down.connect(func() -> void: left_held = true)
	left.button_up.connect(func() -> void: left_held = false)
	down.button_down.connect(func() -> void: down_held = true)
	down.button_up.connect(func() -> void: down_held = false)
	right.button_down.connect(func() -> void: right_held = true)
	right.button_up.connect(func() -> void: right_held = false)
	var tools := Control.new()
	tools.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	tools.position = Vector2(-276, -92)
	tools.size = Vector2(265, 75)
	tools.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(tools)
	var jump_btn := _button(tools, "Прыжок", Vector2(0, 0), Vector2(100, 64))
	var quality_btn := _button(tools, "Графика", Vector2(107, 0), Vector2(150, 64))
	jump_btn.button_down.connect(func() -> void: jump_held = true)
	jump_btn.button_up.connect(func() -> void: jump_held = false)
	quality_btn.pressed.connect(func() -> void: _set_quality(not quality_high))

extends Node3D
## ORVETHRA blacksmith assembly kit. Attach to a Node3D in a test scene.
## Put the four original/optimized GLBs in res://assets/blacksmith/.
## Does not modify existing city saves, roads, or character controller.
@export var module_directory: String = "res://assets/blacksmith/"
@export var wall_span_m: float = 3.0
@export var storey_height_m: float = 3.2
@export var width_bays: int = 3
@export var depth_bays: int = 3
@export var build_on_ready: bool = true
@export var recolor: bool = true

const MODELS := {
    "solid": "стена кузни глухая.glb",
    "window": "стена кузни с окнами.glb",
    "entrance": "вход кузня.glb",
    "roof": "крыша кузни.glb"
}
var _scenes: Dictionary = {}
var _assembled: Node3D
var _materials: Dictionary = {}

func _ready() -> void:
    if build_on_ready:
        assemble()

func _load_scene(kind: String) -> PackedScene:
    if _scenes.has(kind):
        return _scenes[kind]
    var path: String = module_directory.path_join(MODELS[kind])
    if not ResourceLoader.exists(path):
        push_warning("Blacksmith GLB missing: " + path)
        return null
    # Godot imports .glb to PackedScene in the editor/build. Reuse that
    # imported scene instead of reparsing the GLB for every placement.
    var scene := ResourceLoader.load(path, "PackedScene") as PackedScene
    if scene == null:
        push_warning("Cannot load imported GLB scene: " + path)
        return null
    _scenes[kind] = scene
    return scene

func _mat(kind: String) -> StandardMaterial3D:
    if _materials.has(kind):
        return _materials[kind]
    var mat := StandardMaterial3D.new()
    match kind:
        "roof":
            mat.albedo_color = Color("303d57")
            mat.metallic = 0.12
        "entrance":
            mat.albedo_color = Color("77644f")
        "window":
            mat.albedo_color = Color("98928b")
        _:
            mat.albedo_color = Color("8b8984")
    mat.roughness = 0.83
    _materials[kind] = mat
    return mat

func _paint(node: Node, mat: Material) -> void:
    if node is MeshInstance3D:
        (node as MeshInstance3D).material_override = mat
    for child in node.get_children():
        _paint(child, mat)

func _piece(kind: String, position: Vector3, yaw: float, target_span: float, target_height: float) -> bool:
    var packed := _load_scene(kind)
    if packed == null:
        return false
    var instance := packed.instantiate() as Node3D
    if instance == null:
        return false
    _assembled.add_child(instance)
    instance.name = "Blacksmith_" + kind
    # Source GLBs have Y-up, with their origins near the geometric centre.
    # Scale uniformly for walls; keep roof's aspect ratio.
    var bounds := _bounds(instance)
    var extent: Vector3 = bounds.size
    if extent.x < 0.001 or extent.y < 0.001:
        instance.queue_free()
        return false
    var sx: float = target_span / extent.x
    var sy: float = target_height / extent.y
    instance.scale = Vector3(sx, sy, sx)
    instance.rotation.y = yaw
    # Align mesh bottom with floor and centre its original bounding box.
    instance.position = position + Vector3(-bounds.position.x * sx - extent.x * sx * 0.5, -bounds.position.y * sy, -bounds.position.z * sx - extent.z * sx * 0.5)
    if recolor:
        _paint(instance, _mat(kind))
    return true

func _bounds(root: Node3D) -> AABB:
    var found := false
    var result := AABB()
    for node in root.find_children("*", "MeshInstance3D", true, false):
        var mesh_node := node as MeshInstance3D
        if mesh_node.mesh == null:
            continue
        var box: AABB = mesh_node.get_aabb()
        var relative := root.global_transform.affine_inverse() * mesh_node.global_transform
        var transformed := relative * box
        if not found:
            result = transformed
            found = true
        else:
            result = result.merge(transformed)
    return result

func _collision_box(center: Vector3, size: Vector3, label: String) -> void:
    var body := StaticBody3D.new()
    body.name = label
    _assembled.add_child(body)
    body.position = center
    var shape := CollisionShape3D.new()
    var box := BoxShape3D.new()
    box.size = size
    shape.shape = box
    body.add_child(shape)

func assemble() -> bool:
    if _assembled != null and is_instance_valid(_assembled):
        _assembled.queue_free()
    _assembled = Node3D.new()
    _assembled.name = "BlacksmithAssembled"
    add_child(_assembled)
    var w: int = maxi(2, width_bays)
    var d: int = maxi(2, depth_bays)
    var span := wall_span_m
    var height := storey_height_m
    var half_x := float(w) * span * 0.5
    var half_z := float(d) * span * 0.5
    var complete := true
    for x in range(w):
        var px := -half_x + (float(x) + 0.5) * span
        var front := "entrance" if x == int(w / 2) else ("window" if x % 2 == 0 else "solid")
        complete = _piece(front, Vector3(px, 0, -half_z), 0.0, span, height) and complete
        complete = _piece("solid" if x % 2 == 0 else "window", Vector3(px, 0, half_z), PI, span, height) and complete
        if front == "entrance":
            _collision_box(Vector3(px - span * 0.38, height * 0.5, -half_z), Vector3(span * 0.24, height, 0.36), "EntranceLeft")
            _collision_box(Vector3(px + span * 0.38, height * 0.5, -half_z), Vector3(span * 0.24, height, 0.36), "EntranceRight")
        else:
            _collision_box(Vector3(px, height * 0.5, -half_z), Vector3(span, height, 0.36), "FrontWall")
        _collision_box(Vector3(px, height * 0.5, half_z), Vector3(span, height, 0.36), "BackWall")
    for z in range(d):
        var pz := -half_z + (float(z) + 0.5) * span
        for side in [-1, 1]:
            var px := float(side) * half_x
            complete = _piece("window" if z == int(d / 2) else "solid", Vector3(px, 0, pz), float(side) * PI * 0.5, span, height) and complete
            _collision_box(Vector3(px, height * 0.5, pz), Vector3(0.36, height, span), "SideWall")
    # Roof is one square module stretched across the entire shell.
    complete = _piece("roof", Vector3(0, height, 0), 0.0, float(w) * span + 0.7, 2.2) and complete
    _collision_box(Vector3(0, -0.12, 0), Vector3(float(w) * span, 0.24, float(d) * span), "Floor")
    if not complete:
        push_warning("Blacksmith assembled partially: supply the four GLBs in " + module_directory)
    return complete

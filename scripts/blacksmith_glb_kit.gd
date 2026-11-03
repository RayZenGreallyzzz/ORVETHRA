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
@export var place_on_grass: bool = true
@export var manual_placement: bool = false
@export var placement_x_m: float = 0.0
@export var placement_z_m: float = 0.0
@export var placement_yaw_degrees: float = 0.0
@export var grass_search_radius_m: float = 45.0
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
        if manual_placement:
            call_deferred("move_building", Vector3(placement_x_m, global_position.y, placement_z_m), placement_yaw_degrees)
        elif place_on_grass:
            call_deferred("snap_to_grass")

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
        _fallback_piece(kind, position, yaw, target_span, target_height)
        return true
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

## Place on an open terrain patch. Does not change saved city placements.
## Terrain collision is required; excludes existing buildings and roads via
## physics overlap check, and skips any surface without a grass-like collider name.
func snap_to_grass() -> bool:
    var world := get_world_3d()
    if world == null:
        return false
    var space := world.direct_space_state
    var footprint := Vector2(float(maxi(2, width_bays)) * wall_span_m, float(maxi(2, depth_bays)) * wall_span_m)
    var exclusions: Array[RID] = []
    if _assembled != null:
        for body in _assembled.find_children("*", "CollisionObject3D", true, false):
            exclusions.append((body as CollisionObject3D).get_rid())
    for ring in range(1, 9):
        for step in range(16):
            var angle := TAU * float(step) / 16.0
            var radius := grass_search_radius_m * float(ring) / 8.0
            var point := global_position + Vector3(cos(angle) * radius, 0.0, sin(angle) * radius)
            var query := PhysicsRayQueryParameters3D.create(point + Vector3.UP * 80.0, point - Vector3.UP * 80.0)
            query.exclude = exclusions
            var hit := space.intersect_ray(query)
            if hit.is_empty():
                continue
            var collider: Object = hit.get("collider")
            if not collider is Node:
                continue
            var terrain_name := str((collider as Node).name).to_lower()
            if not ("terrain" in terrain_name or "grass" in terrain_name or "ground" in terrain_name or "зем" in terrain_name or "трава" in terrain_name):
                continue
            var surface: Vector3 = hit["position"]
            var check := PhysicsShapeQueryParameters3D.new()
            var box := BoxShape3D.new()
            box.size = Vector3(footprint.x + 3.0, 3.0, footprint.y + 3.0)
            check.shape = box
            check.transform = Transform3D(Basis.IDENTITY, surface + Vector3.UP * 1.6)
            check.exclude = exclusions.duplicate()
            if collider is CollisionObject3D:
                check.exclude.append((collider as CollisionObject3D).get_rid())
            if not space.intersect_shape(check, 8).is_empty():
                continue
            global_position = surface
            return true
    push_warning("No unobstructed grass found. Blacksmith kept at its original position.")
    return false

## Move the entire assembled blacksmith without rebuilding modules or
## touching the city's persistent save. Coordinates are world metres.
func move_building(world_location: Vector3, yaw_degrees: float = 0.0) -> void:
    global_position = world_location
    global_rotation.y = deg_to_rad(yaw_degrees)

## Shift the building relative to its current position (metres).
func nudge_building(dx: float, dz: float, rotation_degrees: float = 0.0) -> void:
    global_position += Vector3(dx, 0.0, dz)
    global_rotation.y += deg_to_rad(rotation_degrees)

## Lightweight temporary geometry is shown until the detailed GLBs arrive.
## All pieces are under the same movable building root.
func _fallback_box(parent: Node3D, center: Vector3, size: Vector3, mat: Material) -> void:
    var view := MeshInstance3D.new()
    var mesh := BoxMesh.new()
    mesh.size = size
    view.mesh = mesh
    view.material_override = mat
    view.position = center
    view.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    parent.add_child(view)

func _fallback_piece(kind: String, position: Vector3, yaw: float, span: float, height: float) -> void:
    var section := Node3D.new()
    section.name = "BlacksmithFallback_" + kind
    section.position = position
    section.rotation.y = yaw
    _assembled.add_child(section)
    var stone := _mat("solid")
    var timber := _mat("entrance")
    if kind == "roof":
        _fallback_box(section, Vector3(0, height * 0.32, 0), Vector3(span, 0.3, span), _mat("roof"))
        _fallback_box(section, Vector3(0, height * 0.62, 0), Vector3(span * 0.85, 0.3, span * 0.85), _mat("roof"))
    elif kind == "entrance":
        for side in [-1.0, 1.0]:
            _fallback_box(section, Vector3(side * span * 0.39, height * 0.5, 0), Vector3(span * 0.22, height, 0.28), stone)
        _fallback_box(section, Vector3(0, height * 0.92, 0), Vector3(span * 0.60, height * 0.16, 0.28), timber)
    elif kind == "window":
        _fallback_box(section, Vector3(0, height * 0.17, 0), Vector3(span, height * 0.34, 0.28), stone)
        _fallback_box(section, Vector3(0, height * 0.88, 0), Vector3(span, height * 0.24, 0.28), stone)
        for side in [-1.0, 1.0]:
            _fallback_box(section, Vector3(side * span * 0.42, height * 0.55, 0), Vector3(span * 0.16, height * 0.50, 0.28), timber)
    else:
        _fallback_box(section, Vector3(0, height * 0.5, 0), Vector3(span, height, 0.28), stone)
        _fallback_box(section, Vector3(0, height * 0.85, 0.18), Vector3(span, 0.14, 0.12), timber)

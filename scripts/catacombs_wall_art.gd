extends RefCounted

# ORVETHRA: Gothic decoration uses only flat textured quads.
const ART_PATHS := {
    "stone_guard":"res://assets/catacombs/tiles/wall_guard_mobile.webp",
    "skull":"res://assets/catacombs/decor/crimson_skull_emblem_mobile.webp",
    "skull_banner":"res://assets/catacombs/decor/crimson_skull_banner_mobile.webp",
    "chain":"res://assets/catacombs/decor/golden_chain_mobile.webp",
    "rune_banner":"res://assets/catacombs/decor/crimson_rune_banner_mobile.webp",
    "angel":"res://assets/catacombs/decor/angel_sword_statue_mobile.webp",
    "sentinel":"res://assets/catacombs/decor/dread_guardian_statue_mobile.webp"
}
const BOSS_CENTER := Vector2(-17.0, -47.5)
const WALL_THICKNESS := 0.46
var cached_materials: Dictionary = {}

func _mat(id: String) -> StandardMaterial3D:
    if cached_materials.has(id):
        return cached_materials[id]
    if not ART_PATHS.has(id):
        return null
    var asset := load(str(ART_PATHS[id])) as Texture2D
    if asset == null:
        return null
    var material := StandardMaterial3D.new()
    material.albedo_texture = asset
    material.roughness = 1.0
    material.cull_mode = BaseMaterial3D.CULL_DISABLED
    material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
    if id != "stone_guard":
        material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    cached_materials[id] = material
    return material

func picture(root: Node3D, id: String, center: Vector3, inward: Vector3, height: float) -> void:
    var material := _mat(id)
    if material == null:
        return
    var tex_size := material.albedo_texture.get_size()
    var ratio := float(tex_size.x) / maxf(1.0, float(tex_size.y))
    var mesh_node := MeshInstance3D.new()
    mesh_node.name = "FlatWallArt_" + id
    var quad := QuadMesh.new()
    quad.size = Vector2(height * ratio, height)
    mesh_node.mesh = quad
    mesh_node.material_override = material
    mesh_node.rotation.y = atan2(inward.x, inward.z)
    mesh_node.position = center + inward * (WALL_THICKNESS * 0.5 + 0.038)
    mesh_node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    root.add_child(mesh_node)

func decorate_room_section(root: Node3D, at: Vector3, inward: Vector3, horizontal: bool, span: float) -> void:
    # The boss has its own wall composition.
    if Vector2(at.x, at.z).distance_to(BOSS_CENTER) < 18.0 or span < 5.5:
        return
    var tangent := Vector3(1.0, 0.0, 0.0) if horizontal else Vector3(0.0, 0.0, 1.0)
    var count := maxi(1, int(round(span / 11.5)))
    var spacing := span / float(count)
    for i in range(count):
        var slot := at + tangent * ((float(i) + 0.5) * spacing - span * 0.5)
        var choice := posmod(roundi(at.x * 17.0 + at.z * 13.0) + i * 5, 7)
        match choice:
            0: picture(root, "stone_guard", slot, inward, 4.35)
            1: picture(root, "angel", slot, inward, 4.4)
            2: picture(root, "rune_banner", slot, inward, 3.75)
            3: picture(root, "skull_banner", slot, inward, 3.75)
            4: picture(root, "sentinel", slot, inward, 4.35)
            5: picture(root, "skull", slot, inward, 3.15)
            _: picture(root, "chain", slot + Vector3.UP * 1.1, inward, 2.5)

func decorate_boss(root: Node3D) -> void:
    # Angels bearing swords on three walls, gobelins and high chains.
    var back := Vector3(0.0, 0.0, 1.0)
    picture(root, "angel", Vector3(-17.0, 2.50, -60.0), back, 4.6)
    picture(root, "skull_banner", Vector3(-24.0, 2.52, -60.0), back, 4.2)
    picture(root, "rune_banner", Vector3(-10.0, 2.52, -60.0), back, 4.2)
    picture(root, "chain", Vector3(-28.0, 3.73, -60.0), back, 2.25)
    picture(root, "chain", Vector3(-6.0, 3.73, -60.0), back, 2.25)

    var left := Vector3(1.0, 0.0, 0.0)
    picture(root, "angel", Vector3(-29.5, 2.50, -47.5), left, 4.45)
    picture(root, "rune_banner", Vector3(-29.5, 2.50, -54.6), left, 3.85)
    picture(root, "skull_banner", Vector3(-29.5, 2.50, -40.2), left, 3.85)
    picture(root, "chain", Vector3(-29.5, 3.78, -58.0), left, 2.3)
    picture(root, "chain", Vector3(-29.5, 3.78, -37.0), left, 2.3)

    var south := Vector3(0.0, 0.0, -1.0)
    picture(root, "angel", Vector3(-17.0, 2.50, -35.0), south, 4.45)
    picture(root, "skull", Vector3(-24.0, 2.55, -35.0), south, 3.1)
    picture(root, "sentinel", Vector3(-10.0, 2.50, -35.0), south, 4.1)
    picture(root, "chain", Vector3(-27.5, 3.75, -35.0), south, 2.25)
    picture(root, "chain", Vector3(-6.5, 3.75, -35.0), south, 2.25)

    # Do not obstruct the east-side entrance to the 25m boss arena.
    var right := Vector3(-1.0, 0.0, 0.0)
    picture(root, "rune_banner", Vector3(-4.5, 2.55, -54.5), right, 3.4)
    picture(root, "skull_banner", Vector3(-4.5, 2.55, -39.0), right, 3.4)

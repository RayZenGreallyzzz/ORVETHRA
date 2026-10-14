extends RefCounted

# ORVETHRA mobile plaza fountain.
# Mobile proxy generated from the user's Guardian Angel Fountain GLB.
# v2 keeps about 49k triangles (instead of ~8k) so the wings, basin and ornament
# keep their shape while remaining far lighter than the ~550k-triangle source.
# Corrected stone/gold/blue colour is baked into vertex colours.
const DATA_PATH := "res://assets/fountain/guardian_fountain_mobile.bin"
const MIN_POS := Vector3(-0.9148550033569336, -0.887890487909317, -0.9113331246376037)
const MAX_POS := Vector3(0.922199010848999, 0.8816908001899719, 0.9049930387529833)
const FOUNTAIN_SCALE := 4.0

static func _signed_byte(value: int) -> float:
    var signed_value := value if value < 128 else value - 256
    return float(signed_value) / 127.0

static func add_to(parent: Node3D) -> Node3D:
    var packed := FileAccess.get_file_as_bytes(DATA_PATH)
    if packed.is_empty():
        push_error("ORVETHRA fountain data is missing")
        return null

    var raw := packed
    if raw.size() < 12:
        push_error("ORVETHRA fountain data is truncated")
        return null
    if raw.slice(0, 4).get_string_from_ascii() != "OFM2":
        push_error("ORVETHRA fountain data has invalid header")
        return null

    var vertex_count := raw.decode_u32(4)
    var face_count := raw.decode_u32(8)
    var offset := 12

    var vertices := PackedVector3Array()
    vertices.resize(vertex_count)
    var normals := PackedVector3Array()
    normals.resize(vertex_count)
    var colors := PackedColorArray()
    colors.resize(vertex_count)
    var span := MAX_POS - MIN_POS

    for i in range(vertex_count):
        var qx := raw.decode_u16(offset)
        offset += 2
        var qy := raw.decode_u16(offset)
        offset += 2
        var qz := raw.decode_u16(offset)
        offset += 2
        var point := MIN_POS + Vector3(float(qx), float(qy), float(qz)) / 65535.0 * span
        point.y -= MIN_POS.y
        vertices[i] = point

    for i in range(vertex_count):
        var nx := _signed_byte(raw[offset])
        offset += 1
        var ny := _signed_byte(raw[offset])
        offset += 1
        var nz := _signed_byte(raw[offset])
        offset += 1
        normals[i] = Vector3(nx, ny, nz).normalized()

    for i in range(vertex_count):
        colors[i] = Color(
            float(raw[offset]) / 255.0,
            float(raw[offset + 1]) / 255.0,
            float(raw[offset + 2]) / 255.0,
            1.0
        )
        offset += 3

    var indices := PackedInt32Array()
    indices.resize(face_count * 3)
    for i in range(face_count * 3):
        indices[i] = raw.decode_u16(offset)
        offset += 2

    var arrays: Array = []
    arrays.resize(Mesh.ARRAY_MAX)
    arrays[Mesh.ARRAY_VERTEX] = vertices
    arrays[Mesh.ARRAY_NORMAL] = normals
    arrays[Mesh.ARRAY_COLOR] = colors
    arrays[Mesh.ARRAY_INDEX] = indices

    var mesh := ArrayMesh.new()
    mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)

    var material := StandardMaterial3D.new()
    material.vertex_color_use_as_albedo = true
    material.roughness = 0.95
    material.metallic = 0.03
    material.cull_mode = BaseMaterial3D.CULL_DISABLED
    mesh.surface_set_material(0, material)

    var root := Node3D.new()
    root.name = "GuardianAngelFountain"
    root.position = Vector3(0.0, 0.04, 0.0)
    root.scale = Vector3.ONE * FOUNTAIN_SCALE
    parent.add_child(root)

    var visual := MeshInstance3D.new()
    visual.name = "FountainVisual"
    visual.mesh = mesh
    visual.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    root.add_child(visual)

    # Cheap mobile collision: keeps the player out of the basin without mesh collision.
    var body := StaticBody3D.new()
    body.name = "FountainCollision"
    body.position = Vector3(0.0, 0.62, 0.0)
    var collision := CollisionShape3D.new()
    var shape := CylinderShape3D.new()
    shape.radius = 3.65
    shape.height = 1.24
    collision.shape = shape
    body.add_child(collision)
    parent.add_child(body)

    return root

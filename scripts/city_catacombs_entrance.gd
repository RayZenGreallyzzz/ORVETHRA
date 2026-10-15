extends Node3D

# Forgotten Catacombs entrance on the NE fringe of ORVETHRA.
# The last street comes from (78,78) to (90,94). Never move the approved roads.
# A reduced imported Meshy crypt can replace this temporary walkable gate later.
const MOBILE_CRYPT := "res://assets/catacombs/ruined_gothic_crypt_mobile.glb"
const CITY_PORTAL_POINT := Vector2(88.0, 85.5)

func _ready() -> void:
    position = Vector3(90, 0.0, 89)
    rotation.y = atan2(12.0, 16.0)
    _gate_stones()
    var plaque := Label3D.new()
    plaque.text = "ЗАБЫТЫЕ КАТАКОМБЫ"
    plaque.font_size = 54
    plaque.pixel_size = 0.011
    plaque.billboard = BaseMaterial3D.BILLBOARD_ENABLED
    plaque.position = Vector3(0, 4.5, -1.3)
    plaque.modulate = Color("eccea1")
    add_child(plaque)

func _add_block(where: Vector3, bounds: Vector3, material: Material, collide := true) -> void:
    var visible_part := MeshInstance3D.new()
    var box := BoxMesh.new()
    box.size = bounds
    visible_part.mesh = box
    visible_part.material_override = material
    visible_part.position = where
    visible_part.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    add_child(visible_part)
    if collide:
        var body := StaticBody3D.new()
        var shape := CollisionShape3D.new()
        var solid := BoxShape3D.new()
        solid.size = bounds
        shape.shape = solid
        body.position = where
        body.add_child(shape)
        add_child(body)

func _gate_stones() -> void:
    var masonry := StandardMaterial3D.new()
    masonry.albedo_color = Color("4f4b4a")
    masonry.roughness = 1.0
    var trim := StandardMaterial3D.new()
    trim.albedo_color = Color("302a2d")
    trim.roughness = 1.0
    var door := StandardMaterial3D.new()
    door.albedo_color = Color("17171b")
    door.roughness = 0.96
    # Broad, unblocked 3m doorway. Trigger is on the playable street side.
    for sign in [-1.0, 1.0]:
        _add_block(Vector3(sign * 2.15, 1.85, 0), Vector3(1.2, 3.7, 2.3), masonry)
        _add_block(Vector3(sign * 2.65, 0.45, -2.1), Vector3(0.55, 0.9, 2.0), trim)
        _add_block(Vector3(sign * 2.15, 3.9, 0.0), Vector3(1.65, 0.56, 2.5), trim)
    _add_block(Vector3(0, 4.2, 0), Vector3(5.5, 0.9, 2.5), masonry)
    _add_block(Vector3(0, 2, 1.1), Vector3(3.15, 3.6, 0.18), door)
    for i in range(3):
        _add_block(Vector3(0, 0.04 + float(i) * 0.06, -4.0 + float(i) * 0.7),
            Vector3(3.6, 0.11, 0.72), masonry, false)
    var torch := StandardMaterial3D.new()
    torch.albedo_color = Color("f09c46")
    torch.emission_enabled = true
    torch.emission = Color("ff9945")
    torch.emission_energy_multiplier = 2.0
    for s in [-1.0, 1.0]:
        _add_block(Vector3(s * 2.1, 2.5, -1.38), Vector3(0.2, 0.65, 0.22), torch, false)

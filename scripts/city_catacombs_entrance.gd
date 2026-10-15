extends Node3D

# Forgotten Catacombs entrance on the NE fringe of ORVETHRA.
# The last street comes from (78,78) to (90,94). Never move the approved roads.
# A reduced imported Meshy crypt can replace this temporary walkable gate later.
const MOBILE_CRYPT := "res://assets/catacombs/crypt_entrance_mobile.glb"
const CITY_PORTAL_POINT := Vector2(86.7, 89.5)

func _ready() -> void:
    # Align the gateway with the road from (78,78) toward (90,94).
    # City playfield ends at Z=93, so the gate sits on its centreline.
    position = Vector3(90.0, 0.0, 94.0)
    rotation.y = atan2(12.0, 16.0) # Road direction to the NE end; local -Z points back to street
    # The real Meshy crypt wins when the optional asset ZIP is installed.
    if ResourceLoader.exists(MOBILE_CRYPT):
        var asset: Resource = load(MOBILE_CRYPT)
        if asset is PackedScene:
            var crypt: Node3D = (asset as PackedScene).instantiate()
            crypt.name = "MeshyGothicCryptMobile"
            # Uniform scale keeps statues and carved arches proportional.
            # Optimized Meshy crypt is 1.895 x 1.251 x 1.472 metres.
            # Uniform 4.6x makes a ~8.7m-wide, ~5.75m-tall gate matching
            # the 8.8m cobbled street without distorting statues or arches.
            crypt.scale = Vector3.ONE * 4.6
            crypt.position = Vector3(0, 2.88, 0.0)
            # The imported GLB facade looks toward +Z. Face the gate and
            # stairs down the approved road, which approaches from local -Z.
            crypt.rotation.y = PI
            add_child(crypt)
            _gate_collision_only()
        else:
            _gate_stones()
    else:
        _gate_stones()
    var plaque := Label3D.new()
    plaque.text = "ЗАБЫТЫЕ КАТАКОМБЫ"
    plaque.font_size = 28
    plaque.pixel_size = 0.009
    plaque.billboard = BaseMaterial3D.BILLBOARD_ENABLED
    plaque.position = Vector3(0, 6.35, -0.8)
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

func _gate_collision_only() -> void:
    # Minimal collision: leave the centre passage clear to approach the door.
    var body := StaticBody3D.new()
    body.name = "CryptSideCollisions"
    add_child(body)
    for side in [-1.0, 1.0]:
        var collider := CollisionShape3D.new()
        var box := BoxShape3D.new()
        box.size = Vector3(1.2, 4.8, 1.8)
        collider.shape = box
        collider.position = Vector3(side * 3.5, 2.4, 0.5)
        body.add_child(collider)
    # A flush landing joins the textured entrance to the existing street.
    var masonry := StandardMaterial3D.new()
    masonry.albedo_color = Color("77716b")
    masonry.albedo_texture = load("res://assets/catacombs/tiles/floor_stone_mobile.webp") as Texture2D
    masonry.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
    masonry.uv1_scale = Vector3(2.8, 1.0, 2.5)
    masonry.roughness = 1.0
    _add_block(Vector3(0, -0.045, -2.9), Vector3(7.6, 0.08, 5.7), masonry, false)

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

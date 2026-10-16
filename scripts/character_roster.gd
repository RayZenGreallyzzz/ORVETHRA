extends RefCounted

# The nine approved test heroes. KWNIPS and Meerkat are male/female pairs,
# NOT adults with baby companions; source filename suffixes are kept intact.
# Filenames deliberately use ASCII for Godot/Android resource portability.
const ENTRIES := [
    {"id":"neonalleycat", "title":"Неон Тенехвост", "species":"Уличный кот", "role":"Страж переулков", "gender":"Самец", "clip":"Run"},
    {"id":"dododog", "title":"Доргар Лютолап", "species":"Додопёс", "role":"Страж диких троп", "gender":"Самец", "clip":"Walk"},
    {"id":"kwnips_baby", "title":"Нимрия Лунолапа", "species":"Квнипс", "role":"Лунная колдунья", "gender":"Самка", "clip":"Walk"},
    {"id":"meerkat_baby", "title":"Мира Песчаная Искра", "species":"Сурикат", "role":"Песчаная следопытка", "gender":"Самка", "clip":"Walk"},
    {"id":"meerkat", "title":"Тарек Песчаный Клык", "species":"Сурикат", "role":"Страж пустыни", "gender":"Самец", "clip":"Walk"},
    {"id":"kwnips", "title":"Кворн Грозолап", "species":"Квнипс", "role":"Грозовой маг", "gender":"Самец", "clip":"Walk"},
    {"id":"bunny", "title":"Лунар Серебролап", "species":"Лунный зверолюд", "role":"Ловкий боец", "gender":"Самец", "clip":"Run"},
    {"id":"graffitialleycat", "title":"Граффит Ночной Коготь", "species":"Уличный кот", "role":"Теневой клинок", "gender":"Самец", "clip":"Run"},
    {"id":"crimsondrakeshadow_lizard", "title":"Кримзар Тенедракон", "species":"Драконид", "role":"Багровый воин", "gender":"Самец", "clip":"Run"}
]

static func model_path(id: String) -> String:
    if id == "neonalleycat" or id == "":
        return "res://assets/characters/ORVETHRA_NeonAlleycat_Animated_Mobile.glb"
    return "res://assets/characters/roster/" + id + "_mobile.glb"

static func get_entry(id: String) -> Dictionary:
    for entry in ENTRIES:
        if entry["id"] == id:
            return entry
    return {}

static func default_id() -> String:
    return "neonalleycat"


# Verified source GLB mesh POSITION heights, measured before any armature
# transforms. Almost all are already 1.9m, while eight GLBs have a 0.01
# Armature hierarchy compensated by skin inverse-bind matrices. Do NOT
# magnify them 100x by measuring imported MeshInstance AABBs.
const SOURCE_HEIGHT_METRES := {
    "neonalleycat": 1.900,
    "dododog": 1.900,
    "kwnips_baby": 1.874,
    "meerkat_baby": 1.900,
    "meerkat": 1.900,
    "kwnips": 1.878,
    "badboy": 1.893,
    "bunny": 1.898,
    "graffitialleycat": 1.894,
    "crimsondrakeshadow_lizard": 1.898
}

static func world_scale(id: String) -> float:
    # A consistent 1.75m world-height body, preserving proportions.
    # The source's skeletal transforms already handle original GLB units.
    return target_height_metres() / float(SOURCE_HEIGHT_METRES.get(id, 1.9))

static func target_height_metres() -> float:
    return 1.75

extends RefCounted

# The nine approved test heroes. KWNIPS and Meerkat are male/female pairs,
# NOT adults with baby companions; source filename suffixes are kept intact.
# Filenames deliberately use ASCII for Godot/Android resource portability.
const ENTRIES := [
    {"id":"dododog", "title":"Доргар Лютолап", "species":"Додопёс", "role":"Страж диких троп", "gender":"Самец", "clip":"Walk"},
    {"id":"kwnips_baby", "title":"Нимрия Лунолапа", "species":"Квнипс", "role":"Лунная колдунья", "gender":"Самка", "clip":"Walk"},
    {"id":"meerkat_baby", "title":"Мира Песчаная Искра", "species":"Сурикат", "role":"Песчаная следопытка", "gender":"Самка", "clip":"Walk"},
    {"id":"meerkat", "title":"Тарек Песчаный Клык", "species":"Сурикат", "role":"Страж пустыни", "gender":"Самец", "clip":"Walk"},
    {"id":"kwnips", "title":"Кворн Грозолап", "species":"Квнипс", "role":"Грозовой маг", "gender":"Самец", "clip":"Walk"},
    {"id":"badboy", "title":"Рокхар Беззаконник", "species":"Бунтарь", "role":"Тёмный дуэлянт", "gender":"Самец", "clip":"Walk"},
    {"id":"bunny", "title":"Лунар Серебролап", "species":"Лунный зверолюд", "role":"Ловкий боец", "gender":"Самец", "clip":"Run"},
    {"id":"graffitialleycat", "title":"Граффит Ночной Коготь", "species":"Уличный кот", "role":"Теневой клинок", "gender":"Самец", "clip":"Run"},
    {"id":"crimsondrakeshadow_lizard", "title":"Кримзар Тенедракон", "species":"Драконид", "role":"Багровый воин", "gender":"Самец", "clip":"Run"}
]

static func model_path(id: String) -> String:
    if id == "neonalleycat" or id == "":
        return "res://assets/characters/ORVETHRA_NeonAlleycat_Animated_Mobile.glb"
    return "res://assets/characters/test_roster/" + id + "_mobile.glb"

static func get_entry(id: String) -> Dictionary:
    for entry in ENTRIES:
        if entry["id"] == id:
            return entry
    return {}

static func default_id() -> String:
    return "dododog"

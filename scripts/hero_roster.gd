extends RefCounted

# Local test-only appearance selection. Each hero keeps their exact source GLB.
# The fantasy names below are display aliases, not changes to asset filenames.
const SAVE_PATH := "user://orvethra_hero_roster.json"
const DEFAULT_ID := "neonalleycat"
const ENTRIES := [
    {"id":"neonalleycat", "name":"Неон Тенехвост", "source":"NeonAlleycat", "model":"res://assets/characters/ORVETHRA_NeonAlleycat_Animated_Mobile.glb", "role":"Страж переулков", "clip":"Idle"},
    {"id":"dododog", "name":"Доргар Лютолап", "source":"Dododog", "model":"res://assets/characters/roster/dododog_mobile.glb", "role":"Страж диких троп", "clip":"Idle"},
    {"id":"kwnips_baby", "name":"Нимрия Лунолапа", "source":"KWNIPS Baby", "model":"res://assets/characters/roster/kwnips_baby_mobile.glb", "role":"Лунная колдунья, самка", "clip":"Idle"},
    {"id":"meerkat_baby", "name":"Мира Песчаная Искра", "source":"Meerkat Baby", "model":"res://assets/characters/roster/meerkat_baby_mobile.glb", "role":"Песчаная следопытка, самка", "clip":"Idle"},
    {"id":"meerkat", "name":"Тарек Песчаный Клык", "source":"Meerkat", "model":"res://assets/characters/roster/meerkat_mobile.glb", "role":"Страж пустыни, самец", "clip":"Idle"},
    {"id":"kwnips", "name":"Кворн Грозолап", "source":"KWNIPS", "model":"res://assets/characters/roster/kwnips_mobile.glb", "role":"Грозовой маг, самец", "clip":"Idle"},
    {"id":"bunny", "name":"Лунар Серебролап", "source":"Bunny", "model":"res://assets/characters/roster/bunny_mobile.glb", "role":"Ловкий боец", "clip":"Idle"},
    {"id":"graffitialleycat", "name":"Граффит Ночной Коготь", "source":"GraffitiAlleyCat", "model":"res://assets/characters/roster/graffitialleycat_mobile.glb", "role":"Теневой клинок", "clip":"Idle"},
    {"id":"crimsondrakeshadow_lizard", "name":"Кримзар Тенедракон", "source":"CrimsonDrakeshadow Lizard", "model":"res://assets/characters/roster/crimsondrakeshadow_lizard_mobile.glb", "role":"Багровый воин", "clip":"Idle"}
]

static func by_id(id: String) -> Dictionary:
    for entry in ENTRIES:
        if entry["id"] == id:
            return entry
    return ENTRIES[0]

static func selected_id() -> String:
    if FileAccess.file_exists(SAVE_PATH):
        var data = JSON.parse_string(FileAccess.get_file_as_string(SAVE_PATH))
        if data is Dictionary:
            var id := str(data.get("model_id", DEFAULT_ID))
            for entry in ENTRIES:
                if entry["id"] == id:
                    return id
    return DEFAULT_ID

static func save_id(id: String) -> void:
    var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
    if file != null:
        file.store_string(JSON.stringify({"model_id":id}))
        file.close()

static func selected_entry() -> Dictionary:
    return by_id(selected_id())

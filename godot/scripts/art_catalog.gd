extends RefCounted
const Regions = preload("res://scripts/art_regions.gd")
static var textures: Dictionary = {}
static var sprites: Dictionary = {}

static func source(name: String) -> Texture2D:
	if not textures.has(name): textures[name] = load("res://assets/art/" + name + ".png")
	return textures[name]

static func cropped(name: String, index: int, regions: Array) -> AtlasTexture:
	var key = name + str(index)
	if not sprites.has(key):
		var a = AtlasTexture.new(); a.atlas = source(name); a.region = regions[index]; a.filter_clip = true; sprites[key] = a
	return sprites[key]

static func companion(index: int) -> Texture2D:
	return cropped("companions_atlas", 7 if index == 0 else index - 1, Regions.COMPANIONS)

static func hero(index: int, mining: bool = false, star_skin: bool = false) -> Texture2D:
	if index == 0 and star_skin:
		var tex = source("skin_star_atlas")
		var h = float(tex.get_height())
		var scale = float(tex.get_width()) / 1774.0
		return cropped("skin_star_atlas", 1 if mining else 0, [Rect2(0, 0, 1040 * scale, h), Rect2(1030 * scale, 0, 744 * scale, h)])
	if index == 0:
		var name = "mining_atlas" if mining else "sprite_atlas"
		var tex = source(name)
		var rect = Rect2(95, 145, 510, 450) if mining else Rect2(0, 85, 460, 341)
		var ratio = Vector2(tex.get_width() / 1280.0, tex.get_height() / 1280.0)
		return hero_original(name, rect, ratio)
	var atlas = "heroes_atlas" if index < 4 else "heroes_late_atlas"
	var tex = source(atlas)
	return cropped(atlas, (index - 1 if index < 4 else index - 4) + (3 if mining else 0), regions_for_heroes(tex))

static func hero_original(name: String, rect: Rect2, ratio: Vector2) -> Texture2D:
	var key = "original_hero_" + name
	if not sprites.has(key):
		var a = AtlasTexture.new(); a.atlas = source(name); a.region = Rect2(rect.position * ratio, rect.size * ratio); a.filter_clip = true; sprites[key] = a
	return sprites[key]

static func regions_for_heroes(tex: Texture2D) -> Array:
	var cell = Vector2(tex.get_width() / 3.0, tex.get_height() / 2.0)
	var regions: Array = []
	for i in range(6): regions.append(Rect2(Vector2(i % 3, floori(i / 3.0)) * cell, cell))
	return regions

static func enemy(index: int) -> Texture2D:
	return cropped("enemies_atlas", index, Regions.ENEMIES)

static func skill(index: int) -> Texture2D:
	return cropped("sprite_atlas", index, Regions.SKILLS)

static func biome(region: int) -> Texture2D:
	if region == 0: return source("forest")
	var tex = source("biomes_atlas"); var index = region - 1
	var a = AtlasTexture.new(); a.atlas = tex; a.filter_clip = true
	var size = Vector2(tex.get_width() / 3.0, tex.get_height() / 3.0)
	a.region = Rect2(Vector2(index % 3, floori(index / 3.0)) * size, size)
	return a

static func foe_index(stage: int, region: int, boss: bool) -> int:
	if boss: return 8 if region == 0 else region
	if region == 0: return -1 if stage % 3 == 2 else 4 if stage % 3 == 0 else 0
	return region

static func foe_name(stage: int, region: int, boss: bool) -> String:
	if boss: return ["Король корней", "Павший король", "Кристальный титан", "Владыка пепла", "Пожиратель луны", "Древний левиафан", "Повелитель теней", "Дракон забвения"][region]
	if region == 0: return "Древесный страж" if stage % 3 == 2 else "Лесной дух" if stage % 3 == 0 else "Лесной гоблин"
	return ["", "Павший страж", "Кристальный голем", "Пепельный демон", "Лунный призрак", "Морской змей", "Теневой рыцарь", "Красный дракон"][region]

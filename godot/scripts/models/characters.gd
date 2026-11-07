extends RefCounted
## Библиотека 3D-моделей «Искры». Все модели строятся кодом из примитивов (см. mesh_kit.gd).
##
## Кости у всех моделей называются одинаково, чтобы их анимировал один код (rig.gd):
##   Hips → Torso → Head / ArmL / ArmR / Cape, Hips → LegL / LegR,
##   ArmR → Weapon / Pickaxe, ArmL → Offhand, у существ ещё Tail / WingL / WingR.

const Kit = preload("res://scripts/models/mesh_kit.gd")

static func c(hex: String) -> Color: return Color(hex)

# =====================================================================================
# Каталог
# =====================================================================================

const HERO_STYLES = ["melee", "cast", "bow", "melee", "spear", "cast", "great"]
const ALLY_STYLES = ["bite", "bow", "cast", "spear", "cast", "great", "cast", "bite"]
const ENEMY_STYLES = {-1: "slam", 0: "melee", 1: "great", 2: "slam", 3: "brute", 4: "cast", 5: "bite", 6: "great", 7: "bite", 8: "slam"}

static func hero(index: int, star_skin := false) -> Node3D:
	var p: Dictionary
	match index:
		0:
			p = {"skin": "#f2c49f", "hair": "#6b3a22", "hair_style": "spiky", "eyes": "#3a2416", "top": "#a3221f", "trim": "#e3a640",
				"legs": "#3b2a26", "boots": "#5a3420", "armor": "#7a5236", "cape": "#b3231e", "cape_len": 1.15,
				"style": "melee", "weapon": "sword", "metal": "#d9d2c7", "glow": "#ff8a2a", "blade_glow": 0.9}
			if star_skin:
				p.merge({"hair": "#f6e7a6", "top": "#f2efff", "trim": "#ffd56a", "armor": "#e9e2c8", "cape": "#3448b3",
					"legs": "#2b3570", "boots": "#e9e2c8", "glow": "#9fd8ff", "metal": "#eaf6ff", "stars": "#ffe78a"}, true)
		1:
			p = {"skin": "#f4d2bf", "hair": "#e9edf5", "hair_style": "braid", "eyes": "#3d7fd6", "top": "#2148a8", "trim": "#d9b45a",
				"legs": "#e9edf5", "boots": "#c9ccd4", "robe": "#2a55c4", "robe_len": 0.95, "cape": "#1d3f99", "cape_len": 0.95,
				"style": "cast", "weapon": "staff", "staff": "ice", "glow": "#7fd8ff", "wood": "#d9dfe8", "bulk": 0.92}
		2:
			p = {"skin": "#f1c3a0", "hair": "#c4472a", "hair_style": "long", "hat": "hood", "hood": "#2f7a35", "eyes": "#2f6a2a",
				"top": "#3d6b2f", "trim": "#a07a3a", "legs": "#5a3a22", "boots": "#6b4426", "cape": "#2f7a35", "cape_len": 1.0,
				"style": "bow", "weapon": "bow", "wood": "#7a4a24", "leaf": "#6fae3a", "bulk": 0.92}
		3:
			p = {"skin": "#f3cba7", "hair": "#f0c75a", "hair_style": "short", "eyes": "#2f5aa8", "top": "#f2ead8", "trim": "#d6a84a",
				"legs": "#2c3f7a", "boots": "#d8c48a", "armor": "#ead9a2", "cape": "#f3ecd6", "cape_len": 1.3,
				"style": "melee", "weapon": "sword", "metal": "#fff1c4", "glow": "#ffd36a", "blade_glow": 0.55, "bulk": 1.05}
		4:
			p = {"skin": "#f0cbb0", "hair": "#e9edf2", "hair_style": "long", "eyes": "#3b8ad8", "top": "#1f3f8f", "trim": "#d4b25a",
				"legs": "#eef0f4", "boots": "#c8ccd6", "armor": "#c8ccd6", "cape": "#22408f", "cape_len": 1.3,
				"style": "spear", "weapon": "spear", "metal": "#e6f2ff", "glow": "#7fc4ff", "wood": "#3a4a6a"}
		5:
			p = {"skin": "#efc9b6", "hair": "#4a2a6e", "hair_style": "long", "eyes": "#3ddc84", "top": "#2b1b3d", "trim": "#c9a24a",
				"legs": "#2b2233", "boots": "#2a1f2a", "robe": "#5b2f86", "robe_len": 1.0, "cape": "#3b2160", "cape_len": 1.1,
				"hat": "tiara", "style": "cast", "weapon": "staff", "staff": "soul", "glow": "#3dff9a", "wood": "#c9a24a", "bulk": 0.92}
		_:
			p = {"skin": "#f1c3a2", "hair": "#c62a22", "hair_style": "spiky", "eyes": "#ffb02e", "top": "#2a1416", "trim": "#d4a43a",
				"legs": "#1f1214", "boots": "#5a1715", "armor": "#a3221f", "cape": "#b01d1a", "cape_len": 1.35, "tattered": true,
				"style": "great", "weapon": "greatsword", "metal": "#ffd0a0", "glow": "#ff5a28", "blade_glow": 0.95, "bulk": 1.08, "spikes": true}
	p["pickaxe"] = true
	return humanoid("Hero%d" % index, p)

static func ally(index: int) -> Node3D:
	match index:
		0: return fox()
		1: return humanoid("Archer", {"skin": "#f3cfae", "hair": "#e7c26b", "hair_style": "long", "eyes": "#3f7a2a", "top": "#3d7a35", "trim": "#c9a24a",
				"legs": "#5a3a22", "boots": "#6b4426", "robe": "#4f8f3a", "robe_len": 0.55, "style": "bow", "weapon": "bow", "wood": "#8a5a2a", "leaf": "#9ad04a", "bulk": 0.9, "ears": "elf"})
		2: return humanoid("Mage", {"skin": "#f2c9a6", "hair": "#6b4426", "hair_style": "short", "eyes": "#2f5aa8", "top": "#2a4fa8", "trim": "#e0c070",
				"legs": "#2b2b3a", "boots": "#3a2a22", "robe": "#2a4fa8", "robe_len": 1.0, "cape": "#1f3a88", "cape_len": 1.1,
				"style": "cast", "weapon": "staff", "staff": "orb", "glow": "#6fb6ff", "wood": "#d9b45a"})
		3: return humanoid("DawnGuard", {"skin": "#f3cba7", "hair": "#f0d080", "hair_style": "long", "eyes": "#2f5aa8", "top": "#f4ecd8", "trim": "#d6a84a",
				"legs": "#2c3f7a", "boots": "#e8d39a", "armor": "#e8d39a", "cape": "#f4ecd8", "cape_len": 1.2,
				"style": "spear", "weapon": "spear", "shield": true, "metal": "#fff1c4", "glow": "#ffe08a", "wood": "#a07a3a"})
		4: return humanoid("MoonWitch", {"skin": "#f1d6c8", "hair": "#e6e2f4", "hair_style": "long", "eyes": "#9a6bff", "top": "#3a2466", "trim": "#d6b45a",
				"legs": "#241a33", "boots": "#2a2030", "robe": "#4a2d80", "robe_len": 1.0, "hat": "witch", "hood": "#3a2466",
				"style": "cast", "weapon": "staff", "staff": "moon", "glow": "#d2c0ff", "wood": "#c9a24a", "bulk": 0.9})
		5: return humanoid("AshKnight", {"skin": "#e8b896", "hair": "#4a2418", "hair_style": "spiky", "eyes": "#ff7a2a", "top": "#2a1412", "trim": "#ff5a28",
				"legs": "#1f1210", "boots": "#3a1a18", "armor": "#4a1d1a", "cape": "#8f1c16", "cape_len": 1.3, "tattered": true, "spikes": true,
				"style": "great", "weapon": "greatsword", "metal": "#ffb08a", "glow": "#ff4a1a", "blade_glow": 1.0, "trim_glow": 0.6})
		6: return humanoid("TimeKeeper", {"skin": "#f0cbb0", "hair": "#d8dde4", "hair_style": "short", "eyes": "#2fa8a8", "top": "#1f7a7f", "trim": "#d8b05a",
				"legs": "#2b2b2b", "boots": "#3a2a22", "robe": "#1f7a7f", "robe_len": 1.0, "cape": "#135a60", "cape_len": 1.15,
				"style": "cast", "weapon": "staff", "staff": "hourglass", "glow": "#ffd27a", "wood": "#d8b05a"})
		_: return dragon("SparkDragon", {"body": "#e0461e", "belly": "#ffb84a", "wing": "#ff7a2a", "horn": "#ffe0a0", "eyes": "#fff27a", "cute": true, "glow": 0.35})

static func enemy(index: int) -> Node3D:
	match index:
		-1: return golem("Treant", {"kind": "wood", "body": "#6b4a2a", "moss": "#6f8f2f", "glow": "#ffb030"})
		0: return humanoid("Goblin", {"skin": "#7da33a", "hair_style": "none", "ears": "goblin", "eyes": "#ffd23a", "eye_glow": 0.8, "top": "#6b4a2a",
				"trim": "#a0623a", "legs": "#4a3a2a", "boots": "#3a2a1e", "armor": "#5a4030", "cape": "#7a5a3a", "cape_len": 0.55, "tattered": true,
				"style": "melee", "weapon": "axe", "metal": "#b8a080", "wood": "#5a3a22", "bulk": 1.2, "hunch": 0.3, "head_r": 0.25, "nose": true})
		1: return humanoid("FallenKing", {"skin": "#d8cfb8", "skull": true, "hair_style": "none", "eyes": "#6fd0ff", "eye_glow": 1.0, "hat": "crown",
				"crown": "#b08a3a", "top": "#3a2e28", "trim": "#8a6a3a", "legs": "#2e2622", "boots": "#4a3e34", "armor": "#5a4a3e",
				"cape": "#6e1a1a", "cape_len": 1.45, "tattered": true, "spikes": true, "style": "great", "weapon": "greatsword",
				"metal": "#8c7a66", "glow": "#6fd0ff", "blade_glow": 0.15, "bulk": 1.15, "hunch": 0.12})
		2: return golem("CrystalGolem", {"kind": "crystal", "body": "#2f63c4", "light": "#8fd0ff", "glow": "#bfefff"})
		3: return humanoid("AshDemon", {"skin": "#3b1712", "hair_style": "none", "hat": "horns", "horn": "#2a0e0a", "eyes": "#ffcf5a", "eye_glow": 1.0,
				"top": "#3b1712", "trim": "#ff6a1e", "trim_glow": 0.9, "legs": "#2e100c", "boots": "#1e0806", "wings": "#c2361a",
				"style": "brute", "weapon": "claws", "glow": "#ff7a2a", "bulk": 1.25, "hunch": 0.18, "lava": true, "spikes": true})
		4: return ghost("MoonSpirit", {"robe": "#cfd9ff", "hair": "#f2f4ff", "glow": "#d6e2ff", "eyes": "#9ad8ff", "moon": true})
		5: return serpent("SeaSerpent", {"body": "#2a7fb8", "belly": "#efe2b0", "fin": "#5fd8ea", "eyes": "#ffe14a"})
		6: return humanoid("ShadowKnight", {"skin": "#1c1626", "hair_style": "none", "hat": "helm", "helm": "#221a30", "eyes": "#c07bff", "eye_glow": 1.0,
				"top": "#1c1626", "trim": "#9a4dff", "trim_glow": 0.8, "legs": "#15111c", "boots": "#221a30", "armor": "#2a2038",
				"cape": "#3a1f66", "cape_len": 1.45, "tattered": true, "spikes": true, "style": "great", "weapon": "greatsword",
				"metal": "#3a2a55", "glow": "#b06bff", "blade_glow": 0.9, "bulk": 1.15})
		7: return dragon("RedDragon", {"body": "#b8261a", "belly": "#f0a050", "wing": "#d2421e", "horn": "#3a1a12", "eyes": "#ffe14a", "glow": 0.15})
		_: return golem("RootKing", {"kind": "wood", "body": "#5a3c22", "moss": "#7f9a32", "glow": "#ffc040", "king": true})

# =====================================================================================
# Гуманоид
# =====================================================================================

## Позы рук в покое: [плечо, сгиб локтя] в радианах (0 — рука вниз, π/2 — вперёд).
const ARM_POSES = {
	"melee": {"R": [0.45, 0.6], "L": [0.15, 0.35]},
	"great": {"R": [0.55, 0.75], "L": [0.6, 0.85]},
	"cast": {"R": [0.3, 0.8], "L": [0.55, 0.55]},
	"bow": {"R": [1.1, 1.85], "L": [1.5, 0.0]},
	"spear": {"R": [0.45, 1.05], "L": [0.85, 0.5]},
	"brute": {"R": [0.35, 0.45], "L": [0.25, 0.35]},
}

static func humanoid(model_name: String, p: Dictionary) -> Node3D:
	var k := Kit.new()
	var bulk: float = p.get("bulk", 1.0)
	var style: String = p.get("style", "melee")
	var skin := c(p.get("skin", "#f2c49f")); var top := c(p.get("top", "#888888")); var trim := c(p.get("trim", "#d6a84a"))
	var legs := c(p.get("legs", "#333333")); var boots := c(p.get("boots", "#4a3020"))
	var armor_on := p.has("armor"); var armor := c(p.get("armor", "#999999"))
	var trim_glow: float = p.get("trim_glow", 0.0)
	var lava: bool = p.get("lava", false)
	var hr: float = p.get("head_r", 0.21)

	k.bone("Hips", "", Vector3(0, 1.25, 0))
	k.bone("Torso", "Hips", Vector3(0, 1.32, 0), Vector3(0, 0, -p.get("hunch", 0.0)))
	k.bone("Head", "Torso", Vector3(0, 2.08, 0))
	k.bone("ArmL", "Torso", Vector3(0, 1.96, -0.29 * bulk))
	k.bone("ArmR", "Torso", Vector3(0, 1.96, 0.29 * bulk))
	k.bone("LegL", "Hips", Vector3(0, 1.22, -0.12 * bulk))
	k.bone("LegR", "Hips", Vector3(0, 1.22, 0.12 * bulk))

	# --- ноги: передняя (дальняя от камеры) и задняя
	for side in [-1, 1]:
		var part := "LegL" if side < 0 else "LegR"
		var hip := Vector3(0, 1.22, 0.12 * bulk * side)
		var a1 := 0.28 if side < 0 else -0.24
		var a2 := 0.08 if side < 0 else -0.34
		var knee := hip + Vector3(sin(a1), -cos(a1), 0) * 0.55
		var ankle := knee + Vector3(sin(a2), -cos(a2), 0) * 0.52
		k.limb(part, hip, knee, 0.13 * bulk, 0.105 * bulk, legs)
		k.limb(part, knee, ankle, 0.105 * bulk, 0.088 * bulk, legs)
		k.tube(part, ankle + Vector3(0, 0.02, 0), knee.lerp(ankle, 0.35), 0.105 * bulk, 0.118 * bulk, boots)
		k.box(part, Vector3(ankle.x + 0.07, 0.065, ankle.z), Vector3(0.33, 0.14, 0.18) * Vector3(1, 1, bulk), boots)
		if armor_on:
			k.ball(part, knee + Vector3(0.05, 0, 0), 0.085 * bulk, armor, Vector3(0.8, 1, 1))
			k.tube(part, knee.lerp(ankle, 0.15), knee.lerp(ankle, 0.75), 0.095 * bulk, 0.08 * bulk, armor)

	# --- корпус
	var robe = p.get("robe", null)
	k.ball("Torso", Vector3(0, 1.3, 0), 0.19 * bulk, legs, Vector3(0.85, 0.75, 1.15))
	k.tube("Torso", Vector3(0, 1.28, 0), Vector3(0, 1.62, 0), 0.16 * bulk, 0.18 * bulk, top, 0.0, 10, Vector3(1, 1, 1.15))
	k.ball("Torso", Vector3(0.01, 1.8, 0), 0.24 * bulk, top, Vector3(0.82, 0.95, 1.22))
	k.tube("Torso", Vector3(0, 1.3, 0), Vector3(0, 1.36, 0), 0.185 * bulk, 0.185 * bulk, trim, trim_glow, 10, Vector3(1, 1, 1.15))
	k.tube("Torso", Vector3(0, 1.95, 0), Vector3(0, 2.12, 0), 0.075, 0.065, skin)
	k.ring("Torso", Vector3(0, 2.0, 0), 0.08, 0.16 * bulk, trim, Vector3.ZERO, trim_glow)
	k.box("Torso", Vector3(0.2 * bulk, 1.72, 0), Vector3(0.03, 0.42, 0.06), trim, Vector3(0, 0, -0.1), trim_glow)
	if lava:
		for i in 6:
			var y := 1.45 + i * 0.09
			k.box("Torso", Vector3(0.21 * bulk, y, sin(i * 2.1) * 0.12), Vector3(0.02, 0.025, 0.16), c("#ff7a2a"), Vector3(0, 0, 0.3 * (i % 2)), 1.0)
	if armor_on:
		k.ball("Torso", Vector3(0.06, 1.8, 0), 0.24 * bulk, armor, Vector3(0.75, 0.9, 1.15))
		for side in [-1, 1]:
			k.ball("Torso", Vector3(0, 1.98, 0.3 * bulk * side), 0.15 * bulk, armor, Vector3(1.05, 0.72, 1.0))
			k.ring("Torso", Vector3(0, 1.93, 0.3 * bulk * side), 0.12 * bulk, 0.16 * bulk, trim, Vector3(0, 0, 0), trim_glow)
			if p.get("spikes", false):
				k.cone("Torso", Vector3(0, 2.02, 0.32 * bulk * side), Vector3(-0.05, 2.32, 0.42 * bulk * side), 0.06, trim if trim_glow > 0 else armor)
	if robe != null:
		var rl: float = p.get("robe_len", 0.9)
		k.tube("Hips", Vector3(0, 1.42, 0), Vector3(0.04, 1.42 - rl, 0), 0.19 * bulk, 0.4 * bulk, c(robe), 0.0, 12, Vector3(1, 1, 1.12))
		k.tube("Hips", Vector3(0.04, 1.42 - rl + 0.02, 0), Vector3(0.04, 1.42 - rl - 0.03, 0), 0.41 * bulk, 0.42 * bulk, trim, trim_glow, 12, Vector3(1, 1, 1.12))
	if p.has("wings"):
		for side in [-1, 1]:
			var wing := "WingL" if side < 0 else "WingR"
			k.bone(wing, "Torso", Vector3(-0.15, 1.9, 0.12 * side))
			var root := Vector3(-0.15, 1.9, 0.12 * side)
			var span := Vector3(-0.55, 0.75, 0.8 * side).normalized()
			var pts := PackedVector2Array([Vector2(0, 0), Vector2(1.3, 0.15), Vector2(1.15, -0.25), Vector2(0.85, -0.2), Vector2(0.7, -0.6), Vector2(0.45, -0.35), Vector2(0.2, -0.75)])
			k.blade(wing, root, span, Vector3(-1, -0.2, 0), pts, 0.03, c(p.wings), 0.15)
			k.tube(wing, root, root + span * 1.3, 0.045, 0.02, c(p.get("horn", "#2a0e0a")))

	# --- голова
	var face := skin
	k.ball("Head", Vector3(0.0, 2.32, 0), hr, face, Vector3(1, 1.05, 0.95), Vector3.ZERO, 0.0, 12)
	if p.get("skull", false):
		k.ball("Head", Vector3(0.12, 2.2, 0), hr * 0.6, face, Vector3(0.9, 0.6, 0.9))
		for side in [-1, 1]:
			k.ball("Head", Vector3(hr * 0.78, 2.34, 0.075 * side), 0.055, c("#1a1418"), Vector3(0.6, 1, 1))
	var eye_glow: float = p.get("eye_glow", 0.0)
	for side in [-1, 1]:
		k.ball("Head", Vector3(hr * 0.86, 2.33, 0.085 * side), 0.048, c(p.get("eyes", "#2a1a12")), Vector3(0.5, 1.35, 0.85), Vector3.ZERO, eye_glow, 8)
		if eye_glow == 0.0:
			k.ball("Head", Vector3(hr * 0.93, 2.36, 0.095 * side), 0.014, Color.WHITE, Vector3.ONE, Vector3.ZERO, 1.0, 6)
	if p.get("nose", false):
		k.cone("Head", Vector3(hr * 0.85, 2.29, 0), Vector3(hr * 1.45, 2.24, 0), 0.05, skin)
		k.box("Head", Vector3(hr * 0.75, 2.17, 0), Vector3(0.12, 0.05, 0.2), c("#2a1a12"))
		for side in [-1, 1]:
			k.cone("Head", Vector3(hr * 0.9, 2.17, 0.06 * side), Vector3(hr * 1.1, 2.27, 0.08 * side), 0.022, c("#f2ead0"))
	match p.get("ears", ""):
		"goblin":
			for side in [-1, 1]:
				var ear := PackedVector2Array([Vector2(0, -0.07), Vector2(0.42, 0.12), Vector2(0, 0.08)])
				k.blade("Head", Vector3(-0.02, 2.36, hr * 0.85 * side), Vector3(-0.3, 0.25, side).normalized(), Vector3(0, 1, 0), ear, 0.03, skin)
		"elf":
			for side in [-1, 1]:
				var ear := PackedVector2Array([Vector2(0, -0.04), Vector2(0.2, 0.08), Vector2(0, 0.05)])
				k.blade("Head", Vector3(-0.02, 2.34, hr * 0.9 * side), Vector3(-0.4, 0.4, side).normalized(), Vector3(0, 1, 0), ear, 0.02, skin)
	_hair(k, p, hr)
	_hat(k, p, hr)

	# --- руки
	var pose: Dictionary = ARM_POSES.get(style, ARM_POSES["melee"])
	var hands := {}
	for side in [-1, 1]:
		var part := "ArmL" if side < 0 else "ArmR"
		var ang: Array = pose["L" if side < 0 else "R"]
		var shoulder := Vector3(0, 1.96, 0.29 * bulk * side)
		var d1 := Vector3(sin(ang[0]), -cos(ang[0]), 0)
		var elbow := shoulder + d1 * 0.36 * maxf(1.0, bulk * 0.95) + Vector3(0, 0, 0.03 * side)
		var d2 := Vector3(sin(ang[0] + ang[1]), -cos(ang[0] + ang[1]), 0)
		var wrist := elbow + d2 * 0.32 * maxf(1.0, bulk * 0.95)
		var sleeve := top if not armor_on else armor
		k.limb(part, shoulder, elbow, 0.098 * bulk, 0.084 * bulk, sleeve)
		k.limb(part, elbow, wrist, 0.082 * bulk, 0.07 * bulk, skin if robe == null and not armor_on else top)
		k.tube(part, elbow.lerp(wrist, 0.55), wrist, 0.087 * bulk, 0.092 * bulk, trim, trim_glow)
		var hand := wrist + d2 * 0.06
		k.ball(part, hand, 0.078 * bulk, skin, Vector3.ONE, Vector3.ZERO, 0.0, 8)
		if p.get("weapon", "") == "claws":
			for f in 3:
				var base := hand + Vector3(0, 0, (f - 1) * 0.04)
				k.cone(part, base, base + d2.rotated(Vector3(0, 0, 1), 0.4) * 0.22 + Vector3(0, 0, (f - 1) * 0.03), 0.022, c("#f2d8a0"), 0.2)
		hands[side] = {"pos": hand, "dir": d2, "angle": ang[0] + ang[1]}

	# --- плащ
	if p.has("cape"):
		k.bone("Cape", "Torso", Vector3(-0.17, 2.0, 0), Vector3(-0.28, 0, -0.3))
		var cl: float = p.get("cape_len", 1.0)
		var w := 0.3 * bulk
		var pts := PackedVector2Array([Vector2(-w, 0), Vector2(w, 0)])
		var teeth := 6 if p.get("tattered", false) else 1
		for i in teeth + 1:
			pts.append(Vector2(lerpf(w * 2.3, -w * 2.3, float(i) / teeth), -cl + (0.2 if i % 2 == 1 else 0.0)))
		k.blade("Cape", Vector3(-0.19, 2.0, 0), Vector3(0, 0, 1), Vector3(0, 1, 0), pts, 0.035, c(p.cape))
		k.tube("Cape", Vector3(-0.17, 2.0, -w), Vector3(-0.17, 2.0, w), 0.045, 0.045, trim, trim_glow)
		if p.has("stars"):
			for i in 7:
				k.ball("Cape", Vector3(-0.23, 1.9 - randf_range(0.1, cl * 0.9), randf_range(-w, w) * 1.2), 0.03, c(p.stars), Vector3.ONE, Vector3.ZERO, 1.0, 6)

	# --- оружие
	_weapon(k, p, hands)
	if p.get("pickaxe", false): _pickaxe(k, hands[1])

	var model := k.build(model_name)
	model.set_meta("style", style)
	if model.get_meta("bones").has("Pickaxe"): model.get_meta("bones")["Pickaxe"].visible = false
	return model

static func _hair(k: Kit, p: Dictionary, hr: float) -> void:
	var style: String = p.get("hair_style", "short")
	if style == "none": return
	var hair := c(p.get("hair", "#5a3a22"))
	k.ball("Head", Vector3(-0.03, 2.39, 0), hr * 1.07, hair, Vector3(1, 0.88, 1.02))
	k.ball("Head", Vector3(0.1, 2.46, 0.02), hr * 0.6, hair, Vector3(0.7, 0.55, 1.45), Vector3(0, 0, -0.3))
	match style:
		"spiky":
			for i in 7:
				var a := -0.9 + i * 0.3
				var base := Vector3(-0.02 + cos(a) * 0.05, 2.45, sin(a) * 0.12)
				k.cone("Head", base, base + Vector3(-0.22 - 0.05 * (i % 2), 0.16 + 0.06 * (i % 3), sin(a) * 0.12), 0.08, hair)
			k.cone("Head", Vector3(0.12, 2.5, -0.05), Vector3(0.3, 2.42, -0.08), 0.06, hair)
		"long":
			var pts := []
			for i in 9: pts.append(Vector3(-0.12 - i * 0.012, 2.36 - i * 0.09, 0))
			k.chain("Head", pts, hr * 0.92, hr * 0.62, hair, 0.0, Vector3(0.55, 1, 1.15))
			for side in [-1, 1]:
				k.chain("Head", [Vector3(0.05, 2.3, 0.18 * side), Vector3(0.06, 2.05, 0.2 * side), Vector3(0.04, 1.85, 0.18 * side)], 0.07, 0.04, hair)
		"braid":
			var pts := []
			for i in 8: pts.append(Vector3(0.0 + i * 0.012, 2.28 - i * 0.085, 0.2 + i * 0.012))
			k.chain("Head", pts, 0.075, 0.05, hair)
			k.ball("Head", Vector3(-0.12, 2.25, 0), hr * 0.85, hair, Vector3(0.7, 1, 1.05))
		"ponytail":
			k.chain("Head", [Vector3(-0.2, 2.42, 0), Vector3(-0.32, 2.3, 0), Vector3(-0.36, 2.05, 0)], 0.08, 0.05, hair)
		"short":
			k.ball("Head", Vector3(-0.08, 2.3, 0), hr * 0.95, hair, Vector3(0.8, 0.9, 1.04))

static func _hat(k: Kit, p: Dictionary, hr: float) -> void:
	match p.get("hat", ""):
		"hood":
			var hood := c(p.get("hood", "#2f7a35"))
			k.ball("Head", Vector3(-0.04, 2.37, 0), hr * 1.22, hood, Vector3(1.05, 1, 1.05))
			k.cone("Head", Vector3(-0.15, 2.5, 0), Vector3(-0.42, 2.35, 0), 0.14, hood)
			k.box("Head", Vector3(hr * 0.98, 2.33, 0), Vector3(0.05, 0.3, 0.3), c(p.get("skin", "#f1c3a0")))
			for side in [-1, 1]:
				k.ball("Head", Vector3(hr * 1.05, 2.33, 0.078 * side), 0.034, c(p.get("eyes", "#2a1a12")), Vector3(0.5, 1.2, 0.9), Vector3.ZERO, 0.0, 8)
		"witch":
			var hat := c(p.get("hood", "#3a2466"))
			k.tube("Head", Vector3(0, 2.5, 0), Vector3(0, 2.53, 0), 0.48, 0.46, hat, 0.0, 14)
			k.chain("Head", [Vector3(0, 2.52, 0), Vector3(-0.04, 2.75, 0), Vector3(-0.16, 2.95, 0), Vector3(-0.34, 3.0, 0)], 0.22, 0.03, hat)
			k.ring("Head", Vector3(0, 2.57, 0), 0.2, 0.25, c(p.get("trim", "#d6b45a")))
			k.ball("Head", Vector3(0.18, 2.62, 0.08), 0.05, c(p.get("glow", "#d2c0ff")), Vector3.ONE, Vector3.ZERO, 1.0, 8)
		"crown":
			var gold := c(p.get("crown", "#c9a24a"))
			k.tube("Head", Vector3(0, 2.46, 0), Vector3(0, 2.56, 0), hr * 0.95, hr * 1.0, gold)
			for i in 7:
				var a := i * TAU / 7.0
				var base := Vector3(cos(a) * hr * 0.95, 2.55, sin(a) * hr * 0.95)
				k.cone("Head", base, base + Vector3(cos(a) * 0.03, 0.2 + 0.05 * (i % 2), sin(a) * 0.03), 0.04, gold)
		"tiara":
			var gold := c(p.get("trim", "#c9a24a"))
			k.ring("Head", Vector3(0, 2.47, 0), hr * 0.92, hr * 1.02, gold, Vector3(0, 0, 0.25))
			k.ball("Head", Vector3(hr * 0.98, 2.52, 0), 0.04, c(p.get("glow", "#3dff9a")), Vector3.ONE, Vector3.ZERO, 1.0, 8)
		"helm":
			var helm := c(p.get("helm", "#555566"))
			k.ball("Head", Vector3(0, 2.34, 0), hr * 1.18, helm, Vector3(1.05, 1.1, 1.0))
			k.box("Head", Vector3(hr * 1.1, 2.33, 0), Vector3(0.06, 0.05, 0.26), c("#08060c"))
			for side in [-1, 1]:
				k.ball("Head", Vector3(hr * 1.14, 2.33, 0.07 * side), 0.03, c(p.get("eyes", "#c07bff")), Vector3.ONE, Vector3.ZERO, 1.0, 6)
				k.chain("Head", [Vector3(-0.02, 2.5, 0.16 * side), Vector3(-0.1, 2.72, 0.26 * side), Vector3(-0.3, 2.86, 0.28 * side)], 0.06, 0.012, helm)
			k.cone("Head", Vector3(-0.05, 2.55, 0), Vector3(-0.25, 2.75, 0), 0.05, c(p.get("trim", "#9a4dff")), 0.8)
		"horns":
			var horn := c(p.get("horn", "#2a0e0a"))
			for side in [-1, 1]:
				k.chain("Head", [Vector3(0.0, 2.48, 0.12 * side), Vector3(-0.08, 2.68, 0.2 * side), Vector3(-0.25, 2.8, 0.2 * side), Vector3(-0.42, 2.74, 0.16 * side)], 0.065, 0.012, horn)
			k.ball("Head", Vector3(-0.03, 2.4, 0), hr * 1.02, c(p.get("skin", "#3b1712")), Vector3(1, 0.85, 1))
			for i in 4:
				k.cone("Head", Vector3(-0.08, 2.4 - i * 0.05, (i - 1.5) * 0.08), Vector3(-0.3, 2.55 - i * 0.12, (i - 1.5) * 0.12), 0.05, c("#ff6a1e"), 1.0)

static func _weapon(k: Kit, p: Dictionary, hands: Dictionary) -> void:
	var metal := c(p.get("metal", "#cfd4dc")); var glow := c(p.get("glow", "#ffffff")); var wood := c(p.get("wood", "#6b4426"))
	var trim := c(p.get("trim", "#d6a84a"))
	var r: Dictionary = hands[1]
	var h: Vector3 = r.pos
	match p.get("weapon", ""):
		"sword", "greatsword":
			var great: bool = p.weapon == "greatsword"
			k.bone("Weapon", "ArmR", h)
			var dir := Vector3(0.78, 0.62, 0).normalized()
			var side := Vector3(-dir.y, dir.x, 0)
			var length := 1.45 if great else 1.05
			var w := 0.11 if great else 0.075
			k.tube("Weapon", h - dir * 0.16, h + dir * 0.1, 0.032, 0.032, c("#3a2418"))
			k.ball("Weapon", h - dir * 0.18, 0.045, trim)
			k.tube("Weapon", h + dir * 0.1 - Vector3(0, 0, 0.15), h + dir * 0.1 + Vector3(0, 0, 0.15), 0.035, 0.035, trim)
			var pts := PackedVector2Array([Vector2(0, -w), Vector2(length * 0.82, -w * 0.9), Vector2(length, 0), Vector2(length * 0.82, w * 0.9), Vector2(0, w)])
			var bg: float = p.get("blade_glow", 0.0)
			k.blade("Weapon", h + dir * 0.12, dir, Vector3(0, 0, 1), pts, 0.035, metal, bg * 0.35)
			if bg > 0.1:
				var core := PackedVector2Array([Vector2(0.05, -w * 0.35), Vector2(length * 0.8, -w * 0.3), Vector2(length * 0.95, 0), Vector2(length * 0.8, w * 0.3), Vector2(0.05, w * 0.35)])
				k.blade("Weapon", h + dir * 0.12, dir, Vector3(0, 0, 1), core, 0.05, glow, bg)
		"axe":
			k.bone("Weapon", "ArmR", h)
			var dir := Vector3(0.55, 0.84, 0).normalized()
			k.tube("Weapon", h - dir * 0.2, h + dir * 0.85, 0.035, 0.03, wood)
			var head := PackedVector2Array([Vector2(-0.08, 0), Vector2(0.18, -0.06), Vector2(0.36, -0.26), Vector2(0.42, 0.1), Vector2(0.3, 0.32), Vector2(0.14, 0.12), Vector2(-0.08, 0.12)])
			k.blade("Weapon", h + dir * 0.62, Vector3(dir.y, -dir.x, 0), dir, head, 0.04, metal)
		"staff":
			k.bone("Weapon", "ArmR", h)
			var dir := Vector3(0.12, 1, 0).normalized()
			var tip := h + dir * 1.0
			k.tube("Weapon", h - dir * 0.85, tip, 0.03, 0.035, wood)
			k.ring("Weapon", h + dir * 0.2, 0.03, 0.05, trim)
			match p.get("staff", "orb"):
				"ice":
					k.ball("Weapon", tip + dir * 0.12, 0.1, glow, Vector3.ONE, Vector3.ZERO, 1.0)
					for i in 7:
						var a := i * TAU / 7.0
						var out := Vector3(cos(a) * 0.9, 0.6 + 0.4 * sin(a * 2), sin(a)).normalized()
						k.cone("Weapon", tip + dir * 0.12, tip + dir * 0.12 + out * (0.22 + 0.1 * (i % 2)), 0.045, c("#c9f0ff"), 0.6, 4)
				"soul":
					k.ring("Weapon", tip + dir * 0.15, 0.12, 0.15, trim, Vector3(PI / 2, 0, 0.3))
					k.ball("Weapon", tip + dir * 0.15, 0.1, glow, Vector3.ONE, Vector3.ZERO, 1.0)
					for i in 3:
						k.cone("Weapon", tip, tip + Vector3(cos(i * 2.1) * 0.12, 0.3, sin(i * 2.1) * 0.12), 0.03, trim)
				"moon":
					var moon := PackedVector2Array()
					for i in 13:
						var a := lerpf(-2.3, 2.3, i / 12.0); moon.append(Vector2(cos(a), sin(a)) * 0.24)
					for i in range(12, -1, -1):
						var a := lerpf(-1.9, 1.9, i / 12.0); moon.append(Vector2(cos(a) * 0.19 + 0.07, sin(a) * 0.19))
					k.blade("Weapon", tip + dir * 0.2, Vector3(0, 1, 0), Vector3(0, 0, 1), moon, 0.04, c("#f4e6a8"), 0.7)
					k.ball("Weapon", tip + dir * 0.2, 0.07, glow, Vector3.ONE, Vector3.ZERO, 1.0)
				"hourglass":
					k.cone("Weapon", tip + dir * 0.18, tip, 0.12, c("#fff2c8"), 0.6)
					k.cone("Weapon", tip + dir * 0.18, tip + dir * 0.36, 0.12, c("#fff2c8"), 0.6)
					k.ring("Weapon", tip + dir * 0.18, 0.2, 0.24, trim, Vector3(0, 0, PI / 2))
					k.ring("Weapon", tip + dir * 0.18, 0.2, 0.24, trim, Vector3(PI / 2, 0, 0))
				_:
					k.ball("Weapon", tip + dir * 0.12, 0.11, glow, Vector3.ONE, Vector3.ZERO, 1.0)
					for i in 4:
						var a := i * TAU / 4.0
						k.chain("Weapon", [tip, tip + Vector3(cos(a) * 0.1, 0.1, sin(a) * 0.1), tip + Vector3(cos(a) * 0.06, 0.22, sin(a) * 0.06)], 0.025, 0.012, trim)
		"spear":
			k.bone("Weapon", "ArmR", h)
			var dir := Vector3(1, 0.22, 0).normalized()
			k.tube("Weapon", h - dir * 0.95, h + dir * 1.25, 0.028, 0.028, wood)
			var head := PackedVector2Array([Vector2(0, -0.07), Vector2(0.12, -0.1), Vector2(0.45, 0), Vector2(0.12, 0.1), Vector2(0, 0.07)])
			k.blade("Weapon", h + dir * 1.22, dir, Vector3(0, 0, 1), head, 0.04, metal, 0.3)
			k.blade("Weapon", h + dir * 1.25, dir, Vector3(0, 0, 1), PackedVector2Array([Vector2(0, -0.03), Vector2(0.36, 0), Vector2(0, 0.03)]), 0.05, glow, 1.0)
			k.ring("Weapon", h + dir * 1.2, 0.03, 0.06, trim, Vector3(0, 0, PI / 2 - 0.22))
		"bow":
			var l: Dictionary = hands[-1]
			k.bone("Offhand", "ArmL", l.pos)
			var pts := []
			for i in 11:
				var t := lerpf(-1, 1, i / 10.0)
				pts.append(l.pos + Vector3(-0.28 * t * t + 0.04, t * 0.78, 0))
			for i in range(1, pts.size()):
				k.tube("Offhand", pts[i - 1], pts[i], 0.03, 0.03, wood)
			k.tube("Offhand", pts[0], pts[-1], 0.006, 0.006, c("#f2ead0"))
			for i in [1, 3, 7, 9]:
				k.ball("Offhand", pts[i] + Vector3(0.03, 0, 0.02), 0.04, c(p.get("leaf", "#6fae3a")), Vector3(1.4, 0.6, 0.8), Vector3(0, 0, 0.6))
			k.bone("Weapon", "ArmR", h)
			k.tube("Weapon", h, h + Vector3(0.95, 0.02, 0), 0.012, 0.012, c("#e8d8b0"))
			k.cone("Weapon", h + Vector3(0.95, 0.02, 0), h + Vector3(1.07, 0.02, 0), 0.03, metal)
	if p.get("shield", false):
		var l: Dictionary = hands[-1]
		if not k.has_bone("Offhand"): k.bone("Offhand", "ArmL", l.pos)
		var kite := PackedVector2Array([Vector2(-0.28, 0.32), Vector2(0.28, 0.32), Vector2(0.3, -0.05), Vector2(0, -0.5), Vector2(-0.3, -0.05)])
		k.blade("Offhand", l.pos + Vector3(0.12, 0, 0), Vector3(0, 0, 1), Vector3(0, 1, 0), kite, 0.06, c(p.get("armor", "#e8d39a")))
		k.ball("Offhand", l.pos + Vector3(0.17, 0.05, 0), 0.09, c(p.get("glow", "#ffe08a")), Vector3(0.4, 1, 1), Vector3.ZERO, 1.0)
		k.blade("Offhand", l.pos + Vector3(0.16, 0, 0), Vector3(0, 0, 1), Vector3(0, 1, 0), PackedVector2Array([Vector2(-0.04, 0.28), Vector2(0.04, 0.28), Vector2(0.04, -0.4), Vector2(-0.04, -0.4)]), 0.03, trim)

static func _pickaxe(k: Kit, hand: Dictionary) -> void:
	var h: Vector3 = hand.pos
	k.bone("Pickaxe", "ArmR", h)
	var dir := Vector3(0.45, 0.89, 0).normalized()
	k.tube("Pickaxe", h - dir * 0.15, h + dir * 1.0, 0.032, 0.03, c("#8a5a2a"))
	var top := h + dir * 0.98
	var across := Vector3(dir.y, -dir.x, 0)
	k.chain("Pickaxe", [top - across * 0.45 - dir * 0.12, top - across * 0.2, top, top + across * 0.2, top + across * 0.45 - dir * 0.12], 0.035, 0.035, c("#8c939e"))
	k.cone("Pickaxe", top + across * 0.43 - dir * 0.11, top + across * 0.55 - dir * 0.22, 0.035, c("#c9ced6"))
	k.cone("Pickaxe", top - across * 0.43 - dir * 0.11, top - across * 0.55 - dir * 0.22, 0.035, c("#c9ced6"))

# =====================================================================================
# Существа
# =====================================================================================

static func fox() -> Node3D:
	var k := Kit.new()
	var fur := c("#f07a2a"); var white := c("#fff1dc"); var dark := c("#3a2418")
	k.bone("Hips", "", Vector3(0, 0.62, 0))
	k.bone("Torso", "Hips", Vector3(0, 0.62, 0))
	k.bone("Head", "Torso", Vector3(0.38, 0.82, 0))
	k.bone("Tail", "Torso", Vector3(-0.38, 0.72, 0))
	k.bone("LegL", "Hips", Vector3(0, 0.55, 0)); k.bone("LegR", "Hips", Vector3(0, 0.55, 0))
	k.ball("Torso", Vector3(0, 0.62, 0), 0.3, fur, Vector3(1.4, 0.82, 0.78))
	k.ball("Torso", Vector3(0.24, 0.6, 0), 0.2, white, Vector3(0.8, 1, 0.9))
	k.ball("Head", Vector3(0.48, 0.95, 0), 0.22, fur, Vector3(1, 0.92, 1))
	k.cone("Head", Vector3(0.6, 0.9, 0), Vector3(0.88, 0.86, 0), 0.11, white)
	k.ball("Head", Vector3(0.88, 0.87, 0), 0.03, dark)
	for side in [-1, 1]:
		k.cone("Head", Vector3(0.42, 1.08, 0.1 * side), Vector3(0.38, 1.36, 0.14 * side), 0.08, fur, 0.0, 4)
		k.ball("Head", Vector3(0.66, 1.0, 0.085 * side), 0.03, dark, Vector3(0.5, 0.9, 0.9))
		k.ball("Head", Vector3(0.52, 0.86, 0.15 * side), 0.09, white, Vector3(1, 0.7, 0.7))
	for leg in [[0.25, "LegL", -1], [0.25, "LegR", 1], [-0.25, "LegL", -1], [-0.25, "LegR", 1]]:
		var top := Vector3(leg[0], 0.5, 0.12 * leg[2])
		k.limb(leg[1], top, top + Vector3(0.02, -0.42, 0), 0.06, 0.045, fur)
		k.ball(leg[1], top + Vector3(0.05, -0.45, 0), 0.05, dark, Vector3(1.4, 0.8, 1))
	k.chain("Tail", [Vector3(-0.38, 0.72, 0), Vector3(-0.66, 0.8, 0), Vector3(-0.85, 1.05, 0), Vector3(-0.85, 1.35, 0)], 0.13, 0.17, fur)
	k.ball("Tail", Vector3(-0.83, 1.45, 0), 0.14, c("#ffd25a"), Vector3.ONE, Vector3.ZERO, 1.0)
	k.cone("Tail", Vector3(-0.83, 1.5, 0), Vector3(-0.75, 1.75, 0), 0.1, c("#ff9a2a"), 1.0)
	var m := k.build("Fox"); m.set_meta("style", "bite"); return m

static func dragon(model_name: String, p: Dictionary) -> Node3D:
	var k := Kit.new()
	var body := c(p.body); var belly := c(p.belly); var wing := c(p.wing); var horn := c(p.horn)
	var g: float = p.get("glow", 0.0)
	var cute: bool = p.get("cute", false)
	var hs := 1.35 if cute else 1.0
	k.bone("Hips", "", Vector3(0, 1.2, 0))
	k.bone("Torso", "Hips", Vector3(0, 1.25, 0))
	k.bone("Head", "Torso", Vector3(0.75, 1.6, 0))
	k.bone("Tail", "Torso", Vector3(-0.75, 1.25, 0))
	k.bone("WingL", "Torso", Vector3(0.05, 1.75, -0.3)); k.bone("WingR", "Torso", Vector3(0.05, 1.75, 0.3))
	k.bone("ArmL", "Torso", Vector3(0.6, 1.2, -0.32)); k.bone("ArmR", "Torso", Vector3(0.6, 1.2, 0.32))
	k.bone("LegL", "Hips", Vector3(-0.4, 1.2, -0.36)); k.bone("LegR", "Hips", Vector3(-0.4, 1.2, 0.36))
	k.ball("Torso", Vector3(0, 1.3, 0), 0.6, body, Vector3(1.45, 0.9, 0.95))
	k.ball("Torso", Vector3(0.55, 1.42, 0), 0.48, body, Vector3(1, 1, 0.95))
	k.ball("Torso", Vector3(0.25, 1.1, 0), 0.5, belly, Vector3(1.3, 0.7, 0.8), Vector3.ZERO, g)
	for i in 6:
		k.cone("Torso", Vector3(0.6 - i * 0.25, 1.78 - absf(i - 2) * 0.03, 0), Vector3(0.5 - i * 0.25, 2.0, 0), 0.07, horn)
	# шея и голова
	var neck := [Vector3(0.75, 1.6, 0), Vector3(0.98, 1.95, 0), Vector3(1.12, 2.25, 0)]
	k.chain("Head", neck, 0.28, 0.2, body)
	k.chain("Head", [Vector3(0.82, 1.55, 0.05), Vector3(1.05, 1.9, 0.08), Vector3(1.18, 2.15, 0.07)], 0.2, 0.13, belly, g)
	var hc := Vector3(1.25, 2.38, 0)
	k.ball("Head", hc, 0.27 * hs, body, Vector3(1.3, 0.85, 0.9))
	k.tube("Head", hc + Vector3(0.15, -0.04, 0), hc + Vector3(0.62 * (0.8 if cute else 1.0), -0.1, 0), 0.17 * hs, 0.11 * hs, body, 0.0, 8, Vector3(1, 1, 1))
	k.blade("Head", hc + Vector3(0.12, -0.16, 0), Vector3(1, -0.25, 0), Vector3(0, 1, 0), PackedVector2Array([Vector2(0, -0.04), Vector2(0.5 * (0.8 if cute else 1.0), -0.02), Vector2(0.5, 0.05), Vector2(0, 0.05)]), 0.22 * hs, belly)
	for side in [-1, 1]:
		k.ball("Head", hc + Vector3(0.2 * hs, 0.08, 0.15 * side * hs), 0.045 * hs, c(p.eyes), Vector3(0.7, 0.8, 1), Vector3.ZERO, 1.0, 8)
		k.chain("Head", [hc + Vector3(-0.1, 0.12, 0.12 * side), hc + Vector3(-0.35, 0.3, 0.18 * side), hc + Vector3(-0.6, 0.32, 0.18 * side)], 0.07 * hs, 0.012, horn)
		if not cute:
			for t in 4:
				k.cone("Head", hc + Vector3(0.3 + t * 0.09, -0.12, 0.08 * side), hc + Vector3(0.32 + t * 0.09, -0.22, 0.08 * side), 0.022, c("#f2ead0"), 0.0, 4)
	# хвост
	var tail := [Vector3(-0.75, 1.25, 0), Vector3(-1.2, 1.0, 0), Vector3(-1.65, 0.7, 0.05), Vector3(-2.05, 0.6, 0.1), Vector3(-2.4, 0.75, 0.1)]
	k.chain("Tail", tail, 0.32, 0.07, body)
	k.blade("Tail", Vector3(-2.4, 0.75, 0.1), Vector3(-1, 0.3, 0), Vector3(0, 1, 0), PackedVector2Array([Vector2(0, -0.12), Vector2(0.35, 0), Vector2(0, 0.12)]), 0.06, horn if not cute else c("#ffd25a"), 1.0 if cute else 0.0)
	# лапы
	for leg in [["ArmL", 0.6, -1], ["ArmR", 0.6, 1], ["LegL", -0.4, -1], ["LegR", -0.4, 1]]:
		var top := Vector3(leg[1], 1.2, 0.36 * leg[2])
		var knee := top + Vector3(0.12 if leg[1] > 0 else -0.08, -0.55, 0)
		var foot := Vector3(knee.x - 0.05, 0.12, knee.z)
		k.limb(leg[0], top, knee, 0.2, 0.13, body)
		k.limb(leg[0], knee, foot, 0.13, 0.1, body)
		k.ball(leg[0], foot + Vector3(0.1, -0.03, 0), 0.13, body, Vector3(1.5, 0.6, 1.1))
		for f in 3:
			k.cone(leg[0], foot + Vector3(0.2, -0.04, (f - 1) * 0.07), foot + Vector3(0.36, -0.1, (f - 1) * 0.09), 0.03, horn, 0.0, 4)
	# крылья
	for side in [-1, 1]:
		var part := "WingL" if side < 0 else "WingR"
		var root := Vector3(0.05, 1.75, 0.3 * side)
		var span := Vector3(-0.45, 0.7, 0.85 * side).normalized()
		var mem := PackedVector2Array([Vector2(0, 0.05), Vector2(1.9, 0.25), Vector2(1.75, -0.2), Vector2(1.35, -0.25), Vector2(1.2, -0.75), Vector2(0.8, -0.5), Vector2(0.55, -1.1), Vector2(0.25, -0.65), Vector2(-0.2, -0.8)])
		k.blade(part, root, span, Vector3(-1, -0.3, 0), mem, 0.03, wing, g)
		k.tube(part, root, root + span * 1.95, 0.08, 0.03, body)
		k.cone(part, root + span * 1.9, root + span * 2.15, 0.04, horn)
	var m := k.build(model_name); m.set_meta("style", "bite"); return m

static func golem(model_name: String, p: Dictionary) -> Node3D:
	var k := Kit.new()
	var crystal: bool = p.kind == "crystal"
	var body := c(p.body); var glow := c(p.glow)
	var accent := c(p.get("light", p.get("moss", "#6f8f2f")))
	var king: bool = p.get("king", false)
	k.bone("Hips", "", Vector3(0, 1.15, 0))
	k.bone("Torso", "Hips", Vector3(0, 1.25, 0), Vector3(0, 0, -0.15))
	k.bone("Head", "Torso", Vector3(0.15, 2.35, 0))
	k.bone("ArmL", "Torso", Vector3(0.05, 2.1, -0.6)); k.bone("ArmR", "Torso", Vector3(0.05, 2.1, 0.6))
	k.bone("LegL", "Hips", Vector3(0, 1.1, -0.32)); k.bone("LegR", "Hips", Vector3(0, 1.1, 0.32))
	var dt := 5 if crystal else 10
	k.ball("Torso", Vector3(0, 1.25, 0), 0.42, body, Vector3(1, 0.8, 1.15), Vector3.ZERO, 0.0, dt)
	k.ball("Torso", Vector3(0.05, 1.85, 0), 0.58, body, Vector3(0.9, 1, 1.25), Vector3(0.3, 0.2, 0) if crystal else Vector3.ZERO, 0.0, dt)
	k.ball("Torso", Vector3(0.38, 1.85, 0), 0.14, glow, Vector3(0.5, 1, 1), Vector3.ZERO, 1.0)
	k.ball("Head", Vector3(0.22, 2.42, 0), 0.24, body, Vector3(1.1, 0.9, 1), Vector3.ZERO, 0.0, dt)
	for side in [-1, 1]:
		k.ball("Head", Vector3(0.44, 2.44, 0.09 * side), 0.045, glow, Vector3(0.5, 0.9, 1.2), Vector3.ZERO, 1.0, 8)
	for side in [-1, 1]:
		var arm := "ArmL" if side < 0 else "ArmR"
		var sh := Vector3(0.05, 2.1, 0.6 * side)
		var el := sh + Vector3(0.12, -0.6, 0.08 * side)
		var hand := el + Vector3(0.18, -0.6, 0)
		k.ball(arm, sh, 0.3, body, Vector3(1, 0.9, 1), Vector3(0.4, 0, 0) if crystal else Vector3.ZERO, 0.0, dt)
		k.limb(arm, sh, el, 0.2, 0.2, body)
		k.limb(arm, el, hand, 0.22, 0.26, body)
		k.ball(arm, hand + Vector3(0.05, -0.12, 0), 0.3, body, Vector3(1.05, 0.9, 1), Vector3(0.5, 0.3, 0) if crystal else Vector3.ZERO, 0.2 if crystal else 0.0, dt)
		var leg := "LegL" if side < 0 else "LegR"
		var hip := Vector3(0, 1.1, 0.32 * side)
		k.limb(leg, hip, Vector3(0.05, 0.55, 0.34 * side), 0.24, 0.22, body)
		k.limb(leg, Vector3(0.05, 0.55, 0.34 * side), Vector3(0.05, 0.18, 0.36 * side), 0.22, 0.25, body)
		k.ball(leg, Vector3(0.12, 0.13, 0.36 * side), 0.25, body, Vector3(1.3, 0.55, 1.05))
		if crystal:
			for i in 3:
				var base := sh + Vector3(-0.05 + i * 0.08, 0.1, 0.12 * side)
				k.cone(arm, base, base + Vector3(-0.15 + i * 0.12, 0.45 - i * 0.08, 0.2 * side), 0.11, accent, 0.45, 5)
		else:
			k.ball(arm, sh + Vector3(0, 0.2, 0), 0.2, accent, Vector3(1.2, 0.6, 1.2))
			k.chain(arm, [sh + Vector3(-0.05, 0.15, 0), sh + Vector3(-0.15, 0.55, 0.15 * side), sh + Vector3(-0.1, 0.85, 0.3 * side)], 0.06, 0.02, body)
	if crystal:
		for i in 9:
			var a := i * 0.7
			var base := Vector3(-0.3 + 0.1 * sin(a), 1.7 + 0.1 * (i % 3), sin(a * 1.3) * 0.45)
			k.cone("Torso", base, base + Vector3(-0.45, 0.35 + 0.15 * (i % 2), sin(a) * 0.3), 0.13, accent if i % 2 == 0 else c("#bfe8ff"), 0.5, 5)
		for i in 4:
			k.cone("Head", Vector3(0.1, 2.55, (i - 1.5) * 0.1), Vector3(-0.1 + i * 0.03, 2.95 - absf(i - 1.5) * 0.1, (i - 1.5) * 0.16), 0.08, accent, 0.5, 5)
	else:
		for i in 5:
			var base := Vector3(-0.2, 1.55 + i * 0.12, sin(i * 1.7) * 0.35)
			k.ball("Torso", base, 0.18, accent, Vector3(1, 0.6, 1.1))
		for i in 4:
			k.ball("Torso", Vector3(0.45, 1.45 + i * 0.18, sin(i * 2.0) * 0.35), 0.05, glow, Vector3.ONE, Vector3.ZERO, 1.0, 6)
		var branches := 6 if king else 3
		for i in branches:
			var a := lerpf(-0.9, 0.9, i / maxf(1, branches - 1.0))
			var base := Vector3(0.1, 2.55, a * 0.2)
			var mid := base + Vector3(-0.1, 0.35, a * 0.25)
			k.chain("Head", [base, mid, mid + Vector3(-0.15, 0.3 + 0.1 * (i % 2), a * 0.2)], 0.07, 0.02, body)
			if king: k.ball("Head", mid + Vector3(-0.15, 0.32, a * 0.2), 0.07, glow, Vector3.ONE, Vector3.ZERO, 1.0, 6)
		for side in [-1, 1]:
			for r in 3:
				k.chain("LegL" if side < 0 else "LegR", [Vector3(0.12, 0.12, 0.36 * side), Vector3(0.35 + r * 0.05, 0.05, (0.36 + (r - 1) * 0.15) * side), Vector3(0.5 + r * 0.06, 0.02, (0.4 + (r - 1) * 0.3) * side)], 0.06, 0.02, body)
	var m := k.build(model_name); m.set_meta("style", "slam"); return m

static func ghost(model_name: String, p: Dictionary) -> Node3D:
	var k := Kit.new(); k.ghost = true
	var robe := c(p.robe); var hair := c(p.hair); var glow := c(p.glow)
	k.bone("Hips", "", Vector3(0, 1.4, 0))
	k.bone("Torso", "Hips", Vector3(0, 1.4, 0))
	k.bone("Head", "Torso", Vector3(0, 2.2, 0))
	k.bone("ArmL", "Torso", Vector3(0, 2.0, -0.3)); k.bone("ArmR", "Torso", Vector3(0, 2.0, 0.3))
	k.bone("Tail", "Hips", Vector3(-0.1, 0.9, 0))
	k.tube("Torso", Vector3(0, 2.05, 0), Vector3(0, 1.1, 0), 0.22, 0.5, robe, 0.25, 12, Vector3(1, 1, 1.2))
	k.chain("Tail", [Vector3(0, 1.1, 0), Vector3(-0.25, 0.75, 0), Vector3(-0.6, 0.55, 0.1), Vector3(-0.95, 0.65, 0.15)], 0.48, 0.05, robe, 0.25)
	k.ball("Head", Vector3(0, 2.38, 0), 0.22, c("#e8eeff"), Vector3(1, 1.08, 0.95), Vector3.ZERO, 0.4)
	for side in [-1, 1]:
		k.ball("Head", Vector3(0.19, 2.39, 0.075 * side), 0.035, c(p.eyes), Vector3(0.5, 1.3, 1), Vector3.ZERO, 1.0, 8)
	k.ball("Head", Vector3(-0.04, 2.45, 0), 0.24, hair, Vector3(1, 0.9, 1.05), Vector3.ZERO, 0.5)
	var strands := []
	for i in 10: strands.append(Vector3(-0.15 - i * 0.08, 2.4 - i * 0.14, sin(i * 0.8) * 0.12))
	k.chain("Head", strands, 0.2, 0.04, hair, 0.5, Vector3(0.7, 1, 1.2))
	for i in 3:
		k.cone("Head", Vector3(0, 2.6, (i - 1) * 0.1), Vector3(-0.05, 2.85 + 0.08 * (i % 2), (i - 1) * 0.18), 0.04, glow, 0.9, 5)
	if p.get("moon", false):
		var moon := PackedVector2Array()
		for i in 17:
			var a := lerpf(-2.4, 2.4, i / 16.0); moon.append(Vector2(cos(a), sin(a)) * 0.55)
		for i in range(16, -1, -1):
			var a := lerpf(-2.0, 2.0, i / 16.0); moon.append(Vector2(cos(a) * 0.45 + 0.16, sin(a) * 0.45))
		k.blade("Head", Vector3(-0.35, 2.55, 0), Vector3(0, 0, 1), Vector3(0, 1, 0), moon, 0.04, c("#f4f0d0"), 0.9)
	for side in [-1, 1]:
		var arm := "ArmL" if side < 0 else "ArmR"
		var sh := Vector3(0, 2.0, 0.3 * side)
		var hand := sh + Vector3(0.55, -0.35, 0.1 * side)
		k.tube(arm, sh, hand, 0.08, 0.2, robe, 0.25, 8)
		k.limb(arm, hand, hand + Vector3(0.2, -0.05, 0), 0.04, 0.03, c("#e8eeff"), 0.4)
		k.ball(arm, hand + Vector3(0.25, 0, 0), 0.08, glow, Vector3.ONE, Vector3.ZERO, 1.0, 8)
	var m := k.build(model_name); m.set_meta("style", "cast"); m.set_meta("float", true); return m

static func serpent(model_name: String, p: Dictionary) -> Node3D:
	var k := Kit.new()
	var body := c(p.body); var belly := c(p.belly); var fin := c(p.fin)
	k.bone("Hips", "", Vector3(0, 0, 0))
	k.bone("Torso", "Hips", Vector3(0, 0.3, 0))
	k.bone("Head", "Torso", Vector3(0.55, 2.55, 0))
	k.bone("Tail", "Torso", Vector3(-0.6, 0.3, 0))
	var pts := []
	for i in 18:
		var a := i * 0.5
		pts.append(Vector3(cos(a) * 0.75 - 0.1, 0.28 + i * 0.03, sin(a) * 0.55))
	for i in 7:
		var t := i / 6.0
		pts.append(Vector3(lerpf(0.5, 0.25, t) + sin(t * 3.0) * 0.2, lerpf(0.9, 2.45, t), lerpf(0.0, 0.0, t)))
	k.chain("Torso", pts, 0.3, 0.24, body)
	for i in range(18, pts.size()):
		k.ball("Torso", pts[i] + Vector3(0.12, 0, 0.05), 0.2, belly, Vector3(0.7, 1, 1.0))
		k.blade("Torso", pts[i] + Vector3(-0.2, 0, 0), Vector3(-1, 0.4, 0), Vector3(0, 1, 0), PackedVector2Array([Vector2(0, -0.15), Vector2(0.3, 0.05), Vector2(0, 0.12)]), 0.03, fin, 0.3)
	k.chain("Tail", [Vector3(-0.6, 0.3, 0.3), Vector3(-1.0, 0.25, 0.5), Vector3(-1.4, 0.35, 0.4), Vector3(-1.7, 0.6, 0.3)], 0.24, 0.06, body)
	k.blade("Tail", Vector3(-1.7, 0.6, 0.3), Vector3(-0.6, 1, 0), Vector3(1, 0, 0), PackedVector2Array([Vector2(0, 0), Vector2(0.4, -0.25), Vector2(0.3, 0.3)]), 0.03, fin, 0.3)
	var hc := Vector3(0.6, 2.62, 0)
	k.ball("Head", hc, 0.3, body, Vector3(1.4, 0.8, 0.95))
	k.tube("Head", hc + Vector3(0.2, 0, 0), hc + Vector3(0.65, -0.08, 0), 0.2, 0.12, body)
	k.blade("Head", hc + Vector3(0.1, -0.18, 0), Vector3(1, -0.55, 0), Vector3(0, 1, 0), PackedVector2Array([Vector2(0, -0.04), Vector2(0.55, -0.02), Vector2(0.5, 0.06), Vector2(0, 0.06)]), 0.22, belly)
	for side in [-1, 1]:
		k.ball("Head", hc + Vector3(0.22, 0.12, 0.17 * side), 0.05, c(p.eyes), Vector3(0.7, 0.8, 1), Vector3.ZERO, 1.0, 8)
		k.blade("Head", hc + Vector3(-0.1, 0.05, 0.2 * side), Vector3(-1, 0.3, 0.6 * side), Vector3(0, 1, 0), PackedVector2Array([Vector2(0, -0.1), Vector2(0.55, 0.15), Vector2(0.4, -0.05), Vector2(0.6, -0.15), Vector2(0, -0.2)]), 0.03, fin, 0.4)
		for t in 4:
			k.cone("Head", hc + Vector3(0.45 + t * 0.07, -0.13, 0.08 * side), hc + Vector3(0.45 + t * 0.07, -0.24, 0.08 * side), 0.02, c("#f2ead0"), 0.0, 4)
	k.blade("Head", hc + Vector3(-0.1, 0.22, 0), Vector3(-1, 0.6, 0), Vector3(0, 0, 1).cross(Vector3(-1, 0.6, 0)).normalized(), PackedVector2Array([Vector2(0, 0), Vector2(0.6, 0.3), Vector2(0.45, -0.05)]), 0.03, fin, 0.4)
	k.ring("Hips", Vector3(0, 0.1, 0), 0.95, 1.08, c("#7fd4ff"), Vector3.ZERO, 0.35)
	k.ring("Hips", Vector3(0.1, 0.06, 0), 1.25, 1.33, c("#bfeaff"), Vector3.ZERO, 0.45)
	for i in 6:
		var a := i * TAU / 6.0 + 0.3
		k.cone("Hips", Vector3(cos(a) * 1.0, 0.05, sin(a) * 0.95), Vector3(cos(a) * 1.15, 0.38 + 0.12 * (i % 2), sin(a) * 1.1), 0.08, c("#d8f2ff"), 0.4, 5)
	var m := k.build(model_name); m.set_meta("style", "bite"); return m

static func ore() -> Node3D:
	var k := Kit.new()
	k.bone("Hips", "", Vector3(0, 0, 0))
	k.bone("Torso", "Hips", Vector3(0, 0.3, 0))
	var rock := c("#6c7079")
	k.ball("Torso", Vector3(0, 0.45, 0), 0.62, rock, Vector3(1.2, 0.85, 1.0), Vector3(0.2, 0.3, 0.1), 0.0, 7)
	k.ball("Torso", Vector3(-0.45, 0.3, 0.3), 0.4, c("#5a5e66"), Vector3(1.1, 0.8, 1), Vector3(0.3, 0.8, 0), 0.0, 6)
	k.ball("Torso", Vector3(0.4, 0.25, -0.3), 0.35, c("#7a7f88"), Vector3(1, 0.8, 1.1), Vector3(0.5, 0.2, 0.3), 0.0, 6)
	for i in 9:
		var a := i * 1.37
		var pos := Vector3(cos(a) * 0.5, 0.35 + 0.35 * sin(a * 1.7) * 0.8 + 0.2, sin(a) * 0.45)
		k.ball("Torso", pos, 0.09 + 0.03 * (i % 3), c("#ffc760"), Vector3(1.2, 0.8, 1), Vector3(a, a, 0), 0.8, 6)
	for i in 3:
		var base := Vector3(-0.1 + i * 0.15, 0.85, (i - 1) * 0.15)
		k.cone("Torso", base, base + Vector3(0.05 * i, 0.35, (i - 1) * 0.1), 0.08, c("#ffe7a0"), 0.9, 5)
	var m := k.build("GoldVein"); m.set_meta("style", "none"); return m

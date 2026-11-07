extends RefCounted
## Замена процедурных моделей файлами из Blender.
##
## Если в res://assets/models3d/glb/ лежит <имя>.glb (имена как в папке blender/models),
## игра берёт его вместо модели из characters.gd. Требования к файлу:
##   • узлы-кости называются как в процедурной модели (Hips, Torso, Head, ArmL, ArmR, LegL, LegR,
##     Cape, Weapon, Pickaxe, Offhand, Tail, WingL, WingR) — по ним работает анимация (rig.gd);
##   • персонаж смотрит в +X (в Blender: вдоль −Y после импорта glTF → оставьте как при экспорте);
##   • цвет — атрибут вершин (Color Attribute), свечение — координата U первой UV-развёртки.
## Материалы из файла заменяются общим мультяшным шейдером с обводкой.

const TOON = preload("res://assets/models3d/toon.gdshader")
const TOON_GHOST = preload("res://assets/models3d/toon_ghost.gdshader")
const OUTLINE = preload("res://assets/models3d/outline.gdshader")
const DIR = "res://assets/models3d/glb/"

const FILES = {
	"hero0_false": "hero_0_iskra", "hero0_true": "hero_0_iskra_star", "hero1_false": "hero_1_ice_sorceress",
	"hero2_false": "hero_2_forest_huntress", "hero3_false": "hero_3_dawn_knight", "hero4_false": "hero_4_storm_guard",
	"hero5_false": "hero_5_soul_keeper", "hero6_false": "hero_6_dragon_knight",
	"ally0": "ally_0_fox", "ally1": "ally_1_forest_archer", "ally2": "ally_2_mage_apprentice", "ally3": "ally_3_dawn_guard",
	"ally4": "ally_4_moon_witch", "ally5": "ally_5_ash_knight", "ally6": "ally_6_time_keeper", "ally7": "ally_7_spark_dragon",
	"enemy-1": "enemy_m1_treant", "enemy0": "enemy_0_goblin", "enemy1": "enemy_1_fallen_king", "enemy2": "enemy_2_crystal_golem",
	"enemy3": "enemy_3_ash_demon", "enemy4": "enemy_4_moon_spirit", "enemy5": "enemy_5_sea_serpent", "enemy6": "enemy_6_shadow_knight",
	"enemy7": "enemy_7_red_dragon", "enemy8": "enemy_8_root_king", "ore": "ore_gold_vein",
}
const BONES = ["Hips", "Torso", "Head", "ArmL", "ArmR", "LegL", "LegR", "Cape", "Weapon", "Pickaxe", "Offhand", "Tail", "WingL", "WingR"]

## Возвращает модель из .glb, подготовленную как процедурная (meta bones/material/bounds/style), или null.
## procedural — модель из characters.gd: из неё берутся стиль атаки и признаки (парит, призрак).
static func load_override(key: String, procedural: Node3D) -> Node3D:
	if not FILES.has(key): return null
	var path: String = DIR + FILES[key] + ".glb"
	if not ResourceLoader.exists(path): return null
	var scene := load(path) as PackedScene
	if scene == null: return null
	var model: Node3D = scene.instantiate()
	model.name = procedural.name
	for meta in ["style", "float"]:
		if procedural.has_meta(meta): model.set_meta(meta, procedural.get_meta(meta))
	var ghost := (procedural.get_meta("material") as ShaderMaterial).shader == TOON_GHOST
	var material := ShaderMaterial.new(); material.shader = TOON_GHOST if ghost else TOON
	if not ghost:
		var outline := ShaderMaterial.new(); outline.shader = OUTLINE; material.next_pass = outline
	var bones := {}
	var bounds := AABB(); var first := true
	for node in model.find_children("*", "", true, false):
		if node is Node3D:
			node.set_meta("rest_position", node.position); node.set_meta("rest_rotation", node.rotation)
			if node.name in BONES and not bones.has(String(node.name)): bones[String(node.name)] = node
		if node is MeshInstance3D:
			node.material_override = material
			var box: AABB = _relative(node, model) * (node as MeshInstance3D).mesh.get_aabb()
			bounds = box if first else bounds.merge(box); first = false
	if bones.has("Pickaxe"): bones["Pickaxe"].visible = false
	model.set_meta("material", material); model.set_meta("bones", bones); model.set_meta("bounds", bounds)
	return model

static func _relative(node: Node, root: Node) -> Transform3D:
	var xf := Transform3D.IDENTITY
	while node != null and node != root:
		if node is Node3D: xf = (node as Node3D).transform * xf
		node = node.get_parent()
	return xf

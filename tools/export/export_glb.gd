extends SceneTree
## Выгрузка процедурных моделей в .glb для Blender.
## Запуск из папки godot/:  godot --headless --script res://../tools/export/export_glb.gd -- <папка>
## Кости (Hips, Torso, Head, ArmL…) становятся объектами-пустышками с мешами внутри.
## Цвет — атрибут вершин COLOR_0; сила свечения — координата U в UV-развёртке (0 = нет, 1 = ярко).

const Chars = preload("res://scripts/models/characters.gd")

func _init() -> void:
	var out: String = OS.get_cmdline_user_args()[0] if OS.get_cmdline_user_args().size() > 0 else "user://glb"
	DirAccess.make_dir_recursive_absolute(out)
	var hero_names = ["iskra", "ice_sorceress", "forest_huntress", "dawn_knight", "storm_guard", "soul_keeper", "dragon_knight"]
	var ally_names = ["fox", "forest_archer", "mage_apprentice", "dawn_guard", "moon_witch", "ash_knight", "time_keeper", "spark_dragon"]
	var enemy_names = {-1: "treant", 0: "goblin", 1: "fallen_king", 2: "crystal_golem", 3: "ash_demon", 4: "moon_spirit", 5: "sea_serpent", 6: "shadow_knight", 7: "red_dragon", 8: "root_king"}
	var jobs = []
	for i in 7: jobs.append(["hero_%d_%s" % [i, hero_names[i]], Chars.hero.bind(i)])
	jobs.append(["hero_0_iskra_star", Chars.hero.bind(0, true)])
	for i in 8: jobs.append(["ally_%d_%s" % [i, ally_names[i]], Chars.ally.bind(i)])
	for i in range(-1, 9): jobs.append(["enemy_%s_%s" % [str(i).replace("-", "m"), enemy_names[i]], Chars.enemy.bind(i)])
	jobs.append(["ore_gold_vein", Chars.ore])
	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true; material.roughness = 1.0
	for job in jobs:
		var model: Node3D = job[1].call()
		for node in model.find_children("*", "", true, false):
			node.visible = true   # кирка тоже выгружается
			if node is MeshInstance3D: node.material_override = null; node.mesh.surface_set_material(0, material)
		model.name = job[0]
		var doc := GLTFDocument.new(); var state := GLTFState.new()
		var err := doc.append_from_scene(model, state)
		if err == OK: err = doc.write_to_filesystem(state, out.path_join(job[0] + ".glb"))
		print(job[0], " -> ", error_string(err))
		model.free()
	quit()

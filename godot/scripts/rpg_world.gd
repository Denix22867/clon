extends RefCounted

var root: Node3D
var stage_root: Node3D
var hero: Node3D
var foe: Node3D
var sword_arm: Node3D
var blade: MeshInstance3D
var sparks: Array = []
var ally_nodes: Array = []
var region_id: int = -1
var foe_id: String = ""
var armor_material: StandardMaterial3D
var foe_material: StandardMaterial3D
var hit: float = 0.0
var swing: float = 0.0
var time: float = 0.0
const PALETTES = [["#567d68", "#315a50", "#7da981"], ["#767489", "#515470", "#aaa2ab"], ["#546f8c", "#3b4969", "#79bbc5"], ["#73524c", "#4f373e", "#d3885d"], ["#62628a", "#393e60", "#a597d4"], ["#3d7778", "#2b515c", "#78aba2"], ["#665676", "#363450", "#a587bc"], ["#7d5749", "#4d343f", "#d5a067"]]

func mat(hex: String) -> StandardMaterial3D:
	var m = StandardMaterial3D.new(); m.albedo_color = Color(hex); m.roughness = 0.9; return m
func mesh(parent: Node3D, shape: Mesh, color: String, pos: Vector3) -> MeshInstance3D:
	var n = MeshInstance3D.new(); n.mesh = shape; n.material_override = mat(color); n.position = pos; parent.add_child(n); return n
func box(parent: Node3D, pos: Vector3, size: Vector3, color: String) -> MeshInstance3D:
	var b = BoxMesh.new(); b.size = size; return mesh(parent, b, color, pos)
func ball(parent: Node3D, pos: Vector3, scale: Vector3, color: String) -> MeshInstance3D:
	var b = SphereMesh.new(); b.radius = 1; b.height = 2; b.radial_segments = 12; b.rings = 6
	var n = mesh(parent, b, color, pos); n.scale = scale; return n
func cone(parent: Node3D, pos: Vector3, radius: float, height: float, color: String, top: float = 0.0) -> MeshInstance3D:
	var b = CylinderMesh.new(); b.top_radius = top; b.bottom_radius = radius; b.height = height; b.radial_segments = 8; return mesh(parent, b, color, pos)

func setup(parent: Node3D) -> void:
	root = parent
	var world = WorldEnvironment.new(); var e = Environment.new(); e.background_mode = Environment.BG_COLOR
	e.background_color = Color("#172334"); e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color("#bacce5"); e.ambient_light_energy = 0.55; world.environment = e; root.add_child(world)
	var sun = DirectionalLight3D.new(); sun.rotation_degrees = Vector3(-45, -30, 0); sun.light_energy = 0.6
	sun.shadow_enabled = true; sun.shadow_bias = 0.2; sun.shadow_normal_bias = 2.0; root.add_child(sun)
	hero = Node3D.new(); root.add_child(hero); hero.position = Vector3(-2.0, 0, 0)
	make_hero()
	for i in range(8):
		var n = Node3D.new(); root.add_child(n); n.position = Vector3(-3.2 + float(i % 4) * 0.6, 0, -1.3 - float(i / 4) * 0.6)
		ball(n, Vector3(0, 0.35, 0), Vector3(0.2, 0.32, 0.2), ["#cc8d57", "#75b99d", "#8d85d0", "#dcb96a", "#af83cf", "#df7863", "#76bfc9", "#e9a966"][i])
		ball(n, Vector3(0, 0.77, 0), Vector3(0.18, 0.18, 0.18), "#e3c8a4")
		cone(n, Vector3(0, 1.0, 0), 0.21, 0.25, "#647389")
		if i == 0:
			for child in n.get_children(): child.queue_free()
			ball(n, Vector3(0, 0.28, 0), Vector3(0.3, 0.22, 0.44), "#cc8d57")
			ball(n, Vector3(0, 0.52, 0.3), Vector3(0.22, 0.23, 0.24), "#e2a463")
			ball(n, Vector3(0, 0.45, 0.51), Vector3(0.13, 0.1, 0.16), "#efe1c2")
			for x in [-0.13, 0.13]: cone(n, Vector3(x, 0.76, 0.3), 0.1, 0.25, "#cc8d57")
			for x in [-0.16, 0.16]:
				for z in [-0.23, 0.22]: box(n, Vector3(x, 0.1, z), Vector3(0.09, 0.18, 0.12), "#6c4d3c")
			ball(n, Vector3(0, 0.33, -0.48), Vector3(0.2, 0.18, 0.33), "#efe1c2")
		elif i in [2, 4, 6]:
			cone(n, Vector3(0, 1.12, 0), 0.23, 0.42, "#8d85d0")
			cone(n, Vector3(0.25, 0.5, 0), 0.04, 1.0, "#7d5f50", 0.04)
			ball(n, Vector3(0.25, 1.07, 0), Vector3.ONE * 0.12, "#cbb4ec")
		elif i in [3, 5]:
			box(n, Vector3(-0.22, 0.42, 0.15), Vector3(0.3, 0.48, 0.1), "#dcb96a")
			box(n, Vector3(0, 0.84, 0.08), Vector3(0.36, 0.29, 0.3), "#8b9eae")
		elif i == 7:
			for x in [-0.3, 0.3]: box(n, Vector3(x, 0.52, -0.1), Vector3(0.4, 0.35, 0.06), "#c97557").rotation_degrees.z = x * 80
		ally_nodes.append(n)

func make_hero() -> void:
	box(hero, Vector3(-0.22, 0.36, 0), Vector3(0.27, 0.65, 0.3), "#33455c")
	box(hero, Vector3(0.22, 0.36, 0), Vector3(0.27, 0.65, 0.3), "#33455c")
	for x in [-0.23, 0.23]: box(hero, Vector3(x, 0.13, 0.14), Vector3(0.36, 0.24, 0.48), "#263443")
	var torso = box(hero, Vector3(0, 1.05, 0), Vector3(0.78, 0.7, 0.47), "#83a8b5"); armor_material = torso.material_override
	box(hero, Vector3(0, 0.73, 0), Vector3(0.82, 0.12, 0.5), "#c8a467")
	box(hero, Vector3(0, 1.02, -0.31), Vector3(0.75, 1.1, 0.08), "#c86856").rotation_degrees.x = -12
	ball(hero, Vector3(0, 1.7, 0.03), Vector3(0.35, 0.38, 0.32), "#eac59b")
	box(hero, Vector3(0, 1.97, 0), Vector3(0.72, 0.22, 0.67), "#77534a")
	box(hero, Vector3(-0.23, 1.75, 0), Vector3(0.23, 0.42, 0.63), "#77534a")
	for x in [-0.12, 0.12]: box(hero, Vector3(x, 1.74, 0.33), Vector3(0.055, 0.065, 0.04), "#25364a")
	box(hero, Vector3(-0.53, 1.04, 0), Vector3(0.25, 0.58, 0.3), "#83a8b5")
	box(hero, Vector3(-0.59, 0.99, 0.27), Vector3(0.55, 0.75, 0.15), "#355d78")
	box(hero, Vector3(-0.59, 0.99, 0.36), Vector3(0.1, 0.55, 0.025), "#e4bc6c")
	sword_arm = Node3D.new(); hero.add_child(sword_arm); sword_arm.position = Vector3(0.52, 1.27, 0)
	box(sword_arm, Vector3(0, -0.25, 0), Vector3(0.25, 0.58, 0.3), "#83a8b5")
	box(sword_arm, Vector3(0, -0.45, 0.18), Vector3(0.26, 0.24, 0.3), "#eac59b")
	box(sword_arm, Vector3(0, -0.22, 0.33), Vector3(0.48, 0.08, 0.12), "#e4bc6c")
	blade = box(sword_arm, Vector3(0, 0.39, 0.33), Vector3(0.16, 1.15, 0.1), "#c7d9dc")

func landscape(region: int) -> void:
	if is_instance_valid(stage_root): stage_root.queue_free()
	region_id = region; stage_root = Node3D.new(); root.add_child(stage_root)
	var p = PALETTES[region]
	cone(stage_root, Vector3(0, -0.4, 0), 5.5, 0.7, p[1], 5.8)
	cone(stage_root, Vector3(0, -0.06, 0), 5.8, 0.12, p[0], 5.8)
	for i in range(15):
		var x = -5.0 + fmod(i * 1.71, 10.0); var z = -2.0 - fmod(i * 1.17, 2.4)
		if region == 0 or region == 4:
			cone(stage_root, Vector3(x, 0.65, z), 0.12, 1.4, "#685645", 0.1)
			cone(stage_root, Vector3(x, 1.7, z), 0.65, 1.6, p[1]); cone(stage_root, Vector3(x, 2.4, z), 0.47, 1.2, p[2])
		elif region == 2 or region == 5:
			var n = cone(stage_root, Vector3(x, 0.65, z), 0.42, 1.6, p[2]); n.rotation_degrees.z = sin(i) * 15
		else:
			box(stage_root, Vector3(x, 0.7, z), Vector3(0.5, 1.4 + sin(i) * 0.5, 0.55), p[1])
			box(stage_root, Vector3(x, 1.5, z), Vector3(0.72, 0.2, 0.72), p[2])
	for i in range(12): ball(stage_root, Vector3(-4.8 + fmod(i * 1.9, 9.7), 0.1, 1.2 + sin(i) * 0.6), Vector3(0.2, 0.16, 0.25), p[2])
	for x in [-4.5, 4.5]:
		cone(stage_root, Vector3(x, 0.5, 0), 0.12, 1.0, "#67564d", 0.1)
		ball(stage_root, Vector3(x, 1.2, 0), Vector3(0.16, 0.3, 0.16), "#efbc75")

func enemy(region: int, is_boss: bool) -> void:
	if is_instance_valid(foe): foe.queue_free()
	foe = Node3D.new(); root.add_child(foe); foe.position = Vector3(2.1, 0, 0)
	var c = PALETTES[region][2]
	if region == 0 and not is_boss:
		var n = ball(foe, Vector3(0, 0.6, 0), Vector3(0.9, 0.7, 0.75), c); foe_material = n.material_override
		for x in [-0.28, 0.28]:
			ball(foe, Vector3(x, 0.85, 0.64), Vector3(0.14, 0.18, 0.08), "#f4e9d0")
			ball(foe, Vector3(x, 0.85, 0.72), Vector3(0.055, 0.1, 0.025), "#243648")
		ball(foe, Vector3(0, 0.42, 0.64), Vector3(0.2, 0.065, 0.045), "#335849")
	else:
		var n = box(foe, Vector3(0, 0.98, 0), Vector3(1.0, 1.1, 0.65), c); foe_material = n.material_override
		for x in [-0.32, 0.32]:
			box(foe, Vector3(x, 0.3, 0), Vector3(0.35, 0.6, 0.4), PALETTES[region][1])
			box(foe, Vector3(x * 2, 1.0, 0), Vector3(0.35, 0.75, 0.4), c)
		ball(foe, Vector3(0, 1.85, 0), Vector3(0.58, 0.5, 0.42), c)
		for x in [-0.22, 0.22]: box(foe, Vector3(x, 1.9, 0.39), Vector3(0.15, 0.09, 0.07), "#f6cc75")
		for x in [-0.48, 0.48]: cone(foe, Vector3(x, 2.34, 0), 0.15, 0.6, "#d5c7a9")
		box(foe, Vector3(0, 1.59, 0.4), Vector3(0.5, 0.11, 0.06), "#304150")
		if region == 1:
			for x in [-0.7, 0.7]: cone(foe, Vector3(x, 2.04, 0), 0.23, 0.45, c).rotation_degrees.z = x * 65
			box(foe, Vector3(-0.79, 0.5, 0), Vector3(0.14, 0.7, 0.14), "#6b5544")
		elif region == 2:
			for x in [-0.7, 0, 0.7]: cone(foe, Vector3(x, 1.35, -0.3), 0.28, 1.3, "#99d6d3")
		elif region == 4:
			cone(foe, Vector3(0, 0.5, 0), 0.75, 1.2, "#8579ad", 0.35)
			ball(foe, Vector3(0, 1.8, 0.07), Vector3(0.62, 0.57, 0.44), "#a5a0c2")
		elif region == 5:
			for x in [-0.7, 0.7]: ball(foe, Vector3(x, 0.3, 0), Vector3(0.2, 0.2, 0.8), c)
		elif region == 6:
			box(foe, Vector3(0, 1.87, 0), Vector3(1.16, 0.75, 0.84), "#394354")
			box(foe, Vector3(0, 1.9, 0.44), Vector3(0.85, 0.06, 0.06), "#d38e78")
			box(foe, Vector3(-0.8, 1.25, 0), Vector3(0.12, 1.6, 0.1), "#a7aabb")
		elif region == 7:
			for x in [-1.0, 1.0]: box(foe, Vector3(x, 1.5, -0.25), Vector3(0.9, 0.85, 0.1), "#ae775b").rotation_degrees.z = x * 35
			cone(foe, Vector3(0, 0.5, -0.8), 0.25, 1.7, c).rotation_degrees.x = 65
		if is_boss:
			for x in [-1.0, 1.0]:
				var wing = box(foe, Vector3(x, 1.5, -0.35), Vector3(0.85, 1.2, 0.1), "#5f4a69"); wing.rotation_degrees.z = x * 30
			cone(foe, Vector3(0, 2.5, 0), 0.35, 0.32, "#e5b66a", 0.28)
	foe.scale = Vector3.ONE * (1.25 if is_boss else 1.0)

func update(state, delta: float) -> void:
	time += delta; hit = maxf(0, hit - delta * 4); swing = maxf(0, swing - delta * 4)
	if region_id != state.region(): landscape(state.region())
	var key = str(state.region()) + str(state.boss()) + str(state.stage)
	if foe_id != key: enemy(state.region(), state.boss()); foe_id = key
	foe.position.y = sin(time * 2.4) * 0.05; foe.position.x = 2.1 + hit * 0.16
	foe.rotation_degrees.z = hit * 8
	hero.position.y = absf(sin(time * 2.0)) * 0.025
	sword_arm.rotation_degrees.z = -sin(swing * PI) * 85
	armor_material.albedo_color = Color(["#83a8b5", "#afc8c8", "#d6b76d", "#b4a0dc", "#de8e65"][mini(4, state.sword / 25)])
	blade.scale.y = 1.0 + minf(0.6, state.sword / 150.0)
	for i in range(8): ally_nodes[i].visible = state.allies[i] > 0; ally_nodes[i].position.y = sin(time * 2 + i) * 0.04
	for i in range(sparks.size() - 1, -1, -1):
		var n = sparks[i]; n.position.y += delta * 1.9; n.scale *= maxf(0, 1 - delta * 3.5)
		if n.scale.x < 0.03: n.queue_free(); sparks.remove_at(i)
func impact() -> void:
	hit = 1; swing = 1
	for i in range(5): sparks.append(ball(root, Vector3(2 + randf_range(-0.5, 0.5), 1 + randf_range(-0.4, 0.5), 0.65), Vector3.ONE * 0.1, "#f3c775"))

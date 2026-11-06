extends RefCounted
const Art = preload("res://scripts/art_catalog.gd")

var root: Node3D
var view: SubViewport
var viewport_image: TextureRect
var scene: Node3D
var hero: Node3D
var foe: Node3D
var fox: Node3D
var miner: Node3D
var ore: Node3D
var mining = false
var mine_clock = 0.0
var miner_base = Vector3.ZERO
var ore_base = Vector3.ZERO
var animation: AnimationPlayer
var swing: float = 0.0
var hit: float = 0.0
var clock: float = 0.0
var hero_base = Vector3.ZERO
var foe_base = Vector3.ZERO
var fox_base = Vector3.ZERO
var sparks: Array = []
var actor_layer: Control
var view_size = Vector2(720, 500)
var scale_factor = 1.0
var enemy_sprite: Sprite3D
var party: Array = []
var party_clocks: Array = []
var projectiles: Array = []
var enemy_index = -99
var active_party: Array = []
var summons: Array = []
var selected_hero: Sprite3D
var hero_index = -1
var hero_mining = false
var hero_skin = false
var last_attack_style = "Огненная дуга"
const ATTACK_STYLES = ["Огненная дуга", "Ледяные осколки", "Тройная стрела", "Свет рассвета", "Разряд молнии", "Сферы душ", "Пламя дракона"]
var hero_color = Color("#ffb35b")

func setup(parent: Node3D) -> void: root = parent
func layout(_rect: Rect2, _screen: Vector2, _camera: Camera3D) -> void: pass

func attach(parent: Control, size: Vector2, top: float, factor: float, _hero_tex: Texture2D, _foe_tex: Texture2D, _fox_tex: Texture2D) -> void:
	sparks.clear(); projectiles.clear(); summons.clear(); party.clear(); party_clocks.clear(); enemy_index = -99; hero_index = -1
	if is_instance_valid(view): view.queue_free()
	if is_instance_valid(viewport_image): viewport_image.queue_free()
	actor_layer = parent; view_size = size; scale_factor = factor
	view = SubViewport.new(); root.add_child(view); view.size = Vector2i(int(size.x * factor), int(size.y * factor)); view.transparent_bg = true
	view.render_target_update_mode = SubViewport.UPDATE_ALWAYS; view.own_world_3d = true
	scene = load("res://assets/models/painted_battle.tscn").instantiate(); view.add_child(scene)
	var mining_scene = load("res://assets/models/mining.tscn").instantiate(); scene.add_child(mining_scene)
	miner = mining_scene.find_child("Miner*", true, false); ore = mining_scene.find_child("GoldVein*", true, false)
	if miner: miner_base = miner.position
	if ore: ore_base = ore.position
	hero = scene.find_child("Hero*", true, false); foe = scene.find_child("Golem*", true, false); fox = scene.find_child("Fox*", true, false)
	animation = scene.find_child("AnimationPlayer", true, false)
	if hero: hero_base = hero.position
	if foe: foe_base = foe.position
	if fox: fox_base = fox.position
	selected_hero = Sprite3D.new(); scene.add_child(selected_hero)
	selected_hero.shaded = false; selected_hero.double_sided = true; selected_hero.alpha_cut = SpriteBase3D.ALPHA_CUT_DISABLED
	selected_hero.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	enemy_sprite = Sprite3D.new(); scene.add_child(enemy_sprite); enemy_sprite.shaded = false; enemy_sprite.double_sided = true; enemy_sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_DISABLED
	for i in range(3):
		var summon = Sprite3D.new(); scene.add_child(summon); summon.texture = Art.enemy(0)
		summon.shaded = false; summon.double_sided = true; summon.alpha_cut = SpriteBase3D.ALPHA_CUT_DISABLED
		summon.pixel_size = 1.1 / summon.texture.get_height(); summon.visible = false; summons.append(summon)
	party.append(fox); party_clocks.append(0.0)
	for i in range(1, 8):
		var fighter = Sprite3D.new(); scene.add_child(fighter); fighter.texture = Art.companion(i)
		fighter.pixel_size = minf(1.55 / fighter.texture.get_height(), 1.25 / fighter.texture.get_width()); fighter.shaded = false; fighter.double_sided = true
		fighter.alpha_cut = SpriteBase3D.ALPHA_CUT_DISABLED; fighter.no_depth_test = true; fighter.render_priority = 10
		party.append(fighter); party_clocks.append(float(i) * 0.18)
	prepare_materials(scene)
	var camera = Camera3D.new(); view.add_child(camera); camera.projection = Camera3D.PROJECTION_ORTHOGONAL; camera.keep_aspect = Camera3D.KEEP_WIDTH; camera.size = 7.2
	var height = 7.2 * size.y / size.x
	camera.position = Vector3(0, height / 2 - 0.12, 12); camera.look_at(Vector3(0, height / 2 - 0.12, 0)); camera.current = true
	viewport_image = TextureRect.new(); parent.add_child(viewport_image); viewport_image.texture = view.get_texture()
	viewport_image.position = Vector2(0, top) * factor; viewport_image.size = size * factor; viewport_image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE; viewport_image.stretch_mode = TextureRect.STRETCH_SCALE; viewport_image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	viewport_image.z_index = 0

func prepare_materials(node: Node) -> void:
	if node is MeshInstance3D:
		for i in range(node.mesh.get_surface_count()):
			var m = node.get_active_material(i)
			if m is StandardMaterial3D:
				var copy = m.duplicate(); copy.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED; copy.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA; copy.cull_mode = BaseMaterial3D.CULL_DISABLED
				copy.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
				node.set_surface_override_material(i, copy)
	for child in node.get_children(): prepare_materials(child)

func update(state, delta: float) -> void:
	clock += delta; swing = maxf(0.0, swing - delta * 3.5); hit = maxf(0.0, hit - delta * 4)
	if not is_instance_valid(scene): return
	mining = state.farming and not state.expedition.active
	if hero_index != state.hero_id or hero_mining != mining or hero_skin != state.star_skin:
		hero_index = state.hero_id; hero_mining = mining; hero_skin = state.star_skin; hero_color = Color(state.HEROES[hero_index].color)
		if hero_index > 0 or hero_skin:
			selected_hero.texture = Art.hero(hero_index, mining, hero_skin)
			selected_hero.pixel_size = minf(4.2 / selected_hero.texture.get_height(), 4.3 / selected_hero.texture.get_width())
	selected_hero.visible = hero_index > 0 or hero_skin
	if selected_hero.visible:
		var height = selected_hero.texture.get_height() * selected_hero.pixel_size
		var pulse = sin(swing * PI)
		var advance = [0.28, - 0.05, - 0.15, 0.2, 0.36, 0.03, 0.42][hero_index]
		var lift = [0.02, 0.1, 0.01, 0.16, 0.02, 0.15, 0.08][hero_index]
		var turn = [- 0.09, 0.04, 0.065, - 0.08, - 0.12, 0.05, - 0.15][hero_index]
		selected_hero.position = Vector3(-1.45 + pulse * advance, height / 2 - 0.35 + absf(sin(clock * 1.7)) * 0.018 + pulse * lift, 0.25)
		selected_hero.rotation.z = pulse * (- 0.09 if mining else turn)
	var index = state.expedition.ART[state.expedition.boss_index] if state.expedition.active else Art.foe_index(state.stage, state.region(), state.boss())
	if index != enemy_index:
		enemy_index = index
		if index >= 0: enemy_sprite.texture = Art.enemy(index)
	for i in range(summons.size()):
		summons[i].visible = state.expedition.active and state.expedition.boss_index == 2 and i < state.expedition.adds
		summons[i].position = Vector3(1.15 + i * 0.68, 0.4 + absf(sin(clock * 2 + i)) * 0.035, 2.0 + i * 0.02)
	enemy_sprite.visible = not mining and index >= 0
	if index >= 0:
		var height = (4.4 if state.boss() or state.expedition.active else 3.4) if index != 5 else 3.7
		enemy_sprite.pixel_size = minf(height / enemy_sprite.texture.get_height(), 4.7 / enemy_sprite.texture.get_width())
		var rendered_height = enemy_sprite.texture.get_height() * enemy_sprite.pixel_size
		enemy_sprite.position = Vector3(2.05 + hit * 0.08, rendered_height / 2 - 0.15, 0)
		enemy_sprite.rotation.z = hit * 0.025
		enemy_sprite.modulate = Color("#c7ffce") if (state.region() == 0 or state.expedition.active) and index == 4 else Color.WHITE
	if hero: hero.visible = not mining and hero_index == 0 and not hero_skin
	if foe: foe.visible = not mining and index < 0
	if miner:
		miner.visible = mining and hero_index == 0 and not hero_skin
		miner.position = miner_base + Vector3(sin(swing * PI) * 0.12, 0, 0)
		miner.rotation.z = sin(swing * PI) * -0.09
	if ore:
		ore.visible = mining
		ore.position = ore_base + Vector3(sin(hit * 19) * hit * 0.04, 0, 0)
	mine_clock += delta
	if mining and mine_clock > 0.8:
		mine_clock = 0; impact()
	if hero:
		hero.position = hero_base + Vector3(sin(swing * PI) * 0.28, absf(sin(clock * 1.7)) * 0.018, 0)
		hero.rotation.z = sin(swing * PI) * -0.09
	if foe:
		foe.position = foe_base + Vector3(hit * 0.1, sin(clock * 1.5) * 0.015, 0)
		foe.rotation.z = hit * 0.025
		foe.scale = Vector3.ONE * (1.0 if state.boss() else 0.87)
	active_party.clear()
	for i in range(party.size()):
		var fighter = party[i]; fighter.visible = int(state.allies[i]) > 0
		if fighter.visible: active_party.append(i)
	for order in range(active_party.size()):
		var i = active_party[order]; var fighter = party[i]
		var span = minf(5.8, maxf(1.0, active_party.size() * 1.15))
		var x = -3.0 + order * span / maxf(1, active_party.size() - 1)
		var burst = fmod(clock + float(i) * 0.2, 1.3)
		if i == 0:
			fighter.scale = Vector3.ONE * (0.7 if active_party.size() > 1 else 1.0)
			if active_party.size() == 1: x = -2.65
			fighter.position = Vector3(x, - 0.15 + absf(sin(clock * 3)) * 0.03, 3.0)
		else:
			var height = fighter.texture.get_height() * fighter.pixel_size
			fighter.scale = Vector3.ONE * (1.0 + minf(0.15, int(state.allies[i]) / 25.0 * 0.025))
			fighter.position = Vector3(x + sin(burst * TAU) * 0.025, height / 2 - 0.15 + absf(sin(clock * 2 + i)) * 0.025, 3.0 + float(i) * 0.005)
			fighter.rotation.z = sin(burst * TAU) * 0.025
		party_clocks[i] += delta
		if party_clocks[i] > 1.5 + float(i) * 0.1:
			party_clocks[i] = 0; ally_attack(i, fighter.position)
	for i in range(projectiles.size() - 1, -1, -1):
		var missile = projectiles[i]
		missile.position += missile.get_meta("velocity") * delta
		var life = float(missile.get_meta("life")) - delta; missile.set_meta("life", life)
		if life <= 0:
			missile.queue_free(); projectiles.remove_at(i)
	for i in range(sparks.size() - 1, -1, -1):
		var p = sparks[i]; p.position += p.get_meta("velocity") * delta; p.modulate.a -= delta * 2.5
		if p.modulate.a <= 0: p.queue_free(); sparks.remove_at(i)

func impact() -> void:
	hit = 1; swing = 1
	if not is_instance_valid(actor_layer): return
	var top = viewport_image.position.y
	last_attack_style = "Удар киркой" if mining else ATTACK_STYLES[maxi(0, hero_index)]
	if not mining:
		var origin = Vector2(315, view_size.y * 0.6)
		var target = Vector2(475, view_size.y * 0.54)
		match maxi(0, hero_index):
			0:
				attack_trail([origin + Vector2(-20, 35), origin + Vector2(30, -30), target + Vector2(25, 10)], hero_color, 7, 0.24)
			1:
				for i in range(3):
					var offset = Vector2(0, (i - 1) * 23)
					attack_trail([origin + offset, target + offset], hero_color, 5, 0.4)
					attack_trail([target + offset + Vector2(-13, -9), target + offset + Vector2(9, 0), target + offset + Vector2(-13, 9)], Color("#e2f9ff"), 3, 0.4)
			2:
				for i in range(3):
					var offset = Vector2(0, (i - 1) * 19)
					attack_trail([origin + offset, target + offset], Color("#baed93"), 2, 0.22)
					attack_trail([target + offset + Vector2(-12, -6), target + offset, target + offset + Vector2(-12, 6)], hero_color, 3, 0.22)
			3:
				attack_trail([target + Vector2(0, -100), target + Vector2(0, 55)], Color("#fff1b9"), 12, 0.38)
				attack_trail([target + Vector2(-43, 0), target + Vector2(43, 0)], hero_color, 5, 0.38)
				attack_ring(target, Color("#ffe5a1"), 48, 0.38)
			4:
				var zigzag = []
				for i in range(9): zigzag.append(origin.lerp(target, i / 8.0) + Vector2(0, 0 if i in [0, 8] else (-20 if i % 2 == 0 else 20)))
				attack_trail(zigzag, hero_color, 7, 0.18)
				attack_trail(zigzag, Color.WHITE, 2, 0.18)
			5:
				for i in range(3):
					var start = origin + Vector2(-20, (i - 1) * 30)
					var orb = ColorRect.new(); actor_layer.add_child(orb); orb.color = hero_color; orb.size = Vector2(12, 12) * scale_factor; orb.mouse_filter = Control.MOUSE_FILTER_IGNORE; orb.z_index = 3
					orb.position = start * scale_factor + Vector2(0, top)
					var tween = root.create_tween(); tween.tween_property(orb, "position", (origin + Vector2(80, (i - 1) * 55)) * scale_factor + Vector2(0, top), 0.15); tween.tween_property(orb, "position", target * scale_factor + Vector2(0, top), 0.18); tween.tween_callback(orb.queue_free)
				attack_ring(target, hero_color, 35, 0.4)
			6:
				attack_trail([origin + Vector2(-15, -55), target + Vector2(30, 35)], Color("#ff7752"), 13, 0.32)
				attack_trail([origin + Vector2(-15, 55), target + Vector2(30, -35)], Color("#ffcf7c"), 8, 0.32)
				attack_ring(target, Color("#ff9450"), 60, 0.32)
	for i in range(15):
		var p = ColorRect.new(); actor_layer.add_child(p); p.color = (Color("#6c7079") if i % 3 == 0 else Color("#ffc760")) if mining else hero_color if i % 2 == 0 else Color("#fff4b7"); p.size = Vector2(randf_range(3, 8), randf_range(3, 8)) * scale_factor
		p.position = Vector2((510 if mining else 468) * scale_factor, top + view_size.y * (0.72 if mining else 0.55) * scale_factor); p.mouse_filter = Control.MOUSE_FILTER_IGNORE; p.z_index = 3
		p.set_meta("velocity", Vector2(randf_range(-100, 140), randf_range(-140, 75)) * scale_factor); sparks.append(p)

func ally_attack(index: int, origin: Vector3) -> void:
	if not is_instance_valid(scene): return
	var missile = MeshInstance3D.new(); scene.add_child(missile)
	var mesh = SphereMesh.new(); mesh.radius = 0.035 if index == 1 else 0.065; mesh.height = mesh.radius * 2; missile.mesh = mesh
	missile.scale = Vector3(4, 0.55, 1) if index == 1 else Vector3.ONE
	var material = StandardMaterial3D.new(); material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color(["#ffac46", "#b8ef83", "#69c8ff", "#ffe28b", "#c98aff", "#ff784b", "#5cfff0", "#ff993e"][index]); missile.material_override = material
	missile.position = origin + Vector3(0.25, 0.3, 0.12)
	var target = Vector3(2.2, 1.35, 0.75)
	missile.set_meta("velocity", (target - missile.position).normalized() * 6.5); missile.set_meta("life", 0.75); projectiles.append(missile)

func attack_trail(points: Array, color: Color, width: float, duration: float) -> void:
	var trail = Line2D.new(); actor_layer.add_child(trail); trail.width = width * scale_factor; trail.default_color = color; trail.z_index = 3
	var path = PackedVector2Array()
	for point in points: path.append(point * scale_factor)
	trail.points = path; trail.position.y = viewport_image.position.y
	var tween = root.create_tween(); tween.tween_property(trail, "modulate:a", 0.0, duration); tween.tween_callback(trail.queue_free)

func attack_ring(center: Vector2, color: Color, radius: float, duration: float) -> void:
	var points = []
	for i in range(25): points.append(center + Vector2(cos(i * TAU / 24), sin(i * TAU / 24)) * radius)
	attack_trail(points, color, 3, duration)

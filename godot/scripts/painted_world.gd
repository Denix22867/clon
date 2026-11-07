extends RefCounted
## Сцена боя в 2.5D: объёмные модели (scripts/models) на нарисованном фоне.
## Перспективная камера слегка сверху, герой и враг стоят вполоборота к зрителю,
## союзники — в два ряда позади, у всех мягкие тени. Эффекты ударов рисуются поверх
## в 2D, но их точки берутся из проекции 3D-позиций.

const Art = preload("res://scripts/art_catalog.gd")
const Chars = preload("res://scripts/models/characters.gd")
const Rig = preload("res://scripts/models/rig.gd")
const BLOB = preload("res://assets/models3d/shadow_blob.gdshader")

const HERO_POS = Vector3(-1.75, 0, 0.75)
const ENEMY_POS = Vector3(1.8, 0, 0.15)
const ORE_POS = Vector3(-0.35, 0, 0.85)
const FACE_RIGHT = -0.55
const FACE_LEFT = PI + 0.55
const HERO_HEIGHT = 2.75
## Рост врагов по номеру рисунка (art_catalog.foe_index); боссы крупнее.
const ENEMY_HEIGHT = {-1: 3.0, 0: 2.0, 1: 2.95, 2: 3.1, 3: 3.0, 4: 3.0, 5: 3.1, 6: 3.0, 7: 2.9, 8: 3.3}
const ALLY_HEIGHT = [0.95, 1.95, 1.95, 2.0, 2.05, 2.05, 1.95, 1.7]
const ALLY_COLORS = ["#ffac46", "#b8ef83", "#69c8ff", "#ffe28b", "#c98aff", "#ff784b", "#5cfff0", "#ff993e"]
const ATTACK_STYLES = ["Огненная дуга", "Ледяные осколки", "Тройная стрела", "Свет рассвета", "Разряд молнии", "Сферы душ", "Пламя дракона"]

var root: Node3D
var view: SubViewport
var viewport_image: TextureRect
var scene: Node3D
var camera: Camera3D
var actor_layer: Control
var view_size = Vector2(720, 500)
var scale_factor = 1.0

var hero: Node3D
var hero_models := {}
var foe: Node3D
var foe_models := {}
var ore: Node3D
var party: Array = []
var party_clocks: Array = []
var party_attack: Array = []
var summons: Array = []
var shadows := {}
var projectiles: Array = []
var sparks: Array = []

var clock := 0.0
var hero_attack := 9.0     # секунды с последнего удара героя
var foe_spawn := 9.0       # секунды с появления врага
var mine_clock := 0.0
var mining = false
var hero_index = -1
var hero_skin = false
var enemy_index = -99
var foe_height := 3.0
var active_party: Array = []
var last_attack_style = "Огненная дуга"
var hero_color = Color("#ffb35b")

func setup(parent: Node3D) -> void: root = parent
func layout(_rect: Rect2, _screen: Vector2, _camera: Camera3D) -> void: pass

func attach(parent: Control, size: Vector2, top: float, factor: float, _hero_tex: Texture2D, _foe_tex: Texture2D, _fox_tex: Texture2D) -> void:
	sparks.clear(); projectiles.clear(); summons.clear(); party.clear(); party_clocks.clear(); party_attack.clear()
	hero_models.clear(); foe_models.clear(); shadows.clear(); hero = null; foe = null
	enemy_index = -99; hero_index = -1
	if is_instance_valid(view): view.queue_free()
	if is_instance_valid(viewport_image): viewport_image.queue_free()
	actor_layer = parent; view_size = size; scale_factor = factor
	view = SubViewport.new(); root.add_child(view); view.size = Vector2i(int(size.x * factor), int(size.y * factor)); view.transparent_bg = true
	view.render_target_update_mode = SubViewport.UPDATE_ALWAYS; view.own_world_3d = true; view.msaa_3d = Viewport.MSAA_2X
	scene = Node3D.new(); view.add_child(scene)
	_lighting()
	ore = _spawn(Rig.instance("ore", Chars.ore), 1.35)
	for i in range(8):
		var fighter := _spawn(Rig.instance("ally%d" % i, Chars.ally.bind(i)), ALLY_HEIGHT[i])
		party.append(fighter); party_clocks.append(float(i) * 0.18); party_attack.append(9.0)
	for i in range(3):
		summons.append(_spawn(Rig.instance("enemy0", Chars.enemy.bind(0)), 1.5))
	camera = Camera3D.new(); view.add_child(camera)
	camera.keep_aspect = Camera3D.KEEP_WIDTH; camera.fov = 30; camera.near = 0.5; camera.far = 60
	var half_h := 13.0 * tan(deg_to_rad(15)) * size.y / size.x
	var look := Vector3(0, half_h - 0.75, 0)
	camera.look_at_from_position(Vector3(0, look.y + 1.5, 13), look); camera.current = true
	viewport_image = TextureRect.new(); parent.add_child(viewport_image); viewport_image.texture = view.get_texture()
	viewport_image.position = Vector2(0, top) * factor; viewport_image.size = size * factor; viewport_image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE; viewport_image.stretch_mode = TextureRect.STRETCH_SCALE; viewport_image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	viewport_image.z_index = 0

func _lighting() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_CLEAR_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("#b4b8d6"); env.ambient_light_energy = 0.7
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	var we := WorldEnvironment.new(); we.environment = env; scene.add_child(we)
	var key := DirectionalLight3D.new(); key.rotation_degrees = Vector3(-42, -28, 0)
	key.light_color = Color("#fff0d8"); key.light_energy = 1.35; scene.add_child(key)
	var back := DirectionalLight3D.new(); back.rotation_degrees = Vector3(-20, 150, 0)
	back.light_color = Color("#ffcf8a"); back.light_energy = 0.35; scene.add_child(back)

## Добавляет модель в сцену, подгоняет рост и создаёт тень. Возвращает модель (изначально скрытую).
func _spawn(model: Node3D, height: float) -> Node3D:
	var bounds: AABB = model.get_meta("bounds")
	var s := height / maxf(0.1, bounds.size.y)
	model.scale = Vector3.ONE * s; model.set_meta("base_scale", s); model.visible = false
	scene.add_child(model)
	var blob := MeshInstance3D.new(); var plane := PlaneMesh.new(); plane.size = Vector2.ONE; blob.mesh = plane
	var m := ShaderMaterial.new(); m.shader = BLOB; blob.material_override = m
	blob.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var w := clampf(maxf(bounds.size.x, bounds.size.z) * s * 0.6, 0.6, 2.6)
	blob.scale = Vector3(w * 1.4, 1, w * 0.8); blob.visible = false
	scene.add_child(blob); shadows[model] = blob
	return model

func _place(model: Node3D, pos: Vector3, facing: float, scale_mul := 1.0) -> void:
	model.visible = true; model.position = pos; model.rotation.y = facing
	model.scale = Vector3.ONE * float(model.get_meta("base_scale")) * scale_mul
	var blob: MeshInstance3D = shadows[model]
	blob.visible = true; blob.position = Vector3(pos.x, 0.015, pos.z)
	var hover := 0.0
	if model.has_meta("float"): hover = 0.25
	(blob.material_override as ShaderMaterial).set_shader_parameter("strength", 0.42 * scale_mul / (1.0 + hover))

func _hide(model: Node3D) -> void:
	if model == null: return
	model.visible = false; shadows[model].visible = false

func _hero_model() -> Node3D:
	var key := "%d_%s" % [hero_index, hero_skin]
	if not hero_models.has(key):
		hero_models[key] = _spawn(Rig.instance("hero" + key, Chars.hero.bind(hero_index, hero_skin)), HERO_HEIGHT)
	return hero_models[key]

func _foe_model(index: int) -> Node3D:
	if not foe_models.has(index):
		var model := Rig.instance("enemy%d" % index, Chars.enemy.bind(index))
		foe_models[index] = _spawn(model, 1.0)
		model.set_meta("unit_scale", model.get_meta("base_scale"))
	return foe_models[index]

func update(state, delta: float) -> void:
	clock += delta; hero_attack += delta; foe_spawn += delta
	if not is_instance_valid(scene): return
	mining = state.farming and not state.expedition.active

	# --- герой
	if hero_index != state.hero_id or hero_skin != state.star_skin or hero == null:
		_hide(hero)
		hero_index = state.hero_id; hero_skin = state.star_skin; hero_color = Color(state.HEROES[hero_index].color)
		hero = _hero_model()
	var bones: Dictionary = hero.get_meta("bones")
	for name in ["Weapon", "Offhand"]:
		if bones.has(name): bones[name].visible = not mining
	if bones.has("Pickaxe"): bones["Pickaxe"].visible = mining
	_place(hero, HERO_POS, FACE_RIGHT + (0.25 if mining else 0.0))
	Rig.pose(hero, clock, hero_attack, 0.0, "mine" if mining else hero.get_meta("style"))
	Rig.set_flash(hero, hero_color, maxf(0.0, 0.35 - hero_attack * 2.0) if hero_attack < 0.2 else 0.0)

	# --- враг
	var index = state.expedition.ART[state.expedition.boss_index] if state.expedition.active else Art.foe_index(state.stage, state.region(), state.boss())
	var big: bool = state.boss() or state.expedition.active
	if index != enemy_index:
		_hide(foe)
		enemy_index = index; foe = _foe_model(index); foe_spawn = 0.0
		Rig.set_tint(foe, Color("#c7ffce") if index == 4 and (state.region() == 0 or state.expedition.active) else Color.WHITE)
	foe_height = float(ENEMY_HEIGHT.get(index, 3.0)) * (1.25 if big else 1.0)
	foe.set_meta("base_scale", float(foe.get_meta("unit_scale")) * foe_height)
	if mining:
		_hide(foe)
	else:
		var pop := 1.0 - pow(1.0 - clampf(foe_spawn / 0.35, 0.0, 1.0), 3.0)
		var hurt := Rig.hurt_curve(hero_attack)
		_place(foe, ENEMY_POS + Vector3(hurt * 0.12, 0, 0), FACE_LEFT, lerpf(0.5, 1.0, pop))
		Rig.pose(foe, clock * 0.9 + 1.7, 9.0, hurt, foe.get_meta("style"))
		Rig.set_flash(foe, Color.WHITE, hurt * 0.7 + (1.0 - pop) * 0.6)

	# --- призванные слуги (третий босс экспедиции)
	for i in range(summons.size()):
		if state.expedition.active and state.expedition.boss_index == 2 and i < state.expedition.adds:
			_place(summons[i], Vector3(0.75 + i * 0.75, 0, 1.55 + i * 0.25), FACE_LEFT)
			Rig.pose(summons[i], clock + i, 9.0, 0.0, "melee")
		else:
			_hide(summons[i])

	# --- рудная жила
	if mining:
		var hurt := Rig.hurt_curve(hero_attack)
		_place(ore, ORE_POS + Vector3(sin(hero_attack * 60.0) * hurt * 0.05, 0, 0), 0.3)
		Rig.set_flash(ore, Color("#ffd27a"), hurt * 0.8)
		mine_clock += delta
		if mine_clock > 0.8:
			mine_clock = 0; impact()
	else:
		_hide(ore)

	# --- союзники: лиса впереди, остальные в два ряда позади героя
	active_party.clear()
	for i in range(party.size()):
		if int(state.allies[i]) > 0: active_party.append(i)
		else: _hide(party[i])
	var back_row: Array = active_party.filter(func(i): return i != 0 and i != 7)
	for order in range(back_row.size()):
		var i: int = back_row[order]
		var x := -3.6 + order * minf(0.95, 3.9 / maxf(1, back_row.size() - 1))
		var z := -1.1 if order % 2 == 0 else -2.3
		var grow := 1.0 + minf(0.15, int(state.allies[i]) / 25.0 * 0.025)
		_place(party[i], Vector3(x, 0, z), FACE_RIGHT + 0.15, grow)
	if 0 in active_party:
		_place(party[0], Vector3(-2.35, 0, 1.95), FACE_RIGHT - 0.2)
	if 7 in active_party:
		_place(party[7], Vector3(-1.9, 0, -3.8), FACE_RIGHT + 0.35)
	for i in active_party:
		party_attack[i] += delta; party_clocks[i] += delta
		Rig.pose(party[i], clock + i * 0.37, party_attack[i], 0.0, party[i].get_meta("style"))
		if party_clocks[i] > 1.5 + float(i) * 0.1:
			party_clocks[i] = 0; party_attack[i] = 0.0
			if not mining: ally_attack(i)

	# --- снаряды и искры
	for i in range(projectiles.size() - 1, -1, -1):
		var missile = projectiles[i]
		var wait = float(missile.get_meta("wait")) - delta; missile.set_meta("wait", wait)
		if wait > 0: continue
		missile.visible = true
		missile.position += missile.get_meta("velocity") * delta
		var life = float(missile.get_meta("life")) - delta; missile.set_meta("life", life)
		if life <= 0:
			missile.queue_free(); projectiles.remove_at(i)
	for i in range(sparks.size() - 1, -1, -1):
		var p = sparks[i]; p.position += p.get_meta("velocity") * delta; p.modulate.a -= delta * 2.5
		if p.modulate.a <= 0: p.queue_free(); sparks.remove_at(i)

## Точка 3D-сцены в координатах слоя эффектов (единицы view_size, без scale_factor).
func screen_point(p: Vector3) -> Vector2:
	if not is_instance_valid(camera): return Vector2.ZERO
	return camera.unproject_position(p) / scale_factor

func foe_center() -> Vector3:
	return ENEMY_POS + Vector3(-0.2, foe_height * 0.5, 0.3)

func impact() -> void:
	hero_attack = 0.0
	if not is_instance_valid(actor_layer) or not is_instance_valid(camera): return
	last_attack_style = "Удар киркой" if mining else ATTACK_STYLES[maxi(0, hero_index)]
	# эффекты появляются в момент попадания, а не в начале замаха
	var timer := root.create_tween(); timer.tween_interval(Rig.STRIKE); timer.tween_callback(_impact_effects)

func _impact_effects() -> void:
	if not is_instance_valid(actor_layer) or not is_instance_valid(camera): return
	var top = viewport_image.position.y
	var origin := screen_point(HERO_POS + Vector3(0.75, 1.75, 0.3))
	var target := screen_point(foe_center())
	var burst_at := screen_point(ORE_POS + Vector3(0, 1.0, 0.3)) if mining else target
	if not mining:
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
		p.position = burst_at * scale_factor + Vector2(0, top); p.mouse_filter = Control.MOUSE_FILTER_IGNORE; p.z_index = 3
		p.set_meta("velocity", Vector2(randf_range(-100, 140), randf_range(-140, 75)) * scale_factor); sparks.append(p)

## Снаряд союзника: светящаяся капля летит из руки (или пасти) к врагу.
func ally_attack(index: int) -> void:
	if not is_instance_valid(scene): return
	var fighter: Node3D = party[index]
	var missile = MeshInstance3D.new(); scene.add_child(missile)
	var mesh = SphereMesh.new(); mesh.radius = 0.04 if index == 1 else 0.075; mesh.height = mesh.radius * 2; mesh.radial_segments = 8; mesh.rings = 4; missile.mesh = mesh
	var material = StandardMaterial3D.new(); material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color(ALLY_COLORS[index]); missile.material_override = material
	var height: float = ALLY_HEIGHT[index] * float(fighter.scale.x / float(fighter.get_meta("base_scale")))
	missile.position = fighter.position + Vector3(0.35, height * (0.45 if index == 0 else 0.62), 0.1)
	var target := foe_center() + Vector3(randf_range(-0.2, 0.2), randf_range(-0.3, 0.3), 0)
	var direction: Vector3 = (target - missile.position).normalized()
	if index == 1: missile.scale = Vector3(4, 0.55, 1); missile.look_at_from_position(missile.position, target); missile.rotate_object_local(Vector3.UP, PI / 2)
	missile.set_meta("velocity", direction * 7.5); missile.set_meta("life", missile.position.distance_to(target) / 7.5)
	missile.set_meta("wait", Rig.STRIKE); missile.visible = false
	projectiles.append(missile)

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

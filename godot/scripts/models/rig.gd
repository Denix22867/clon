extends RefCounted
## Процедурная анимация моделей из characters.gd.
## Каждая кость хранит позу покоя (meta rest_position / rest_rotation); здесь к ней добавляются смещения.

const Overrides = preload("res://scripts/models/overrides.gd")

const WINDUP := 0.1   # замах
const STRIKE := 0.17   # момент попадания
const RECOVER := 0.6   # возврат в стойку

static var _templates := {}

## Экземпляр модели из кэша: построение медленнее копирования, а сцена пересобирается при смене вкладок.
## У каждой копии свой материал, чтобы вспышки и оттенки не задевали другие копии.
static func instance(key: String, builder: Callable) -> Node3D:
	if not _templates.has(key):
		var built: Node3D = builder.call()
		var replacement := Overrides.load_override(key, built)
		if replacement != null:
			built.free(); built = replacement
		var names: Array = (built.get_meta("bones") as Dictionary).keys()
		built.remove_meta("bones")
		for node in built.find_children("*", "", true, false): node.owner = built
		var packed := PackedScene.new(); packed.pack(built); built.free()
		_templates[key] = {"scene": packed, "bones": names}
	var template: Dictionary = _templates[key]
	var copy: Node3D = (template.scene as PackedScene).instantiate()
	var material: ShaderMaterial = (copy.get_meta("material") as ShaderMaterial).duplicate()
	copy.set_meta("material", material)
	var bones := {}
	for name in template.bones:
		var node := copy.find_child(name, true, false)
		if node: bones[name] = node
	copy.set_meta("bones", bones)
	for mi in copy.find_children("*", "MeshInstance3D", true, false):
		(mi as MeshInstance3D).material_override = material
	return copy

static func set_flash(model: Node3D, color: Color, amount: float) -> void:
	var m: ShaderMaterial = model.get_meta("material")
	m.set_shader_parameter("flash", Color(color.r, color.g, color.b, clampf(amount, 0.0, 1.0)))

static func set_tint(model: Node3D, color: Color) -> void:
	(model.get_meta("material") as ShaderMaterial).set_shader_parameter("tint", color)

## Кривая удара по времени после нажатия: 0 → 1 (замах) → -1 (удар) → 0 (стойка).
static func strike_curve(t: float) -> float:
	if t < 0.0 or t > RECOVER: return 0.0
	if t < WINDUP: return smoothstep(0.0, WINDUP, t)
	if t < STRIKE: return lerpf(1.0, -1.0, smoothstep(WINDUP, STRIKE, t))
	return -1.0 + smoothstep(STRIKE, RECOVER, t)

## Сила отдачи у цели после удара (0..1).
static func hurt_curve(t: float) -> float:
	if t < STRIKE or t > STRIKE + 0.45: return 0.0
	var k := (t - STRIKE) / 0.45
	return (1.0 - k) * (1.0 - k)

static func _apply(bones: Dictionary, name: String, rot: Vector3, pos := Vector3.ZERO) -> void:
	if not bones.has(name): return
	var n: Node3D = bones[name]
	n.rotation = n.get_meta("rest_rotation") + rot
	n.position = n.get_meta("rest_position") + pos

static func pose(model: Node3D, time: float, attack_time: float, hurt: float, style: String) -> void:
	var b: Dictionary = model.get_meta("bones")
	var k := strike_curve(attack_time)
	var up := maxf(k, 0.0); var dn := maxf(-k, 0.0)
	var breathe := sin(time * 2.1)
	var hips := Vector3(0, breathe * 0.015, 0)
	if model.has_meta("float"): hips.y += sin(time * 1.6) * 0.1 + 0.05
	var torso := Vector3(0, 0, breathe * 0.02 + hurt * 0.25)
	var head := Vector3(0, sin(time * 0.9) * 0.05, sin(time * 1.3) * 0.035 + hurt * 0.18)
	var arm_r := Vector3(0, 0, sin(time * 2.1 + 0.6) * 0.035 - hurt * 0.2)
	var arm_l := Vector3(0, 0, sin(time * 2.1 + 1.4) * 0.035 - hurt * 0.2)
	var arm_r_pos := Vector3.ZERO
	match style:
		"melee", "great", "brute", "mine":
			var big := 1.3 if style == "great" or style == "mine" else 1.0
			arm_r.z += up * 1.75 * big - dn * 0.8
			arm_l.z += (up * 1.2 - dn * 0.6) if style == "great" else (up * 0.45 - dn * 0.25)
			torso.z += up * 0.2 - dn * 0.3
			hips.x += -up * 0.06 + dn * 0.14
			if style == "brute": arm_l.z += -up * 0.3 + dn * 1.2
		"spear":
			arm_r.z += -up * 0.3 + dn * 0.25
			arm_r_pos.x += -up * 0.28 + dn * 0.5
			torso.z += up * 0.12 - dn * 0.25
			hips.x += dn * 0.18
		"cast":
			arm_r.z += up * 0.7 + dn * 0.25
			arm_l.z += up * 0.35 + dn * 1.05
			torso.z += up * 0.1 - dn * 0.14
			head.z += up * 0.1
		"bow":
			arm_r.z += -up * 0.2 + dn * 0.25
			arm_r_pos.x += -up * 0.14 + dn * 0.05
			torso.z += up * 0.06 - dn * 0.04
		"bite":
			head.z += up * 0.4 - dn * 0.6
			torso.z += up * 0.14 - dn * 0.2
			hips.x += dn * 0.3
		"slam":
			arm_r.z += up * 2.3 - dn * 0.7
			arm_l.z += up * 2.3 - dn * 0.7
			torso.z += up * 0.22 - dn * 0.38
	_apply(b, "Hips", Vector3.ZERO, hips)
	_apply(b, "Torso", torso)
	_apply(b, "Head", head)
	_apply(b, "ArmR", arm_r, arm_r_pos)
	_apply(b, "ArmL", arm_l)
	_apply(b, "Cape", Vector3(sin(time * 1.7) * 0.07, 0, sin(time * 1.9) * 0.08 + up * 0.12 - dn * 0.18))
	_apply(b, "Tail", Vector3(0, sin(time * 1.8) * 0.25, sin(time * 2.3) * 0.08))
	var flap := sin(time * 3.2) * 0.22 + up * 0.35
	_apply(b, "WingL", Vector3(flap, 0, 0))
	_apply(b, "WingR", Vector3(-flap, 0, 0))

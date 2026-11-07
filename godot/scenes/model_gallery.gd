extends Node3D
## Галерея 3D-моделей: запустите сцену (F6), чтобы осмотреть всех персонажей.
## Модели медленно вращаются и по очереди показывают атаку.
## Сами модели описаны кодом в scripts/models/characters.gd.

const Chars = preload("res://scripts/models/characters.gd")
const Rig = preload("res://scripts/models/rig.gd")

var models: Array = []
var clock := 0.0

func _ready() -> void:
	var list := []
	for i in 7: list.append(["Герой %d" % i, Chars.hero.bind(i), "hero%d_false" % i])
	list.append(["Искра (звёздный облик)", Chars.hero.bind(0, true), "hero0_true"])
	for i in 8: list.append(["Союзник %d" % i, Chars.ally.bind(i), "ally%d" % i])
	for i in range(-1, 9): list.append(["Враг %d" % i, Chars.enemy.bind(i), "enemy%d" % i])
	list.append(["Рудная жила", Chars.ore, "ore"])
	var cols := 7
	for n in list.size():
		var model := Rig.instance(list[n][2], list[n][1])
		var bounds: AABB = model.get_meta("bounds")
		model.scale = Vector3.ONE * (2.4 / maxf(bounds.size.y, bounds.size.x * 0.6))
		model.position = Vector3((n % cols - (cols - 1) / 2.0) * 3.3, 0, -floorf(n / float(cols)) * 4.2)
		add_child(model)
		var label := Label3D.new(); label.text = list[n][0]; label.position = model.position + Vector3(0, -0.3, 0.6); label.font_size = 48; label.pixel_size = 0.006
		add_child(label)
		models.append(model)
	$Camera.look_at_from_position(Vector3(0, 13, 9), Vector3(0, 0.5, -5.6))

func _process(delta: float) -> void:
	clock += delta
	for n in models.size():
		var model: Node3D = models[n]
		model.rotation.y = -0.55 + sin(clock * 0.4 + n) * 0.6
		var attack := fmod(clock + n * 0.37, 2.5)
		Rig.pose(model, clock + n, attack, 0.0, model.get_meta("style"))

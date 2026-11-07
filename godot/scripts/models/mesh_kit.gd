extends RefCounted
## Процедурное моделирование из примитивов.
##
## Модель — это дерево «костей» (Node3D). Всё, что добавлено в кость, сливается в один
## MeshInstance3D: цвет хранится в вершинах, сила свечения — в UV.x. Поэтому каждая кость
## рисуется одним вызовом с общим мультяшным материалом.
##
## Координаты задаются в пространстве модели (персонаж смотрит в +X, вверх +Y, правая сторона +Z,
## ступни на y = 0). Кость хранит абсолютную точку поворота; геометрия пересчитывается в её локальные координаты.

const TOON = preload("res://assets/models3d/toon.gdshader")
const TOON_GHOST = preload("res://assets/models3d/toon_ghost.gdshader")
const OUTLINE = preload("res://assets/models3d/outline.gdshader")

var s := 1.0               # общий масштаб, применяется к позициям и размерам
var ghost := false         # полупрозрачная модель (призраки)
var outline_width := 0.022
var _order: Array = []
var _bones := {}           # name -> {parent, pos, rot, v, n, c, u, i}

# ---------------------------------------------------------------- кости

func bone(name: String, parent: String, pos: Vector3, rest_rot := Vector3.ZERO) -> void:
	_bones[name] = {"parent": parent, "pos": pos, "rot": rest_rot,
		"v": PackedVector3Array(), "n": PackedVector3Array(), "c": PackedColorArray(), "u": PackedVector2Array(), "i": PackedInt32Array()}
	_order.append(name)

func has_bone(name: String) -> bool:
	return _bones.has(name)

# ---------------------------------------------------------------- низкий уровень

func _append(part: String, arrays: Array, xf: Transform3D, color: Color, emit: float) -> void:
	var b = _bones[part]
	var full := Transform3D(Basis.from_scale(Vector3.ONE * s), Vector3.ZERO) * xf
	full.origin -= b.pos * s
	var nb := full.basis.inverse().transposed()
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var norms: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var idx: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	var base: int = b.v.size()
	for k in verts.size():
		b.v.append(full * verts[k]); b.n.append((nb * norms[k]).normalized()); b.c.append(color); b.u.append(Vector2(emit, 0))
	if full.basis.determinant() < 0:
		for j in range(0, idx.size(), 3):
			b.i.append(base + idx[j]); b.i.append(base + idx[j + 2]); b.i.append(base + idx[j + 1])
	else:
		for j in idx: b.i.append(base + j)

static func basis_y(dir: Vector3) -> Basis:
	var y := dir.normalized()
	var ref := Vector3.RIGHT if absf(y.x) < 0.9 else Vector3.BACK
	var x := y.cross(ref).normalized()
	return Basis(x, y, x.cross(y))

static func euler(rot: Vector3) -> Basis:
	return Basis.from_euler(rot)

# ---------------------------------------------------------------- примитивы

func ball(part: String, pos: Vector3, r: float, color: Color, scale := Vector3.ONE, rot := Vector3.ZERO, emit := 0.0, detail := 10) -> void:
	var m := SphereMesh.new(); m.radius = r; m.height = r * 2; m.radial_segments = detail; m.rings = maxi(4, detail / 2)
	_append(part, m.get_mesh_arrays(), Transform3D(euler(rot) * Basis.from_scale(scale), pos), color, emit)

func box(part: String, pos: Vector3, size: Vector3, color: Color, rot := Vector3.ZERO, emit := 0.0) -> void:
	var m := BoxMesh.new(); m.size = size
	_append(part, m.get_mesh_arrays(), Transform3D(euler(rot), pos), color, emit)

## Усечённый конус от точки a (радиус ra) к точке b (радиус rb). squash сплющивает сечение по одной оси.
func tube(part: String, a: Vector3, b: Vector3, ra: float, rb: float, color: Color, emit := 0.0, seg := 8, squash := Vector3.ONE) -> void:
	var len := a.distance_to(b)
	if len < 0.0001: return
	var m := CylinderMesh.new(); m.height = len; m.bottom_radius = ra; m.top_radius = rb; m.radial_segments = seg; m.rings = 1
	var basis := basis_y(b - a) * Basis.from_scale(squash)
	_append(part, m.get_mesh_arrays(), Transform3D(basis, (a + b) * 0.5), color, emit)

## Конечность: трубка с шарами на концах (сглаженные суставы).
func limb(part: String, a: Vector3, b: Vector3, ra: float, rb: float, color: Color, emit := 0.0) -> void:
	tube(part, a, b, ra, rb, color, emit)
	ball(part, a, ra, color, Vector3.ONE, Vector3.ZERO, emit, 8)
	ball(part, b, rb, color, Vector3.ONE, Vector3.ZERO, emit, 8)

func cone(part: String, a: Vector3, b: Vector3, r: float, color: Color, emit := 0.0, seg := 7) -> void:
	tube(part, a, b, r, 0.0, color, emit, seg)

func ring(part: String, pos: Vector3, inner: float, outer: float, color: Color, rot := Vector3.ZERO, emit := 0.0) -> void:
	var m := TorusMesh.new(); m.inner_radius = inner; m.outer_radius = outer; m.rings = 16; m.ring_segments = 6
	_append(part, m.get_mesh_arrays(), Transform3D(euler(rot), pos), color, emit)

## Плоская фигура (контур в плоскости XY), выдавленная на depth по Z, затем повёрнутая и перенесённая.
## Используется для клинков, топоров, щитов, ушей, крыльев, плащей.
func slab(part: String, points: PackedVector2Array, depth: float, xf: Transform3D, color: Color, emit := 0.0) -> void:
	var tris := Geometry2D.triangulate_polygon(points)
	if tris.is_empty():
		points.reverse(); tris = Geometry2D.triangulate_polygon(points)
	var v := PackedVector3Array(); var n := PackedVector3Array(); var idx := PackedInt32Array()
	var h := depth * 0.5
	var ccw := _area(points) > 0
	for side in [1.0, -1.0]:
		var base := v.size()
		for p in points:
			v.append(Vector3(p.x, p.y, h * side)); n.append(Vector3(0, 0, side))
		for t in range(0, tris.size(), 3):
			_tri(v, idx, base + tris[t], base + tris[t + 1], base + tris[t + 2], Vector3(0, 0, side))
	var count := points.size()
	for k in count:
		var p0 := points[k]; var p1 := points[(k + 1) % count]
		var e := (p1 - p0).normalized()
		var normal := Vector3(e.y, -e.x, 0) if ccw else Vector3(-e.y, e.x, 0)
		var base := v.size()
		v.append_array([Vector3(p0.x, p0.y, h), Vector3(p1.x, p1.y, h), Vector3(p1.x, p1.y, -h), Vector3(p0.x, p0.y, -h)])
		for _i in 4: n.append(normal)
		_tri(v, idx, base, base + 1, base + 2, normal); _tri(v, idx, base, base + 2, base + 3, normal)
	var arrays := []; arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = v; arrays[Mesh.ARRAY_NORMAL] = n; arrays[Mesh.ARRAY_INDEX] = idx
	_append(part, arrays, xf, color, emit)

## Треугольник с порядком вершин, при котором его лицевая сторона смотрит по normal
## (в Godot лицевыми считаются грани, обходимые по часовой стрелке со стороны зрителя).
static func _tri(v: PackedVector3Array, idx: PackedInt32Array, a: int, b: int, c: int, normal: Vector3) -> void:
	if (v[b] - v[a]).cross(v[c] - v[a]).dot(normal) > 0:
		idx.append_array([a, c, b])
	else:
		idx.append_array([a, b, c])

static func _area(points: PackedVector2Array) -> float:
	var a := 0.0
	for k in points.size():
		var p := points[k]; var q := points[(k + 1) % points.size()]
		a += p.x * q.y - q.x * p.y
	return a * 0.5

## Плоская фигура, ориентированная по направлению: ось X фигуры идёт вдоль dir, ось Y — вдоль up.
func blade(part: String, origin: Vector3, dir: Vector3, up: Vector3, points: PackedVector2Array, depth: float, color: Color, emit := 0.0) -> void:
	var x := dir.normalized()
	var z := x.cross(up).normalized()
	var y := z.cross(x).normalized()
	slab(part, points, depth, Transform3D(Basis(x, y, z), origin), color, emit)

## Цепочка шаров вдоль ломаной (косы, хвосты, тела змей).
func chain(part: String, points: Array, r0: float, r1: float, color: Color, emit := 0.0, squash := Vector3.ONE) -> void:
	for k in points.size():
		var t := float(k) / maxf(1, points.size() - 1)
		var r := lerpf(r0, r1, t)
		ball(part, points[k], r, color, squash, Vector3.ZERO, emit, 8)
		if k > 0: tube(part, points[k - 1], points[k], lerpf(r0, r1, float(k - 1) / maxf(1, points.size() - 1)), r, color, emit, 8, squash)

# ---------------------------------------------------------------- сборка

func build(model_name: String) -> Node3D:
	var root := Node3D.new(); root.name = model_name
	var material := ShaderMaterial.new(); material.shader = TOON_GHOST if ghost else TOON
	var outline := ShaderMaterial.new(); outline.shader = OUTLINE; outline.set_shader_parameter("width", outline_width * s)
	if not ghost: material.next_pass = outline
	var nodes := {}
	var aabb := AABB(); var first := true
	for name in _order:
		var b = _bones[name]
		var node := Node3D.new(); node.name = name
		var parent_pos: Vector3 = _bones[b.parent].pos if b.parent != "" else Vector3.ZERO
		node.position = (b.pos - parent_pos) * s
		node.rotation = b.rot
		node.set_meta("rest_position", node.position); node.set_meta("rest_rotation", node.rotation)
		(nodes[b.parent] if b.parent != "" else root).add_child(node)
		nodes[name] = node
		if b.v.size() > 0:
			var arrays := []; arrays.resize(Mesh.ARRAY_MAX)
			arrays[Mesh.ARRAY_VERTEX] = b.v; arrays[Mesh.ARRAY_NORMAL] = b.n; arrays[Mesh.ARRAY_COLOR] = b.c
			arrays[Mesh.ARRAY_TEX_UV] = b.u; arrays[Mesh.ARRAY_INDEX] = b.i
			var mesh := ArrayMesh.new(); mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
			var mi := MeshInstance3D.new(); mi.name = "Mesh"; mi.mesh = mesh; mi.material_override = material
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			node.add_child(mi)
			var box_abs := AABB(b.pos * s + mesh.get_aabb().position, mesh.get_aabb().size)
			aabb = box_abs if first else aabb.merge(box_abs); first = false
	root.set_meta("material", material)
	root.set_meta("bounds", aabb)
	root.set_meta("bones", nodes)
	return root

extends Panel

var accent = Color("#b89452")
var active = false
var ornate = true
var bevel = true

func _ready() -> void:
	resized.connect(queue_redraw)

func _draw() -> void:
	var r = Rect2(Vector2.ZERO, size)
	if size.x < 10 or size.y < 10: return
	var s = clampf(size.x / 220.0, 0.7, 1.3)
	var corner = minf(11.0 * s, size.y * 0.15)
	var pts = PackedVector2Array([Vector2(corner, 1), Vector2(size.x - corner, 1), Vector2(size.x - 1, corner), Vector2(size.x - 1, size.y - corner), Vector2(size.x - corner, size.y - 1), Vector2(corner, size.y - 1), Vector2(1, size.y - corner), Vector2(1, corner), Vector2(corner, 1)])
	draw_polyline(pts, Color("#332b20"), maxf(2, s * 3), true)
	draw_polyline(pts, accent, maxf(1, s), true)
	draw_rect(r.grow(-4 * s), Color(accent, 0.18), false, maxf(1, s))
	if bevel:
		draw_line(Vector2(corner, 3 * s), Vector2(size.x - corner, 3 * s), Color("#f5d893"), maxf(1, s), true)
		draw_line(Vector2(corner, size.y - 3 * s), Vector2(size.x - corner, size.y - 3 * s), Color("#544027"), maxf(1, s), true)
	if ornate:
		for x in [corner, size.x - corner]:
			for y in [corner, size.y - corner]:
				var d = 4 * s
				draw_colored_polygon(PackedVector2Array([Vector2(x - d, y), Vector2(x, y - d), Vector2(x + d, y), Vector2(x, y + d)]), accent)
		var x = size.x / 2
		draw_colored_polygon(PackedVector2Array([Vector2(x - 5 * s, 1), Vector2(x, -3 * s), Vector2(x + 5 * s, 1), Vector2(x, 5 * s)]), Color("#ebc877"))

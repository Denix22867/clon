extends ScrollContainer

var dragging = false
var moved = false
var start = Vector2.ZERO
var previous = Vector2.ZERO
var touch_active = false

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_PASS
	scroll_deadzone = 12

func _input(event: InputEvent) -> void:
	if not is_visible_in_tree(): return
	if event is InputEventScreenTouch:
		touch_active = event.pressed
		handle_pointer(event.position, event.pressed)
	elif event is InputEventScreenDrag and touch_active:
		move_pointer(event.position)
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not touch_active:
		handle_pointer(event.position, event.pressed)
	elif event is InputEventMouseMotion and dragging and not touch_active:
		move_pointer(event.position)

func handle_pointer(pos: Vector2, pressed: bool) -> void:
	if pressed:
		var rect = get_global_rect()
		dragging = rect.has_point(pos) and pos.x < rect.end.x - get_v_scroll_bar().size.x
		moved = false; start = pos; previous = pos
	else:
		if dragging and moved: get_viewport().set_input_as_handled()
		dragging = false

func move_pointer(pos: Vector2) -> void:
	if not dragging: return
	if absf(pos.y - start.y) > 12: moved = true
	if moved:
		scroll_vertical += int(previous.y - pos.y)
		cancel_buttons(self)
		get_viewport().set_input_as_handled()
	previous = pos

func cancel_buttons(node: Node) -> void:
	if node is BaseButton: node.set_pressed_no_signal(false)
	for child in node.get_children(): cancel_buttons(child)

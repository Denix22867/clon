extends Node

var reset_callback: JavaScriptObject
var pause_callback: JavaScriptObject
var was_muted = false
var applied_pause = false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if not OS.has_feature("web"): return
	var platform = JavaScriptBridge.get_interface("IskraPlatform")
	if platform:
		pause_callback = JavaScriptBridge.create_callback(_on_browser_pause)
		platform.bindGodotPause(pause_callback)
	var guard = JavaScriptBridge.get_interface("IskraGuard")
	if guard:
		reset_callback = JavaScriptBridge.create_callback(_on_reset_progress)
		guard.bindGodotReset(reset_callback)

func _on_browser_pause(args: Array) -> void:
	if not args.is_empty(): apply_pause(args[0] == true)

func apply_pause(value: bool) -> void:
	if value == applied_pause: return
	applied_pause = value
	if value:
		was_muted = AudioServer.is_bus_mute(0)
		AudioServer.set_bus_mute(0, true)
		get_parent().save_game()
	else:
		AudioServer.set_bus_mute(0, was_muted)
		get_parent().save_game()
	get_tree().paused = value
	get_parent().publish_state()

func _process(delta: float) -> void:
	if not OS.has_feature("web"): return

	var paused = JavaScriptBridge.eval("window.IskraPlatform ? window.IskraPlatform.tick(%f) : false" % minf(delta, 0.25), true)
	apply_pause(paused == true)


func _on_reset_progress(_args: Array) -> void:
	get_parent().reset_full_progress()

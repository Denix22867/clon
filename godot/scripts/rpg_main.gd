extends Node3D
const Economy = preload("res://scripts/rpg_economy.gd")
const World = preload("res://scripts/rpg_world.gd")
const PlatformBridge = preload("res://scripts/platform_bridge.gd")
const INK = Color("#eae5d4")
const MUTED = Color("#98aabb")
const PANEL = Color("#223347")
const GOLD = Color("#e3b66c")
var game = Economy.new()
var world = World.new()
var camera: Camera3D
var ui: Control
var controls: Dictionary = {}
var rows: Array = []
var factor: float = 1.0
var screen: Vector2
var last_size = Vector2.ZERO
var portrait = false
var tab = "hero"
var bulk = 1
var timer = 0.0
var save_timer = 0.0
var auto_anim = 0.0
var toast_timer = 0.0
var toast: Label
var content: Control
var modal: Control
var sound_player: AudioStreamPlayer
var playback: AudioStreamGeneratorPlayback
var beep_left = 0
var phase = 0.0

func _ready() -> void:
	if OS.has_feature("web"):
		var platform = JavaScriptBridge.get_interface("IskraPlatform")
		if platform: TranslationServer.set_locale(str(platform.getLanguage()))
	load_game(); world.setup(self)
	camera = Camera3D.new(); camera.projection = Camera3D.PROJECTION_ORTHOGONAL; camera.keep_aspect = Camera3D.KEEP_WIDTH
	camera.position = Vector3(0, 5.8, 10); add_child(camera); camera.look_at(Vector3(0, 0.85, 0)); camera.current = true
	var layer = CanvasLayer.new(); add_child(layer); ui = Control.new(); layer.add_child(ui)
	ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var theme = Theme.new(); var font = FontVariation.new(); font.base_font = load("res://assets/fonts/NotoSans.ttf"); font.variation_opentype = {"wght": 600.0 }; theme.default_font = font; ui.theme = theme
	sound_player = AudioStreamPlayer.new(); var stream = AudioStreamGenerator.new(); stream.mix_rate = 22050; stream.buffer_length = 0.1
	sound_player.stream = stream; sound_player.volume_db = -19; add_child(sound_player)
	rebuild()
	var away = Time.get_unix_time_from_system() - game.saved_at
	if game.saved_at > 0 and away > 60:
		var value = game.offline(away); tell("Отряд добыл за отсутствие: " + number(value) + " золота")
	save_game(); refresh()
	if OS.has_feature("web"):
		add_child(PlatformBridge.new())
		JavaScriptBridge.eval("window.rpgReady=true", true)
func _process(delta: float) -> void:
	game.tick(minf(delta, 0.2)); world.update(game, delta)
	auto_anim += delta
	if auto_anim > 0.95:
		auto_anim = 0
		if not game.farming or game.expedition.active: world.impact()
	if playback and game.sound:
		for i in range(playback.get_frames_available()):
			var amplitude = sin(phase) * 0.18 * float(beep_left) / 1200.0 if beep_left > 0 else 0.0
			phase += TAU * 420 / 22050.0; beep_left = maxi(0, beep_left - 1); playback.push_frame(Vector2(amplitude, amplitude))
	if last_size != get_viewport().get_visible_rect().size: rebuild()
	timer += delta; save_timer += delta
	if timer > 0.2:
		timer = 0; refresh(); publish_state()
		if not game.events.is_empty(): tell(str(game.events.pop_front())); save_game()
	if save_timer > 5: save_timer = 0; save_game()
	toast_timer = maxf(0, toast_timer - delta)
	if is_instance_valid(toast): toast.visible = toast_timer > 0
func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_WM_CLOSE_REQUEST: save_game()
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_SPACE and not is_instance_valid(modal): attack()
		if event.keycode == KEY_ESCAPE: close_modal()
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT and not is_instance_valid(modal):
		var center = camera.unproject_position(Vector3(2.1, 1.1, 0))
		if Rect2(center - Vector2(85, 95) * factor, Vector2(170, 190) * factor).has_point(event.position): attack()
func number(n: float) -> String:
	if n < 1000: return str(int(n))
	var suffix = ["тыс", "млн", "млрд", "трлн", "квд", "квн"]
	var power = int(log(n) / log(1000.0))
	if power <= suffix.size(): return ("%.1f" % (n / pow(1000.0, power))) + " " + suffix[power - 1]
	return "%.2fe%d" % [n / pow(10.0, floor(log(n) / log(10.0))), int(floor(log(n) / log(10.0)))]
func style(color: Color, radius: int = 12) -> StyleBoxFlat:
	var s = StyleBoxFlat.new(); s.bg_color = color; s.set_corner_radius_all(int(radius * factor)); return s
func place(c: Control, r: Rect2) -> void: c.position = r.position * factor; c.size = r.size * factor
func panel(parent: Control, r: Rect2, color: Color = PANEL) -> Panel:
	var p = Panel.new(); parent.add_child(p); place(p, r); p.add_theme_stylebox_override("panel", style(color)); return p
func label(parent: Control, text: String, r: Rect2, size: int = 14, color: Color = INK) -> Label:
	var l = Label.new(); parent.add_child(l); place(l, r); l.text = text; l.add_theme_font_size_override("font_size", int(size * factor)); l.add_theme_color_override("font_color", color); l.mouse_filter = Control.MOUSE_FILTER_IGNORE; return l
func button(parent: Control, text: String, r: Rect2, action: Callable, key: String = "", primary: bool = false) -> Button:
	var b = Button.new(); parent.add_child(b); place(b, r); b.text = text; b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", int(12 * factor))
	for state in ["normal", "hover", "pressed", "disabled"]:
		var color = GOLD if primary else Color("#324a60")
		if state == "hover": color = color.lightened(0.1)
		if state == "pressed": color = color.darkened(0.15)
		if state == "disabled": color = Color("#293b4b")
		b.add_theme_stylebox_override(state, style(color, 9))
	for state in ["font_color", "font_hover_color", "font_pressed_color"]: b.add_theme_color_override(state, Color("#253346") if primary else INK)
	b.add_theme_color_override("font_disabled_color", Color("#657b8c")); b.pressed.connect(action)
	if key != "": controls[key] = b
	return b
func bar(parent: Control, r: Rect2) -> ProgressBar:
	var p = ProgressBar.new(); parent.add_child(p); place(p, r); p.show_percentage = false; p.max_value = 100
	p.add_theme_stylebox_override("background", style(Color("#304458"), 4)); p.add_theme_stylebox_override("fill", style(Color("#b8616a"), 4)); return p
func rebuild() -> void:
	last_size = get_viewport().get_visible_rect().size; portrait = last_size.x / last_size.y < 1.0
	factor = last_size.x / (390.0 if portrait else 1280.0); screen = last_size / factor
	for child in ui.get_children(): child.queue_free()
	controls.clear(); rows.clear(); modal = null
	var w = screen.x; var h = screen.y
	label(ui, "ИСКРА", Rect2(18, 15, 180, 28), 23, GOLD)
	label(ui, "ПУТЬ ГЕРОЯ · IDLE RPG", Rect2(19, 43, 220, 15), 9, MUTED)
	var wallet = panel(ui, Rect2(w - 175, 14, 157, 47))
	controls.gold = label(wallet, "", Rect2(12, 4, 145, 24), 19, GOLD)
	controls.shards = label(wallet, "", Rect2(12, 29, 140, 13), 9, MUTED)
	var arena_x = 18.0 if portrait else 350.0; var arena_w = w - 36 if portrait else 550.0
	controls.zone = label(ui, "", Rect2(arena_x, 80, arena_w - 80, 21), 13)
	controls.stage = label(ui, "", Rect2(arena_x + arena_w - 85, 81, 85, 20), 12, GOLD)
	controls.foe = label(ui, "", Rect2(arena_x, 105, arena_w, 18), 11, MUTED)
	controls.hp = bar(ui, Rect2(arena_x, 130, arena_w, 8))
	controls.health = label(ui, "", Rect2(arena_x, 142, arena_w, 17), 9, MUTED)
	var attack_y = h * 0.43 if portrait else h - 114
	button(ui, "", Rect2(arena_x, attack_y, arena_w, 49), attack, "attack", true)
	button(ui, "", Rect2(arena_x, attack_y + 57, arena_w / 2 - 4, 35), use_skill.bind("flame"), "flame")
	button(ui, "", Rect2(arena_x + arena_w / 2 + 4, attack_y + 57, arena_w / 2 - 4, 35), use_skill.bind("frenzy"), "frenzy")
	var pane_x = 16.0 if portrait else 950.0; var pane_w = w - 32 if portrait else 312.0; var pane_y = attack_y + 104 if portrait else 85.0
	var names = ["Герой", "Отряд", "Задания", "Искра"]; var keys = ["hero", "allies", "quests", "prestige"]
	for i in range(4):
		var b = button(ui, names[i], Rect2(pane_x + i * (pane_w / 4), pane_y, pane_w / 4 - 3, 33), select_tab.bind(keys[i]), "tab_" + keys[i])
		if keys[i] == tab: b.add_theme_stylebox_override("normal", style(Color("#526172"), 9))
	content = panel(ui, Rect2(pane_x, pane_y + 40, pane_w, maxf(130, h - pane_y - 74)))
	if not portrait:
		var info = panel(ui, Rect2(18, 112, 270, 274)); label(info, "ТВОЙ ПОХОД", Rect2(18, 15, 230, 22), 13, GOLD)
		controls.info = label(info, "", Rect2(18, 50, 234, 175), 14)
		label(info, "Боссы: каждый 10-й этап\nЭволюции: каждые 25 уровней", Rect2(18, 215, 235, 40), 10, MUTED)
	button(ui, "", Rect2(18, h - 28, 164 if portrait else 270, 22), farm, "farm")
	button(ui, "", Rect2(w - 72, h - 28, 54, 22), toggle_sound, "sound")
	if portrait: controls.info = label(ui, "", Rect2(187, h - 26, w - 260, 20), 9, MUTED)
	camera.size = 14.0 if portrait else 22.0
	camera.v_offset = ((160 + attack_y) / 2 - h / 2) * camera.size / w if portrait else ((175 + attack_y) / 2 - h / 2) * camera.size / w
	camera.h_offset = 0.0 if portrait else 0.26
	toast = label(ui, "", Rect2(18, 66, w - 36, 42), 11, GOLD); toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toast.add_theme_stylebox_override("normal", style(Color("#24394d"), 8)); toast.visible = false; toast_timer = 0
	build_content(); refresh()
func select_tab(value: String) -> void:
	tab = value; rebuild()
	if value != "hero": notify_platform_break()

func notify_platform_break() -> void:
	if OS.has_feature("web"): JavaScriptBridge.eval("window.IskraPlatform?.maybeShowInterstitial()", true)
func build_content() -> void:
	var pw = content.size.x / factor; var ph = content.size.y / factor
	label(content, "СНАРЯЖЕНИЕ" if tab == "hero" else "СПУТНИКИ" if tab == "allies" else "ХРОНИКА" if tab == "quests" else "ВОЗРОЖДЕНИЕ", Rect2(13, 9, pw - 122, 21), 10, GOLD)
	if tab in ["hero", "allies"]: button(content, "x" + ("MAX" if bulk < 0 else str(bulk)), Rect2(pw - 82, 8, 69, 25), cycle_bulk, "bulk")
	var scroll = ScrollContainer.new(); content.add_child(scroll); place(scroll, Rect2(10, 41, pw - 20, ph - 51)); scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var list = VBoxContainer.new(); scroll.add_child(list); list.size_flags_horizontal = Control.SIZE_EXPAND_FILL; list.add_theme_constant_override("separation", int(8 * factor))
	if tab == "hero" or tab == "allies":
		for i in range(3 if tab == "hero" else game.ALLIES.size()):
			var kind = ["sword", "gloves", "amulet"][i] if tab == "hero" else "ally"
			var row = make_row(list, pw - 20, 108)
			var title = label(row, "", Rect2(12, 7, pw - 50, 21), 13, Color(game.ALLIES[i].color) if kind == "ally" else INK)
			var desc = label(row, ["Урон героя · x2 каждые 25 ур.", "Сила клика и шанс критического удара", "+3% золота с врагов за уровень"][i] if tab == "hero" else "", Rect2(12, 32, pw - 50, 18), 9, MUTED)
			var key = "buy_ally" + str(i) if kind == "ally" else "buy_" + kind
			var b = button(row, "", Rect2(12, 61, pw - 64, 35), purchase.bind(kind, i if kind == "ally" else 0), key, true)
			rows.append({"kind": kind, "index": i if kind == "ally" else 0, "title": title, "button": b, "desc": desc })
		if tab == "hero":
			var row = make_row(list, pw - 20, 70); label(row, "АВТОУДАРЫ ВКЛЮЧЕНЫ", Rect2(12, 9, pw - 50, 22), 11, GOLD); label(row, "Герой сражается сам. Клики помогают.", Rect2(12, 35, pw - 50, 20), 9, MUTED)
	elif tab == "quests":
		for i in range(game.QUESTS.size()):
			var row = make_row(list, pw - 20, 104); label(row, game.QUESTS[i].name, Rect2(12, 7, pw - 50, 23), 13)
			var desc = label(row, "", Rect2(12, 33, pw - 50, 18), 9, MUTED)
			var b = button(row, "", Rect2(12, 58, pw - 64, 33), claim.bind(i), "claim" + str(i), true)
			rows.append({"kind": "quest", "index": i, "desc": desc, "button": b })
	else:
		var loot = make_row(list, pw - 20, 132)
		label(loot, "РЕЛИКВИИ БОССОВ", Rect2(12, 8, pw - 50, 23), 13, GOLD)
		var loot_desc = label(loot, "", Rect2(12, 35, pw - 50, 40), 10, MUTED)
		var loot_button = button(loot, "", Rect2(12, 84, pw - 64, 35), open_chest, "open_chest", true)
		rows.append({"kind": "loot", "desc": loot_desc, "button": loot_button })
		var row = make_row(list, pw - 20, 278); label(row, "У костра всё начинается заново", Rect2(12, 8, pw - 50, 42), 12, GOLD)
		var desc = label(row, "", Rect2(12, 56, pw - 50, 112), 11, MUTED)
		var b = button(row, "", Rect2(12, 185, pw - 64, 42), request_prestige, "rebirth", true)
		label(row, "Задания и статистика сохраняются", Rect2(12, 238, pw - 50, 22), 9, MUTED)
		rows.append({"kind": "prestige", "desc": desc, "button": b })
		var relic_row = make_row(list, pw - 20, 245)
		label(relic_row, "КОЛЛЕКЦИЯ · СОХРАНЯЕТСЯ НАВСЕГДА", Rect2(12, 6, pw - 50, 23), 9, GOLD)
		var relic_desc = label(relic_row, "", Rect2(12, 35, pw - 50, 205), 10)
		rows.append({"kind": "collection", "desc": relic_desc })
		var stat = make_row(list, pw - 20, 150); label(stat, "ХРОНИКА\nПобед: %d · Ударов: %d\nВозрождений: %d\nВ игре: %d мин." % [game.kills, game.clicks, game.rebirths, int(game.played / 60)], Rect2(12, 10, pw - 50, 120), 12)
func make_row(list: VBoxContainer, width: float, height: float) -> Panel:
	var p = Panel.new(); list.add_child(p); p.custom_minimum_size = Vector2(width, height) * factor; p.add_theme_stylebox_override("panel", style(Color("#293e53"), 9)); return p
func cycle_bulk() -> void:
	bulk = 10 if bulk == 1 else 25 if bulk == 10 else -1 if bulk == 25 else 1; select_tab(tab)
func refresh() -> void:
	if controls.is_empty(): return
	controls.gold.text = number(game.gold) + " зол."
	controls.shards.text = "ИСКРЫ %d · БОНУС +%d%%" % [game.shards, game.shards * 15]
	controls.zone.text = game.ZONES[game.region()]; controls.stage.text = "ЭТАП %d" % game.stage
	controls.foe.text = ("БОСС · " + game.BOSSES[game.region()]) if game.boss() else game.FOES[game.region()]
	controls.hp.value = game.hp / game.max_hp() * 100
	controls.health.text = number(game.hp) + " / " + number(game.max_hp()) + (" · %.1f сек." % game.boss_time if game.boss() else " · боссу нужно ~" + number(game.max_hp(game.best) / 30) + " / сек." if game.farming and game.best % 10 == 0 else " · добыча золота" if game.farming else "")
	controls.attack.text = "УДАРИТЬ  +" + number(game.click_damage())
	controls.flame.text = "ОГОНЬ · этап 5" if game.best < 5 else "ОГОНЬ · %d сек." % int(ceil(game.flame_cd)) if game.flame_cd > 0 else "ОГНЕННЫЙ УДАР"
	controls.flame.disabled = game.best < 5 or game.flame_cd > 0
	controls.frenzy.text = "ЯРОСТЬ · этап 15" if game.best < 15 else "ЯРОСТЬ · %d сек." % int(ceil(game.frenzy_cd)) if game.frenzy_cd > 0 else "ЯРОСТЬ x3"
	controls.frenzy.disabled = game.best < 15 or game.frenzy_cd > 0
	controls.farm.text = "ПРОДОЛЖИТЬ ПОХОД" if game.farming else "ДОБЫВАТЬ ЗОЛОТО"; controls.sound.text = "ЗВУК" if game.sound else "ТИХО"
	controls.info.text = "%s / сек." % number(game.dps()) if portrait else "Урон отряда\n%s / сек.\n\nСила удара\n%s\n\nЛучший этап: %d" % [number(game.dps()), number(game.click_damage()), game.best]
	for row in rows:
		var kind = row.kind
		if kind in ["sword", "gloves", "amulet", "ally"]:
			var idx = int(row.index); var lv = game.level(kind, idx); var q = game.purchase_quote(kind, idx, bulk)
			var locked = kind == "ally" and game.best < int(game.ALLIES[idx].stage)
			var name = game.ALLIES[idx].name if kind == "ally" else "Меч Искры" if kind == "sword" else "Перчатки охотника" if kind == "gloves" else "Золотой талисман"
			row.title.text = name + " · ур. " + str(lv)
			if kind == "ally": row.desc.text = "Откроется на этапе %d" % game.ALLIES[idx].stage if locked else game.ALLIES[idx].role + " · " + number(game.ally_dps(idx)) + " / сек."
			row.button.text = "ЭТАП %d" % game.ALLIES[idx].stage if locked else "+%d ур. · %s зол." % [q.count, number(q.cost)] if q.count > 0 else "Недостаточно золота"
			row.button.disabled = locked or q.count == 0 or game.gold < q.cost
		elif kind == "quest":
			var i = int(row.index); var d = game.QUESTS[i]; var v = game.quest_value(d.kind)
			row.desc.text = "%d / %d · Награда: %s зол." % [mini(v, d.target), d.target, number(d.reward)]
			row.button.text = "ПОЛУЧЕНО" if game.claimed.has(i) else "ЗАБРАТЬ НАГРАДУ" if v >= d.target else "В ПРОЦЕССЕ"
			row.button.disabled = game.claimed.has(i) or v < d.target
		elif kind == "loot":
			row.desc.text = "Сундуки за победы над боссами.\nБонус коллекции: +%d%% урона." % int(game.relic_bonus() * 100)
			row.button.text = "ОТКРЫТЬ · СУНДУКОВ %d" % game.chests if game.chests > 0 else "СУНДУКОВ НЕТ"
			row.button.disabled = game.chests <= 0
		elif kind == "collection":
			var text = ""
			for i in range(game.RELICS.size()): text += (game.RELICS[i].name + " · ур. " + str(game.relics[i]) if game.relics[i] > 0 else "??? · " + game.RELICS[i].rarity) + "\n"
			row.desc.text = text
		else:
			row.desc.text = "Каждая Искра навсегда даёт +15% урона.\n\nСбросятся: этапы, золото, снаряжение\nи уровни союзников.\n\nДоступно после победы на этапе 50."
			row.button.text = "ВОЗРОДИТЬСЯ · +%d ИСКР" % game.prestige_reward() if game.prestige_reward() > 0 else "НУЖНО ПРОЙТИ ЭТАП 50"; row.button.disabled = game.prestige_reward() <= 0
func attack() -> void:
	var value = game.strike(); world.impact(); beep()
	var p = camera.unproject_position(Vector3(2.1, 2.1, 0)) / factor
	var l = label(ui, ("КРИТ! " if game.last_crit else "") + number(value), Rect2(p.x - 50, p.y - 10, 130, 30), 18, GOLD)
	var t = create_tween(); t.set_parallel(true); t.tween_property(l, "position", l.position - Vector2(0, 50) * factor, 0.6); t.tween_property(l, "modulate:a", 0, 0.6); t.chain().tween_callback(l.queue_free); refresh()
func purchase(kind: String, index: int) -> void:
	if game.buy(kind, index, bulk): save_game(); refresh(); beep()
func claim(index: int) -> void:
	if game.claim(index): tell("Награда: " + number(game.QUESTS[index].reward) + " золота"); save_game(); refresh()
func farm() -> void: game.toggle_farm(); save_game(); refresh()
func open_chest() -> void:
	var index = game.open_chest()
	if index >= 0: tell(game.RELICS[index].rarity + " реликвия: " + game.RELICS[index].name); save_game(); refresh(); beep()
func use_skill(kind: String) -> void:
	if game.skill(kind): world.impact(); tell("Огненный удар!" if kind == "flame" else "Ярость: весь урон x3 на 10 секунд"); save_game(); refresh(); beep()
func tell(text: String) -> void:
	if is_instance_valid(toast): toast.text = text; toast.visible = true; toast_timer = 3.2
func toggle_sound() -> void:
	game.sound = not game.sound
	if not game.sound: sound_player.stop(); playback = null
	save_game(); refresh(); beep()
func beep() -> void:
	if not game.sound: return
	if not sound_player.playing: sound_player.play(); playback = sound_player.get_stream_playback()
	beep_left = 1200
func request_prestige() -> void:
	close_modal(); modal = Control.new(); ui.add_child(modal); modal.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var shade = ColorRect.new(); modal.add_child(shade); shade.color = Color(0.04, 0.08, 0.15, 0.85); shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var pw = minf(screen.x - 32, 480); var p = panel(modal, Rect2((screen.x - pw) / 2, (screen.y - 250) / 2, pw, 250))
	label(p, "Начать новый поход?", Rect2(18, 15, pw - 36, 35), 20, GOLD)
	label(p, "Золото, этапы и уровни сбросятся.\nТы получишь %d Искр.\nПостоянный бонус: +%d%% урона." % [game.prestige_reward(), (game.shards + game.prestige_reward()) * 15], Rect2(18, 64, pw - 36, 89), 12)
	button(p, "ВОЗРОДИТЬСЯ", Rect2(18, 160, pw - 36, 38), do_prestige, "confirm_rebirth", true); button(p, "Продолжить этот поход", Rect2(18, 205, pw - 36, 30), close_modal, "cancel_rebirth")
func close_modal() -> void:
	if is_instance_valid(modal): modal.queue_free()
	modal = null; controls.erase("confirm_rebirth"); controls.erase("cancel_rebirth")
func do_prestige() -> void:
	if game.prestige(): close_modal(); save_game(); rebuild(); tell("Искра стала сильнее. Новый поход начинается!")
func save_game() -> void:
	var raw = JSON.stringify(game.to_dict())
	if OS.has_feature("web"): JavaScriptBridge.eval("try{localStorage.setItem('iskra-idle-v2',%s);window.IskraCloud?.save(localStorage.getItem('iskra-idle-v2'))}catch(e){}" % JSON.stringify(raw), true)
	else:
		var f = FileAccess.open("user://iskra-save.json", FileAccess.WRITE)
		if f: f.store_string(raw)
func load_game() -> void:
	var raw = ""
	if OS.has_feature("web"):
		var value = JavaScriptBridge.eval("(()=>{try{return localStorage.getItem('iskra-idle-v2')||''}catch(e){return ''}})()", true)
		if value is String: raw = value
	elif FileAccess.file_exists("user://iskra-save.json"): raw = FileAccess.get_file_as_string("user://iskra-save.json")
	var data = JSON.parse_string(raw) if raw != "" else null
	if data is Dictionary: game.load_dict(data)
func publish_state() -> void:
	if not OS.has_feature("web"): return
	var coords = {}; var scale = JavaScriptBridge.eval("window.innerWidth", true) / last_size.x
	for key in controls:
		var c = controls[key]
		if is_instance_valid(c) and c is Button and c.is_visible_in_tree():
			var r = c.get_global_rect(); coords[key] = {"x": r.get_center().x * scale, "y": r.get_center().y * scale, "disabled": c.disabled }
	var snapshot = {"gold": game.gold, "stage": game.stage, "best": game.best, "kills": game.kills, "clicks": game.clicks, "sword": game.sword, "gloves": game.gloves, "amulet": game.amulet, "allies": game.allies, "shards": game.shards, "rebirths": game.rebirths, "hp": game.hp, "max_hp": game.max_hp(), "boss": game.boss(), "boss_time": game.boss_time, "farm": game.farming, "dps": game.dps(), "tab": tab, "bulk": bulk, "chests": game.chests, "relics": game.relics, "controls": coords }
	snapshot.combo = game.combo; snapshot.combo_left = game.combo_left; snapshot.treasures = game.treasures; snapshot.treasure_goal = game.treasure_goal; snapshot.power_left = game.power_left; snapshot.gold_left = game.gold_left
	snapshot.paused = get_tree().paused; snapshot.audio_muted = AudioServer.is_bus_mute(0)
	JavaScriptBridge.eval("window.rpgState=" + JSON.stringify(snapshot), true)

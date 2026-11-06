extends "res://scripts/rpg_main.gd"

const PaintedWorld = preload("res://scripts/painted_world.gd")
const Frame = preload("res://scripts/fantasy_frame.gd")
const ReleaseNotes = preload("res://scripts/release_notes.gd")
signal cloud_loaded
var cloud_callback: JavaScriptObject
var cloud_booting = true
var release_notes_active = false
var release_version = ReleaseNotes.VERSION
var shop_soon_active = false

const Art = preload("res://scripts/art_catalog.gd")
var serif: FontVariation
var hud: Control
var arena_rect: Rect2
var gem_label: Label
var enemy_label: Label
var hero_level: Label
var hero_rows: Array = []
var crest: TextureRect
var effects: Control
var menu_scroll: ScrollContainer
var last_kills = 0
var last_earned = 0.0
var combo_meter: ProgressBar
var background: TextureRect
var shown_region = -1
var hero_picker_rows: Array = []
var hero_portrait: TextureRect
var hero_caption: Label
var expedition_menu = false
var expedition_result_seen = 0
var tutorial_active = false
var tutorial_step = 0
const LESSONS = [
	["Твой путь начинается", "Побеждай врагов, усиливай отряд и открывай новые земли. Герой атакует сам, а твои нажатия помогают ему. Во время обучения поход приостановлен."],
	["Удары и комбо", "Нажимай «Ударить». Несколько быстрых ударов дают комбо и повышают урон. На каждом десятом этапе ждёт босс: победи его за 30 секунд."],
	["Три полезных улучшения", "Меч усиливает удары. Лис помогает автоматически, даже без нажатий. Талисман даёт +3% золота за уровень. Улучшай их зелёными кнопками под ареной."],
	["Добыча — не прохождение", "Не хватает золота? Открой «Карта» → «Добывать золото». В шахте этап не растёт. Чтобы открыть следующие земли, вернись: «Карта» → «Продолжить поход»."],
	["Собери героев", "Открой «Герои» сверху. Герои покупаются за золото навсегда и дают разные бонусы. Новые герои требуют этапов 31, 71 и 121: одной добычи золота недостаточно."],
	["Цель длинного похода", "Открывай земли и спутников, побеждай боссов и собирай реликвии. На этапах 31, 71 и 121 открываются сложности экспедиции. После этапа 50 доступно возрождение. Герои и реликвии остаются."],
	["Честная игра", "Автокликеры запрещены. При сверхчастых ударах появится предупреждение на 10 секунд. Останови автокликер — прогресс сохранится. Если автоматические нажатия продолжатся всё это время, прогресс сбросится. Оплаченные товары сохраняются."]
	]

func _ready() -> void:
	if OS.has_feature("web"):


		JavaScriptBridge.eval("window.IskraShop={purchasesEnabled:false,init(){},bindGodot(){},tick(){},open(){},close(){},getState(){return {purchasesEnabled:false,initialized:true,busy:false}}}", true)

		var social_css = FileAccess.get_file_as_string("res://web/social.css")
		for asset in ["social-atlas.png", "social-background.png"]:
			var bytes = FileAccess.get_file_as_bytes("res://web/art/" + asset + ".bin")
			var encoded = Marshalls.raw_to_base64(bytes)
			var script = "(()=>{window.IskraArtworkURLs ||= {};const name=" + JSON.stringify(asset) + ";if(!window.IskraArtworkURLs[name]){const raw=atob(" + JSON.stringify(encoded) + ");const data=new Uint8Array(raw.length);for(let i=0;i<raw.length;i++)data[i]=raw.charCodeAt(i);window.IskraArtworkURLs[name]=URL.createObjectURL(new Blob([data],{type:'image/png'}))}return window.IskraArtworkURLs[name]})()"
			var asset_url = JavaScriptBridge.eval(script, true)
			if asset_url is String: social_css = social_css.replace(asset, asset_url)
		var social_js = FileAccess.get_file_as_string("res://web/social.js")
		JavaScriptBridge.eval("(()=>{let s=document.getElementById('iskra-social-style');if(!s){s=document.createElement('style');s.id='iskra-social-style';document.body.append(s)}s.textContent=" + JSON.stringify(social_css) + ";if(window.IskraSocial?.version!=='1.0.3'){eval(" + JSON.stringify(social_js) + ")}})();void 0", true)
		var social_art = FileAccess.get_file_as_string("res://web/social-art.js")
		JavaScriptBridge.eval(social_art + ";void 0", true)
		var remote_version = JavaScriptBridge.eval("(()=>{try{return JSON.parse(localStorage.getItem('iskra-updater-v1'))?.pending?.version || ''}catch(e){return ''}})()", true)
		if remote_version is String and remote_version != "": release_version = remote_version
	if OS.has_feature("web"):
		JavaScriptBridge.eval(FileAccess.get_file_as_string("res://web/cloud-save.js") + ";void 0", true)
		cloud_callback = JavaScriptBridge.create_callback(_on_cloud_save)
		JavaScriptBridge.get_interface("IskraCloud").start(cloud_callback)
		await cloud_loaded
	cloud_booting = false
	world = PaintedWorld.new()
	super._ready()
	last_kills = game.kills; last_earned = game.earned
	call_deferred("show_startup_screen")

func _on_cloud_save(args: Array) -> void:
	if cloud_booting:
		if not args.is_empty() and str(args[0]) == "": cloud_loaded.emit()
		return
	if args.is_empty() or str(args[0]) == "": return
	var data = JSON.parse_string(str(args[0]))
	if not data is Dictionary or data.get("version", 0) != 2: return
	close_modal(); game = Economy.new(); game.load_dict(data)
	var away = Time.get_unix_time_from_system() - game.saved_at
	if game.saved_at > 0 and away > 60: game.offline(away)
	tutorial_active = false; release_notes_active = false; expedition_menu = false
	last_kills = game.kills; last_earned = game.earned; expedition_result_seen = game.expedition.result_serial
	rebuild(); world.update(game, 0); save_game(); refresh(); publish_state()
	tell("Прогресс восстановлен из Яндекса")

func _notification(what: int) -> void:
	if cloud_booting: return
	super._notification(what)

func _process(delta: float) -> void:
	if cloud_booting: return
	if shop_soon_active:
		if last_size != get_viewport().get_visible_rect().size:
			rebuild()
			open_shop()
		return
	if release_notes_active:
		if last_size != get_viewport().get_visible_rect().size:
			release_notes_active = false
			rebuild()
			show_release_notes()
		return
	if expedition_menu:
		if last_size != get_viewport().get_visible_rect().size:
			rebuild(); show_expeditions()
		return
	if tutorial_active:
		if last_size != get_viewport().get_visible_rect().size:
			rebuild(); show_tutorial(tutorial_step)
		return
	super._process(delta)
	if game.farming and game.kills > last_kills:
		var gain_label = center_label(hud, "+" + number(game.earned - last_earned) + " золота", Rect2(400, screen.y * 0.41, 290, 48), 30, GOLD)
		var tween = create_tween(); tween.set_parallel(true); tween.tween_property(gain_label, "position", gain_label.position - Vector2(0, 50) * factor, 0.9); tween.tween_property(gain_label, "modulate:a", 0, 0.9); tween.chain().tween_callback(gain_label.queue_free)
	last_kills = game.kills; last_earned = game.earned
	if game.expedition.result_serial > expedition_result_seen:
		expedition_result_seen = game.expedition.result_serial
		save_game(); call_deferred("show_expeditions")
	if is_instance_valid(crest): crest.modulate = Color("#ffc866") if game.boss() else Color("#d6bf97")

func rounded_skin(color: Color, radius: int = 5) -> StyleBoxFlat:
	var s = StyleBoxFlat.new(); s.bg_color = color; s.set_corner_radius_all(int(radius * factor))
	s.set_border_width_all(maxi(1, int(factor))); s.border_color = Color("#695237")
	s.shadow_color = Color(0, 0, 0, 0.7); s.shadow_size = int(3 * factor); return s

func panel(parent: Control, r: Rect2, color: Color = Color("#111923")) -> Panel:
	var p = Panel.new(); parent.add_child(p); place(p, r)
	p.add_theme_stylebox_override("panel", rounded_skin(Color(color, 0.94), 3))
	trim(p)
	return p

func trim(parent: Control, active: bool = false, ornate: bool = true) -> Control:
	var f = Panel.new(); f.set_script(Frame); parent.add_child(f); f.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	f.mouse_filter = Control.MOUSE_FILTER_IGNORE; f.active = active; f.ornate = ornate
	f.accent = Color("#efc66a") if active else Color("#ac8550")
	f.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	return f

func label(parent: Control, text: String, r: Rect2, size: int = 14, color: Color = Color("#f3e9ca")) -> Label:
	var l = super.label(parent, text, r, maxi(size, 18), color)
	if serif:
		l.add_theme_font_override("font", serif)
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.95)); l.add_theme_constant_override("shadow_offset_y", maxi(1, int(2 * factor)))
	return l

func button(parent: Control, text: String, r: Rect2, action: Callable, key: String = "", primary: bool = false) -> Button:
	var b = Button.new(); parent.add_child(b); place(b, r); b.text = text; b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", maxi(9, int(18 * factor)))
	if serif: b.add_theme_font_override("font", serif)
	for state in ["normal", "hover", "pressed", "disabled"]:
		var color = Color("#b47722") if primary else Color("#18232c")
		if state == "hover": color = color.lightened(0.12)
		if state == "pressed": color = color.darkened(0.22)
		if state == "disabled": color = Color("#263328") if primary else Color("#131c26")
		var s = rounded_skin(color, 4); s.border_color = Color("#d9b360") if primary else Color("#6c573d")
		b.add_theme_stylebox_override(state, s)
	for state in ["font_color", "font_hover_color", "font_pressed_color"]: b.add_theme_color_override(state, Color("#fff0bb"))
	b.add_theme_color_override("font_disabled_color", Color("#879084")); b.pressed.connect(action)
	trim(b, primary)
	if key != "": controls[key] = b
	return b

func picture(parent: Control, texture: Texture2D, r: Rect2, mode: int = TextureRect.STRETCH_KEEP_ASPECT_CENTERED) -> TextureRect:
	var t = TextureRect.new(); parent.add_child(t); t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE; t.texture = texture; t.stretch_mode = mode; place(t, r); t.mouse_filter = Control.MOUSE_FILTER_IGNORE; return t

func art(index: int) -> AtlasTexture:
	var tex = load("res://assets/art/sprite_atlas.png") as Texture2D
	var a = AtlasTexture.new(); a.atlas = tex
	if tex:
		a.region = Rect2(Vector2(index % 3, floori(index / 3.0)) * Vector2(tex.get_width() / 3.0, tex.get_height() / 3.0), Vector2(tex.get_width() / 3.0, tex.get_height() / 3.0))
		a.filter_clip = true
		if index < 3:
			var regions = [Rect2(0, 85, 460, 341), Rect2(460, 50, 390, 376), Rect2(865, 100, 380, 326)]
			a.region = Rect2(regions[index].position * Vector2(tex.get_width() / 1280.0, tex.get_height() / 1280.0), regions[index].size * Vector2(tex.get_width() / 1280.0, tex.get_height() / 1280.0))
	return a
func icon(name: String) -> Texture2D: return load("res://assets/ui/" + name + ".png") as Texture2D
func mining_art(index: int) -> AtlasTexture:
	var tex = load("res://assets/art/mining_atlas.png") as Texture2D
	var a = AtlasTexture.new(); a.atlas = tex; a.filter_clip = true
	var regions = [Rect2(95, 145, 510, 450), Rect2(700, 220, 480, 370), Rect2(135, 730, 425, 435), Rect2(640, 640, 640, 640)]
	var rect = regions[index]; var scale = Vector2(tex.get_width() / 1280.0, tex.get_height() / 1280.0)
	a.region = Rect2(rect.position * scale, rect.size * scale); return a
func center_label(parent: Control, text: String, r: Rect2, size: int, color: Color = Color("#f2e5c5")) -> Label:
	var l = label(parent, text, r, size, color); l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER; return l

func rebuild() -> void:
	last_size = get_viewport().get_visible_rect().size
	portrait = last_size.x / last_size.y < 1.0
	factor = last_size.x / 720.0 if portrait else minf(last_size.y / 1280.0, last_size.x / 720.0)
	screen = last_size / factor
	for c in ui.get_children(): c.queue_free()
	controls.clear(); rows.clear(); hero_rows.clear(); hero_picker_rows.clear(); modal = null; toast_timer = 0; menu_scroll = null
	if not serif:
		serif = FontVariation.new(); serif.base_font = load("res://assets/fonts/NotoSerif.ttf"); serif.variation_opentype = {"wght": 700.0 }
	var w = 720.0; var h = screen.y
	background = picture(ui, Art.biome(0 if game.expedition.active else game.region()), Rect2(0, 0, screen.x, h), TextureRect.STRETCH_KEEP_ASPECT_COVERED)
	background.modulate = Color("#b4c2cb"); shown_region = 0 if game.expedition.active else game.region()
	hud = Control.new(); ui.add_child(hud); place(hud, Rect2((screen.x - w) / 2, 0, w, h)); hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	effects = Control.new(); hud.add_child(effects); effects.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); effects.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var header = ColorRect.new(); hud.add_child(header); place(header, Rect2(0, 0, w, 90)); header.color = Color(0.015, 0.025, 0.04, 0.65); header.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var logo = center_label(hud, "ИСКРА", Rect2(12, 7, 143, 74), 38, Color("#ffde8a")); logo.add_theme_constant_override("outline_size", maxi(1, int(2 * factor))); logo.add_theme_color_override("font_outline_color", Color("#3c2717"))
	picture(hud, icon("spark"), Rect2(59, -5, 53, 31))
	var hero_button = button(hud, "", Rect2(158, 4, 79, 79), show_heroes, "heroes")
	hero_button.tooltip_text = "Купить или сменить героя"
	hero_portrait = picture(hero_button, art(5) if game.hero_id == 0 and not game.star_skin else Art.hero(game.hero_id, false, game.star_skin), Rect2(8, 2, 63, 57))
	center_label(hero_button, "Герои", Rect2(2, 59, 75, 18), 18, GOLD)
	hero_caption = center_label(hud, game.HEROES[game.hero_id].short, Rect2(240, 7, 106, 25), 18, GOLD)
	var player = panel(hud, Rect2(244, 35, 100, 39), Color("#171719")); hero_level = label(player, "", Rect2(9, 5, 88, 27), 18, Color("#ebcd84"))
	wallet(hud, Rect2(354, 25, 135, 41), "coin", "gold")
	wallet(hud, Rect2(503, 25, 145, 41), "gem", "shards")
	var settings = button(hud, "", Rect2(665, 23, 40, 43), show_settings, "settings"); picture(settings, icon("gear"), Rect2(5, 6, 30, 30))
	var plaque = panel(hud, Rect2(205, h * 0.075, 305, 42), Color("#141b22"))
	controls.zone = center_label(plaque, "", Rect2(4, 0, 297, 41), 25)
	controls.stage = center_label(hud, "", Rect2(262, h * 0.108, 200, 28), 18)
	var hpframe = panel(hud, Rect2(177, h * 0.132, 364, 22), Color("#201718"))
	var hp = ProgressBar.new(); hpframe.add_child(hp); place(hp, Rect2(5, 4, 354, 14)); hp.show_percentage = false
	hp.add_theme_stylebox_override("background", rounded_skin(Color("#312522"), 1)); hp.add_theme_stylebox_override("fill", rounded_skin(Color("#b32932"), 1)); controls.hp = hp
	controls.health = center_label(hpframe, "", Rect2(5, 0, 354, 22), 13)
	crest = picture(hud, art(1), Rect2(139, h * 0.12, 66, 58))
	enemy_label = center_label(hud, "", Rect2(180, h * 0.155, 370, 26), 14, Color("#dac294"))
	arena_rect = Rect2((screen.x - w) / 2, h * 0.17, w, h * 0.375)
	world.layout(arena_rect, screen, camera)
	camera.current = false

	world.attach(hud, arena_rect.size, arena_rect.position.y, factor, art(0), art(1), art(2))
	var attack_y = h * 0.554

	var status_y = attack_y + 10 + h * 0.064 + 8
	controls.combo = center_label(hud, "", Rect2(189, status_y, 342, 30), 22, GOLD)
	place(controls.combo, Rect2(189, status_y, 342, 30))
	combo_meter = ProgressBar.new(); hud.add_child(combo_meter); combo_meter.show_percentage = false; combo_meter.mouse_filter = Control.MOUSE_FILTER_IGNORE
	combo_meter.add_theme_font_size_override("font_size", 1)
	for state in ["background", "fill"]:
		var meter_style = StyleBoxFlat.new(); meter_style.bg_color = Color("#26303a") if state == "background" else GOLD
		meter_style.set_corner_radius_all(maxi(1, int(2 * factor))); meter_style.set_content_margin_all(0)
		combo_meter.add_theme_stylebox_override(state, meter_style)
	place(combo_meter, Rect2(214, status_y + 32, 292, 4))
	controls.farm_status = center_label(hud, "", Rect2(189, status_y + 42, 342, 30), 22, GOLD)
	place(controls.farm_status, Rect2(189, status_y + 42, 342, 30))
	var side_y = h * 0.126
	for i in range(3):
		var key = ["rewards", "map", "events"][i]; var name = ["Награды", "Карта", "Сундуки"][i]
		var callback = select_tab.bind("quests") if i == 0 else show_map if i == 1 else show_treasures
		var b = button(hud, "", Rect2(18, side_y + i * 90, 66, 67), callback, key)
		picture(b, art(8) if i != 1 else icon("map"), Rect2(1, 1, 64, 64))
		center_label(hud, name, Rect2(2, side_y + 65 + i * 90, 96, 20), 14)
		var dot = ColorRect.new(); b.add_child(dot); place(dot, Rect2(55, 0, 10, 10)); dot.color = Color("#d93e36"); dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if i == 2: controls.treasure_dot = dot
	var expedition_button = button(hud, "Экспедиция", Rect2(545, h * 0.078, 163, 45), show_expeditions, "expeditions")
	button(hud, "Профиль", Rect2(18, h * 0.078, 163, 45), open_social.bind("profile"), "profile")
	button(hud, "Рейтинг", Rect2(545, h * 0.126, 163, 45), open_social.bind("rating"), "rating")
	expedition_button.tooltip_text = "Сердце Шепчущего леса: боссы и уникальная реликвия"
	controls.treasure_progress = label(hud, "", Rect2(98, side_y + 185, 208, 62), 22, GOLD)
	controls.buff_status = center_label(hud, "", Rect2(195, h * 0.203, 440, 52), 23, GOLD)
	controls.buff_status.add_theme_stylebox_override("normal", rounded_skin(Color(0.03, 0.045, 0.06, 0.82), 3))
	var attack_button = button(hud, "", Rect2(189, attack_y + 10, 342, h * 0.064), attack, "attack", true)
	var gradient = Gradient.new(); gradient.colors = PackedColorArray([Color("#6c340c"), Color("#de9d27"), Color("#fff29d"), Color("#dda026"), Color("#63350f")]); gradient.offsets = PackedFloat32Array([0, 0.2, 0.5, 0.8, 1])
	var gt = GradientTexture2D.new(); gt.gradient = gradient; gt.fill_from = Vector2(0, 0); gt.fill_to = Vector2(0, 1)
	var gold_bg = picture(attack_button, gt, Rect2(3, 3, 336, h * 0.064 - 6), TextureRect.STRETCH_SCALE)
	attack_button.move_child(gold_bg, 0)
	controls.attack_icon = picture(attack_button, icon("swords"), Rect2(35, 13, 50, h * 0.064 - 25))
	controls.attack_text = center_label(attack_button, "УДАРИТЬ", Rect2(94, 6, 213, h * 0.064 - 12), 31, Color("#351d0a"))
	for i in range(2):
		var key = "flame" if i == 0 else "frenzy"; var b = button(hud, "", Rect2(36 if i == 0 else 574, attack_y - 8, 110, 110), use_skill.bind(key), key)
		for child in b.get_children(): child.queue_free()
		for state in ["normal", "hover", "pressed", "disabled"]: b.add_theme_stylebox_override(state, StyleBoxEmpty.new())
		picture(b, Art.skill(i), Rect2(0, 0, 110, 110), TextureRect.STRETCH_SCALE)
		controls[key + "_caption"] = center_label(hud, "", Rect2(15 if i == 0 else 552, attack_y + 100, 153, 38), 15)
	var card_y = maxf(h * 0.657, status_y + 82); var card_h = h * 0.874 - card_y
	content = Control.new(); hud.add_child(content); place(content, Rect2(15, card_y, 690, card_h)); content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if tab == "hero": build_hero_cards(card_h)
	else: build_sheet(card_h)
	var nav_y = h * 0.895; var nav_h = h * 0.086
	var nav_names = ["Герой", "Отряд", "Задания", "Реликвии"]; var tabs = ["hero", "allies", "quests", "prestige"]; var icons = ["helmet", "party", "scroll", "rune"]
	for i in range(4):
		var b = button(hud, "", Rect2(5 + i * 179, nav_y, 173, nav_h), select_tab.bind(tabs[i]), "tab_" + tabs[i])
		if tabs[i] == tab:
			b.add_theme_stylebox_override("normal", rounded_skin(Color("#32291b"), 4)); trim(b, true)
		picture(b, icon(icons[i]), Rect2(50, 9, 73, nav_h * 0.48))
		center_label(b, nav_names[i], Rect2(2, nav_h * 0.52, 169, nav_h * 0.35), 21, Color("#ffe09a") if tabs[i] == tab else Color("#c8c0b1"))
	controls.info = center_label(hud, "", Rect2(170, h * 0.984, 380, 18), 11, Color("#beac85"))
	toast = center_label(hud, "", Rect2(102, h * 0.185, 516, 45), 17, Color("#ffe0a0")); toast.add_theme_stylebox_override("normal", rounded_skin(Color("#142021"), 4)); toast.visible = false
	refresh()

func wallet(parent: Control, rect: Rect2, glyph: String, key: String) -> void:
	var p = panel(parent, rect, Color("#14171c")); picture(p, icon(glyph), Rect2(-12, -4, 46, 46))
	controls[key] = center_label(p, "", Rect2(32, 4, rect.size.x - 55, 32), 19)
	var b = button(p, "+", Rect2(rect.size.x - 28, 6, 24, 27), open_shop, "wallet_" + key)
	b.add_theme_font_size_override("font_size", int(22 * factor))

func build_hero_cards(height: float) -> void:
	var titles = ["Меч героя", "Лис-спутник", "Талисман Искры"]; var kinds = ["sword", "ally", "amulet"]; var arts = [3, 2, 4]
	for i in range(3):
		var p = panel(content, Rect2(i * 233, 0, 224, height), Color("#111a23"))
		var title = label(p, titles[i], Rect2(13, 9, 202, 32), 23)
		var lv = label(p, "", Rect2(16, 40, 95, 24), 15)
		var artwork = picture(p, art(arts[i]), Rect2(6, 56, 211, maxf(52, height - 160)))
		var desc = label(p, "", Rect2(13, height - 92, 202, 26), 19)
		var b = button(p, "", Rect2(13, height - 62, 198, 48), purchase.bind(kinds[i], 0), "buy_" + kinds[i] if i != 1 else "buy_ally0", true)
		b.add_theme_stylebox_override("normal", rounded_skin(Color("#285c32"), 5)); b.add_theme_stylebox_override("hover", rounded_skin(Color("#35733d"), 5)); b.add_theme_stylebox_override("pressed", rounded_skin(Color("#193a24"), 5))
		var value = center_label(b, "", Rect2(12, 22, 174, 23), 20)
		center_label(b, "Улучшить", Rect2(8, 1, 182, 22), 20, Color("#f3e8c3"))
		hero_rows.append({"kind": kinds[i], "title": title, "artwork": artwork, "level": lv, "desc": desc, "button": b, "value": value })

func build_sheet(_height: float) -> void:
	var menu_height = screen.y * 0.69
	place(content, Rect2(15, screen.y * 0.185, 690, menu_height))
	var pane = panel(content, Rect2(0, 0, 690, menu_height), Color("#0e1720"))
	content = pane
	center_label(pane, "Спутники" if tab == "allies" else "Задания" if tab == "quests" else "Реликвии и возрождение", Rect2(20, 12, 500, 44), 30, GOLD)
	button(pane, "×", Rect2(604, 10, 66, 60), select_tab.bind("hero"), "close_menu")
	if tab == "allies": button(pane, "x" + ("MAX" if bulk < 0 else str(bulk)), Rect2(492, 13, 100, 54), cycle_bulk, "bulk")
	center_label(pane, "Листай пальцем вверх или вниз", Rect2(20, 65, 630, 32), 21, MUTED)
	menu_scroll = ScrollContainer.new(); menu_scroll.set_script(preload("res://scripts/touch_scroll.gd")); pane.add_child(menu_scroll)
	place(menu_scroll, Rect2(16, 111, 658, menu_height - 129)); menu_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	menu_scroll.get_v_scroll_bar().custom_minimum_size.x = 24 * factor
	var list = VBoxContainer.new(); menu_scroll.add_child(list); list.size_flags_horizontal = Control.SIZE_EXPAND_FILL; list.add_theme_constant_override("separation", int(16 * factor))
	var width = 626.0
	if tab == "allies":
		for i in range(game.ALLIES.size()):
			var row = make_row(list, width, 184)
			picture(row, Art.companion(i), Rect2(16, 14, 100, 100))
			var title = label(row, "", Rect2(132, 14, width - 148, 38), 26, GOLD)
			var desc = label(row, "", Rect2(132, 57, width - 148, 55), 22, MUTED); desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			var b = button(row, "", Rect2(18, 117, width - 36, 54), purchase.bind("ally", i), "buy_ally" + str(i), true); b.add_theme_font_size_override("font_size", int(24 * factor))
			rows.append({"kind": "ally", "index": i, "title": title, "desc": desc, "button": b })
	elif tab == "quests":
		for i in range(game.QUESTS.size()):
			var row = make_row(list, width, 181)
			label(row, game.QUESTS[i].name, Rect2(18, 10, width - 36, 38), 27, GOLD)
			var desc = label(row, "", Rect2(18, 54, width - 36, 46), 22, MUTED)
			var b = button(row, "", Rect2(18, 113, width - 36, 54), claim.bind(i), "claim" + str(i), true); b.add_theme_font_size_override("font_size", int(24 * factor))
			rows.append({"kind": "quest", "index": i, "desc": desc, "button": b })
	else:
		var loot = make_row(list, width, 214)
		label(loot, "Сундуки боссов", Rect2(18, 12, width - 36, 40), 28, GOLD)
		var desc = label(loot, "", Rect2(18, 61, width - 36, 73), 23, MUTED); desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		var b = button(loot, "", Rect2(18, 146, width - 36, 54), open_chest, "open_chest", true)
		rows.append({"kind": "loot", "desc": desc, "button": b })
		var relic_row = make_row(list, width, 415)
		label(relic_row, "Коллекция · сохраняется навсегда", Rect2(18, 12, width - 36, 40), 25, GOLD)
		var relic_desc = label(relic_row, "", Rect2(18, 68, width - 36, 330), 24)
		rows.append({"kind": "collection", "desc": relic_desc })
		var row = make_row(list, width, 408)
		label(row, "Возрождение героя", Rect2(18, 12, width - 36, 40), 28, GOLD)
		var rebirth_desc = label(row, "", Rect2(18, 66, width - 36, 245), 23, MUTED); rebirth_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		var rebirth_button = button(row, "", Rect2(18, 330, width - 36, 60), request_prestige, "rebirth", true)
		rows.append({"kind": "prestige", "desc": rebirth_desc, "button": rebirth_button })

func make_row(list: VBoxContainer, width: float, height: float) -> Panel:
	var p = super.make_row(list, width, height); p.mouse_filter = Control.MOUSE_FILTER_PASS; p.add_theme_stylebox_override("panel", rounded_skin(Color("#182431"), 3)); trim(p, false, false); return p

func refresh() -> void:
	if controls.is_empty(): return
	var in_mine = game.farming and not game.expedition.active
	var visible_region = 0 if game.expedition.active else game.region()
	if shown_region != visible_region:
		shown_region = 0 if game.expedition.active else game.region(); background.texture = Art.biome(shown_region)
	controls.gold.text = number(game.gold); controls.shards.text = str(game.shards)
	hero_level.text = "Ур. %d" % game.sword
	hero_caption.text = game.HEROES[game.hero_id].short
	hero_portrait.texture = art(5) if game.hero_id == 0 and not game.star_skin else Art.hero(game.hero_id, false, game.star_skin)
	refresh_hero_picker()
	controls.zone.text = game.ZONES[game.region()]; controls.stage.text = ("ЖИЛА %d" if in_mine else "ЭТАП %d") % game.stage
	var expedition = game.expedition
	var enemy_hp = expedition.hp if expedition.active else game.hp
	var enemy_max_hp = expedition.max_hp() if expedition.active else game.max_hp()
	controls.hp.value = enemy_hp / enemy_max_hp * 100
	controls.health.text = number(enemy_hp) + " / " + number(enemy_max_hp)
	enemy_label.text = "Золотая жила · запас руды" if in_mine else Art.foe_name(game.stage, game.region(), game.boss()) + (" · %.1f сек." % game.boss_time if game.boss() else "")
	var foe_index = Art.foe_index(game.stage, game.region(), game.boss())
	crest.texture = mining_art(3) if in_mine else Art.enemy(foe_index) if foe_index >= 0 else art(1)
	if expedition.active:
		controls.zone.text = "Сердце леса"
		controls.stage.text = "БОСС %d / 3 · %s" % [expedition.boss_index + 1, expedition.DIFFICULTIES[expedition.difficulty]]
		enemy_label.text = expedition.NAMES[expedition.boss_index] + " · %.1f сек." % expedition.time_left
		crest.texture = Art.enemy(expedition.ART[expedition.boss_index])
	controls.attack_text.text = "ДОБЫВАТЬ" if in_mine else "УДАРИТЬ"
	controls.attack_icon.texture = mining_art(2) if in_mine else icon("swords")
	var hpfill = rounded_skin(Color("#c3952d") if in_mine else Color("#b32932"), 1)
	controls.hp.add_theme_stylebox_override("fill", hpfill)
	controls.attack.text = ""
	for key in ["flame", "frenzy"]:
		var locked = game.best < (5 if key == "flame" else 15); var cd = game.flame_cd if key == "flame" else game.frenzy_cd
		controls[key].disabled = locked or cd > 0
		controls[key].modulate = Color("#8f929a") if locked or cd > 0 else Color.WHITE
		controls[key + "_caption"].text = ("Этап %d" % (5 if key == "flame" else 15)) if locked else ("%d сек." % int(ceil(cd))) if cd > 0 else "Огненный\nвзрыв" if key == "flame" else "Грозовой\nудар"
	controls.info.text = ("ДОБЫЧА ЗОЛОТА · " if in_mine else "") + number(game.dps()) + " урона / сек. · Искры +%d%%" % (game.shards * 15)
	controls.farm_status.text = ("Золото: ~" + number(game.reward() * game.dps() / game.max_hp() * 60) + " / мин.") if in_mine else hero_goal()
	if expedition.active: controls.farm_status.text = expedition.hint(game); controls.farm_status.add_theme_font_size_override("font_size", int(17 * factor))
	else: controls.farm_status.add_theme_font_size_override("font_size", int(22 * factor))
	controls.farm_status.visible = true
	controls.combo.text = "КОМБО %d · ×%.1f" % [game.combo, game.combo_bonus()]
	controls.combo.visible = game.combo > 1; combo_meter.visible = game.combo > 1; combo_meter.value = game.combo_left / 1.5 * 100
	controls.treasure_progress.text = "Открыть: %d" % game.treasures if game.treasures > 0 else "Ещё %d побед\nдо сундука" % maxi(0, game.treasure_goal - game.kills)
	controls.treasure_dot.visible = game.treasures > 0
	var buffs = ""
	if game.power_left > 0: buffs = "Урон ×2 · %d сек." % int(ceil(game.power_left))
	if game.shop_boost_seconds > 0: buffs += ("\n" if buffs != "" else "") + "Золото ×2 · магазин %d:%02d" % [int(ceil(game.shop_boost_seconds)) / 60, int(ceil(game.shop_boost_seconds)) % 60]
	elif game.gold_left > 0: buffs += ("\n" if buffs != "" else "") + "Золото ×2 · %d сек." % int(ceil(game.gold_left))
	controls.buff_status.text = buffs; controls.buff_status.visible = buffs != ""
	if is_instance_valid(modal) and controls.has("treasure_gold") and is_instance_valid(controls.treasure_gold):
		controls.treasure_gold.text = "Золото сразу · +" + number(game.treasure_gold())
	for row in hero_rows:
		var q = game.purchase_quote(row.kind, 0, bulk); row.level.text = "Ур. %d" % game.level(row.kind, 0)
		row.desc.text = "Урон: " + number(game.click_damage()) if row.kind == "sword" else "Помощь: " + number(game.ally_dps(0)) + " / сек." if row.kind == "ally" else "Золото: +%d%%" % (game.amulet * 3)
		row.value.text = number(q.cost) + " зол." if q.count > 0 else "Нет золота"
		row.button.disabled = q.count == 0 or game.gold < q.cost
		if row.kind == "sword":
			row.title.text = "Кирка героя" if in_mine else ["Меч героя", "Посох чародейки", "Лук охотницы", "Клинок рассвета", "Копьё грозы", "Посох душ", "Клинок дракона"][game.hero_id]
			row.artwork.texture = Art.hero(0, in_mine, true) if game.hero_id == 0 and game.star_skin else mining_art(2) if in_mine else art(3) if game.hero_id == 0 else Art.hero(game.hero_id)
			if in_mine: row.desc.text = "Добыча: " + number(game.click_damage())
	refresh_list()

func hero_goal() -> String:
	for i in range(1, game.HEROES.size()):
		if not game.owns_hero(i):
			return "%s: этап %d · %s зол." % [game.HEROES[i].short, game.hero_stage(i), number(game.HEROES[i].cost)] if game.best < game.hero_stage(i) else "%s: %s зол." % [game.HEROES[i].short, number(game.HEROES[i].cost)]
	if game.best >= 31 and not game.expedition.cleared[0]: return "Новая цель: экспедиция «Сердце леса»"
	if game.best >= 71 and not game.expedition.cleared[1]: return "Цель: сложная экспедиция"
	if game.best >= 121 and not game.expedition.cleared[2]: return "Цель: героическая экспедиция"
	return "Следующая цель: босс этапа %d" % (ceili(game.stage / 10.0) * 10)

func refresh_list() -> void:
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
			row.button.text = "ПОЛУЧЕНО" if game.claimed.has(i) else "ЗАБРАТЬ НАГРАДУ" if v >= d.target else "В ПРОЦЕССЕ"; row.button.disabled = game.claimed.has(i) or v < d.target
		elif kind == "loot":
			row.desc.text = "Сундуки за победы над боссами.\nБонус коллекции: +%d%% урона." % int(game.relic_bonus() * 100); row.button.text = "ОТКРЫТЬ · %d СУНДУКОВ" % game.chests if game.chests > 0 else "СУНДУКОВ НЕТ"; row.button.disabled = game.chests <= 0
		elif kind == "collection":
			var text = ""
			for i in range(game.RELICS.size()): text += (game.RELICS[i].name + " · ур. " + str(game.relics[i]) if game.relics[i] > 0 else "??? · " + game.RELICS[i].rarity) + "\n"
			row.desc.text = text
		else:
			row.desc.text = "Каждая Искра навсегда даёт +15% урона.\n\nСбросятся золото, снаряжение и спутники.\nРеликвии останутся.\n\nДоступно после победы на этапе 50."
			row.button.text = "ВОЗРОДИТЬСЯ · +%d ИСКР" % game.prestige_reward() if game.prestige_reward() > 0 else "НУЖНО ПРОЙТИ ЭТАП 50"; row.button.disabled = game.prestige_reward() <= 0

func attack() -> void:
	if is_instance_valid(modal) or get_tree().paused: return
	if OS.has_feature("web"):

		var allowed = JavaScriptBridge.eval("(window.IskraGuard ? window.IskraGuard.allowStrike() : true) ? 1 : 0", true)
		if allowed != 1.0: return
	var value = game.strike(); world.impact(); beep(); refresh()
	var l = center_label(hud, "-" + number(value) + (" КРИТ" if game.last_crit else ""), Rect2(420, screen.y * 0.34, 240, 72), 42, Color("#ffdb51"))
	l.add_theme_color_override("font_outline_color", Color("#a22710")); l.add_theme_constant_override("outline_size", int(3 * factor))
	var t = create_tween(); t.set_parallel(true); t.tween_property(l, "position", l.position - Vector2(0, 70) * factor, 0.7); t.tween_property(l, "modulate:a", 0, 0.7); t.chain().tween_callback(l.queue_free)

func open_skin_modal(title: String, height: float = 500) -> Panel:
	close_modal(); modal = Control.new(); ui.add_child(modal); modal.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var shade = ColorRect.new(); modal.add_child(shade); shade.color = Color(0, 0, 0, 0.8); shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var pw = minf(screen.x - 36, 620); var p = panel(modal, Rect2((screen.x - pw) / 2, (screen.y - height) / 2, pw, height))
	center_label(p, title, Rect2(20, 12, pw - 90, 44), 28, GOLD); button(p, "x", Rect2(pw - 56, 16, 36, 36), close_modal, "close_modal")
	notify_platform_break()
	return p

func show_heroes() -> void:
	hero_picker_rows.clear()
	var height = minf(920, screen.y - 54)
	var p = open_skin_modal("Герои Искры", height); var pw = p.size.x / factor
	var note = label(p, "7 героев · покупка навсегда · разные бонусы\nНовые герои: этапы 31, 71, 121 и золото.", Rect2(22, 67, pw - 44, 62), 20, MUTED)
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	controls.hero_wallet = label(p, "", Rect2(22, 135, pw - 44, 32), 23, GOLD)
	var scroll = ScrollContainer.new(); scroll.set_script(preload("res://scripts/touch_scroll.gd")); p.add_child(scroll)
	place(scroll, Rect2(18, 184, pw - 36, height - 205)); scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.get_v_scroll_bar().custom_minimum_size.x = 20 * factor
	var list = VBoxContainer.new(); scroll.add_child(list); list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", int(16 * factor))
	var width = pw - 65
	for i in range(game.HEROES.size()):
		var data = game.HEROES[i]; var row = make_row(list, width, 244)
		picture(row, Art.hero(i), Rect2(10, 18, 150, 184))
		var title = label(row, data.name, Rect2(172, 15, width - 187, 69), 27, Color(data.color)); title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		var role = label(row, data.role, Rect2(172, 84, width - 187, 52), 21, MUTED); role.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		var state = label(row, "", Rect2(172, 141, width - 187, 29), 22, GOLD)
		var b = button(row, "", Rect2(172, 184, width - 187, 46), choose_hero.bind(i), "hero_" + str(i), true)
		b.add_theme_font_size_override("font_size", int(21 * factor))
		hero_picker_rows.append({"index": i, "state": state, "button": b })
	refresh_hero_picker()

func refresh_hero_picker() -> void:
	if not is_instance_valid(modal): return
	if controls.has("hero_wallet") and is_instance_valid(controls.hero_wallet): controls.hero_wallet.text = "Твоё золото: " + number(game.gold)
	for row in hero_picker_rows:
		if not is_instance_valid(row.button): continue
		var i = int(row.index); var owned = game.owns_hero(i); var active = game.hero_id == i
		var price = float(game.HEROES[i].cost)
		var locked = game.best < game.hero_stage(i)
		row.state.text = "Текущий герой" if active else "Куплен навсегда" if owned else "Этап %d · %s зол." % [game.hero_stage(i), number(price)] if locked else number(price) + " золота"
		row.button.text = "ВЫБРАН" if active else "ВЫБРАТЬ" if owned else "ЭТАП %d" % game.hero_stage(i) if locked else "КУПИТЬ" if game.gold >= price else "НЕ ХВАТАЕТ"
		row.button.disabled = active or (not owned and (game.gold < price or locked))
		row.button.tooltip_text = "Не хватает " + number(maxf(0, price - game.gold)) + " золота" if not owned and game.gold < price else ""

func choose_hero(index: int) -> void:
	var owned = game.owns_hero(index)
	var success = game.select_hero(index) if owned else game.buy_hero(index)
	if not success: return
	save_game(); world.update(game, 0); refresh(); beep()
	tell(("Выбран: " if owned else "Куплен навсегда: ") + game.HEROES[index].name)

func release_notes_seen() -> bool:
	if OS.has_feature("web"):
		return str(JavaScriptBridge.eval("(()=>{try{return localStorage.getItem('iskra-release-seen-v1')||''}catch(e){return ''}})()", true)) == release_version
	return FileAccess.file_exists("user://release-seen.txt") and FileAccess.get_file_as_string("user://release-seen.txt") == release_version

func show_startup_screen() -> void:
	if not release_notes_seen(): show_release_notes()
	elif not game.tutorial_done: show_tutorial()

func show_release_notes() -> void:
	release_notes_active = false
	var height = minf(680, screen.y - 40)
	var p = open_skin_modal("Что нового · " + release_version, height)
	var pw = p.size.x / factor
	release_notes_active = true
	if OS.has_feature("web"): JavaScriptBridge.eval("window.IskraPlatform?.setActivityPaused(true)", true)
	var scroll = ScrollContainer.new()
	scroll.set_script(preload("res://scripts/touch_scroll.gd"))
	p.add_child(scroll)
	place(scroll, Rect2(24, 82, pw - 48, height - 198))
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var list = VBoxContainer.new()
	scroll.add_child(list)
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for item in ReleaseNotes.CHANGES:
		var text = label(list, "• " + item, Rect2(0, 0, pw - 82, 90), 24)
		text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		text.custom_minimum_size = Vector2((pw - 82) * factor, 110 * factor)
	button(p, "ПРОДОЛЖИТЬ", Rect2(24, height - 88, pw - 48, 60), close_modal, "release_continue", true)
	publish_state()

func mark_release_seen() -> void:
	if OS.has_feature("web"):
		JavaScriptBridge.eval("localStorage.setItem('iskra-release-seen-v1'," + JSON.stringify(release_version) + ")", true)
	else:
		var file = FileAccess.open("user://release-seen.txt", FileAccess.WRITE)
		if file: file.store_string(release_version)

func show_settings() -> void:
	var p = open_skin_modal("Настройки похода", 620); var pw = p.size.x / factor
	button(p, "Звук: " + ("включён" if game.sound else "выключен"), Rect2(24, 90, pw - 48, 55), func (): toggle_sound(); close_modal(); show_settings(), "sound")
	button(p, "Прокачка: x" + ("MAX" if bulk < 0 else str(bulk)), Rect2(24, 157, pw - 48, 55), func (): bulk = 10 if bulk == 1 else 25 if bulk == 10 else -1 if bulk == 25 else 1; close_modal(); rebuild(); show_settings(), "bulk")
	label(p, "Перчатки охотника · ур. %d\nУсиливают клик и шанс критического удара" % game.gloves, Rect2(24, 236, pw - 48, 55), 17)
	var q = game.purchase_quote("gloves", 0, bulk)
	var b = button(p, "Улучшить · " + number(q.cost) + " зол.", Rect2(24, 302, pw - 48, 55), func (): purchase("gloves", 0); close_modal(); show_settings(), "buy_gloves", true); b.disabled = q.count == 0 or game.gold < q.cost
	button(p, "Повторить обучение", Rect2(24, 390, pw - 48, 55), show_tutorial, "tutorial", true)
	label(p, "Прогресс сохраняется автоматически на этом устройстве.", Rect2(24, 500, pw - 48, 50), 15, MUTED)

func show_tutorial(step: int = 0) -> void:
	tutorial_active = true; tutorial_step = clampi(step, 0, LESSONS.size() - 1)
	if OS.has_feature("web"): JavaScriptBridge.eval("window.IskraPlatform.setTutorial(true)", true)
	var height = minf(720, screen.y - 54)
	var p = open_skin_modal("Обучение · %d / %d" % [tutorial_step + 1, LESSONS.size()], height)
	var pw = p.size.x / factor
	controls.close_modal.pressed.disconnect(close_modal)
	controls.close_modal.pressed.connect(finish_tutorial)
	picture(p, art(5) if tutorial_step == 0 else art(3) if tutorial_step == 1 else art(2) if tutorial_step == 2 else mining_art(2) if tutorial_step == 3 else Art.hero(4) if tutorial_step == 4 else art(4), Rect2((pw - 130) / 2, 80, 130, 125))
	center_label(p, LESSONS[tutorial_step][0], Rect2(28, 218, pw - 56, 55), 28, GOLD)
	var description = label(p, LESSONS[tutorial_step][1], Rect2(36, 288, pw - 72, height - 430), 25)
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	button(p, "НАЧАТЬ ПОХОД" if tutorial_step == LESSONS.size() - 1 else "ДАЛЬШЕ", Rect2(28, height - 88, pw - 56, 58), advance_tutorial, "tutorial_next", true)
	button(p, "Назад", Rect2(28, height - 141, (pw - 68) / 2, 40), func (): show_tutorial(tutorial_step - 1), "tutorial_back").disabled = tutorial_step == 0
	button(p, "Пропустить", Rect2(pw / 2 + 6, height - 141, (pw - 68) / 2, 40), finish_tutorial, "tutorial_skip")
	for key in ["tutorial_next", "tutorial_back", "tutorial_skip"]: controls[key].add_theme_font_size_override("font_size", int(24 * factor))
	publish_state()

func advance_tutorial() -> void:
	if tutorial_step == LESSONS.size() - 1: finish_tutorial()
	else: show_tutorial(tutorial_step + 1)

func finish_tutorial() -> void:
	tutorial_active = false; game.tutorial_done = true; close_modal(); save_game(); refresh(); publish_state()
	if OS.has_feature("web"): JavaScriptBridge.eval("window.IskraPlatform.setTutorial(false)", true)

func show_map() -> void:
	var p = open_skin_modal("Земли Искры", 700); var pw = p.size.x / factor
	var scroll = ScrollContainer.new(); scroll.set_script(preload("res://scripts/touch_scroll.gd")); p.add_child(scroll); place(scroll, Rect2(24, 82, pw - 48, 470)); scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var list = VBoxContainer.new(); scroll.add_child(list); list.size_flags_horizontal = Control.SIZE_EXPAND_FILL; list.add_theme_constant_override("separation", int(12 * factor))
	for i in range(8):
		var unlocked = game.best >= i * 20 + 1
		var row = make_row(list, pw - 82, 90)
		var b = button(row, ("Перейти · " if unlocked else "Этап %d · " % (i * 20 + 1)) + game.ZONES[i], Rect2(6, 6, pw - 94, 78), travel.bind(i), "travel" + str(i), unlocked); b.disabled = not unlocked
		b.add_theme_font_size_override("font_size", int(24 * factor))
	button(p, "Продолжить поход" if game.farming else "Добывать золото", Rect2(27, 588, pw - 54, 66), func (): farm(); close_modal(), "farm", true)

func travel(index: int) -> void:
	if game.visit_region(index): close_modal(); save_game(); refresh(); tell(game.ZONES[index])

func publish_state() -> void:
	super.publish_state()
	if OS.has_feature("web"):
		JavaScriptBridge.eval("Object.assign(window.rpgState," + JSON.stringify({"visible_allies": world.active_party, "foe_art": world.enemy_index, "biome": shown_region, "release_version": release_version, "release_notes_active": release_notes_active, "shop_soon_active": shop_soon_active, "tutorial_active": tutorial_active, "tutorial_step": tutorial_step, "tutorial_done": game.tutorial_done, "hero_id": game.hero_id, "hero_name": game.HEROES[game.hero_id].name, "owned_heroes": game.owned_heroes, "star_skin": game.star_skin, "shop_boost_seconds": game.shop_boost_seconds, "expedition": game.expedition.to_dict(), "expedition_hint": game.expedition.hint(game), "attack_style": world.last_attack_style }) + ")", true)

func show_treasures() -> void:
	var p = open_skin_modal("Сокровища · %d" % game.treasures, 630); var pw = p.size.x / factor
	if game.treasures <= 0:
		picture(p, art(8), Rect2((pw - 210) / 2, 90, 210, 200))
		center_label(p, "Ещё %d побед до сундука" % maxi(0, game.treasure_goal - game.kills), Rect2(22, 310, pw - 44, 70), 27, GOLD)
		var hint = center_label(p, "Первый сундук — после 5 побед.\nДальше — каждые 20.\nДобытые жилы тоже считаются!", Rect2(22, 402, pw - 44, 130), 23)
		hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		return
	center_label(p, "Выбери одну из трёх наград", Rect2(22, 70, pw - 44, 44), 25)
	var titles = ["Золото сразу · +" + number(game.treasure_gold()), "Боевая ярость · урон ×2", "Золотая лихорадка · золото ×2"]
	var notes = ["Купи улучшения прямо сейчас", "Все удары и отряд усилены на 60 сек.", "Двойная награда за победы на 60 сек."]
	var choices = ["gold", "power", "rush"]
	for i in range(3):
		var b = button(p, "", Rect2(22, 127 + i * 151, pw - 44, 127), choose_bonus.bind(choices[i]), "choose_" + choices[i], true)
		picture(b, icon("coin") if i == 0 else icon("swords") if i == 1 else mining_art(3), Rect2(15, 22, 73, 73))
		var title = label(b, titles[i], Rect2(104, 15, pw - 177, 46), 25, GOLD); title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		var note = label(b, notes[i], Rect2(104, 70, pw - 177, 44), 21); note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		if i == 0: controls.treasure_gold = title

func choose_bonus(kind: String) -> void:
	if game.choose_treasure(kind):
		close_modal(); save_game(); refresh(); beep()
		tell("Награда получена!" if kind == "gold" else "Урон ×2 на минуту!" if kind == "power" else "Золотая лихорадка на минуту!")

func _unhandled_input(event: InputEvent) -> void:
	if cloud_booting: return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_SPACE: attack()
		if event.keycode == KEY_ESCAPE: close_modal()
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT and not is_instance_valid(modal) and tab == "hero":
		if Rect2(Vector2((screen.x - 720) / 2 + 260, screen.y * 0.22) * factor, Vector2(460, screen.y * 0.31) * factor).has_point(event.position): attack()

func open_shop() -> void:
	var p = open_skin_modal("Лавка путешественника", minf(520, screen.y - 50))
	var pw = p.size.x / factor
	shop_soon_active = true
	if OS.has_feature("web"): JavaScriptBridge.eval("window.IskraPlatform?.setActivityPaused(true)", true)
	picture(p, icon("coin"), Rect2((pw - 90) / 2, 88, 90, 90))
	center_label(p, "Скоро появится", Rect2(22, 197, pw - 44, 58), 34, GOLD)
	var note = center_label(p, "Лавка готовится к открытию.\nПокупки пока недоступны.\n\nПродолжай поход: все герои\nоткрываются за игровое золото.", Rect2(26, 262, pw - 52, 145), 22, MUTED)
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	button(p, "Продолжить поход", Rect2(22, 430, pw - 44, 60), close_modal, "shop_soon_close", true)
	publish_state()

func open_social(view: String) -> void:
	close_modal()
	if OS.has_feature("web"):
		JavaScriptBridge.eval("window.IskraSocial?.open(" + JSON.stringify(view) + ");void 0", true)
	else:
		tell("Профиль и рейтинг доступны на Яндекс Играх.")

func close_modal() -> void:
	shop_soon_active = false
	var closed_release = release_notes_active
	if closed_release:
		mark_release_seen()
		release_notes_active = false
	super.close_modal()
	expedition_menu = false
	if OS.has_feature("web"): JavaScriptBridge.eval("window.IskraPlatform?.setActivityPaused(false)", true)
	if closed_release and not game.tutorial_done: call_deferred("show_tutorial")

func show_expeditions() -> void:
	var p = open_skin_modal("Сердце Шепчущего леса", minf(950, screen.y - 50))
	var pw = p.size.x / factor
	expedition_menu = true
	if OS.has_feature("web"): JavaScriptBridge.eval("window.IskraPlatform?.setActivityPaused(true)", true)
	var expedition = game.expedition
	var description = label(p, "Три босса: щит, лечение и рой. По 75 секунд на каждого.\nВыбирай героя под механику. Во время выбора игра на паузе.", Rect2(22, 70, pw - 44, 90), 20, MUTED)
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var status = label(p, expedition.result if expedition.result != "" else "Первое прохождение сложности усиливает Сердце леса навсегда.", Rect2(22, 175, pw - 44, 80), 22, GOLD)
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if expedition.active:
		label(p, "Босс %d / 3: %s" % [expedition.boss_index + 1, expedition.NAMES[expedition.boss_index]], Rect2(22, 270, pw - 44, 65), 25, GOLD)
		button(p, "Вернуться к бою", Rect2(22, 365, pw - 44, 68), close_modal, "expedition_resume", true)
		button(p, "Покинуть экспедицию", Rect2(22, 450, pw - 44, 60), leave_expedition, "expedition_leave")
		publish_state()
		return
	for i in range(3):
		var y = 270 + i * 150
		var row = panel(p, Rect2(22, y, pw - 44, 137))
		label(row, expedition.DIFFICULTIES[i] + (" · пройдена" if expedition.cleared[i] else ""), Rect2(14, 8, pw - 75, 32), 24, GOLD)
		label(row, "Первый раз: +%d%% урона · %d осколков" % [[10, 15, 20][i], expedition.MATERIALS[i]], Rect2(14, 45, pw - 75, 28), 19, MUTED)
		var locked = game.best < expedition.UNLOCKS[i]
		var b = button(row, "Нужен этап %d" % expedition.UNLOCKS[i] if locked else "Начать экспедицию", Rect2(14, 80, pw - 75, 44), start_expedition.bind(i), "expedition_" + str(i), not locked)
		b.disabled = locked
	label(p, "Сердце леса: +%d%% урона · ур. %d\nОсколки: %d · осталось наград: %d / 3 (UTC)" % [int(round(expedition.permanent_bonus() * 100)), expedition.heart_level, expedition.materials, expedition.rewards_left()], Rect2(22, 731, pw - 44, 70), 22, GOLD)
	var cost = expedition.upgrade_cost()
	var b = button(p, "Улучшить сердце · %d осколков (+2%% урона)" % cost if expedition.heart_level < 20 else "Сердце леса: максимальный уровень", Rect2(22, 820, pw - 44, 60), upgrade_heart, "upgrade_heart", true)
	b.disabled = not expedition.cleared.has(true) or expedition.heart_level >= 20 or expedition.materials < cost
	publish_state()

func start_expedition(index: int) -> void:
	if game.expedition.start(game, index):
		close_modal(); world.update(game, 0); save_game(); refresh(); tell("Экспедиция началась. Победи трёх боссов!")

func leave_expedition() -> void:
	game.expedition.leave(game); expedition_result_seen = game.expedition.result_serial
	save_game(); show_expeditions()

func upgrade_heart() -> void:
	if game.expedition.upgrade(): save_game(); show_expeditions()

func reset_full_progress() -> void:
	if OS.has_feature("web"): JavaScriptBridge.eval("window.IskraCloud?.reset();void 0", true)
	var paid_skin = game.star_skin
	var paid_boost = game.shop_boost_seconds
	close_modal(); game = Economy.new(); game.star_skin = paid_skin; game.shop_boost_seconds = paid_boost
	tab = "hero"; bulk = 1; tutorial_active = false; tutorial_step = 0; expedition_result_seen = 0
	if OS.has_feature("web"): JavaScriptBridge.eval("window.IskraPlatform?.setTutorial(false)", true)
	sound_player.stop(); playback = null; last_kills = 0; last_earned = 0
	rebuild(); world.update(game, 0); save_game(); publish_state(); call_deferred("show_tutorial")

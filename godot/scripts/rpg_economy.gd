extends RefCounted
const Expedition = preload("res://scripts/expedition.gd")
var expedition = Expedition.new()

const HEROES = [
	{"name": "Герой Искры", "short": "Искра", "role": "Воин с огненным мечом", "cost": 0.0, "color": "#ffb35b" },
	{"name": "Ледяная чародейка", "short": "Лёд", "role": "Урон нажатия +10%", "cost": 2500.0, "color": "#86dbff", "click": 1.1 },
	{"name": "Лесная охотница", "short": "Лес", "role": "Автоматический урон +15%", "cost": 15000.0, "color": "#b3e78c", "idle": 1.15 },
	{"name": "Рыцарь рассвета", "short": "Рассвет", "role": "Золото за победы +15%", "cost": 100000.0, "color": "#ffe5a1", "gold": 1.15 },
	{"name": "Страж грозы", "short": "Гроза", "role": "Урон нажатия +30%", "cost": 500000.0, "color": "#86bbff", "stage": 31, "click": 1.3 },
	{"name": "Хранительница душ", "short": "Души", "role": "Автоматический урон +40%", "cost": 5000000.0, "color": "#c6a2ff", "stage": 71, "idle": 1.4 },
	{"name": "Драконий рыцарь", "short": "Дракон", "role": "Весь урон +35% · золото +10%", "cost": 50000000.0, "color": "#ff9179", "stage": 121, "click": 1.35, "idle": 1.35, "gold": 1.1 }]

var star_skin = false
var shop_boost_seconds = 0.0
var hero_id: int = 0
var owned_heroes: Array = [true, false, false, false, false, false, false]
var tutorial_done: bool = false

func hero_stage(index: int) -> int:
	return int(HEROES[index].get("stage", 1))

func hero_bonus(kind: String) -> float:
	return float(HEROES[hero_id].get(kind, 1.0))

func owns_hero(index: int) -> bool:
	return index >= 0 and index < HEROES.size() and owned_heroes[index] == true

func buy_hero(index: int) -> bool:
	if index <= 0 or index >= HEROES.size() or owns_hero(index): return false
	var cost: float = HEROES[index].cost
	if gold < cost or best < hero_stage(index): return false
	gold -= cost; owned_heroes[index] = true; hero_id = index
	return true

func select_hero(index: int) -> bool:
	if not owns_hero(index): return false
	hero_id = index
	return true

const ALLIES = [
	{"name": "Лис-разведчик", "role": "Первый спутник", "cost": 50.0, "dps": 1.5, "stage": 1, "color": "#ce8a50" },
	{"name": "Лесная лучница", "role": "Стрелы из тени", "cost": 350.0, "dps": 9.0, "stage": 8, "color": "#75b99d" },
	{"name": "Ученик мага", "role": "Искры и заклинания", "cost": 2400.0, "dps": 48.0, "stage": 18, "color": "#8d85d0" },
	{"name": "Страж рассвета", "role": "Несокрушимый щит", "cost": 18000.0, "dps": 270.0, "stage": 30, "color": "#dcb96a" },
	{"name": "Лунная ведьма", "role": "Сила древних рун", "cost": 140000.0, "dps": 1700.0, "stage": 45, "color": "#af83cf" },
	{"name": "Рыцарь пепла", "role": "Последний из ордена", "cost": 1100000.0, "dps": 10000.0, "stage": 65, "color": "#df7863" },
	{"name": "Хранитель времени", "role": "За гранью веков", "cost": 9500000.0, "dps": 68000.0, "stage": 90, "color": "#76bfc9" },
	{"name": "Дракон Искры", "role": "Легенда пробуждается", "cost": 85000000.0, "dps": 450000.0, "stage": 120, "color": "#e9a966" }]
const ZONES = ["Шепчущий лес", "Руины королей", "Кристальные пещеры", "Пепельная пустошь", "Лунный перевал", "Затонувший храм", "Цитадель теней", "Сердце дракона"]
const FOES = ["Древесный страж", "Дикий древень", "Каменный страж", "Пепельный древень", "Лунный страж", "Страж глубин", "Теневой древень", "Древний хранитель"]
const BOSSES = ["Король корней", "Павший король", "Кристальный титан", "Владыка пепла", "Пожиратель луны", "Древний левиафан", "Повелитель теней", "Дракон забвения"]
const RELICS = [
	{"name": "Зуб лесного зверя", "rarity": "Обычная", "power": 0.03, "color": "#a4b8a6" },
	{"name": "Осколок щита", "rarity": "Обычная", "power": 0.03, "color": "#a4b8a6" },
	{"name": "Знак разведчика", "rarity": "Обычная", "power": 0.03, "color": "#a4b8a6" },
	{"name": "Лунный камень", "rarity": "Редкая", "power": 0.06, "color": "#78b9de" },
	{"name": "Руна стража", "rarity": "Редкая", "power": 0.06, "color": "#78b9de" },
	{"name": "Перо феникса", "rarity": "Эпическая", "power": 0.12, "color": "#b597da" },
	{"name": "Око ведьмы", "rarity": "Эпическая", "power": 0.12, "color": "#b597da" },
	{"name": "Сердце Искры", "rarity": "Легендарная", "power": 0.25, "color": "#e3b66c" }]
const QUESTS = [
	{"name": "Первая победа", "kind": "kills", "target": 1, "reward": 20.0 },
	{"name": "Верный спутник", "kind": "allies", "target": 1, "reward": 60.0 },
	{"name": "Сотня ударов", "kind": "clicks", "target": 100, "reward": 140.0 },
	{"name": "Первый босс", "kind": "best", "target": 11, "reward": 220.0 },
	{"name": "Меч ученика", "kind": "sword", "target": 25, "reward": 850.0 },
	{"name": "Новые земли", "kind": "best", "target": 21, "reward": 1500.0 },
	{"name": "Отряд собран", "kind": "allies", "target": 10, "reward": 3500.0 },
	{"name": "Сотня побед", "kind": "kills", "target": 100, "reward": 6500.0 },
	{"name": "Право на возрождение", "kind": "best", "target": 51, "reward": 20000.0 },
	{"name": "Вторая жизнь", "kind": "rebirths", "target": 1, "reward": 500.0 },
	{"name": "За горизонтом", "kind": "best", "target": 101, "reward": 250000.0 },
	{"name": "Тысяча побед", "kind": "kills", "target": 1000, "reward": 2000000.0 }]

var gold: float = 30.0
var stage: int = 1
var best: int = 1
var hp: float = 32.0
var boss_time: float = 30.0
var sword: int = 1
var gloves: int = 1
var amulet: int = 0
var allies: Array = [0, 0, 0, 0, 0, 0, 0, 0]
var shards: int = 0
var rebirths: int = 0
var kills: int = 0
var clicks: int = 0
var earned: float = 0.0
var farming: bool = false
var farm_stage: int = 1
var claimed: Array = []
var saved_at: float = 0.0
var played: float = 0.0
var flame_cd: float = 0.0
var frenzy_cd: float = 0.0
var frenzy_left: float = 0.0
var sound: bool = false
var last_crit: bool = false
var events: Array = []
var chests: int = 0
var relics: Array = [0, 0, 0, 0, 0, 0, 0, 0]
var combo: int = 0
var combo_left: float = 0.0
var treasures: int = 0
var treasure_goal: int = 5
var power_left: float = 0.0
var gold_left: float = 0.0

func combo_bonus() -> float: return 1.0 + minf(1.5, maxi(0, combo - 1) * 0.1)
func treasure_gold() -> float:
	var target = maxi(1, best - 1)
	if target % 10 == 0: target -= 1
	return floor(reward(target) * 18.0)
func choose_treasure(kind: String) -> bool:
	if treasures <= 0 or kind not in ["gold", "power", "rush"]: return false
	treasures -= 1
	if kind == "gold": gain(treasure_gold())
	elif kind == "power": power_left = minf(180.0, power_left + 60.0)
	else: gold_left = minf(180.0, gold_left + 60.0)
	return true

func safe_pow(base: float, power: float) -> float:
	return pow(base, minf(power, log(1.0e100) / log(base)))

func region() -> int: return ((stage - 1) / 20) % ZONES.size()
func boss() -> bool: return stage % 10 == 0
func max_hp(at: int = -1) -> float:
	var s = stage if at < 0 else at
	return 32.0 * safe_pow(1.2, s - 1) * (8.0 if s % 10 == 0 else 1.0)
func reward(at: int = -1) -> float:
	var s = stage if at < 0 else at
	return 8.0 * safe_pow(1.135, s - 1) * (6.0 if s % 10 == 0 else 1.0) * (1.0 + amulet * 0.03) * (2.0 if gold_left > 0 or shop_boost_seconds > 0 else 1.0) * hero_bonus("gold")
func relic_bonus() -> float:
	var value = expedition.permanent_bonus()
	for i in range(relics.size()): value += int(relics[i]) * RELICS[i].power
	return value
func bonus() -> float: return (1.0 + shards * 0.15) * (1.0 + relic_bonus()) * (2.0 if power_left > 0 else 1.0)
func open_chest() -> int:
	if chests <= 0: return -1
	chests -= 1
	var roll = randf(); var index = randi_range(0, 2) if roll < 0.6 else randi_range(3, 4) if roll < 0.85 else randi_range(5, 6) if roll < 0.97 else 7
	relics[index] = int(relics[index]) + 1
	return index
func weapon_power() -> float: return (2.0 + sword * 2.0) * safe_pow(1.055, sword) * safe_pow(2.0, sword / 25)
func click_damage() -> float: return weapon_power() * (1.0 + gloves * 0.15) * bonus() * (3.0 if frenzy_left > 0 else 1.0) * hero_bonus("click")
func ally_dps(index: int) -> float:
	var lv = int(allies[index])
	return ALLIES[index].dps * lv * safe_pow(1.035, lv) * safe_pow(2.0, lv / 25) * bonus()
func dps() -> float:
	var value = weapon_power() * 0.6 * bonus()
	for i in range(allies.size()): value += ally_dps(i)
	return value * (3.0 if frenzy_left > 0 else 1.0) * hero_bonus("idle")
func crit_chance() -> float: return minf(0.35, 0.05 + gloves * 0.002)
func gain(value: float) -> void:
	gold = minf(1.0000000000000001e120, gold + value); earned = minf(1.0000000000000001e120, earned + value)

func reset_enemy() -> void:
	hp = max_hp(); boss_time = 30.0

func strike() -> float:
	clicks += 1
	combo = combo + 1 if combo_left > 0 else 1; combo_left = 1.5
	last_crit = randf() < crit_chance()
	var value = click_damage() * combo_bonus() * (3.0 if last_crit else 1.0)
	if expedition.active: value = expedition.damage(self, value, true)
	else: damage(value)
	return value

func damage(value: float) -> void:
	if expedition.active:
		expedition.damage(self, value)
		return
	hp -= maxf(0.0, value)
	if hp <= 0:
		gain(reward())

		if farming:
			reset_enemy()
			return
		kills += 1
		if kills >= treasure_goal:
			treasures += 1; treasure_goal = kills + 20
			events.append("Найден сундук! Выбери награду в «Сокровищах»")
		if boss():
			chests += 1
			events.append("Босс повержен! Сундук реликвий ждёт во вкладке «Искра»")
		if not farming:
			stage += 1; best = maxi(best, stage)
			if (stage - 1) % 20 == 0: events.append("Новая земля: " + ZONES[region()])
		reset_enemy()

func tick(delta: float) -> void:
	played += delta
	combo_left = maxf(0.0, combo_left - delta)
	if combo_left <= 0: combo = 0
	power_left = maxf(0.0, power_left - delta); gold_left = maxf(0.0, gold_left - delta)
	flame_cd = maxf(0.0, flame_cd - delta); frenzy_cd = maxf(0.0, frenzy_cd - delta)
	frenzy_left = maxf(0.0, frenzy_left - delta)
	if expedition.active:
		expedition.tick(self, delta)
		return
	if boss() and not farming:
		boss_time -= delta
		if boss_time <= 0:
			farming = true; farm_stage = recommended_farm_stage(); stage = farm_stage; reset_enemy()
			events.append("Босс слишком силён. Копи золото и усиливай отряд")
	damage(dps() * delta)

func toggle_farm() -> void:
	if expedition.active: return
	combo = 0; combo_left = 0
	if farming:
		farming = false; stage = best
	else:
		farming = true; farm_stage = recommended_farm_stage(); stage = farm_stage
	reset_enemy()

func recommended_farm_stage() -> int:
	var target = maxi(1, best - 1)
	while target > 1 and (target % 10 == 0 or max_hp(target) / maxf(0.01, dps()) > 3.0):
		target -= 1
	return target

func visit_region(index: int) -> bool:
	if expedition.active: return false
	if index < 0 or index >= ZONES.size() or best < index * 20 + 1: return false
	stage = index * 20 + 1; farming = false; combo = 0; combo_left = 0; reset_enemy()
	return true

func skill(kind: String) -> bool:
	if kind == "flame" and flame_cd <= 0 and best >= 5:
		if expedition.active: expedition.burst()
		flame_cd = 25.0; damage(click_damage() * 12.0 + dps() * 3.0); return true
	if kind == "frenzy" and frenzy_cd <= 0 and best >= 15:
		frenzy_cd = 60.0; frenzy_left = 10.0; return true
	return false

func level(kind: String, index: int = 0) -> int:
	return int(allies[index]) if kind == "ally" else sword if kind == "sword" else gloves if kind == "gloves" else amulet
func unit_cost(kind: String, index: int, lv: int) -> float:
	if kind == "ally": return ALLIES[index].cost * safe_pow(1.13, lv)
	if kind == "sword": return 15.0 * safe_pow(1.17, lv - 1)
	if kind == "gloves": return 25.0 * safe_pow(1.18, lv - 1)
	return 80.0 * safe_pow(1.2, lv)
func purchase_quote(kind: String, index: int = 0, count: int = 1) -> Dictionary:
	var lv = level(kind, index)
	var total: float = 0.0
	var bought = 0
	for i in range(1000 if count < 0 else count):
		var cost = unit_cost(kind, index, lv + i)
		if count < 0 and total + cost > gold: break
		total += cost; bought += 1
	return {"cost": total, "count": bought }
func buy(kind: String, index: int = 0, count: int = 1) -> bool:
	if kind == "ally" and best < int(ALLIES[index].stage): return false
	var q = purchase_quote(kind, index, count)
	if q.count == 0 or gold + 1.0e-5 < q.cost: return false
	gold = maxf(0.0, gold - q.cost)
	if kind == "sword": sword += int(q.count)
	elif kind == "gloves": gloves += int(q.count)
	elif kind == "amulet": amulet += int(q.count)
	else: allies[index] = int(allies[index]) + int(q.count)
	return true

func quest_value(kind: String) -> int:
	if kind == "kills": return kills
	if kind == "clicks": return clicks
	if kind == "best": return best
	if kind == "sword": return sword
	if kind == "rebirths": return rebirths
	var n = 0
	for lv in allies: n += int(lv)
	return n
func claim(index: int) -> bool:
	if claimed.has(index) or quest_value(QUESTS[index].kind) < QUESTS[index].target: return false
	claimed.append(index); gain(QUESTS[index].reward); return true
func prestige_reward() -> int:
	return int(pow(maxf(0.0, (best - 40) / 10.0), 1.25)) if best >= 51 else 0
func prestige() -> bool:
	if expedition.active: return false
	var n = prestige_reward()
	if n <= 0: return false
	shards += n; rebirths += 1; gold = 30.0; stage = 1; best = 1
	sword = 1; gloves = 1; amulet = 0; allies = [0, 0, 0, 0, 0, 0, 0, 0]; farming = false
	flame_cd = 0; frenzy_cd = 0; frenzy_left = 0; combo = 0; combo_left = 0; power_left = 0; gold_left = 0; reset_enemy()
	return true
func offline(seconds: float) -> float:
	var s = maxi(1, best - 1)
	if s % 10 == 0: s -= 1
	var rate = minf(1.5, dps() / max_hp(s))
	var value = reward(s) * rate * minf(28800.0, maxf(0.0, seconds)) * 0.6
	gain(value)
	return value
func to_dict() -> Dictionary:
	return {"version": 2, "expedition": expedition.to_dict(), "gold": gold, "stage": stage, "best": best, "hp": hp, "boss_time": boss_time, "sword": sword, "gloves": gloves, "amulet": amulet, "allies": allies, "shards": shards, "rebirths": rebirths, "kills": kills, "clicks": clicks, "earned": earned, "farming": farming, "farm_stage": farm_stage, "claimed": claimed, "saved_at": Time.get_unix_time_from_system(), "played": played, "sound": sound, "flame_cd": flame_cd, "frenzy_cd": frenzy_cd, "chests": chests, "relics": relics, "treasures": treasures, "treasure_goal": treasure_goal, "power_left": power_left, "gold_left": gold_left, "hero_id": hero_id, "owned_heroes": owned_heroes.duplicate(), "tutorial_done": tutorial_done }
func load_dict(data: Dictionary) -> bool:
	if data.get("version", 0) != 2: return false
	owned_heroes = [true, false, false, false, false, false, false]; hero_id = 0
	tutorial_done = data.get("tutorial_done", true) == true
	var heroes = data.get("owned_heroes", [])
	if heroes is Array:
		for i in range(1, mini(heroes.size(), HEROES.size())): owned_heroes[i] = heroes[i] is bool and heroes[i] == true
	var selected = data.get("hero_id", 0)
	if (selected is int or selected is float) and is_finite(float(selected)):
		var index = clampi(int(selected), 0, HEROES.size() - 1)
		if owns_hero(index): hero_id = index
	for key in ["gold", "earned", "played", "saved_at"]:
		var v = data.get(key, 0)
		if (v is int or v is float) and is_finite(float(v)): set(key, clampf(float(v), 0.0, 1.0000000000000001e120))
	for key in ["stage", "best", "sword", "gloves", "amulet", "shards", "rebirths", "kills", "clicks", "farm_stage", "chests"]:
		var v = data.get(key, 0)
		if v is int or v is float: set(key, clampi(int(v), 1 if key in ["stage", "best", "sword", "gloves", "farm_stage"] else 0, 1000000))
	best = maxi(stage, best)
	var a = data.get("allies", [])
	if a is Array and a.size() == 8:
		for i in range(8):
			if a[i] is int or a[i] is float: allies[i] = clampi(int(a[i]), 0, 1000000)
	var c = data.get("claimed", [])
	var r = data.get("relics", [])
	if r is Array and r.size() == 8:
		for i in range(8):
			if r[i] is int or r[i] is float: relics[i] = clampi(int(r[i]), 0, 1000000)
	if c is Array:
		for value in c:
			if value is int and value >= 0 and value < QUESTS.size() and not claimed.has(value): claimed.append(value)
	farming = data.get("farming", false) == true; sound = data.get("sound", false) == true
	hp = clampf(float(data.get("hp", max_hp())), 0.01, max_hp())
	boss_time = clampf(float(data.get("boss_time", 30)), 0.1, 30.0)
	flame_cd = clampf(float(data.get("flame_cd", 0)), 0, 25); frenzy_cd = clampf(float(data.get("frenzy_cd", 0)), 0, 60)
	treasures = clampi(int(data.get("treasures", 0)), 0, 1000000)
	treasure_goal = maxi(kills + 1, int(data.get("treasure_goal", kills + 5)))
	var away = maxf(0.0, Time.get_unix_time_from_system() - saved_at) if saved_at > 0 else 0.0
	power_left = maxf(0.0, clampf(float(data.get("power_left", 0)), 0, 180) - away)
	gold_left = maxf(0.0, clampf(float(data.get("gold_left", 0)), 0, 180) - away)
	expedition.load_dict(data.get("expedition", {}), best)
	return true

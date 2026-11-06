extends RefCounted
const DIFFICULTIES = ["Обычная", "Сложная", "Героическая"]
const UNLOCKS = [31, 71, 121]
const NAMES = ["Страж корней", "Дух исцеления", "Владыка роя"]
const ART = [8, 4, 0]
const MATERIALS = [6, 12, 20]
var cleared = [false, false, false]
var materials = 0
var heart_level = 0
var reward_day = 0
var daily_rewards = 0
var active = false
var difficulty = 0
var boss_index = 0
var hp = 0.0
var time_left = 75.0
var elapsed = 0.0
var mechanic_clock = 0.0
var adds = 0
var interrupt_left = 0.0
var result = ""
var result_serial = 0

func day() -> int: return int(Time.get_unix_time_from_system() / 86400.0)
func refresh_day() -> void:
	if day() > reward_day: reward_day = day(); daily_rewards = 0
func rewards_left() -> int:
	refresh_day(); return maxi(0, 3 - daily_rewards)
func permanent_bonus() -> float:
	var value = heart_level * 0.02
	for i in range(3):
		if cleared[i]: value += [0.1, 0.15, 0.2][i]
	return value
func upgrade_cost() -> int: return int(ceil(12 * pow(1.35, heart_level)))
func upgrade() -> bool:
	if not cleared.has(true) or heart_level >= 20 or materials < upgrade_cost(): return false
	materials -= upgrade_cost(); heart_level += 1; return true
func max_hp() -> float:
	var stages = [30, 70, 120]
	return 32.0 * pow(1.2, stages[difficulty] + boss_index * 3 - 1) * 8.0
func start(game, index: int) -> bool:
	if active or index < 0 or index >= 3 or game.best < UNLOCKS[index]: return false
	refresh_day(); difficulty = index; boss_index = 0; active = true; result = ""; reset_boss(); return true
func reset_boss() -> void:
	hp = max_hp(); time_left = 75; elapsed = 0; mechanic_clock = 0; adds = 0; interrupt_left = 0
func shielded() -> bool: return boss_index == 0 and fmod(elapsed, 8.0) < 3.0 and interrupt_left <= 0
func hint(game) -> String:
	if boss_index == 0:
		return "Щит: мечи пробивают · взрыв снимает" if shielded() else "Щит опущен — атакуй!"
	if boss_index == 1:
		return "Лечение каждые 6 сек. · Лёд блокирует" if game.hero_id != 1 else "Лёд блокирует лечение босса"
	return "Рой: %d · Лес и взрыв уничтожают рой" % adds
func burst() -> void: interrupt_left = 3.0; adds = 0
func damage(game, value: float, manual: bool = false) -> float:
	if not active: return 0.0
	var amount = maxf(0, value)
	if shielded() and game.hero_id not in [0, 3, 4, 6]: amount *= 0.2
	if boss_index == 2 and adds > 0:
		if game.hero_id == 2: adds = 0
		elif manual: adds -= 1; amount *= 0.2
		else: amount *= 0.2
	hp -= amount
	if hp <= 0:
		if boss_index < 2:
			boss_index += 1; reset_boss(); game.events.append("Следующий босс: " + NAMES[boss_index])
		else: finish(game, true)
	return amount
func tick(game, delta: float) -> void:
	if not active: return
	elapsed += delta; time_left -= delta; mechanic_clock += delta; interrupt_left = maxf(0, interrupt_left - delta)
	if time_left <= 0: finish(game, false); return
	if boss_index == 1 and mechanic_clock >= 6:
		mechanic_clock = 0
		if game.hero_id != 1 and interrupt_left <= 0: hp = minf(max_hp(), hp + max_hp() * 0.07)
	elif boss_index == 2 and mechanic_clock >= 7:
		mechanic_clock = 0; adds = 1 if game.hero_id == 5 else 3
	damage(game, game.dps() * delta)
func finish(game, won: bool) -> void:
	if not active: return
	active = false; result_serial += 1
	if not won:
		result = "Время вышло. Усиль отряд или выбери героя под механику босса. Поход сохранён."
	else:
		refresh_day(); result = "Экспедиция пройдена!"
		if not cleared[difficulty]:
			cleared[difficulty] = true
			result += " Сердце леса: постоянный урон +%d%%." % int([10, 15, 20][difficulty])
		if daily_rewards < 3:
			daily_rewards += 1; materials += MATERIALS[difficulty]
			result += " Получено %d осколков леса." % MATERIALS[difficulty]
		else: result += " Дневные награды получены; новые осколки доступны завтра по UTC."
	game.events.append(result)
func leave(game) -> void:
	if active:
		active = false; result = "Экспедиция прервана. Твой поход сохранён."; result_serial += 1
func to_dict() -> Dictionary:
	return {"cleared": cleared.duplicate(), "materials": materials, "heart_level": heart_level, "reward_day": reward_day, "daily_rewards": daily_rewards, "active": active, "difficulty": difficulty, "boss_index": boss_index, "hp": hp, "time_left": time_left, "elapsed": elapsed, "mechanic_clock": mechanic_clock, "adds": adds, "interrupt_left": interrupt_left }
func load_dict(data: Variant, best: int) -> void:
	if not data is Dictionary: return
	var flags = data.get("cleared", [])
	if flags is Array:
		for i in range(mini(3, flags.size())): cleared[i] = flags[i] == true
	for key in ["materials", "heart_level", "reward_day", "daily_rewards", "difficulty", "boss_index", "adds"]:
		var v = data.get(key, 0)
		if (v is int or v is float) and is_finite(float(v)): set(key, maxi(0, int(v)))
	heart_level = mini(20, heart_level); difficulty = mini(2, difficulty); boss_index = mini(2, boss_index); adds = mini(3, adds); daily_rewards = mini(3, daily_rewards)
	for key in ["hp", "time_left", "elapsed", "mechanic_clock", "interrupt_left"]:
		var v = data.get(key, 0)
		if (v is int or v is float) and is_finite(float(v)): set(key, maxf(0, float(v)))
	hp = clampf(hp, 0.01, max_hp()); time_left = clampf(time_left, 0.01, 75); interrupt_left = minf(3, interrupt_left)
	active = data.get("active", false) == true and best >= UNLOCKS[difficulty]
	refresh_day()

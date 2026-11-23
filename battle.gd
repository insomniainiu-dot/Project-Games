class_name Battle
extends CanvasLayer
## ระบบต่อสู้แบบผลัดกันบุก-รับ
## ฝ่ายบุกเลือก: Attack / Strike / Magic (หรือใช้ไอเทม / หนี)
## ฝ่ายรับเลือก: Guard / Counter / Ward
##   Attack  : ดาเมจปกติ  -> Guard ลดครึ่ง
##   Strike  : ดาเมจ x2  -> แต่ถ้าเจอ Counter จะสะท้อนกลับใส่คนตี
##   Magic   : ใช้ค่า MAG ไม่ค่อยสน DEF -> Ward ลดเหลือ 40%
## ใช้:  var result: String = await battle.start(player, "Goblin")  # "win" / "lose" / "run"

signal _chosen(choice: String)

const LABELS := {
	"attack": "Attack", "strike": "Strike", "magic": "Magic", "item": "Item", "run": "Run",
	"guard": "Guard", "counter": "Counter", "ward": "Ward", "back": "Back",
}
const HINTS := {
	"attack": "Normal hit. Halved by Guard.",
	"strike": "Double damage, breaks Guard. Reflected by Counter!",
	"magic": "Uses MAG, mostly ignores DEF. Weak vs Ward.",
	"item": "Use an item (takes your turn).",
	"run": "Try to escape. Faster = better chance.",
	"guard": "Halve damage from Attack.",
	"counter": "Reflect a Strike back. Useless vs others.",
	"ward": "Cut Magic damage to 40%.",
}
const SAY_TIME := 1.1

var player: PlayerStats
var mon: Dictionary
var mon_name := ""
var mon_hp := 0

var _player_sprite: Sprite2D
var _mon_sprite: Sprite2D
var _player_home := Vector2.ZERO
var _mon_home := Vector2.ZERO
var _p_bar: ProgressBar
var _m_bar: ProgressBar
var _p_text: Label
var _m_text: Label
var _log: Label
var _hint: Label
var _buttons: HBoxContainer
var _time := 0.0


func _init() -> void:
	layer = 4


func _process(delta: float) -> void:
	_time += delta
	if _mon_sprite:
		var n: int = mon.frames
		_mon_sprite.frame = n + int(_time * 6.0) % n # แถว 1 = หันซ้าย
	if _player_sprite:
		_player_sprite.frame = 21 if fmod(_time, 3.3) < 0.12 else 20 # ยืนหันขวา + กระพริบตา
		_player_sprite.position.y = _player_home.y + sin(_time * 2.5) * 2.0


# ================================================================ ลำดับการต่อสู้
func start(p: PlayerStats, monster_id: String) -> String:
	player = p
	mon_name = monster_id
	mon = GameData.MONSTERS[monster_id]
	mon_hp = mon.hp
	_build()
	_refresh_bars()
	await _say("A %s appears!" % mon_name)

	var player_turn := player.stat("spd") >= int(mon.spd) # เร็วกว่าได้บุกก่อน
	var result := ""
	while result == "":
		if player_turn:
			result = await _player_attacks()
		else:
			result = await _monster_attacks()
		player_turn = not player_turn

	match result:
		"win":
			await _victory()
		"lose":
			await _say("You were defeated...")
	return result


func _player_attacks() -> String:
	var choice := await _ask("Your turn to ATTACK!", ["attack", "strike", "magic", "item", "run"])
	match choice:
		"item":
			var used := await _use_item_menu()
			if used == "escape":
				return "run"
			if used == "":
				return await _player_attacks() # ยกเลิก -> เลือกใหม่
			return ""
		"run":
			var chance := clampf(0.5 + (player.stat("spd") - int(mon.spd)) * 0.05, 0.2, 0.9)
			if randf() < chance:
				await _say("You got away!")
				return "run"
			await _say("Couldn't escape!")
			return ""
	var defense := _pick_weighted(mon.defense)
	await _say("You: %s   vs   %s: %s" % [LABELS[choice], mon_name, LABELS[defense]])
	await _resolve(true, choice, defense)
	return _check_end()


func _monster_attacks() -> String:
	var offense := _pick_weighted(mon.offense)
	var choice := await _ask("%s is about to attack! How do you DEFEND?" % mon_name, ["guard", "counter", "ward"])
	await _say("%s: %s   vs   You: %s" % [mon_name, LABELS[offense], LABELS[choice]])
	await _resolve(false, offense, choice)
	return _check_end()


func _check_end() -> String:
	if player.hp <= 0:
		return "lose"
	if mon_hp <= 0:
		return "win"
	return ""


## คำนวณดาเมจจากท่าบุก vs ท่ารับ
func _resolve(player_attacking: bool, off: String, dfn: String) -> void:
	var a := _stats(player_attacking)
	var d := _stats(not player_attacking)
	var dmg := 0.0
	var reflect := false
	match off:
		"attack":
			dmg = maxf(1.0, a.atk * 2.0 - d.def)
			if dfn == "guard":
				dmg *= 0.5
		"strike":
			dmg = maxf(1.0, a.atk * 2.0 - d.def) * 2.0
			if dfn == "counter":
				reflect = true
		"magic":
			dmg = maxf(1.0, a.mag * 2.0 - d.def * 0.5)
			if dfn == "ward":
				dmg *= 0.4
	var amount := maxi(1, roundi(dmg * randf_range(0.9, 1.1)))

	await _lunge(player_attacking, off == "magic")
	if reflect:
		_damage(player_attacking, amount)
		await _say("COUNTERED! The Strike bounces back for %d!" % amount)
	else:
		_damage(not player_attacking, amount)
		var who := mon_name if player_attacking else "You"
		var extra := ""
		if (off == "attack" and dfn == "guard") or (off == "magic" and dfn == "ward"):
			extra = " (blocked)"
		elif off == "strike" and dfn != "counter":
			extra = " (critical!)"
		await _say("%s took %d damage%s" % [who, amount, extra])


func _stats(is_player: bool) -> Dictionary:
	if is_player:
		return {"atk": player.stat("atk"), "def": player.stat("def"), "mag": player.stat("mag")}
	return {"atk": mon.atk, "def": mon.def, "mag": mon.mag}


func _pick_weighted(weights: Dictionary) -> String:
	var total := 0
	for k in weights:
		total += weights[k]
	var r := randi_range(1, total)
	for k in weights:
		r -= weights[k]
		if r <= 0:
			return k
	return weights.keys()[0]


func _use_item_menu() -> String:
	var usable: Array = []
	for it in player.items:
		if GameData.ITEMS[it].type == "use" and not usable.has(it):
			usable.append(it)
	if usable.is_empty():
		await _say("You have no usable items!")
		return ""
	var options := usable.duplicate()
	options.append("back")
	var pick := await _ask("Use which item?", options)
	if pick == "back":
		return ""
	player.items.erase(pick)
	var data: Dictionary = GameData.ITEMS[pick]
	if data.get("escape", false):
		await _say("You used %s and vanished in the smoke!" % pick)
		return "escape"
	var healed := player.heal(data.get("heal", 0))
	_refresh_bars()
	await _say("Used %s. Recovered %d HP." % [pick, healed])
	return "used"


func _victory() -> void:
	var gold: int = roundi(mon.gold * player.gold_mult())
	player.gold += gold
	var ups := player.gain_exp(mon.exp)
	_refresh_bars()
	var text := "Victory! Got %d EXP and %d Gold." % [mon.exp, gold]
	if ups > 0:
		text += "\nLEVEL UP! Now Lv %d." % player.level
	await _say(text, 2.2)


# ================================================================ เอฟเฟกต์
func _lunge(player_attacking: bool, is_magic: bool) -> void:
	var s := _player_sprite if player_attacking else _mon_sprite
	var home := _player_home if player_attacking else _mon_home
	var dir := 1.0 if player_attacking else -1.0
	var t := create_tween()
	if is_magic:
		t.tween_property(s, "modulate", Color(0.6, 0.8, 2.0), 0.15)
		t.tween_property(s, "modulate", _base_modulate(s), 0.2)
	else:
		t.tween_property(s, "position:x", home.x + 140.0 * dir, 0.12).set_trans(Tween.TRANS_QUAD)
		t.tween_property(s, "position:x", home.x, 0.18)
	await t.finished


func _damage(to_player: bool, amount: int) -> void:
	if to_player:
		player.hp = maxi(0, player.hp - amount)
	else:
		mon_hp = maxi(0, mon_hp - amount)
	_refresh_bars()
	var s := _player_sprite if to_player else _mon_sprite
	var home := _player_home if to_player else _mon_home
	var t := create_tween()
	t.tween_property(s, "modulate", Color(2.0, 0.4, 0.4), 0.06)
	t.tween_property(s, "position:x", home.x + 10, 0.05)
	t.tween_property(s, "position:x", home.x - 10, 0.05)
	t.tween_property(s, "position:x", home.x, 0.05)
	t.tween_property(s, "modulate", _base_modulate(s), 0.15)
	# ตัวเลขดาเมจลอยขึ้น
	var n := Label.new()
	n.text = str(amount)
	n.add_theme_font_size_override("font_size", 40)
	n.add_theme_color_override("font_color", Color(1, 0.9, 0.4))
	n.add_theme_color_override("font_outline_color", Color.BLACK)
	n.add_theme_constant_override("outline_size", 10)
	n.position = home + Vector2(-20, -240)
	add_child(n)
	var nt := n.create_tween()
	nt.tween_property(n, "position:y", n.position.y - 50, 0.7)
	nt.parallel().tween_property(n, "modulate:a", 0.0, 0.7).set_delay(0.3)
	nt.tween_callback(n.queue_free)


func _base_modulate(s: Sprite2D) -> Color:
	return mon.tint if s == _mon_sprite else Color.WHITE


# ================================================================ UI
func _say(text: String, wait := SAY_TIME) -> void:
	_log.text = text
	_clear_buttons()
	await get_tree().create_timer(wait).timeout


func _ask(prompt: String, choices: Array) -> String:
	_log.text = prompt
	_clear_buttons()
	for c in choices:
		var b := Button.new()
		b.text = LABELS.get(c, c)
		b.tooltip_text = HINTS.get(c, GameData.ITEMS.get(c, {}).get("desc", ""))
		b.custom_minimum_size = Vector2(130, 48)
		b.add_theme_font_size_override("font_size", 20)
		b.pressed.connect(func(): _chosen.emit.call_deferred(c)) # deferred: ไม่ลบปุ่มระหว่างที่มันยังส่งสัญญาณอยู่
		b.mouse_entered.connect(func(): _hint.text = b.tooltip_text)
		b.focus_entered.connect(func(): _hint.text = b.tooltip_text)
		_buttons.add_child(b)
	(_buttons.get_child(0) as Button).grab_focus.call_deferred()
	var picked: String = await _chosen
	_hint.text = ""
	return picked


func _clear_buttons() -> void:
	for c in _buttons.get_children():
		_buttons.remove_child(c)
		c.queue_free()


func _refresh_bars() -> void:
	_p_bar.max_value = player.max_hp()
	_p_bar.value = player.hp
	_p_text.text = "%s  Lv %d   HP %d/%d" % [player.name, player.level, player.hp, player.max_hp()]
	_m_bar.max_value = mon.hp
	_m_bar.value = mon_hp
	_m_text.text = "%s   HP %d/%d" % [mon_name, mon_hp, mon.hp]


func _build() -> void:
	var screen := get_viewport().get_visible_rect().size

	# พื้นหลังไล่สี + พื้นดิน
	var sky := TextureRect.new()
	var grad := GradientTexture2D.new()
	grad.gradient = Gradient.new()
	grad.gradient.set_color(0, Color(0.1, 0.12, 0.22))
	grad.gradient.set_color(1, Color(0.28, 0.2, 0.26))
	grad.fill_from = Vector2(0, 0)
	grad.fill_to = Vector2(0, 1)
	sky.texture = grad
	sky.size = screen
	sky.stretch_mode = TextureRect.STRETCH_SCALE
	add_child(sky)
	var ground := ColorRect.new()
	ground.color = Color(0.2, 0.17, 0.15)
	ground.position = Vector2(0, screen.y * 0.62)
	ground.size = Vector2(screen.x, screen.y * 0.38)
	add_child(ground)

	var feet_y := screen.y * 0.66
	_player_home = Vector2(screen.x * 0.3, feet_y)
	_mon_home = Vector2(screen.x * 0.7, feet_y)
	for pos in [_player_home, _mon_home]:
		var shadow := Polygon2D.new()
		var pts := PackedVector2Array()
		for i in 20:
			var a := TAU * i / 20.0
			pts.append(pos + Vector2(cos(a) * 70, sin(a) * 14))
		shadow.polygon = pts
		shadow.color = Color(0, 0, 0, 0.35)
		add_child(shadow)

	_player_sprite = _make_sprite("res://witch_sheet.png", 4, 6, 2.2)
	_player_sprite.position = _player_home
	add_child(_player_sprite)
	_mon_sprite = _make_sprite(mon.sprite, mon.frames, 2, 2.2 * mon.scale)
	_mon_sprite.position = _mon_home
	_mon_sprite.modulate = mon.tint
	add_child(_mon_sprite)

	# แถบ HP
	_p_bar = _make_bar(Vector2(40, 30), Color(0.4, 0.8, 0.45))
	_p_text = _make_label(Vector2(40, 52), 20)
	_m_bar = _make_bar(Vector2(screen.x - 400, 30), Color(0.85, 0.3, 0.3))
	_m_text = _make_label(Vector2(screen.x - 400, 52), 20)

	# ข้อความ + ปุ่ม
	_log = _make_label(Vector2(0, 110), 26)
	_log.size = Vector2(screen.x, 40)
	_log.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint = _make_label(Vector2(0, screen.y - 120), 18)
	_hint.size = Vector2(screen.x, 30)
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint.add_theme_color_override("font_color", Color(0.85, 0.85, 0.7))
	_buttons = HBoxContainer.new()
	_buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	_buttons.add_theme_constant_override("separation", 10)
	_buttons.position = Vector2(0, screen.y - 80)
	_buttons.size = Vector2(screen.x, 50)
	add_child(_buttons)


func _make_sprite(path: String, h: int, v: int, s: float) -> Sprite2D:
	var sp := Sprite2D.new()
	sp.texture = load(path)
	sp.hframes = h
	sp.vframes = v
	sp.scale = Vector2(s, s)
	sp.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sp.offset = Vector2(0, -sp.texture.get_height() / float(v) / 2.0) # จุด position = เท้า
	return sp


func _make_bar(pos: Vector2, color: Color) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.position = pos
	bar.size = Vector2(360, 20)
	bar.show_percentage = false
	var fill := StyleBoxFlat.new()
	fill.bg_color = color
	fill.set_corner_radius_all(4)
	bar.add_theme_stylebox_override("fill", fill)
	add_child(bar)
	return bar


func _make_label(pos: Vector2, font_size: int) -> Label:
	var l := Label.new()
	l.position = pos
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.add_theme_constant_override("outline_size", 8)
	add_child(l)
	return l

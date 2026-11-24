class_name CCBattleUI
extends CanvasLayer
## หน้าจอต่อสู้แบบช่องเช็ค: เลือกท่า (+ Focus ล็อกช่อง) แล้วดูช่องเช็คเปิดทีละช่อง
## ใช้:  var final: Dictionary = await ui.start(config, portraits)
## portraits = [ฮีโร่, มอนสเตอร์] แต่ละอัน {"texture", "hframes", "vframes", "frame", "tint"}

signal finished(final_state: Dictionary)

const GOLD := Color(0.95, 0.8, 0.45)
const OK_COLOR := Color(0.5, 0.95, 0.55)
const BAD_COLOR := Color(1.0, 0.45, 0.45)
const MUTED := Color(0.75, 0.72, 0.8)
const SLOT_DELAY := 0.28
const EVENT_DELAY := 0.55

var state := {}
var portraits: Array = [{}, {}]
var _busy := false
var _focus_pick := 0
var _shown_hp := [0, 0]

var _cards: Array = []
var _banner: Label
var _slots: HBoxContainer
var _controls: VBoxContainer
var _log: RichTextLabel
var _error: Label


func _init() -> void:
	layer = 7


func start(config: Dictionary, p_portraits: Array = []) -> Dictionary:
	if p_portraits.size() == 2:
		portraits = p_portraits
	state = CCBattle.create_battle(config)
	# HP ที่แสดงเริ่มจากก่อนเหตุการณ์แรก (มอนสเตอร์อาจได้ตีก่อนตั้งแต่ตอนสร้าง) แล้วลดตามจังหวะ animation
	_shown_hp = [clampi(int(config.hero.get("hp", config.hero.stats.hp)), 1, int(config.hero.stats.hp)), int(config.monster.stats.hp)]
	_build()
	if not is_inside_tree():
		await tree_entered
	_busy = true
	_refresh()
	await _play(state.log)
	_busy = false
	_refresh()
	var final: Dictionary = await finished
	return final


# ================================================================ การกระทำ
func _do(action: Dictionary) -> void:
	if _busy:
		return
	var from: int = state.log.size()
	var r := CCBattle.apply_action(state, action)
	_error.text = r.error
	if r.error != "":
		return
	state = r.state
	_focus_pick = 0
	_busy = true
	_refresh()
	await _play(state.log.slice(from))
	_busy = false
	_refresh()


## เล่นเหตุการณ์ทีละอัน (ช่องเช็คเปิดทีละช่อง, HP ลดตามจังหวะ)
func _play(events: Array) -> void:
	for e in events:
		_append_log(e)
		match e.t:
			"check":
				await _show_check(e)
			"damage":
				_shown_hp[e.unit] = e.hp
				_update_cards()
				_flash(e.unit)
				_banner.text = "%s takes %d%s" % [_name(e.unit), e.amount, {"burn": " (over time)", "drone": " (drone)", "hp_cost": " (paid HP)"}.get(e.cause, "")]
				await _wait(EVENT_DELAY)
			"item":
				_shown_hp[e.unit] = mini(state.units[e.unit].max_hp, _shown_hp[e.unit] + e.heal)
				_update_cards()
				_banner.text = event_text(e, _names())
				await _wait(EVENT_DELAY)
			"intent":
				_clear(_slots)
				_banner.text = event_text(e, _names())
				await _wait(EVENT_DELAY)
			"heal":
				_shown_hp[e.unit] = e.hp
				_update_cards()
				_banner.text = event_text(e, _names())
				await _wait(EVENT_DELAY)
			"miss", "dodge", "stunned", "effect", "guard", "flee_failed", "round", "barrier":
				_banner.text = event_text(e, _names())
				await _wait(EVENT_DELAY * (0.6 if e.t == "round" else 1.0))


func _show_check(e: Dictionary) -> void:
	_clear(_slots)
	var what := move_name(e)
	_banner.text = "%s %s %s  (%d%% per slot%s)" % [_name(e.unit), "defends with" if e.get("defense", false) else "uses", what,
		roundi(e.chance * 100), ", Focus +%d" % e.focus if e.get("focus", 0) > 0 else ""]
	var labels := []
	for i in e.slots.size():
		var l := _label(40, MUTED, "◯")
		_slots.add_child(l)
		labels.append(l)
	for i in e.slots.size():
		await _wait(SLOT_DELAY)
		var r: int = e.slots[i]
		labels[i].text = "●" if r == 1 else "✕"
		labels[i].add_theme_color_override("font_color", OK_COLOR if r == 1 else BAD_COLOR)
	if e.perfect and e.skill != "flee":
		_slots.add_child(_label(24, GOLD, "  PERFECT!"))
	await _wait(SLOT_DELAY)


func _wait(t: float) -> void:
	await get_tree().create_timer(t).timeout


func _flash(unit: int) -> void:
	var card: Dictionary = _cards[unit]
	var tw := create_tween()
	tw.tween_property(card.pic, "modulate", Color(2, 0.5, 0.5), 0.08)
	tw.tween_property(card.pic, "modulate", portraits[unit].get("tint", Color.WHITE), 0.2)


# ================================================================ แสดงผล
func _refresh() -> void:
	_update_cards()
	_clear(_controls)
	if _busy:
		_controls.add_child(_label(18, MUTED, "..."))
		return
	if state.result != "":
		_build_end()
		return
	var hero: Dictionary = state.units[0]
	var mon: Dictionary = state.units[1]
	_focus_pick = mini(_focus_pick, hero.focus)
	_controls.add_child(_focus_row(hero))
	if CCBattle.phase(state) == "defend":
		_build_defense(hero, mon)
		return
	_banner.text = "Your turn - choose an action"

	# ---- ท่า
	for skill in CCBattle.skills_for(hero):
		var d := CCBattle.action_def(hero, skill)
		var cost: int = d.get("cost", 0)
		var n := CCBattle.slots_for(state, CCBattle.HERO, skill)
		var lo := CCBattle.damage_for(hero, mon, skill, 1, n)
		var hi := CCBattle.damage_for(hero, mon, skill, n, n)
		var perfect := ", ".join(PackedStringArray(d.perfect.map(func(x): return CCBalance.PERFECT_TEXT[x])))
		var dmg_text := "dmg %d-%d" % [lo, hi * (2 if d.perfect.has("double") else 1)]
		if d.kind == "drone":
			dmg_text = "drone %d/turn x%d" % [CCBattle.drone_damage(hero), CCBattle.drone_turns(hero, false)]
		var costs := PackedStringArray()
		if cost > 0:
			costs.append("%d Focus" % cost)
		if d.get("hp_cost", 0.0) > 0.0:
			costs.append("%d HP" % ceili(hero.max_hp * d.hp_cost))
		var extras := "  [costs %s]" % " + ".join(costs) if not costs.is_empty() else ""
		if d.get("drain", 0.0) > 0.0:
			extras += "  [heals %d%% of damage]" % roundi(d.drain * 100)
		var text := "%s%-13s %s  %d%%   %s%s   Perfect: %s" % ["★ " if hero.get("granted", []).has(skill) else "", d.name, "◯".repeat(n),
			roundi(CCBattle.action_chance(hero, skill, _focus_pick) * 100), dmg_text, extras, perfect]
		var b := _button(text, Vector2(0, 40), true)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.disabled = _focus_pick + cost > hero.focus
		b.tooltip_text = "%s\nChecks %s.%s" % [text, GameData.stat_label(d.check), "  (Weapon attack)" if skill == "attack" else ("  (Unique weapon skill)" if hero.get("granted", []).has(skill) else "  (Skill Gem)")]
		b.pressed.connect(_do.bind({"type": "skill", "skill": skill, "focus": _focus_pick}))
		_controls.add_child(b)

	# ---- Guard / ไอเทม / หนี
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	var g := _button("Guard  (half damage, +%d Focus)" % CCBalance.FOCUS_ON_GUARD, Vector2(0, 38))
	g.pressed.connect(_do.bind({"type": "guard"}))
	row.add_child(g)
	_add_item_buttons(row, "attack")
	row.add_child(_flee_button(hero))
	_controls.add_child(row)


## ปุ่มไอเทมที่ใช้ได้ในเทิร์นนี้ (turn = "attack" / "defense")
func _add_item_buttons(row: HBoxContainer, turn: String) -> void:
	var seen := {}
	for it in state.items:
		if CCBattle.item_usable(it, turn) and not seen.has(it):
			seen[it] = true
			var ib := _button("%s x%d" % [it, state.items.count(it)], Vector2(0, 38))
			ib.tooltip_text = GameData.ITEMS[it].desc
			ib.pressed.connect(_do.bind({"type": "item", "item": it}))
			row.add_child(ib)


func _flee_button(hero: Dictionary) -> Button:
	var fb := _button("Flee  %d%%" % roundi(CCBattle.chance(hero.stats.spd, _focus_pick) * 100), Vector2(0, 38))
	fb.tooltip_text = "Check SPD (1 slot). Fail on the defense turn = take the hit with no defense."
	fb.pressed.connect(_do.bind({"type": "flee", "focus": _focus_pick}))
	return fb


## Focus ที่จะใช้ (+% ทุกช่องของท่า/การป้องกันครั้งนี้)
func _focus_row(hero: Dictionary) -> HBoxContainer:
	var frow := HBoxContainer.new()
	frow.add_theme_constant_override("separation", 8)
	frow.add_child(_label(17, Color.WHITE, "Use Focus:"))
	var minus := _button("-", Vector2(36, 34))
	minus.disabled = _focus_pick <= 0
	minus.pressed.connect(func() -> void:
		_focus_pick -= 1
		_refresh())
	frow.add_child(minus)
	frow.add_child(_label(20, GOLD, "%d" % _focus_pick))
	var plus := _button("+", Vector2(36, 34))
	plus.disabled = _focus_pick >= hero.focus
	plus.pressed.connect(func() -> void:
		_focus_pick += 1
		_refresh())
	frow.add_child(plus)
	frow.add_child(_label(14, MUTED, "  (+%d%% to every slot of this move)" % roundi(CCBalance.FOCUS_CHANCE_BONUS)))
	return frow


## เทิร์นป้องกัน: มอนสเตอร์ประกาศท่าแล้ว ผู้เล่นเลือกวิธีรับ
func _build_defense(hero: Dictionary, mon: Dictionary) -> void:
	var skill: String = state.pending.skill
	var d := CCBattle.action_def(mon, skill)
	_banner.text = "%s is about to use %s! Choose your defense" % [mon.name, d.name]
	_controls.add_child(_label(15, MUTED, "%s: %d slots at %d%%, up to %d damage%s" % [d.name, d.slots, roundi(CCBattle.action_chance(mon, skill) * 100),
		CCBattle.damage_for(mon, hero, skill, d.slots), "  (magic)" if d.kind == "magic" else ""]))
	for defense in CCBalance.DEFENSES:
		var dd: Dictionary = CCBalance.DEFENSES[defense]
		var e := CCAi.exchange(state, CCBattle.MONSTER, skill, 0, defense, _focus_pick)
		var text := "%-8s %s  %d%%  (%s)   expected damage ~%d%s   %s" % [dd.name, "◯".repeat(dd.slots),
			roundi(CCBattle.defense_chance(hero, defense, skill, _focus_pick, mon) * 100), GameData.stat_label(CCBattle.defense_stat(defense, skill, mon)),
			roundi(e.taken), ", hit back ~%d" % roundi(e.counter) if e.counter > 0 else "", CCBalance.DEFENSE_TEXT[defense]]
		var b := _button(text, Vector2(0, 42), true)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		if not CCBattle.can_defend_with(hero, defense):
			b.disabled = true
			b.text = "%-8s (can't - Juggernaut)" % dd.name
		b.pressed.connect(_do.bind({"type": "defend", "defense": defense, "focus": _focus_pick}))
		_controls.add_child(b)
	# ไอเทมเสริมพลัง/ฮีล หรือหนี — สละการป้องกัน
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	_add_item_buttons(row, "defense")
	row.add_child(_flee_button(hero))
	_controls.add_child(row)
	_controls.add_child(_label(13, MUTED, "Using an item or a failed Flee means taking the hit with no defense."))


func _build_end() -> void:
	var titles := {"win": "Victory!", "lose": "Defeat...", "run": "You got away."}
	_banner.text = titles.get(state.result, "")
	_clear(_slots)
	if state.stolen_gold > 0:
		_controls.add_child(_label(17, GOLD, "Stole %d Gold during the fight!" % state.stolen_gold))
	var b := _button("Continue", Vector2(200, 46))
	b.pressed.connect(func() -> void: finished.emit(state))
	_controls.add_child(b)
	b.grab_focus.call_deferred()


func _update_cards() -> void:
	for i in 2:
		var u: Dictionary = state.units[i]
		var c: Dictionary = _cards[i]
		c.title.text = "%s%s" % [u.name, "  (%s)" % u.job if u.job != "" else ""]
		c.hp.max_value = u.max_hp
		c.hp.value = _shown_hp[i]
		var tags := PackedStringArray(["HP %d / %d" % [_shown_hp[i], u.max_hp]])
		c.info.text = tags[0]
		if _busy:
			continue # ระหว่าง animation ยังไม่โชว์สถานะใหม่ (กันสปอยล์ผล)
		if i == 0:
			tags.append("Focus %s%s" % ["●".repeat(u.focus), "○".repeat(maxi(0, CCBalance.FOCUS_MAX - u.focus))])
		if u.guarding:
			tags.append("GUARD")
		if u.stunned:
			tags.append("STUNNED")
		if u.burn > 0:
			tags.append("BURN/POISON %d" % u.burn)
		if u.get("drone", 0) > 0:
			tags.append("DRONE %d" % u.drone)
		if u.get("barrier", 0) > 0:
			tags.append("BARRIER %d" % u.barrier)
		c.info.text = "   ".join(tags)
		c.stats.text = "ATK %d  ARM %d  TEC %d  SPD %d  LCK %d (CRIT %d%%)" % [u.stats.atk, u.stats.def, u.stats.mag, u.stats.spd,
			u.stats.get("lck", 0), roundi(CCBattle.crit_chance(u) * 100)]


func _append_log(e: Dictionary) -> void:
	var t := event_text(e, _names())
	if t != "":
		_log.append_text(t + "\n")


func _names() -> Array:
	return [state.units[0].name, state.units[1].name]


func _name(i: int) -> String:
	return state.units[i].name


## ชื่อท่า/วิธีป้องกันใน event (Attack ใช้ชื่อตามอาวุธที่ engine บันทึกไว้)
static func move_name(e: Dictionary) -> String:
	if e.get("defense", false):
		return CCBalance.DEFENSES[e.skill].name
	return e.get("name", CCBalance.ACTIONS[e.skill].name)


static func event_text(e: Dictionary, names: Array) -> String:
	match e.t:
		"start":
			return "%s vs %s" % [e.hero, e.monster]
		"round":
			return "-- Round %d --" % e.round
		"check":
			var marks := ""
			for r in e.slots:
				marks += "●" if r == 1 else "✕"
			var what := move_name(e)
			return "%s: %s %s%s%s" % [names[e.unit], what, marks, " PERFECT" if e.perfect and e.skill != "flee" else "",
				" (Second Chance re-rolled slot %d)" % (e.rerolled + 1) if e.get("rerolled", -1) >= 0 else ""]
		"heal":
			return "%s recovers %d HP (%s)" % [names[e.unit], e.amount, {"regen": "Auto-Repair", "guard": "Adrenal Surge", "drain": "Blood Siphon"}.get(e.cause, e.cause)]
		"barrier":
			return "Barrier absorbs %d (%d left)" % [e.amount, e.left]
		"intent":
			return "%s prepares %s!" % [names[e.unit], move_name(e)]
		"miss":
			return "%s missed!" % names[e.unit]
		"dodge":
			return "%s dodged!" % names[e.unit]
		"damage":
			var why: String = {"burn": " - over time", "counter": " - counter!", "item": " - item", "drone": " - drone", "hp_cost": " - paid HP"}.get(e.cause, "")
			return "%s takes %d (%d HP left)%s" % [names[e.unit], e.amount, e.hp, why]
		"effect":
			match e.effect:
				"focus":
					return "%s blocked perfectly: +1 Focus" % names[e.unit]
				"crit":
					return "CRITICAL HIT by %s!" % names[e.unit]
				"stun":
					return "%s is stunned!" % names[e.unit]
				"burn":
					return "%s is burning!" % names[e.unit]
				"poison":
					return "%s is poisoned!" % names[e.unit]
				"drone":
					return "%s deploys a drone! (%d dmg x %d turns)" % [names[e.unit], e.damage, e.turns]
				"steal":
					return "Stole %d Gold!" % e.gold
		"stunned":
			return "%s is stunned and loses the turn" % names[e.unit]
		"guard":
			return "%s guards" % names[e.unit]
		"item":
			var extra := " (+%d HP)" % e.heal if e.heal > 0 else ""
			for k in e.get("buff", {}):
				extra += " (%s +%d)" % [GameData.stat_label(k), e.buff[k]]
			return "%s used %s%s" % [names[e.unit], e.item, extra]
		"flee_failed":
			return "%s couldn't escape!" % names[e.unit]
		"end":
			return {"win": "Victory!", "lose": "Defeated...", "run": "Escaped."}.get(e.result, "")
	return ""


# ================================================================ สร้าง UI
func _build() -> void:
	var dim := ColorRect.new()
	dim.color = Color(0.06, 0.05, 0.08, 0.97)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dim)
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 14)
	add_child(margin)
	var main := HBoxContainer.new()
	main.add_theme_constant_override("separation", 14)
	margin.add_child(main)

	var left := VBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.add_theme_constant_override("separation", 10)
	main.add_child(left)
	var cards := HBoxContainer.new()
	cards.add_theme_constant_override("separation", 14)
	left.add_child(cards)
	for i in 2:
		var c := _make_card(i)
		cards.add_child(c.root)
		_cards.append(c)

	var stage := PanelContainer.new()
	stage.add_theme_stylebox_override("panel", Dialogs.panel_style())
	stage.custom_minimum_size = Vector2(0, 110)
	left.add_child(stage)
	var sbox := VBoxContainer.new()
	sbox.alignment = BoxContainer.ALIGNMENT_CENTER
	stage.add_child(sbox)
	_banner = _label(20, GOLD)
	_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sbox.add_child(_banner)
	_slots = HBoxContainer.new()
	_slots.alignment = BoxContainer.ALIGNMENT_CENTER
	_slots.add_theme_constant_override("separation", 14)
	sbox.add_child(_slots)

	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", Dialogs.panel_style())
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left.add_child(panel)
	_controls = VBoxContainer.new()
	_controls.add_theme_constant_override("separation", 6)
	panel.add_child(_controls)
	_error = _label(15, BAD_COLOR)
	left.add_child(_error)

	var right := PanelContainer.new()
	right.add_theme_stylebox_override("panel", Dialogs.panel_style())
	right.custom_minimum_size = Vector2(300, 0)
	main.add_child(right)
	var rbox := VBoxContainer.new()
	right.add_child(rbox)
	rbox.add_child(_label(18, GOLD, "Battle log"))
	_log = RichTextLabel.new()
	_log.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_log.scroll_following = true
	_log.add_theme_font_size_override("normal_font_size", 14)
	rbox.add_child(_log)


func _make_card(i: int) -> Dictionary:
	var root := PanelContainer.new()
	root.add_theme_stylebox_override("panel", Dialogs.panel_style())
	root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	root.add_child(row)
	var pic := TextureRect.new()
	pic.custom_minimum_size = Vector2(84, 84)
	pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	pic.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var pt: Dictionary = portraits[i]
	if not pt.is_empty():
		var tex: Texture2D = pt.texture
		var w: float = tex.get_width() / float(pt.hframes)
		var h: float = tex.get_height() / float(pt.vframes)
		var at := AtlasTexture.new()
		at.atlas = tex
		at.region = Rect2((pt.frame % pt.hframes) * w, (pt.frame / pt.hframes) * h, w, h)
		pic.texture = at
		pic.modulate = pt.get("tint", Color.WHITE)
	row.add_child(pic)
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(box)
	var title := _label(19, Color.WHITE)
	box.add_child(title)
	var hp := ProgressBar.new()
	hp.custom_minimum_size = Vector2(0, 16)
	hp.show_percentage = false
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color(0.4, 0.8, 0.45) if i == 0 else Color(0.85, 0.3, 0.3)
	fill.set_corner_radius_all(4)
	hp.add_theme_stylebox_override("fill", fill)
	box.add_child(hp)
	var info := _label(15, Color.WHITE)
	info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART # สถานะยาว ๆ ตัดบรรทัดแทนดันการ์ดล้นจอ
	box.add_child(info)
	var stats := _label(13, MUTED)
	stats.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(stats)
	return {"root": root, "pic": pic, "title": title, "hp": hp, "info": info, "stats": stats}


## clip = ปุ่มเต็มแถวที่ข้อความยาว: ตัดข้อความแทนการดันเลย์เอาต์ล้นจอ (ดูเต็มใน tooltip)
func _button(text: String, min_size: Vector2, clip := false) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = min_size
	b.add_theme_font_size_override("font_size", 16)
	b.focus_mode = Control.FOCUS_NONE
	b.clip_text = clip
	b.tooltip_text = text
	return b


func _label(size: int, color: Color, text := "") -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l


func _clear(node: Node) -> void:
	for c in node.get_children():
		node.remove_child(c)
		c.queue_free()

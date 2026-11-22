class_name DDBattleUI
extends CanvasLayer
## หน้าจอต่อสู้ Dice Duel — ใช้ได้ทั้งในบอร์ดเกม (สู้กับมอนสเตอร์ AI) และฉาก standalone
##   mode "ai"      : ผู้เล่นคนเดียว vs AI
##   mode "hotseat" : 2 คนเครื่องเดียว มีหน้าจอ "ส่งเครื่องให้ผู้เล่นถัดไป" ซ่อนเต๋าของอีกฝ่าย
## UI เห็นข้อมูลผ่าน DDView.get_player_view() เท่านั้น
##
## ใช้:  var final: Dictionary = await ui.start(config, "ai", "aggressive", 1, portraits)

signal finished(final_state: Dictionary)

const GOLD := Color(0.95, 0.8, 0.45)
const OK_COLOR := Color(0.55, 0.95, 0.6)
const BAD_COLOR := Color(1.0, 0.5, 0.5)
const MUTED := Color(0.75, 0.72, 0.8)
const AI_DELAY := 0.7

var state := {}
var mode := "ai"
var ai_player := 1
var ai_personality := "aggressive"
## รูปตัวละคร [P1, P2]: {"texture", "hframes", "vframes", "frame", "tint"} (ไม่ใส่ก็ได้)
var portraits: Array = [{}, {}]
var viewer := 0

var _ai_rng := RandomNumberGenerator.new()
var _ai_pending := false
var _sel: Array = [] # die_id ที่เลือก ตามลำดับ (ลูกแรก = ลูกหลักของ Magic)
var _wild := {} # die_id -> ค่าที่เลือกให้ ✦
var _move := ""
var _sel_key := ""
var _swipe_mine := 0
var _swipe_theirs := 0
var _error := ""
var _replay_saved := false

var _main: Control
var _status: Label
var _bars: Array = []
var _actions: VBoxContainer
var _error_label: Label
var _last: Label
var _log: RichTextLabel
var _overlay: PanelContainer
var _overlay_box: VBoxContainer


func _init() -> void:
	layer = 7


func start(config: Dictionary, p_mode := "ai", personality := "aggressive", ai_p := 1, p_portraits: Array = []) -> Dictionary:
	state = DDBattle.create_battle(config)
	mode = p_mode
	ai_personality = personality
	ai_player = ai_p
	if p_portraits.size() == 2:
		portraits = p_portraits
	viewer = 1 - ai_player if mode == "ai" else -1
	_ai_rng.seed = int(config.seed) ^ 0x5bd1e995
	_build()
	_refresh()
	var final: Dictionary = await finished
	return final


# ================================================================ การกระทำ
func _apply(action: Dictionary) -> void:
	var r := DDBattle.apply_action(state, action)
	_error = r.error
	if r.error == "":
		state = r.state
	_refresh()


func _schedule_ai() -> void:
	if _ai_pending:
		return
	_ai_pending = true
	if not is_inside_tree():
		await tree_entered # AI อาจได้บุกก่อนตั้งแต่ตอนสร้าง UI
	await get_tree().create_timer(AI_DELAY).timeout
	_ai_pending = false
	if not is_inside_tree() or state.phase == "over" or DDBattle.actor_of(state) != ai_player:
		return
	# AI เห็นแค่ PlayerView ของตัวเอง เหมือนคนเล่น
	_apply(DDAi.choose_action(DDView.get_player_view(state, ai_player, false), ai_personality, _ai_rng))


func _toggle(id: String) -> void:
	if _sel.has(id):
		_sel.erase(id)
	else:
		_sel.append(id)
	_error = ""
	_refresh()


func _reroll(id: String) -> void:
	_sel.erase(id)
	_apply({"type": "reroll", "player": viewer, "die_id": id})


func _selected_infos(v: Dictionary) -> Array:
	var out := []
	for id in _sel:
		for d in v.me.dice:
			if d.die.id == id:
				out.append(DDAi.own_info(v, d, int(_wild.get(id, 6))))
	return out


func _place(v: Dictionary) -> void:
	var dice := []
	for info in _selected_infos(v):
		dice.append({"die_id": info.die_id, "wild": info.wild})
	_apply({"type": "place", "player": viewer, "move": _move, "dice": dice})


# ================================================================ แสดงผล
func _refresh() -> void:
	_clear(_actions)
	_error_label.text = _error
	var actor := DDBattle.actor_of(state)
	if mode == "hotseat" and actor >= 0 and actor != viewer:
		_show_handoff(actor)
		return
	_overlay.visible = false
	_main.visible = true

	var v := DDView.get_player_view(state, maxi(viewer, 0))
	var key := "%d-%s-%d" % [v.round, v.phase, viewer]
	if key != _sel_key:
		_sel_key = key
		_sel = []
		_wild = {}
		_move = DDMoves.offense_moves_for(v.me.job)[0] if v.phase == "attack" else "guard"
		_swipe_mine = 0
		_swipe_theirs = 0

	var attacker_name: String = v.me.name if v.attacker == v.player_id else v.opponent.name
	_status.text = "Round %d / %d  -  %s attacks" % [v.round, v.max_rounds, attacker_name] if v.phase != "over" else "Battle over"
	_set_bar(_bars[0], v.opponent, "Opponent", portraits[1 - v.player_id])
	_set_bar(_bars[1], v.me, "You", portraits[v.player_id])
	_set_log(v)
	_last.text = ""
	if v.reveal != null and v.reveal.outcome != null and v.phase != "over":
		_last.text = _reveal_text(v.reveal, _names(v), "Last round")

	if v.phase == "over":
		_build_game_over(v)
	elif not v.is_my_turn:
		_actions.add_child(_label(20, MUTED, "%s is thinking..." % v.opponent.name if mode == "ai" else "Waiting..."))
		if mode == "ai" and actor == ai_player:
			_schedule_ai()
	elif v.phase == "swipe":
		_build_swipe(v)
	else:
		_build_place(v)


func _build_place(v: Dictionary) -> void:
	var me: Dictionary = v.me
	var attacking: bool = v.phase == "attack"
	_actions.add_child(_label(21, GOLD, "Your ATTACK - choose a move and dice" if attacking else "Your DEFENSE - choose a move and dice"))
	if not attacking and v.opponent.placed_count >= 0:
		_actions.add_child(_label(16, MUTED, "%s placed %d %s. (Their move is hidden.)" % [v.opponent.name, v.opponent.placed_count, "die" if v.opponent.placed_count == 1 else "dice"]))
	if me.peek != null:
		_actions.add_child(_label(16, OK_COLOR, "Shadow Read: one of their dice shows  %s" % DDFaces.label(me.peek.face)))

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	for d in me.dice:
		var id: String = d.die.id
		var col := VBoxContainer.new()
		col.alignment = BoxContainer.ALIGNMENT_CENTER
		var b := Button.new()
		b.text = DDFaces.label(d.face)
		b.custom_minimum_size = Vector2(72, 72)
		b.add_theme_font_size_override("font_size", 34)
		b.focus_mode = Control.FOCUS_NONE
		_style_die(b, _sel.has(id), d.face.k)
		b.tooltip_text = _die_tooltip(d)
		b.pressed.connect(_toggle.bind(id))
		col.add_child(b)
		var tag := "#%d " % (_sel.find(id) + 1) if _sel.has(id) else ""
		var ctx := "offense" if attacking else "defense"
		var info := DDAi.own_info(v, d, int(_wild.get(id, 6)))
		if d.face.k == "num" and DDFaces.condition_value(info, ctx) != int(d.face.v):
			tag += "(=%d) " % DDFaces.condition_value(info, ctx) # เช่น Heavy ปัด 1 เป็น 3
		col.add_child(_label(12, GOLD if _sel.has(id) else MUTED, tag + _die_extras(d)))
		if d.face.k == "wild" and _sel.has(id):
			var opt := OptionButton.new()
			for i in range(1, 7):
				opt.add_item("= %d" % i)
			opt.selected = int(_wild.get(id, 6)) - 1
			opt.item_selected.connect(func(i: int) -> void:
				_wild[id] = i + 1
				_refresh())
			col.add_child(opt)
		var free: bool = me.job == "warrior" and not me.free_reroll_used and d.face.k == "num" and int(d.face.v) == 1
		var rb := Button.new()
		rb.text = "Reroll (free)" if free else "Reroll"
		rb.focus_mode = Control.FOCUS_NONE
		rb.disabled = not free and me.focus < DDBalance.REROLL_COST
		rb.pressed.connect(_reroll.bind(id))
		col.add_child(rb)
		row.add_child(col)
	_actions.add_child(row)

	var frow := HBoxContainer.new()
	frow.add_theme_constant_override("separation", 12)
	frow.add_child(_label(17, Color.WHITE, "Focus  %s%s   (reroll costs %d)" % ["●".repeat(me.focus), "○".repeat(DDBalance.FOCUS_MAX - me.focus), DDBalance.REROLL_COST]))
	if me.job == "ninja" and not me.shadow_read_used:
		var sr := Button.new()
		sr.text = "Shadow Read"
		sr.focus_mode = Control.FOCUS_NONE
		sr.pressed.connect(func() -> void: _apply({"type": "shadow_read", "player": viewer}))
		frow.add_child(sr)
	_actions.add_child(frow)

	var mrow := HBoxContainer.new()
	mrow.add_theme_constant_override("separation", 8)
	var moves: Array = DDMoves.offense_moves_for(me.job) if attacking else DDMoves.DEFENSE
	for m in moves:
		var mb := Button.new()
		mb.text = DDMoves.NAMES[m]
		mb.custom_minimum_size = Vector2(110, 40)
		mb.add_theme_font_size_override("font_size", 18)
		mb.focus_mode = Control.FOCUS_NONE
		if m == _move:
			mb.add_theme_color_override("font_color", GOLD)
			mb.add_theme_stylebox_override("normal", _box(Color(0.3, 0.24, 0.12), GOLD))
		mb.pressed.connect(func() -> void:
			_move = m
			_refresh())
		mrow.add_child(mb)
	_actions.add_child(mrow)
	_actions.add_child(_label(15, MUTED, DDMoves.hint(_move)))

	var infos := _selected_infos(v)
	var preview := ""
	var ok := false
	if attacking:
		var e := DDMoves.evaluate_offense(_move, infos, me.job, me.stats)
		ok = e.valid
		preview = "OK - power %.1f" % e.power if e.valid else "Won't work: %s" % e.reason
	else:
		var e := DDMoves.evaluate_defense(_move, infos, me.job, me.stats)
		ok = e.valid
		preview = "OK" if e.valid else "Won't work: %s" % e.reason
		if e.valid and e.reduction > 0:
			preview += " - blocks %.1f" % e.reduction
		if e.valid and e.heal > 0:
			preview += " - heals %d" % e.heal
	_actions.add_child(_label(17, OK_COLOR if ok else BAD_COLOR, preview))

	var pb := Button.new()
	pb.text = "Place %d %s  (%s)" % [infos.size(), "die" if infos.size() == 1 else "dice", DDMoves.NAMES[_move]]
	pb.custom_minimum_size = Vector2(0, 46)
	pb.add_theme_font_size_override("font_size", 20)
	pb.focus_mode = Control.FOCUS_NONE
	pb.disabled = attacking and infos.is_empty()
	pb.pressed.connect(_place.bind(v))
	_actions.add_child(pb)
	_actions.add_child(_label(13, MUTED, "Unplaced dice give +1 Focus each.  Magic: the first die you pick is the main die."))


func _build_swipe(v: Dictionary) -> void:
	var r: Dictionary = v.reveal
	var am_attacker: bool = r.attacker == v.player_id
	var mine: Array = r.attack_dice if am_attacker else r.defense_dice
	var theirs: Array = r.defense_dice if am_attacker else r.attack_dice
	_actions.add_child(_label(21, GOLD, "SWIPE?  (once per battle, costs %d Focus)" % DDBalance.SWIPE_FOCUS_COST))
	if DDBalance.SWIPE_RANDOM_TARGET:
		_actions.add_child(_label(15, MUTED, "You pick your die; their die is chosen at random."))
	_actions.add_child(_label(15, Color.WHITE, _reveal_text(r, _names(v), "Revealed")))
	_actions.add_child(_pick_row("Your die:", mine, _swipe_mine, func(i: int) -> void:
		_swipe_mine = i
		_refresh()))
	_actions.add_child(_pick_row("Their die:", theirs, _swipe_theirs, func(i: int) -> void:
		_swipe_theirs = i
		_refresh()))
	var m2 := mine.duplicate()
	var t2 := theirs.duplicate()
	m2[_swipe_mine] = theirs[_swipe_theirs]
	t2[_swipe_theirs] = mine[_swipe_mine]
	_actions.add_child(_label(16, MUTED, "Keep:  " + _outcome_text(DDAi.swipe_outcome(v, mine, theirs))))
	_actions.add_child(_label(16, OK_COLOR, "Swap:  " + _outcome_text(DDAi.swipe_outcome(v, m2, t2))))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	var sb := Button.new()
	sb.text = "Swipe!"
	sb.custom_minimum_size = Vector2(140, 44)
	sb.pressed.connect(func() -> void: _apply({"type": "swipe", "player": viewer, "mine": _swipe_mine, "theirs": _swipe_theirs}))
	row.add_child(sb)
	var kb := Button.new()
	kb.text = "Keep it for later"
	kb.custom_minimum_size = Vector2(160, 44)
	kb.pressed.connect(func() -> void: _apply({"type": "skip_swipe", "player": viewer}))
	row.add_child(kb)
	_actions.add_child(row)


func _build_game_over(v: Dictionary) -> void:
	var names := _names(v)
	var title := "Draw!"
	if v.winner != DDBattle.DRAW:
		if mode == "ai":
			title = "Victory!" if v.winner == v.player_id else "Defeat..."
		else:
			title = "%s wins!" % names[v.winner]
	_actions.add_child(_label(30, GOLD, title))
	if v.reveal != null and v.reveal.outcome != null:
		_actions.add_child(_label(15, Color.WHITE, _reveal_text(v.reveal, names, "Final round")))
	if not _replay_saved:
		_replay_saved = DDReplay.save(DDReplay.to_replay(state))
	if _replay_saved:
		_actions.add_child(_label(13, MUTED, "Replay saved (%s)" % ProjectSettings.globalize_path(DDReplay.SAVE_PATH)))
	var b := Button.new()
	b.text = "Continue"
	b.custom_minimum_size = Vector2(180, 46)
	b.add_theme_font_size_override("font_size", 20)
	b.pressed.connect(func() -> void: finished.emit(state))
	_actions.add_child(b)
	b.grab_focus.call_deferred()


func _show_handoff(actor: int) -> void:
	_main.visible = false # ซ่อนทุกอย่าง กันเห็นเต๋าของอีกฝ่าย
	_overlay.visible = true
	_clear(_overlay_box)
	var name: String = state.fighters[actor].character.name
	_overlay_box.add_child(_label(28, GOLD, "Pass the device to %s" % name))
	_overlay_box.add_child(_label(17, MUTED, "Other player: look away! %s's dice are secret." % name))
	if state.reveal != null and state.reveal.outcome != null:
		var names := [state.fighters[0].character.name, state.fighters[1].character.name]
		_overlay_box.add_child(_label(16, Color.WHITE, _reveal_text(state.reveal, names, "Last round")))
	var b := Button.new()
	b.text = "I'm %s - show my dice" % name
	b.custom_minimum_size = Vector2(0, 48)
	b.add_theme_font_size_override("font_size", 20)
	b.pressed.connect(func() -> void:
		viewer = actor
		_refresh())
	_overlay_box.add_child(b)


# ================================================================ ข้อความ
func _names(v: Dictionary) -> Array:
	return [v.me.name, v.opponent.name] if v.player_id == 0 else [v.opponent.name, v.me.name]


func _reveal_text(r: Dictionary, names: Array, title: String) -> String:
	var d: int = 1 - r.attacker
	var s := "%s (round %d):\n  %s attacks with %s  %s\n  %s defends with %s  %s" % [
		title, r.round, names[r.attacker], DDMoves.NAMES[r.attack_move], DDFormat.dice_text(r.attack_dice),
		names[d], DDMoves.NAMES[r.defense_move], DDFormat.dice_text(r.defense_dice)]
	if not r.swipes.is_empty():
		s += "\n  (Swipe was used)"
	if r.outcome != null:
		s += "\n  -> " + _outcome_text(r.outcome, names[d], names[r.attacker])
	return s


func _outcome_text(o: Dictionary, def_name := "Defender", att_name := "Attacker") -> String:
	var s := "%s. %s takes %d" % [o.note, def_name, o.damage_to_defender]
	if o.damage_to_attacker > 0:
		s += ", %s takes %d (reflected)" % [att_name, o.damage_to_attacker]
	if o.heal_defender > 0:
		s += ", %s heals %d" % [def_name, o.heal_defender]
	return s


func _set_log(v: Dictionary) -> void:
	var names := _names(v)
	var my_builds := []
	for d in v.me.dice:
		my_builds.append(d.die)
	var builds := [my_builds, v.opponent.dice] if v.player_id == 0 else [v.opponent.dice, my_builds]
	var lines := PackedStringArray()
	for e in v.log:
		lines.append(DDFormat.event_text(e, names, builds))
	_log.text = "\n".join(lines)
	_log.scroll_to_line(_log.get_line_count())


func _die_extras(d: Dictionary) -> String:
	var parts := PackedStringArray()
	if d.die.body != "standard":
		parts.append(DDBodies.get_body(d.die.body).name)
	for r in d.die.die_runes:
		parts.append(DDRunes.get_rune(r).name)
	var fr: String = d.die.face_runes[d.face_index]
	if fr != "":
		parts.append(DDRunes.get_rune(fr).name)
	return " ".join(parts) if not parts.is_empty() else " "


func _die_tooltip(d: Dictionary) -> String:
	var faces := PackedStringArray()
	for f in d.die.faces:
		faces.append(DDFaces.label(f))
	var s := "Faces: %s\nBody: %s - %s" % [" ".join(faces), DDBodies.get_body(d.die.body).name, DDBodies.get_body(d.die.body).desc]
	for r in d.die.die_runes:
		s += "\nRune %s - %s" % [DDRunes.get_rune(r).name, DDRunes.get_rune(r).desc]
	return s


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
	_main = main

	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	main.add_child(scroll)
	var left := VBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.add_theme_constant_override("separation", 8)
	scroll.add_child(left)
	_status = _label(20, GOLD)
	left.add_child(_status)
	for i in 2:
		var bar := _make_bar()
		left.add_child(bar.root)
		_bars.append(bar)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", Dialogs.panel_style())
	left.add_child(panel)
	_actions = VBoxContainer.new()
	_actions.add_theme_constant_override("separation", 8)
	panel.add_child(_actions)
	_error_label = _label(16, BAD_COLOR)
	left.add_child(_error_label)
	_last = _label(15, MUTED)
	_last.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	left.add_child(_last)

	var right := PanelContainer.new()
	right.add_theme_stylebox_override("panel", Dialogs.panel_style())
	right.custom_minimum_size = Vector2(390, 0)
	main.add_child(right)
	var rbox := VBoxContainer.new()
	right.add_child(rbox)
	rbox.add_child(_label(18, GOLD, "Event log"))
	_log = RichTextLabel.new()
	_log.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_log.scroll_following = true
	_log.selection_enabled = true
	_log.add_theme_font_size_override("normal_font_size", 14)
	rbox.add_child(_log)

	_overlay = PanelContainer.new()
	_overlay.add_theme_stylebox_override("panel", Dialogs.panel_style())
	_overlay.anchor_left = 0.5
	_overlay.anchor_right = 0.5
	_overlay.anchor_top = 0.5
	_overlay.anchor_bottom = 0.5
	_overlay.custom_minimum_size = Vector2(600, 0)
	_overlay.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_overlay.grow_vertical = Control.GROW_DIRECTION_BOTH
	_overlay.visible = false
	add_child(_overlay)
	_overlay_box = VBoxContainer.new()
	_overlay_box.add_theme_constant_override("separation", 14)
	_overlay.add_child(_overlay_box)


func _make_bar() -> Dictionary:
	var root := HBoxContainer.new()
	root.add_theme_constant_override("separation", 10)
	var pic := TextureRect.new()
	pic.custom_minimum_size = Vector2(56, 56)
	pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	pic.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	root.add_child(pic)
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 2)
	root.add_child(box)
	var title := _label(17, Color.WHITE)
	box.add_child(title)
	var hp := ProgressBar.new()
	hp.custom_minimum_size = Vector2(0, 16)
	hp.show_percentage = false
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color(0.85, 0.25, 0.3)
	fill.set_corner_radius_all(4)
	hp.add_theme_stylebox_override("fill", fill)
	box.add_child(hp)
	var info := _label(14, MUTED)
	box.add_child(info)
	return {"root": root, "pic": pic, "title": title, "hp": hp, "info": info}


func _set_bar(bar: Dictionary, f: Dictionary, who: String, portrait: Dictionary) -> void:
	bar.title.text = "%s  (%s - %s, %s)   HP %d / %d" % [f.name, who, DDJobs.NAMES.get(f.job, f.job), DDJobs.SKILLS.get(f.job, ""), f.hp, f.max_hp]
	bar.hp.max_value = f.max_hp
	bar.hp.value = f.hp
	var info := "Focus %d   AT %d  DF %d  MG %d  SP %d" % [f.focus, f.stats.at, f.stats.df, f.stats.mg, f.stats.sp]
	if f.job == "thief":
		info += "   Swipe %s" % ("used" if f.swipe_used else "ready")
	bar.info.text = info
	bar.pic.visible = not portrait.is_empty()
	if not portrait.is_empty() and bar.pic.texture == null:
		var tex: Texture2D = portrait.texture
		var w: float = tex.get_width() / float(portrait.hframes)
		var h: float = tex.get_height() / float(portrait.vframes)
		var at := AtlasTexture.new()
		at.atlas = tex
		at.region = Rect2((portrait.frame % portrait.hframes) * w, (portrait.frame / portrait.hframes) * h, w, h)
		bar.pic.texture = at
		bar.pic.modulate = portrait.get("tint", Color.WHITE)
	bar.pic.tooltip_text = DDJobs.SKILL_DESC.get(f.job, "")
	bar.title.tooltip_text = DDJobs.SKILL_DESC.get(f.job, "")
	bar.title.mouse_filter = Control.MOUSE_FILTER_PASS


func _pick_row(title: String, dice: Array, selected: int, on_pick: Callable) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	row.add_child(_label(16, Color.WHITE, title))
	for i in dice.size():
		var b := Button.new()
		b.text = DDFaces.info_label(dice[i])
		b.custom_minimum_size = Vector2(56, 48)
		b.add_theme_font_size_override("font_size", 22)
		_style_die(b, i == selected, dice[i].face.k)
		b.pressed.connect(on_pick.bind(i))
		row.add_child(b)
	return row


func _style_die(b: Button, selected: bool, kind: String) -> void:
	var bg := Color(0.96, 0.93, 0.86)
	if kind == "skull":
		bg = Color(0.35, 0.35, 0.38)
	elif kind == "wild":
		bg = Color(0.93, 0.86, 1.0)
	var border := GOLD if selected else Color(0, 0, 0, 0.4)
	for st in ["normal", "hover", "pressed", "focus"]:
		var box := _box(bg.lightened(0.05) if st == "hover" else bg, border, 5 if selected else 2)
		b.add_theme_stylebox_override(st, box)
	var fc := Color.WHITE if kind == "skull" else Color(0.12, 0.1, 0.1)
	for c in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		b.add_theme_color_override(c, fc)


func _box(bg: Color, border: Color, width := 2) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(width)
	sb.set_corner_radius_all(10)
	sb.set_content_margin_all(6)
	return sb


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

class_name PassiveWindow
extends CanvasLayer
## หน้าต่าง Passive Tree (ปุ่ม Passive บนกระดาน)
## ซ้าย = ต้นทั้งต้นในจอเดียว, ขวา = แต้มเหลือ / ค่าพลังก่อน -> หลัง / คำอธิบายโหนด / ปุ่ม
## คลิกโหนดที่เรืองแสง = เลือกไว้ (ยังไม่บันทึก) → Confirm ถึงบันทึกจริง, Cancel / Esc = ทิ้งที่เลือก
## โหนดที่ยืนยันแล้วคืนไม่ได้ในหน้านี้ ต้องรีเซ็ตทั้งต้นที่ปราสาท
## ใช้:  await passive_window.open(player)

signal closed

const COLOR_GOLD := Color(0.95, 0.8, 0.45)
const COLOR_UP := Color(0.5, 1.0, 0.55)
const COLOR_DOWN := Color(1.0, 0.5, 0.5)
const COLOR_LOCKED := Color(0.22, 0.22, 0.27)
const NODE_SIZE := {"start": 34, "hub": 30, "small": 20, "notable": 28, "keystone": 36, "bridge": 26}
const HINT := "Click a glowing node to pick it, then Confirm to save.\n\nWhite ring = yours   Gold ring = picked\nGlow = can pick   Square = Keystone\nLetters = where each job starts.\n\nReset the whole tree at the castle."

var player: PlayerStats
var _pending: Array = []
var _hover := ""
var _canvas: Control
var _buttons := {} # node id -> Button
var _job_label: Label
var _points_label: Label
var _stat_labels := {}
var _info: Label
var _confirm: Button
var _undo: Button
var _close: Button


func _init() -> void:
	layer = 6
	visible = false
	_build()


func is_open() -> bool:
	return visible


func open(p: PlayerStats) -> void:
	player = p
	_pending.clear()
	_hover = ""
	visible = true
	_refresh()
	_layout.call_deferred()
	await closed
	_pending.clear()
	visible = false


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		closed.emit()


# ================================================================ สถานะ
## โหนดที่มี (ยืนยันแล้ว + ที่เลือกไว้)
func _have() -> Array:
	return player.allocated() + _pending


func _points_left() -> int:
	return player.unspent_points() - _pending.size()


## "owned" / "pending" / "available" / "locked" / "other_start"
func _state_of(id: String) -> String:
	var n: Dictionary = PassiveTree.NODES[id]
	if n.type == "start":
		return "owned" if n.job == player.job else "other_start"
	if player.allocated().has(id):
		return "owned"
	if _pending.has(id):
		return "pending"
	if _points_left() > 0 and PassiveTree.can_allocate(_have(), id, player.job):
		return "available"
	return "locked"


# ================================================================ การกระทำ
func _click(id: String) -> void:
	var st := _state_of(id)
	match st:
		"pending":
			if PassiveTree.can_refund(_have(), id, player.job):
				_pending.erase(id)
			else:
				_set_info(id, "Other picks depend on this node. Remove those first.")
				return
		"available":
			_pending.append(id)
		"owned":
			_set_info(id, "Already yours. Reset the whole tree at the castle to change it.")
			return
		"other_start":
			_set_info(id, "This is where the %s tree starts. Change job at the castle to start here." % PassiveTree.NODES[id].job)
			return
		_:
			if _points_left() <= 0:
				_set_info(id, "No points left. You get 1 point every level.")
			else:
				_set_info(id, "Not connected yet. Pick a glowing node next to your tree first.")
			return
	_refresh()
	_set_info(id)


func _suggest() -> void:
	var added := 0
	for id in GameData.JOBS[player.job].get("suggested", []):
		if _points_left() <= 0:
			break
		if not _have().has(id) and PassiveTree.can_allocate(_have(), id, player.job):
			_pending.append(id)
			added += 1
	_refresh()
	if added > 0:
		_info.text = "Picked %d suggested node%s. Press Confirm to save." % [added, "" if added == 1 else "s"]
	elif _points_left() <= 0:
		_info.text = "No points left. You get 1 point every level."
	else:
		_info.text = "The suggested path is done. Spend the rest anywhere you like!"


func _undo_all() -> void:
	_pending.clear()
	_refresh()
	_info.text = HINT


func _confirm_picks() -> void:
	if _pending.is_empty():
		return
	var n := _pending.size()
	if player.set_tree(_have()):
		_pending.clear()
		_refresh()
		_info.text = "Saved %d node%s!" % [n, "" if n == 1 else "s"]
	else:
		_info.text = "Couldn't save. (The picks must connect to your tree.)"


# ================================================================ แสดงผล
func _refresh() -> void:
	_job_label.text = "%s  -  Lv %d" % [player.job, player.level]
	var left := _points_left()
	_points_label.text = "Points left: %d" % left
	_points_label.add_theme_color_override("font_color", COLOR_GOLD if left > 0 else Color(0.75, 0.75, 0.75))
	for id in _buttons:
		_style_button(id)
	_show_stats()
	_confirm.disabled = _pending.is_empty()
	_confirm.text = "Confirm (%d)" % _pending.size() if not _pending.is_empty() else "Confirm"
	_undo.disabled = _pending.is_empty()
	_close.text = "Cancel" if not _pending.is_empty() else "Close"
	_canvas.queue_redraw()


func _show_stats() -> void:
	var nodes := _have()
	if _hover != "" and _state_of(_hover) == "available":
		nodes = nodes + [_hover]
	for k in GameData.STAT_KEYS:
		var cur := player.stat_with(k, player.allocated())
		var nv := player.stat_with(k, nodes)
		var l: Label = _stat_labels[k]
		if nv == cur:
			l.text = str(cur)
			l.add_theme_color_override("font_color", Color.WHITE)
		else:
			l.text = "%d  →  %d" % [cur, nv]
			l.add_theme_color_override("font_color", COLOR_UP if nv > cur else COLOR_DOWN)


func _set_info(id: String, extra := "") -> void:
	var status: String = {
		"owned": "Yours.", "pending": "Picked (click again to remove). Not saved yet.",
		"available": "Click to pick.", "locked": "Not reachable yet.", "other_start": "Another job's start.",
	}[_state_of(id)]
	var body := PassiveTree.effect_text(id) + "\n" if PassiveTree.NODES[id].has("name") else "" # โหนดเล็ก: ชื่อ = ค่าพลังอยู่แล้ว
	_info.text = "%s  [%s]\n%s%s" % [PassiveTree.title(id), PassiveTree.type_name(id), body, extra if extra != "" else status]


func _on_hover(id: String) -> void:
	_hover = id
	_set_info(id)
	_show_stats()


func _on_unhover(id: String) -> void:
	if _hover == id:
		_hover = ""
		_show_stats()


func _style_button(id: String) -> void:
	var b: Button = _buttons[id]
	var n: Dictionary = PassiveTree.NODES[id]
	var arm: Color = PassiveTree.ARM_COLORS[n.arm]
	var sb := StyleBoxFlat.new()
	sb.set_corner_radius_all(64)
	match _state_of(id):
		"owned":
			sb.bg_color = arm
			sb.border_color = Color.WHITE
			sb.set_border_width_all(3)
		"pending":
			sb.bg_color = arm.lerp(Color.WHITE, 0.25)
			sb.border_color = COLOR_GOLD
			sb.set_border_width_all(4)
		"available":
			sb.bg_color = arm.darkened(0.45)
			sb.border_color = COLOR_GOLD
			sb.set_border_width_all(3)
			sb.shadow_color = Color(COLOR_GOLD, 0.55)
			sb.shadow_size = 6
		"other_start":
			sb.bg_color = Color(0.4, 0.4, 0.45)
			sb.border_color = arm.darkened(0.2)
			sb.set_border_width_all(2)
		_:
			sb.bg_color = COLOR_LOCKED.lerp(arm, 0.18)
			sb.border_color = Color(0.4, 0.4, 0.45)
			sb.set_border_width_all(1)
	if n.type == "keystone":
		sb.set_corner_radius_all(6) # Keystone เป็นสี่เหลี่ยม ให้เห็นว่าพิเศษ
	var hover := sb.duplicate() as StyleBoxFlat
	hover.border_color = Color.WHITE
	hover.set_border_width_all(4)
	for s in ["normal", "pressed", "focus", "disabled"]:
		b.add_theme_stylebox_override(s, sb)
	b.add_theme_stylebox_override("hover", hover)


# ================================================================ วาดต้น
func _layout() -> void:
	var sz := _canvas.size
	var scale := minf(sz.x, sz.y) * 0.5 / 1.12
	var center := sz * 0.5
	for id in _buttons:
		var b: Button = _buttons[id]
		b.position = center + PassiveTree.unit_pos(id) * scale - b.size * 0.5
	_canvas.queue_redraw()


func _draw_links() -> void:
	if player == null:
		return
	var have := PassiveTree.owned(_have(), player.job)
	for id in _buttons:
		for nb in PassiveTree.neighbors(id):
			if str(nb) < str(id):
				continue # วาดเส้นละครั้ง
			var a: Button = _buttons[id]
			var c: Button = _buttons[nb]
			var pa := a.position + a.size * 0.5
			var pc := c.position + c.size * 0.5
			var both := have.has(id) and have.has(nb)
			var one := have.has(id) or have.has(nb)
			var col := Color(0.32, 0.32, 0.38, 0.6)
			var w := 2.0
			if both:
				var arm_id: String = id if PassiveTree.NODES[id].arm != "hub" else nb
				col = PassiveTree.ARM_COLORS[PassiveTree.NODES[arm_id].arm]
				w = 5.0
			elif one:
				col = Color(0.75, 0.7, 0.55, 0.8)
				w = 2.5
			_canvas.draw_line(pa, pc, col, w, true)


# ================================================================ สร้าง UI
func _build() -> void:
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.6)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dim)

	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", Dialogs.panel_style())
	panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	panel.offset_left = 16
	panel.offset_top = 16
	panel.offset_right = -16
	panel.offset_bottom = -16
	add_child(panel)

	var cols := HBoxContainer.new()
	cols.add_theme_constant_override("separation", 16)
	panel.add_child(cols)

	# ---- ซ้าย: ต้น
	_canvas = Control.new()
	_canvas.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_canvas.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_canvas.clip_contents = true
	_canvas.draw.connect(_draw_links)
	_canvas.resized.connect(_layout)
	cols.add_child(_canvas)
	for id in PassiveTree.NODES:
		var n: Dictionary = PassiveTree.NODES[id]
		var b := Button.new()
		var s: int = NODE_SIZE[n.type]
		b.custom_minimum_size = Vector2(s, s)
		b.size = Vector2(s, s)
		b.focus_mode = Control.FOCUS_NONE
		if n.type == "start":
			b.text = str(n.job).substr(0, 1)
			b.add_theme_font_size_override("font_size", 16)
		b.tooltip_text = "%s\n%s" % [PassiveTree.title(id), PassiveTree.effect_text(id)]
		b.pressed.connect(_click.bind(id))
		b.mouse_entered.connect(_on_hover.bind(id))
		b.mouse_exited.connect(_on_unhover.bind(id))
		_canvas.add_child(b)
		_buttons[id] = b

	# ---- ขวา: ข้อมูล + ปุ่ม
	var side := VBoxContainer.new()
	side.custom_minimum_size = Vector2(300, 0)
	side.add_theme_constant_override("separation", 8)
	cols.add_child(side)
	var title := Label.new()
	title.text = "Passive Tree"
	title.add_theme_font_size_override("font_size", 26)
	title.add_theme_color_override("font_color", COLOR_GOLD)
	side.add_child(title)
	_job_label = _label(19)
	side.add_child(_job_label)
	_points_label = _label(22)
	side.add_child(_points_label)

	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 24)
	for k in GameData.STAT_KEYS:
		var key := _label(18)
		key.text = "Max HP" if k == "hp" else GameData.stat_label(k)
		grid.add_child(key)
		var val := _label(18)
		grid.add_child(val)
		_stat_labels[k] = val
	side.add_child(grid)

	_info = _label(16)
	_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_info.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_info.add_theme_color_override("font_color", Color(0.88, 0.86, 0.78))
	_info.text = HINT
	side.add_child(_info)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	side.add_child(row)
	var suggest := _button("Suggested")
	suggest.tooltip_text = "Pick the recommended nodes for your job."
	suggest.pressed.connect(_suggest)
	row.add_child(suggest)
	_undo = _button("Undo")
	_undo.tooltip_text = "Drop all picks that are not saved yet."
	_undo.pressed.connect(_undo_all)
	row.add_child(_undo)
	var row2 := HBoxContainer.new()
	row2.add_theme_constant_override("separation", 8)
	side.add_child(row2)
	_confirm = _button("Confirm")
	_confirm.pressed.connect(_confirm_picks)
	row2.add_child(_confirm)
	_close = _button("Close")
	_close.pressed.connect(closed.emit, CONNECT_DEFERRED)
	row2.add_child(_close)


func _label(font_size: int) -> Label:
	var l := Label.new()
	l.add_theme_font_size_override("font_size", font_size)
	return l


func _button(text: String) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, 42)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.add_theme_font_size_override("font_size", 18)
	b.focus_mode = Control.FOCUS_NONE
	return b

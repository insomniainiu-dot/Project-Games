class_name EquipWindow
extends CanvasLayer
## หน้าต่างสวมใส่อาวุธ / ชุดเกราะ / เครื่องประดับ
## ซ้าย = ของที่สวมอยู่ (คลิกเพื่อถอด) + ค่าพลัง, ขวา = อุปกรณ์สำรอง (คลิกเพื่อสวม)
## ชี้เมาส์หรือเลื่อนลูกศรไปที่อุปกรณ์ จะเห็นค่าพลังก่อน -> หลัง (เขียว = ดีขึ้น, แดง = ลดลง)
## ใช้:  await equip_window.open(player)

signal closed

const STAT_NAMES := {"hp": "Max HP", "atk": "ATK", "def": "ARM", "mag": "TEC", "spd": "SPD", "lck": "LCK"}
const COLOR_UP := Color(0.5, 1.0, 0.55)
const COLOR_DOWN := Color(1.0, 0.5, 0.5)
const COLOR_GOLD := Color(0.95, 0.8, 0.45)
const DEFAULT_INFO := "Hover or select gear to compare. Click to equip. (Esc = close)"

var player: PlayerStats
var _title: Label
var _slot_buttons := {} # slot -> Button
var _gem_buttons: Array = [] # ช่อง Skill Gem (index = ช่อง)
var _stat_labels := {} # stat key -> Label
var _gear_title: Label
var _gear_list: VBoxContainer
var _info: Label
var _close_button: Button


func _init() -> void:
	layer = 6
	visible = false
	_build()


func is_open() -> bool:
	return visible


func open(p: PlayerStats) -> void:
	player = p
	_refresh()
	visible = true
	await closed
	visible = false


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		closed.emit()


# ================================================================ การกระทำ
func _equip(item: String) -> void:
	var old := player.equip(item)
	_refresh()
	_info.text = "Equipped %s." % GameData.display_name(item) + (" (%s went to your gear bag)" % GameData.display_name(old) if old != "" else "")


func _unequip(slot: String) -> void:
	var cur := player.equipped(slot)
	if cur == "":
		return
	if player.unequip(slot):
		_refresh()
		_info.text = "Removed %s." % GameData.display_name(cur)
	else:
		_info.text = "Your gear bag is full! (%d/%d)" % [player.gear.size(), GameData.MAX_GEAR]


func _equip_gem(gem: String) -> void:
	if player.gems.size() >= CCBalance.GEM_SLOTS:
		_info.text = "Both gem slots are full. Click a gem slot on the left to remove one first."
		return
	player.set_gem(player.gems.size(), gem)
	_refresh()
	_info.text = "Socketed %s." % GameData.gem_name(gem)


func _remove_gem(slot: int) -> void:
	var old := player.remove_gem(slot)
	if old == "":
		return
	_refresh()
	_info.text = "Removed %s (back in your gem bag)." % GameData.gem_name(old)


func _preview_gem(gem: String) -> void:
	_show_stats({})
	_info.text = "[Skill Gem] %s" % CCBalance.GEMS[gem].desc


# ================================================================ แสดงผล
func _refresh() -> void:
	_title.text = "Equipment  -  %s  [%s Lv %d]   HP %d/%d" % [player.name, player.job, player.level, player.hp, player.max_hp()]
	for slot in PlayerStats.SLOTS:
		var it := player.equipped(slot)
		var b: Button = _slot_buttons[slot]
		if it == "":
			b.text = "%s:  -  (empty)" % GameData.SLOT_NAMES[slot]
		else:
			var extra := GameData.weapon_attack_text(it)
			b.text = "%s:  %s\n    %s%s" % [GameData.SLOT_NAMES[slot], GameData.display_name(it), GameData.stat_text(it), "   " + extra if extra != "" else ""]
		if GameData.rarity(it) != "common":
			b.add_theme_color_override("font_color", ItemDB.color(it))
		else:
			b.remove_theme_color_override("font_color")
	for i in CCBalance.GEM_SLOTS:
		var gb: Button = _gem_buttons[i]
		gb.text = "Gem %d:  %s" % [i + 1, GameData.gem_name(player.gems[i]) if i < player.gems.size() else "-  (empty)"]

	_gear_title.text = "Gear bag  (%d/%d)  -  click to equip" % [player.gear.size(), GameData.MAX_GEAR]
	for c in _gear_list.get_children():
		_gear_list.remove_child(c)
		c.queue_free()
	if player.gear.is_empty() and player.gem_bag.is_empty():
		var empty := Label.new()
		empty.text = "(empty)\nBuy weapons and armor at the Smithy\n- the house left of the castle."
		empty.add_theme_font_size_override("font_size", 18)
		empty.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
		_gear_list.add_child(empty)
	for it in player.gear:
		var b := Button.new()
		b.text = "%s   [%s]   %s" % [GameData.display_name(it), GameData.SLOT_NAMES[GameData.item(it).type], GameData.stat_text(it)]
		if GameData.rarity(it) != "common":
			b.add_theme_color_override("font_color", ItemDB.color(it))
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.custom_minimum_size = Vector2(0, 42)
		b.add_theme_font_size_override("font_size", 18)
		b.pressed.connect(_equip.bind(it), CONNECT_DEFERRED) # deferred: ปุ่มนี้จะถูกลบตอนรีเฟรช
		b.mouse_entered.connect(_preview_equip.bind(it))
		b.focus_entered.connect(_preview_equip.bind(it))
		_gear_list.add_child(b)
	for gem in player.gem_bag:
		var b := Button.new()
		b.text = "%s   [Skill Gem]" % GameData.gem_name(gem)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.custom_minimum_size = Vector2(0, 42)
		b.add_theme_font_size_override("font_size", 18)
		b.pressed.connect(_equip_gem.bind(gem), CONNECT_DEFERRED)
		b.mouse_entered.connect(_preview_gem.bind(gem))
		b.focus_entered.connect(_preview_gem.bind(gem))
		_gear_list.add_child(b)

	_show_stats({})
	_info.text = DEFAULT_INFO
	# โฟกัสปุ่มแรกให้ใช้คีย์บอร์ดได้
	var first: Control = _close_button
	for c in _gear_list.get_children():
		if c is Button:
			first = c as Button
			break
	first.grab_focus.call_deferred()


## แสดงค่าพลัง ถ้ามีค่าใหม่จะแสดงเป็น "เดิม -> ใหม่" พร้อมสี
func _show_stats(new_vals: Dictionary) -> void:
	for k in GameData.STAT_KEYS:
		var cur := player.stat(k)
		var nv: int = new_vals.get(k, cur)
		var l: Label = _stat_labels[k]
		if nv == cur:
			l.text = str(cur)
			l.add_theme_color_override("font_color", Color.WHITE)
		else:
			l.text = "%d  →  %d" % [cur, nv]
			l.add_theme_color_override("font_color", COLOR_UP if nv > cur else COLOR_DOWN)


func _preview_equip(item: String) -> void:
	var vals := {}
	for k in GameData.STAT_KEYS:
		vals[k] = player.preview_stat(k, item)
	_show_stats(vals)
	var data := GameData.item(item)
	var cur := player.equipped(data.type)
	var atk := GameData.weapon_attack_text(item)
	var uq := GameData.item_lines(item).replace("\n", "   ") # affix ต่อกันบรรทัดเดียว (ประหยัดความสูง)
	_info.text = "%s  [%s]  %s - %s%s\n%s%s" % [
		GameData.display_name(item), GameData.SLOT_NAMES[data.type], GameData.stat_text(item), data.desc, "  " + atk if atk != "" else "",
		uq + "\n" if uq != "" else "", "Replaces: %s" % GameData.display_name(cur) if cur != "" else "Slot is empty.",
	]


func _preview_remove(slot: String) -> void:
	var cur := player.equipped(slot)
	if cur == "":
		_show_stats({})
		_info.text = "Nothing equipped in the %s slot." % GameData.SLOT_NAMES[slot]
		return
	var vals := {}
	for k in GameData.STAT_KEYS:
		vals[k] = player.preview_remove_stat(k, slot)
	_show_stats(vals)
	var uq := GameData.item_lines(cur).replace("\n", "   ")
	_info.text = "%s - %s\n%sClick to remove it (goes to your gear bag)." % [GameData.display_name(cur), GameData.item(cur).desc, uq + "\n" if uq != "" else ""]


func _preview_none() -> void:
	_show_stats({})
	_info.text = DEFAULT_INFO


# ================================================================ สร้าง UI
func _build() -> void:
	# พื้นหลังมืด กันคลิกทะลุไปข้างหลัง
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.55)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dim)

	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", Dialogs.panel_style())
	panel.anchor_left = 0.5
	panel.anchor_right = 0.5
	panel.anchor_top = 0.5
	panel.anchor_bottom = 0.5
	panel.custom_minimum_size = Vector2(860, 500)
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	add_child(panel)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 8)
	panel.add_child(root)

	_title = Label.new()
	_title.add_theme_font_size_override("font_size", 26)
	_title.add_theme_color_override("font_color", COLOR_GOLD)
	root.add_child(_title)

	var cols := HBoxContainer.new()
	cols.add_theme_constant_override("separation", 24)
	cols.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(cols)

	# ---- ซ้าย: ของที่สวม + ค่าพลัง
	var left := VBoxContainer.new()
	left.custom_minimum_size = Vector2(360, 0)
	left.add_theme_constant_override("separation", 8)
	cols.add_child(left)
	left.add_child(_section("Equipped  (click to remove)"))
	for slot in PlayerStats.SLOTS:
		var b := Button.new()
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.custom_minimum_size = Vector2(0, 50)
		b.add_theme_font_size_override("font_size", 17)
		b.pressed.connect(_unequip.bind(slot), CONNECT_DEFERRED)
		b.mouse_entered.connect(_preview_remove.bind(slot))
		b.focus_entered.connect(_preview_remove.bind(slot))
		left.add_child(b)
		_slot_buttons[slot] = b
	left.add_child(_section("Skill Gems  (click to remove)"))
	var gem_row := HBoxContainer.new() # 2 ช่องในแถวเดียว ประหยัดความสูง (จอ 648)
	gem_row.add_theme_constant_override("separation", 6)
	left.add_child(gem_row)
	for i in CCBalance.GEM_SLOTS:
		var gb := Button.new()
		gb.alignment = HORIZONTAL_ALIGNMENT_LEFT
		gb.custom_minimum_size = Vector2(0, 36)
		gb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		gb.clip_text = true
		gb.add_theme_font_size_override("font_size", 16)
		gb.pressed.connect(_remove_gem.bind(i), CONNECT_DEFERRED)
		gb.mouse_entered.connect(func() -> void:
			if i < player.gems.size():
				_preview_gem(player.gems[i]))
		gem_row.add_child(gb)
		_gem_buttons.append(gb)
	left.add_child(_section("Stats"))
	var grid := GridContainer.new()
	grid.columns = 6 # ชื่อ/ค่า 3 คู่ต่อแถว
	grid.add_theme_constant_override("h_separation", 14)
	for k in GameData.STAT_KEYS:
		var key_label := Label.new()
		key_label.text = STAT_NAMES[k]
		key_label.add_theme_font_size_override("font_size", 17)
		key_label.add_theme_color_override("font_color", Color(0.75, 0.72, 0.8))
		grid.add_child(key_label)
		var val := Label.new()
		val.add_theme_font_size_override("font_size", 17)
		val.custom_minimum_size = Vector2(62, 0)
		grid.add_child(val)
		_stat_labels[k] = val
	left.add_child(grid)

	# ---- ขวา: กระเป๋าอุปกรณ์
	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.add_theme_constant_override("separation", 8)
	cols.add_child(right)
	_gear_title = _section("")
	right.add_child(_gear_title)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.custom_minimum_size = Vector2(0, 280)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	right.add_child(scroll)
	_gear_list = VBoxContainer.new()
	_gear_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_gear_list.add_theme_constant_override("separation", 6)
	scroll.add_child(_gear_list)
	right.mouse_exited.connect(_preview_none)

	# ---- ล่าง: คำอธิบาย + ปุ่มปิด
	_info = Label.new()
	_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_info.custom_minimum_size = Vector2(0, 52)
	_info.add_theme_font_size_override("font_size", 17)
	_info.add_theme_color_override("font_color", Color(0.88, 0.86, 0.78))
	root.add_child(_info)
	_close_button = Button.new()
	_close_button.text = "Close"
	_close_button.custom_minimum_size = Vector2(160, 44)
	_close_button.add_theme_font_size_override("font_size", 20)
	_close_button.size_flags_horizontal = Control.SIZE_SHRINK_END
	_close_button.pressed.connect(closed.emit, CONNECT_DEFERRED)
	_close_button.focus_entered.connect(_preview_none)
	root.add_child(_close_button)


func _section(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 20)
	l.add_theme_color_override("font_color", COLOR_GOLD)
	return l

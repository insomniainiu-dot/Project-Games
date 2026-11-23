class_name MainUI
extends Node
## UI หลักบนกระดาน: ข้อความเต๋า/ก้าว, ปุ่ม Roll/Bag/Equip, ปุ่มเลือกทิศ, ลูกเต๋า
## และเป็นเจ้าของ HUD / กล่องข้อความ / หน้าต่าง Equip
## UI ไม่เรียกระบบเกมเอง แต่ส่ง signal ออกไปให้ TurnManager จัดการ
##   ui.roll_requested.connect(...)
##   var results: Array = await ui.roll_dice()
##   var dir: Vector2i = await ui.choose_direction(options)

signal roll_requested
signal bag_requested
signal equip_requested
signal passive_requested
signal _direction_picked(dir: Vector2i)
signal _dice_done(results: Array)

var hud: Hud
var dialogs: Dialogs
var equip_window: EquipWindow
var passive_window: PassiveWindow
var _passive_button: Button

var _dice_label: Label
var _steps_label: Label
var _roll_button: Button
var _bag_button: Button
var _equip_button: Button
var _dir_buttons: Dictionary = {} # Vector2i -> Button
var _dice: Array[Dice] = []
var _choices: Array[Vector2i] = []
var _pending := 0
var _results: Array = []


## ต้องเรียกหลัง add_child (ใช้ขนาดจอจาก viewport)
func build() -> void:
	var ui := CanvasLayer.new()
	add_child(ui)

	_dice_label = _label(Vector2(24, 20), 28, "Press Space or click Roll")
	ui.add_child(_dice_label)
	_steps_label = _label(Vector2(24, 130), 22, "")
	ui.add_child(_steps_label)

	_roll_button = _button("Roll Dice", Vector2(24, 70), Vector2(160, 50))
	_roll_button.pressed.connect(roll_requested.emit)
	ui.add_child(_roll_button)
	_bag_button = _button("Bag", Vector2(194, 70), Vector2(100, 50))
	_bag_button.pressed.connect(bag_requested.emit)
	ui.add_child(_bag_button)
	_equip_button = _button("Equip", Vector2(304, 70), Vector2(110, 50))
	_equip_button.pressed.connect(equip_requested.emit)
	ui.add_child(_equip_button)
	_passive_button = _button("Passive", Vector2(424, 70), Vector2(140, 50))
	_passive_button.pressed.connect(passive_requested.emit)
	ui.add_child(_passive_button)

	hud = Hud.new()
	add_child(hud)
	dialogs = Dialogs.new()
	add_child(dialogs)
	equip_window = EquipWindow.new()
	add_child(equip_window)
	passive_window = PassiveWindow.new()
	add_child(passive_window)

	var screen := get_viewport().get_visible_rect().size

	# ปุ่มเลือกทิศ (โชว์เฉพาะตอนถึงทางแยก)
	var pad_center := Vector2(110, screen.y - 110)
	var specs := {Board.UP: ["Up", Vector2(0, -1)], Board.DOWN: ["Down", Vector2(0, 1)], Board.LEFT: ["Left", Vector2(-1, 0)], Board.RIGHT: ["Right", Vector2(1, 0)]}
	for d in specs:
		var b := Button.new()
		b.text = specs[d][0]
		b.custom_minimum_size = Vector2(80, 44)
		b.add_theme_font_size_override("font_size", 20)
		b.position = pad_center + specs[d][1] * 60.0 - Vector2(40, 22)
		b.focus_mode = Control.FOCUS_NONE
		b.visible = false
		b.pressed.connect(_pick.bind(d))
		ui.add_child(b)
		_dir_buttons[d] = b

	# ลูกเต๋า 2 ลูก มุมขวาล่างของจอ
	for i in 2:
		var die := Dice.new()
		die.position = Vector2(screen.x - 170 + i * 100, screen.y - 80)
		die.roll_duration = 0.8 + i * 0.25 # ลูกที่ 2 หยุดทีหลังนิดนึง
		die.rolled.connect(_on_die_rolled)
		ui.add_child(die)
		_dice.append(die)


# ================================================================ ข้อความ / ปุ่ม
func set_dice_text(text: String) -> void:
	_dice_label.text = text


func set_steps_text(text: String) -> void:
	_steps_label.text = text


func append_steps_text(text: String) -> void:
	_steps_label.text += text


func set_controls_enabled(enabled: bool) -> void:
	_roll_button.disabled = not enabled
	_bag_button.disabled = not enabled
	_equip_button.disabled = not enabled
	_passive_button.disabled = not enabled


## ปุ่ม Passive บอกแต้มที่ยังไม่ได้ใช้ (เรืองทองเมื่อมีแต้ม)
func set_passive_points(n: int) -> void:
	_passive_button.text = "Passive +%d" % n if n > 0 else "Passive"
	_passive_button.modulate = Color(1.25, 1.1, 0.6) if n > 0 else Color.WHITE
	_passive_button.custom_minimum_size.x = 170 if n > 0 else 140


## มีหน้าต่างอะไรเปิดบังกระดานอยู่ไหม
func is_blocked() -> bool:
	return dialogs.is_open() or equip_window.is_open() or passive_window.is_open()


# ================================================================ ลูกเต๋า
## ทอยเต๋าทุกลูก แล้วรอจนหยุดครบ คืนผลแต่ละลูก
func roll_dice() -> Array:
	_results.clear()
	_pending = _dice.size()
	for d in _dice:
		d.roll()
	return await _dice_done


func _on_die_rolled(value: int) -> void:
	_results.append(value)
	_pending -= 1
	if _pending == 0:
		_dice_done.emit(_results.duplicate())


# ================================================================ เลือกทิศที่ทางแยก
func choose_direction(options: Array[Vector2i]) -> Vector2i:
	_choices = options
	for d in _dir_buttons:
		_dir_buttons[d].visible = true
		_dir_buttons[d].disabled = not options.has(d)
	var chosen: Vector2i = await _direction_picked
	_choices = []
	for d in _dir_buttons:
		_dir_buttons[d].visible = false
	return chosen


func _pick(dir: Vector2i) -> void:
	if _choices.has(dir):
		_direction_picked.emit(dir)


func _unhandled_input(event: InputEvent) -> void:
	if is_blocked():
		return
	if not _choices.is_empty():
		if event.is_action_pressed("ui_up"):
			_pick(Board.UP)
		elif event.is_action_pressed("ui_down"):
			_pick(Board.DOWN)
		elif event.is_action_pressed("ui_left"):
			_pick(Board.LEFT)
		elif event.is_action_pressed("ui_right"):
			_pick(Board.RIGHT)
		return
	if event.is_action_pressed("ui_accept"): # Space หรือ Enter
		roll_requested.emit()


# ================================================================ ตัวช่วย
func _label(pos: Vector2, font_size: int, text: String) -> Label:
	var l := Label.new()
	l.position = pos
	l.text = text
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	l.add_theme_constant_override("outline_size", 8)
	return l


func _button(text: String, pos: Vector2, min_size: Vector2) -> Button:
	var b := Button.new()
	b.text = text
	b.position = pos
	b.custom_minimum_size = min_size
	b.add_theme_font_size_override("font_size", 24)
	b.focus_mode = Control.FOCUS_NONE # กัน Space กดปุ่มซ้ำ
	return b

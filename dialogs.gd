class_name Dialogs
extends CanvasLayer
## กล่องข้อความ + ตัวเลือก ใช้กับ await ได้
##   await dialogs.message("text")
##   var i: int = await dialogs.choose("text", ["A", "B"])

signal _picked(index: int)

var _panel: PanelContainer
var _label: Label
var _buttons: VBoxContainer


func _init() -> void:
	layer = 5
	_panel = PanelContainer.new()
	_panel.add_theme_stylebox_override("panel", panel_style())
	_panel.anchor_left = 0.5
	_panel.anchor_right = 0.5
	_panel.anchor_top = 1.0
	_panel.anchor_bottom = 1.0
	_panel.offset_left = -300
	_panel.offset_right = 300
	_panel.offset_top = -24 # บน=ล่าง แล้วให้กล่องขยายขึ้นตามเนื้อหา (ไม่ล้นจอด้านล่าง)
	_panel.offset_bottom = -24
	_panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_panel.visible = false
	add_child(_panel)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	_panel.add_child(box)
	_label = Label.new()
	_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_label.add_theme_font_size_override("font_size", 22)
	box.add_child(_label)
	_buttons = VBoxContainer.new()
	_buttons.add_theme_constant_override("separation", 6)
	box.add_child(_buttons)


static func panel_style() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.08, 0.07, 0.1, 0.92)
	sb.border_color = Color(0.85, 0.68, 0.35)
	sb.set_border_width_all(3)
	sb.set_corner_radius_all(10)
	sb.set_content_margin_all(18)
	return sb


func is_open() -> bool:
	return _panel.visible


func message(text: String) -> void:
	await choose(text, ["OK"])


func choose(text: String, options: Array) -> int:
	_label.text = text
	for c in _buttons.get_children():
		_buttons.remove_child(c)
		c.queue_free()
	for i in options.size():
		var b := Button.new()
		b.text = str(options[i])
		b.custom_minimum_size = Vector2(0, 40)
		b.add_theme_font_size_override("font_size", 20)
		b.pressed.connect(func(): _picked.emit.call_deferred(i)) # deferred: ไม่ลบปุ่มระหว่างที่มันยังส่งสัญญาณอยู่
		_buttons.add_child(b)
	_panel.visible = true
	# ไม่ใช้ reset_size(): มันคงขอบบนไว้แล้วขยายลง ทำให้กล่องหลุดจอ
	_panel.offset_top = -24
	_panel.offset_bottom = -24
	if _buttons.get_child_count() > 0:
		(_buttons.get_child(0) as Button).grab_focus.call_deferred() # ใช้ลูกศร+Enter เลือกได้
	var index: int = await _picked
	_panel.visible = false
	return index

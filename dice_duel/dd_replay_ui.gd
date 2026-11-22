class_name DDReplayUI
extends CanvasLayer
## ดู replay ทีละ action (มุมมองผู้ชม: เห็นทุกอย่าง)
## ใช้:  await replay_ui.open(DDReplay.load_file())

signal closed

var _data := {}
var _slider: HSlider
var _info: Label
var _log: RichTextLabel


func _init() -> void:
	layer = 8


func open(data: Dictionary) -> void:
	_data = data
	_build()
	_slider.max_value = data.actions.size()
	_slider.value = data.actions.size()
	_show_step()
	await closed


func _show_step() -> void:
	var step := int(_slider.value)
	var s := DDReplay.replay(_data, step)
	var names := [s.fighters[0].character.name, s.fighters[1].character.name]
	var builds := [s.fighters[0].character.dice, s.fighters[1].character.dice]
	var result := ""
	if s.winner == DDBattle.DRAW:
		result = "   Result: draw"
	elif s.winner >= 0:
		result = "   Result: %s wins" % names[s.winner]
	_info.text = "Action %d / %d   Round %d   Phase: %s%s\n%s  HP %d/%d  Focus %d     %s  HP %d/%d  Focus %d" % [
		step, _data.actions.size(), s.round, s.phase, result,
		names[0], s.fighters[0].hp, s.fighters[0].max_hp, s.fighters[0].focus,
		names[1], s.fighters[1].hp, s.fighters[1].max_hp, s.fighters[1].focus]
	var lines := PackedStringArray()
	for e in s.log:
		lines.append(DDFormat.event_text(e, names, builds))
	_log.text = "\n".join(lines)
	_log.scroll_to_line(_log.get_line_count())


func _step(delta: int) -> void:
	_slider.value = clampf(_slider.value + delta, 0, _slider.max_value)


func _build() -> void:
	var dim := ColorRect.new()
	dim.color = Color(0.06, 0.05, 0.08, 0.98)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 18)
	add_child(margin)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	margin.add_child(box)
	var title := Label.new()
	title.text = "Replay  (seed %d) - spectator view, everything is visible" % int(_data.config.seed)
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", DDBattleUI.GOLD)
	box.add_child(title)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	box.add_child(row)
	for spec in [["|<", -100000], ["<", -1], [">", 1], [">|", 100000]]:
		var b := Button.new()
		b.text = spec[0]
		b.custom_minimum_size = Vector2(44, 36)
		b.pressed.connect(_step.bind(spec[1]))
		row.add_child(b)
	_slider = HSlider.new()
	_slider.step = 1
	_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_slider.value_changed.connect(func(_v: float) -> void: _show_step())
	row.add_child(_slider)
	var close := Button.new()
	close.text = "Close"
	close.custom_minimum_size = Vector2(90, 36)
	close.pressed.connect(func() -> void: closed.emit())
	row.add_child(close)
	_info = Label.new()
	_info.add_theme_font_size_override("font_size", 17)
	box.add_child(_info)
	_log = RichTextLabel.new()
	_log.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_log.selection_enabled = true
	_log.add_theme_font_size_override("normal_font_size", 15)
	box.add_child(_log)

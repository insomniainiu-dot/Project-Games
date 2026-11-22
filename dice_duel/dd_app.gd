extends Control
## ฉากทดลอง Dice Duel แบบ standalone (res://dice_duel/dice_duel.tscn)
## ตั้งค่า → ต่อสู้ (vs AI / hot-seat 2 คน / ดู AI สู้กันเอง) → ดู replay ล่าสุด

const MODES := [["Play vs AI", "ai"], ["Hot-seat (2 players)", "hotseat"]]

var _menu: PanelContainer
var _mode: OptionButton
var _names: Array = []
var _jobs: Array = []
var _pers: OptionButton
var _seed: SpinBox
var _msg: Label


func _ready() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.1, 0.09, 0.12)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	_build_menu()
	# ทางลัดสำหรับทดสอบ: --dd-autostart เริ่มเกมทันที
	if OS.get_cmdline_user_args().has("--dd-autostart"):
		_start.call_deferred()


func _start() -> void:
	var mode: String = MODES[_mode.selected][1]
	var name0: String = _names[0].text if _names[0].text != "" else "Player 1"
	var name1: String = _names[1].text if _names[1].text != "" else ("AI" if mode == "ai" else "Player 2")
	var config := {"seed": int(_seed.value), "fighters": [
		DDBattle.create_character("P1", DDJobs.IDS[_jobs[0].selected], name0),
		DDBattle.create_character("P2", DDJobs.IDS[_jobs[1].selected], name1)]}
	_menu.visible = false
	var ui := DDBattleUI.new()
	add_child(ui)
	await ui.start(config, mode, DDAi.PERSONALITIES[_pers.selected], 1)
	ui.queue_free()
	_menu.visible = true
	_seed.value = randi() % 1000000000
	_msg.text = ""


func _watch_replay() -> void:
	var data := DDReplay.load_file()
	if data.is_empty():
		_msg.text = "No replay yet - finish a battle first."
		return
	_menu.visible = false
	var viewer := DDReplayUI.new()
	add_child(viewer)
	await viewer.open(data)
	viewer.queue_free()
	_menu.visible = true


func _build_menu() -> void:
	_menu = PanelContainer.new()
	_menu.add_theme_stylebox_override("panel", Dialogs.panel_style())
	_menu.anchor_left = 0.5
	_menu.anchor_right = 0.5
	_menu.anchor_top = 0.5
	_menu.anchor_bottom = 0.5
	_menu.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_menu.grow_vertical = Control.GROW_DIRECTION_BOTH
	_menu.custom_minimum_size = Vector2(640, 0)
	add_child(_menu)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	_menu.add_child(box)

	var title := Label.new()
	title.text = "Dice Duel - prototype"
	title.add_theme_font_size_override("font_size", 30)
	title.add_theme_color_override("font_color", DDBattleUI.GOLD)
	box.add_child(title)

	_mode = OptionButton.new()
	for m in MODES:
		_mode.add_item(m[0])
	box.add_child(_row("Mode", _mode))

	for i in 2:
		var name_edit := LineEdit.new()
		name_edit.placeholder_text = "Player %d" % (i + 1)
		name_edit.custom_minimum_size = Vector2(160, 0)
		_names.append(name_edit)
		var job := OptionButton.new()
		for j in DDJobs.IDS:
			job.add_item("%s (%s)" % [DDJobs.NAMES[j], DDJobs.SKILLS[j]])
		job.selected = 0 if i == 0 else 1
		_jobs.append(job)
		var hint := Label.new()
		hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		hint.custom_minimum_size = Vector2(600, 0)
		hint.add_theme_font_size_override("font_size", 14)
		hint.add_theme_color_override("font_color", DDBattleUI.MUTED)
		hint.text = DDJobs.SKILL_DESC[DDJobs.IDS[job.selected]]
		job.item_selected.connect(func(idx: int) -> void: hint.text = DDJobs.SKILL_DESC[DDJobs.IDS[idx]])
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		var l := Label.new()
		l.text = "Player %d" % (i + 1) if i == 0 else "Player 2 / AI"
		l.custom_minimum_size = Vector2(120, 0)
		row.add_child(l)
		row.add_child(name_edit)
		row.add_child(job)
		box.add_child(row)
		box.add_child(hint)

	_pers = OptionButton.new()
	_pers.add_item("aggressive")
	_pers.add_item("bluffer")
	box.add_child(_row("AI personality", _pers))

	_seed = SpinBox.new()
	_seed.max_value = 999999999
	_seed.value = randi() % 1000000000
	box.add_child(_row("Seed", _seed))

	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 10)
	var start := Button.new()
	start.text = "Start battle"
	start.custom_minimum_size = Vector2(180, 46)
	start.pressed.connect(_start)
	buttons.add_child(start)
	var rep := Button.new()
	rep.text = "Watch last replay"
	rep.custom_minimum_size = Vector2(180, 46)
	rep.pressed.connect(_watch_replay)
	buttons.add_child(rep)
	box.add_child(buttons)
	_msg = Label.new()
	_msg.add_theme_color_override("font_color", DDBattleUI.BAD_COLOR)
	box.add_child(_msg)


func _row(title: String, control: Control) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	var l := Label.new()
	l.text = title
	l.custom_minimum_size = Vector2(120, 0)
	row.add_child(l)
	row.add_child(control)
	return row

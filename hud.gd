class_name Hud
extends CanvasLayer
## แถบสถานะผู้เล่น มุมขวาบน

var _text: Label
var _hp_bar: ProgressBar


func _init() -> void:
	layer = 2
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", Dialogs.panel_style())
	panel.anchor_left = 1.0
	panel.anchor_right = 1.0
	panel.offset_left = -290
	panel.offset_right = -16
	panel.offset_top = 16
	add_child(panel)
	var box := VBoxContainer.new()
	panel.add_child(box)
	_hp_bar = ProgressBar.new()
	_hp_bar.custom_minimum_size = Vector2(0, 18)
	_hp_bar.show_percentage = false
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color(0.85, 0.25, 0.3)
	fill.set_corner_radius_all(4)
	_hp_bar.add_theme_stylebox_override("fill", fill)
	box.add_child(_hp_bar)
	_text = Label.new()
	_text.add_theme_font_size_override("font_size", 17)
	box.add_child(_text)


func refresh(p: PlayerStats, day: int) -> void:
	_hp_bar.max_value = p.max_hp()
	_hp_bar.value = p.hp
	_text.text = "%s  [%s Lv %d]\nHP %d / %d    EXP %d / %d\nATK %d  DEF %d  MAG %d  SPD %d\nGold %d    Day %d    Towns %d/%d\nWeapon: %s\nArmor: %s\nAccessory: %s\nItems: %s" % [
		p.name, p.job, p.level,
		p.hp, p.max_hp(), p.xp, p.exp_needed(),
		p.stat("atk"), p.stat("def"), p.stat("mag"), p.stat("spd"),
		p.gold, day, p.towns.size(), GameData.TOWNS.size(),
		_or_dash(p.weapon), _or_dash(p.armor), _or_dash(p.accessory),
		", ".join(PackedStringArray(p.items)) if not p.items.is_empty() else "-",
	]


func _or_dash(s: String) -> String:
	return s if s != "" else "-"

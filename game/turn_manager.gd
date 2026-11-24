class_name TurnManager
extends Node
## ลำดับของ 1 เทิร์น: ทอยเต๋า -> เดิน -> หยุดบนช่อง -> จบวัน
## รวมถึงการเปิดกระเป๋า / หน้าต่าง Equip นอกการต่อสู้ (กันไม่ให้เปิดซ้อนตอนกำลังเดิน)

var _state: GameState
var _walker: BoardWalker
var _events: TileEvents
var _piece: Witch
var _ui: MainUI
var _busy := false


func setup(state: GameState, walker: BoardWalker, events: TileEvents, piece: Witch, ui: MainUI) -> void:
	_state = state
	_walker = walker
	_events = events
	_piece = piece
	_ui = ui
	_ui.roll_requested.connect(play_turn)
	_ui.bag_requested.connect(_open_bag)
	_ui.equip_requested.connect(_open_equip)
	_ui.passive_requested.connect(_open_passive)


func play_turn() -> void:
	if _busy:
		return # ยังทอย/เดินอยู่
	_busy = true
	_ui.set_controls_enabled(false)
	_ui.set_dice_text("Rolling...")
	var results: Array = await _ui.roll_dice()
	var total := 0
	for v in results:
		total += v
	var text := "Rolled: %s = %d" % [" + ".join(results.map(func(v): return str(v))), total]
	if results.size() == 2 and results[0] == results[1]:
		text += "  DOUBLE!"
	_ui.set_dice_text(text)

	var player := _state.player
	await _walker.walk(player, _piece, total)
	_ui.set_steps_text("")
	await _events.land(player)
	await _end_day()
	SaveGame.save(_state) # เซฟอัตโนมัติทุกสิ้นวัน
	_busy = false
	_ui.set_controls_enabled(true)
	_state.notify()


## จบวัน: วันเพิ่ม + เก็บภาษีจากเมืองที่เป็นของเรา
func _end_day() -> void:
	_state.day += 1
	var player := _state.player
	var tax := 0
	for t in player.towns:
		tax += GameData.TOWNS[t].tax
	if tax > 0:
		player.gold += tax
		await _ui.dialogs.message("Day %d begins. Your towns paid %d Gold in taxes." % [_state.day, tax])


## หน้าต่างสวมใส่อุปกรณ์ (ปุ่ม Equip)
func _open_equip() -> void:
	if _busy or _ui.is_blocked():
		return
	_busy = true
	_ui.set_controls_enabled(false)
	await _ui.equip_window.open(_state.player)
	_state.notify()
	_busy = false
	_ui.set_controls_enabled(true)


## หน้าต่าง Passive Tree (ปุ่ม Passive)
func _open_passive() -> void:
	if _busy or _ui.is_blocked():
		return
	_busy = true
	_ui.set_controls_enabled(false)
	await _ui.passive_window.open(_state.player)
	_state.notify()
	_busy = false
	_ui.set_controls_enabled(true)


## ใช้ไอเทมนอกการต่อสู้ (ปุ่ม Bag)
func _open_bag() -> void:
	if _busy or _ui.is_blocked():
		return
	_busy = true
	_ui.set_controls_enabled(false)
	var player := _state.player
	while true:
		var labels: Array = []
		for it in player.items:
			labels.append("%s - %s" % [it, GameData.ITEMS[it].desc])
		labels.append("Close")
		var pick := await _ui.dialogs.choose("Bag (%d/%d)" % [player.items.size(), GameData.MAX_ITEMS], labels)
		if pick >= player.items.size():
			break
		var item: String = player.items[pick]
		var heal: int = GameData.ITEMS[item].get("heal", 0)
		if heal > 0:
			player.items.remove_at(pick)
			var healed := player.heal(heal)
			_state.notify()
			await _ui.dialogs.message("Used %s. Recovered %d HP." % [item, healed])
		else:
			await _ui.dialogs.message("%s can only be used in battle." % item)
	_busy = false
	_ui.set_controls_enabled(true)

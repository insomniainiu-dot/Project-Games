extends Node3D
## ฉากหลักของเกมกระดานแบบ HD-2D: ประกอบระบบต่าง ๆ เข้าด้วยกันเท่านั้น
## ตัวระบบอยู่ในไฟล์ของแต่ละส่วน:
##   world/  scene_lighting.gd (แสง/กล้อง), scenery.gd (ของตกแต่ง), mesh_factory.gd
##   board/  board.gd (ผังกระดาน), board_walker.gd (เดิน + เลือกทาง)
##   game/   game_state.gd, turn_manager.gd (ลำดับเทิร์น), tile_events.gd (เหตุการณ์บนช่อง), shops.gd
##   ui/     main_ui.gd (ปุ่ม/ลูกเต๋า/HUD/กล่องข้อความ)

var state := GameState.new()


func _ready() -> void:
	randomize()
	var rng := RandomNumberGenerator.new()
	rng.seed = 42 # ให้ของตกแต่งอยู่ที่เดิมทุกครั้ง (Board ใช้ก่อน แล้ว Scenery ใช้ต่อ)

	# ---- โลก 3D
	var lighting := SceneLighting.new()
	add_child(lighting)
	lighting.build()
	var board := Board.new()
	add_child(board)
	board.build(rng)
	var scenery := Scenery.new()
	add_child(scenery)
	scenery.build(board, rng)

	var witch := Witch.new()
	add_child(witch)
	witch.position = Board.tile_pos(state.player.tile)
	lighting.follow(witch)

	# ---- UI
	var ui := MainUI.new()
	add_child(ui)
	ui.build()
	state.changed.connect(func():
		ui.hud.refresh(state.player, state.day)
		ui.set_passive_points(state.player.unspent_points()))

	# ---- ระบบเกม
	var shops := Shops.new()
	add_child(shops)
	shops.setup(state, ui.dialogs, ui.equip_window)
	var events := TileEvents.new()
	add_child(events)
	events.setup(state, board, witch, ui.dialogs, shops)
	var walker := BoardWalker.new()
	add_child(walker)
	walker.setup(board, ui)
	var turns := TurnManager.new()
	add_child(turns)
	turns.setup(state, walker, events, witch, ui)

	state.notify()

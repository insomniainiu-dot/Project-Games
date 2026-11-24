class_name TileEvents
extends Node3D
## เหตุการณ์เมื่อหยุดบนช่อง: ปราสาท / เมือง / ร้าน / ต่อสู้ / ไอเทม / เงิน / กับดัก
## รวมถึงการต่อสู้ แพ้แล้วกลับปราสาท และมอนสเตอร์ผู้คุมเมืองที่ยืนบนกระดาน
##   await events.land(player)

var _state: GameState
var _board: Board
var _piece: Witch
var _dialogs: Dialogs
var _shops: Shops
var _town_guards: Dictionary = {} # Vector2i -> Sprite3D (มอนสเตอร์ที่ยึดเมือง)
var _time := 0.0


func setup(state: GameState, board: Board, piece: Witch, dialogs: Dialogs, shops: Shops) -> void:
	_state = state
	_board = board
	_piece = piece
	_dialogs = dialogs
	_shops = shops
	_build_town_guards()


func _process(delta: float) -> void:
	_time += delta
	for g in _town_guards.values():
		g.frame = int(_time * 4.0) % g.hframes # ผู้คุมเมืองขยับ


# ================================================================ หยุดบนช่อง
func land(player: PlayerStats) -> void:
	match _board.type_of(player.tile):
		"castle":
			await _visit_castle(player)
		"town":
			await _visit_town(player, player.tile)
		"shop":
			await _shops.visit_shop(player)
		"smithy":
			await _shops.visit_smithy(player)
		"battle":
			var id: String = GameData.WILD_MONSTERS[randi() % GameData.WILD_MONSTERS.size()]
			await fight(player, id)
		"item":
			var item: String = ["Medkit", "Medkit", "Big Medkit", "Smoke Bomb"][randi() % 4]
			if player.add_item(item):
				await _dialogs.message("Item tile! You found a %s." % item)
			else:
				await _dialogs.message("You found a %s, but your bag is full." % item)
		"gold":
			var amount := randi_range(10, 40)
			amount = roundi(amount * player.gold_mult())
			player.gold += amount
			await _dialogs.message("Gold tile! You found %d Gold." % amount)
		"event":
			await run_event(player)
		"trap":
			if randf() < 0.5:
				var lost := roundi(player.gold * 0.15)
				player.gold -= lost
				await _dialogs.message("Trap! A pickpocket stole %d Gold." % lost)
			else:
				var dmg := randi_range(4, 9)
				player.hp = maxi(1, player.hp - dmg)
				await _dialogs.message("Trap! Falling rocks hit you for %d damage." % dmg)
	_state.notify()


# ================================================================ อีเวนต์ (EventData / EventRunner)
func run_event(player: PlayerStats, event_id := "") -> void:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	if event_id == "":
		event_id = EventRunner.pick(player, rng)
	var ev: Dictionary = EventData.EVENTS[event_id]
	while true:
		var opts := EventRunner.visible_options(player, event_id)
		var labels: Array = opts.map(func(o): return EventRunner.describe(player, o))
		var pick := await _dialogs.choose("%s\n%s" % [ev.title.to_upper(), ev.text], labels)
		var opt: Dictionary = opts[pick]
		var av := EventRunner.availability(player, opt)
		if not av.ok:
			await _dialogs.message(av.reason)
			continue
		var r := EventRunner.resolve(player, event_id, opt.key, rng)
		_state.notify()
		if not r.back_path.is_empty():
			var points: Array[Vector3] = []
			for c in r.back_path:
				points.append(Board.tile_pos(c))
			await _piece.move_along(points)
		await _dialogs.message("\n".join(r.lines))
		return


# ================================================================ ต่อสู้
## ระบบต่อสู้ที่ใช้บนกระดาน
##   "check"     = ช่องเช็ค (res://combat/)
##   "dice_duel" = Dice Duel (res://dice_duel/ เก็บไว้ สลับกลับได้ที่นี่)
const COMBAT_SYSTEM := "check"


## ต่อสู้กับมอนสเตอร์ — คืนผล "win" / "lose" / "run"
func fight(player: PlayerStats, monster_id: String) -> String:
	if COMBAT_SYSTEM == "dice_duel":
		return await _fight_dice_duel(player, monster_id)
	var m: Dictionary = GameData.MONSTERS[monster_id]
	var ui := CCBattleUI.new()
	add_child(ui)
	var final: Dictionary = await ui.start(CCBridge.config(player, monster_id, randi()), CCBridge.portraits(monster_id))
	ui.queue_free()
	CCBridge.apply_result(player, final)
	player.fatigue = 0 # Fatigue ใช้ไปกับการต่อสู้ครั้งนี้แล้ว
	var result: String = final.result
	match result:
		"win":
			await _victory(player, m)
		"lose":
			await _defeated(player)
		_:
			await _dialogs.message("You got away from the %s." % monster_id)
	_state.notify()
	return result


func _fight_dice_duel(player: PlayerStats, monster_id: String) -> String:
	var m: Dictionary = GameData.MONSTERS[monster_id]
	if player.items.has("Smoke Bomb"):
		var pick := await _dialogs.choose("A %s blocks your way!" % monster_id, ["Fight!", "Use Smoke Bomb (escape)"])
		if pick == 1:
			player.items.erase("Smoke Bomb")
			_state.notify()
			await _dialogs.message("You vanished in the smoke!")
			return "run"

	var ui := DDBattleUI.new()
	add_child(ui)
	var final: Dictionary = await ui.start(DDBoardBridge.config(player, monster_id, randi()), "ai",
		m.get("dd_personality", "aggressive"), 1, DDBoardBridge.portraits(monster_id))
	ui.queue_free()
	player.hp = final.fighters[0].hp

	var result := "run"
	if final.winner == 0:
		result = "win"
		await _victory(player, m)
	elif final.winner == 1:
		result = "lose"
		await _defeated(player)
	else:
		player.hp = maxi(1, player.hp)
		await _dialogs.message("Neither side could win. The %s runs off." % monster_id)
	_state.notify()
	return result


func _victory(player: PlayerStats, m: Dictionary) -> void:
	var gold: int = roundi(m.gold * player.gold_mult())
	player.gold += gold
	var ups := player.gain_exp(m.exp)
	var text := "Victory! Got %d EXP and %d Gold." % [m.exp, gold]
	if ups > 0:
		text += "\nLEVEL UP! Now Lv %d." % player.level
		text += "\n+%d Passive Point%s! Press Passive to spend." % [ups, "" if ups == 1 else "s"]
	_state.notify()
	await _dialogs.message(text)
	await _gear_drop(player, m)
	await _unique_drop(player, m)


## ดรอปอุปกรณ์ Rare/Epic (ผู้คุมเมืองดรอปแน่นอน, มอนสเตอร์ทั่วไปตาม ItemDB.GEAR_DROP_CHANCE)
func _gear_drop(player: PlayerStats, m: Dictionary) -> void:
	if randf() >= float(m.get("gear_chance", ItemDB.GEAR_DROP_CHANCE)):
		return
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var item := ItemDB.random_drop(rng)
	await _offer_gear(player, item, "%s DROP!" % ItemDB.TIERS[GameData.rarity(item)].name.to_upper())


## ดรอปอุปกรณ์ Unique (อาวุธ/เกราะ/เครื่องประดับ) ที่ยังไม่มี (ผู้คุมเมืองดรอปแน่นอน, มอนสเตอร์ทั่วไปตาม UNIQUE_DROP_CHANCE)
func _unique_drop(player: PlayerStats, m: Dictionary) -> void:
	if randf() >= float(m.get("unique_chance", GameData.UNIQUE_DROP_CHANCE)):
		return
	var pool: Array = GameData.unique_items().filter(func(it): return not player.owns(it))
	if pool.is_empty():
		return
	await _offer_gear(player, pool[randi() % pool.size()], "UNIQUE DROP!")


## เก็บอุปกรณ์ที่ดรอปเข้ากระเป๋า แล้วถามว่าจะสวมเลยไหม (กระเป๋าเต็ม = ทิ้ง)
func _offer_gear(player: PlayerStats, item: String, header: String) -> void:
	var parts := PackedStringArray(["%s  %s" % [header, GameData.display_name(item)], GameData.stat_text(item)])
	for extra in [GameData.weapon_attack_text(item), GameData.item_lines(item)]:
		if extra != "":
			parts.append(extra)
	var info := "\n".join(parts)
	if not player.add_gear(item):
		await _dialogs.message(info + "\n\nYour gear bag is full... you had to leave it behind.")
		return
	_state.notify()
	if await _dialogs.choose(info + "\n\nEquip it now?", ["Equip now", "Keep in gear bag"]) == 0:
		player.equip(item)
		_state.notify()


## แพ้: กลับปราสาท เสียเงิน 30% HP เหลือครึ่ง
func _defeated(player: PlayerStats) -> void:
	var lost := roundi(player.gold * 0.3)
	player.gold -= lost
	player.hp = maxi(1, int(player.max_hp() / 2.0))
	player.tile = Board.CASTLE_TILE
	player.came_from = Board.NO_TILE
	_piece.position = Board.tile_pos(player.tile)
	_piece.facing = Witch.Dir.DOWN
	await _dialogs.message("You wake up at the castle... (lost %d Gold)" % lost)


# ================================================================ ปราสาท / เมือง
func _visit_castle(player: PlayerStats) -> void:
	while true:
		var cost := player.reset_cost()
		var reset_label := "Reset Passive Tree (%s)" % ("free" if cost == 0 else "%d Gold" % cost)
		var pick := await _dialogs.choose("Welcome home to the castle.", ["Rest (full HP)", "Change Job", reset_label, "Leave"])
		match pick:
			0:
				player.hp = player.max_hp()
				player.fatigue = 0
				_state.notify()
				await _dialogs.message("You rest well. HP fully restored, fatigue gone!")
			1:
				var jobs: Array = GameData.JOBS.keys()
				var labels: Array = []
				for j in jobs:
					labels.append("%s - %s%s" % [j, GameData.JOBS[j].desc, "  (current)" if j == player.job else ""])
				labels.append("Back")
				var j_pick := await _dialogs.choose("Choose a job. (Level is kept. Each job keeps its own Passive Tree.)", labels)
				if j_pick < jobs.size() and jobs[j_pick] != player.job:
					player.change_job(jobs[j_pick])
					_state.notify()
					var pts := player.unspent_points()
					await _dialogs.message("You are now a %s!%s" % [player.job, "\nYou have %d Passive Point%s to spend." % [pts, "" if pts == 1 else "s"] if pts > 0 else ""])
			2:
				if player.allocated().is_empty():
					await _dialogs.message("Your %s tree is already empty." % player.job)
				elif player.gold < cost:
					await _dialogs.message("You need %d Gold to reset (free until Lv %d)." % [cost, GameData.FREE_RESET_LEVEL])
				else:
					var yes := await _dialogs.choose("Refund every %s passive node%s" % [player.job, " for %d Gold?" % cost if cost > 0 else "?"], ["Reset", "Cancel"])
					if yes == 0:
						player.gold -= cost
						var n := player.reset_tree()
						_state.notify()
						await _dialogs.message("Refunded %d point%s. Spend them with the Passive button." % [n, "" if n == 1 else "s"])
			_:
				return


func _visit_town(player: PlayerStats, cell: Vector2i) -> void:
	var town: Dictionary = GameData.TOWNS[cell]
	if player.towns.has(cell):
		var healed := player.heal(roundi(player.max_hp() * 0.3))
		await _dialogs.message("The people of %s cheer for you! (+%d HP)" % [town.name, healed])
		return
	var pick := await _dialogs.choose("%s is ruled by the %s!\nFight to free the town?" % [town.name, town.guard], ["Fight!", "Not now"])
	if pick != 0:
		return
	var result := await fight(player, town.guard)
	if result == "win":
		player.towns.append(cell)
		if _town_guards.has(cell):
			_town_guards[cell].queue_free()
			_town_guards.erase(cell)
		_state.notify()
		await _dialogs.message("%s is free! It will pay you %d Gold every day." % [town.name, town.tax])
		if player.towns.size() == GameData.TOWNS.size():
			await _dialogs.message("All towns are free! You saved the kingdom in %d days!" % _state.day)


## เอาผู้คุมของเมืองที่ปลดปล่อยแล้วออก (หลังโหลดเซฟ)
func refresh_town_guards() -> void:
	for cell in _state.player.towns:
		if _town_guards.has(cell):
			_town_guards[cell].queue_free()
			_town_guards.erase(cell)


## มอนสเตอร์ผู้คุมยืนเฝ้าเมือง
func _build_town_guards() -> void:
	for cell in GameData.TOWNS:
		var m: Dictionary = GameData.MONSTERS[GameData.TOWNS[cell].guard]
		var s := Sprite3D.new()
		s.texture = load(m.sprite)
		s.hframes = m.frames
		s.vframes = 2
		s.frame = 0
		var height := 1.1 * float(m.scale)
		s.pixel_size = height / (s.texture.get_height() / 2.0)
		s.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
		s.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		s.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
		s.shaded = true
		s.modulate = m.tint
		s.position = Board.tile_pos(cell) + Vector3(0, height / 2.0, -0.15)
		add_child(s)
		_town_guards[cell] = s

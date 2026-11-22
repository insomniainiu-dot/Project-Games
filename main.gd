extends Node3D
## ฉากกระดานแบบ HD-2D: ตัวละครพิกเซล 2D + ฉาก 3D + แสงเงา + Glow + ภาพเบลอหน้า/หลัง (DOF)
## กระดาน 30 ช่อง มีทางแยก ขึ้น/ลง/ซ้าย/ขวา ทอยเต๋าแล้วเลือกทางเดินเองที่ทางแยก

signal direction_chosen(dir: Vector2i)

const STEP := 1.1          # ระยะห่างระหว่างช่อง (หน่วยโลก 3D)
const TILE_SIZE := 1.0
const TILE_TOP := 0.2      # ความสูงผิวบนของช่อง
const GRID_CENTER := Vector2(3, 1.5) # จุดกึ่งกลางกระดาน (พิกัดกริด)
const CAMERA_OFFSET := Vector3(0, 5.9, 7.2) # กล้องอยู่ห่างจากตัวละครเท่านี้ (ไกลขึ้น + เลนส์แคบ = ดูเป็นโมเดลจิ๋ว)
const NO_TILE := Vector2i(9999, 9999)

const UP := Vector2i(0, -1)
const DOWN := Vector2i(0, 1)
const LEFT := Vector2i(-1, 0)
const RIGHT := Vector2i(1, 0)
const DIRS: Array[Vector2i] = [UP, DOWN, LEFT, RIGHT]

const CATEGORY_NAMES := {"weapon": "Weapons", "armor": "Armor", "accessory": "Accessories"}

# ช่องปราสาท (จุดเริ่มต้น)
const CASTLE_TILE := Vector2i(3, -2)

var tiles: Dictionary = {}   # Vector2i -> MeshInstance3D
var current: Vector2i = CASTLE_TILE
var came_from: Vector2i = NO_TILE

var witch: Witch
var camera: Camera3D
var dice_label: Label
var steps_label: Label
var roll_button: Button
var dir_buttons: Dictionary = {} # Vector2i -> Button
var dice: Array[Dice] = []
var _markers: Array[Node3D] = []
var _choices: Array[Vector2i] = []
var _busy := false
var _pending := 0
var _results: Array[int] = []
var _rng := RandomNumberGenerator.new()
var _torches: Array[OmniLight3D] = []
var _time := 0.0

# ---- ระบบเกม ----
var player := PlayerStats.new()
var day := 1
var tile_types: Dictionary = {}   # Vector2i -> "battle"/"gold"/...
var town_guards: Dictionary = {}  # Vector2i -> Sprite3D (มอนสเตอร์ที่ยึดเมือง)
var hud: Hud
var dialogs: Dialogs
var bag_button: Button
var equip_button: Button
var equip_window: EquipWindow


func _ready() -> void:
	randomize()
	_rng.seed = 42 # ให้ของตกแต่งอยู่ที่เดิมทุกครั้ง

	_build_environment()
	_build_ground()
	_build_board()
	_build_castle()
	_build_props()
	_build_motes()
	_build_post_fx()

	witch = Witch.new()
	add_child(witch)
	witch.position = _tile_pos(current)
	camera.global_position = witch.position + CAMERA_OFFSET

	_build_town_guards()
	_build_ui()
	hud.refresh(player, day)


func _process(delta: float) -> void:
	# กล้องตามตัวละครแบบนุ่ม ๆ
	var target := witch.position + CAMERA_OFFSET
	camera.global_position = camera.global_position.lerp(target, 1.0 - exp(-delta * 4.0))

	# ไฟคบเพลิงปราสาทกะพริบ
	_time += delta
	for i in _torches.size():
		_torches[i].light_energy = 1.6 + sin(_time * 9.0 + i * 2.0) * 0.25 + sin(_time * 23.0 + i) * 0.15
	for g in town_guards.values():
		g.frame = int(_time * 4.0) % g.hframes # ผู้คุมเมืองขยับ


# ================================================================ กระดาน
## แผนผังกระดาน 30 ช่อง (พิกัดกริด x = ขวา, y = ลงมาทางกล้อง)
##
##                    C            <- ปราสาท (3,-2) จุดเริ่ม
##                    |
##          o--o--o--+--o--o--o     + = ทางแยก 4 ทาง
##          |        |        |
##          o        o        o
##          |        |        |
##    o--o--+        o        +--o--o
##          |        |        |
##          o        o        o
##          |        |        |
##          o--o--o--+--o--o--o
##                   |
##                   o
func _board_layout() -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	# วงรอบนอก 7x5 (20 ช่อง)
	for x in 7:
		cells.append(Vector2i(x, 0))
		cells.append(Vector2i(x, 4))
	for y in range(1, 4):
		cells.append(Vector2i(0, y))
		cells.append(Vector2i(6, y))
	# ถนนกลางแนวตั้ง (3 ช่อง) -> ทำให้เกิดทางแยก 4 ทางบนและล่าง
	for y in range(1, 4):
		cells.append(Vector2i(3, y))
	# ทางขึ้นไปปราสาท (2 ช่อง)
	cells.append(Vector2i(3, -1))
	cells.append(CASTLE_TILE)
	# ทางลงด้านล่าง (1 ช่อง)
	cells.append(Vector2i(3, 5))
	# ทางแยกซ้าย (2 ช่อง) และขวา (2 ช่อง)
	cells.append(Vector2i(-1, 2))
	cells.append(Vector2i(-2, 2))
	cells.append(Vector2i(7, 2))
	cells.append(Vector2i(8, 2))
	return cells # รวม 30 ช่อง


func _build_board() -> void:
	var k := 0
	for cell in _board_layout():
		# ชนิดช่อง: ช่องพิเศษตาม GameData ที่เหลือวนตามรูปแบบ
		var type: String
		if GameData.SPECIAL_TILES.has(cell):
			type = GameData.SPECIAL_TILES[cell]
		else:
			type = GameData.TILE_PATTERN[k % GameData.TILE_PATTERN.size()]
			k += 1
		tile_types[cell] = type
		var tint := _rng.randf_range(0.92, 1.04)
		# ผสมกับสีหินเดิม ให้สีช่องนุ่มลงแต่ยังแยกชนิดออก
		var color: Color = Color(0.9, 0.86, 0.8).lerp(GameData.TILE_TYPES[type].color, 0.6) * tint
		color.a = 1.0
		var tile := _box(Vector3(TILE_SIZE, TILE_TOP, TILE_SIZE), _tile_pos(cell) - Vector3(0, TILE_TOP / 2.0, 0), _mat("stone", color))
		add_child(tile)
		tiles[cell] = tile


func _neighbors(cell: Vector2i, cells = null) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for d in DIRS:
		var n: Vector2i = cell + d
		if cells == null:
			if tiles.has(n):
				result.append(d)
		elif (cells as Array).has(n):
			result.append(d)
	return result


## จุดกึ่งกลางผิวบนของช่อง (ตำแหน่งเท้าตัวละคร)
func _tile_pos(cell: Vector2i) -> Vector3:
	return _grid_to_world(Vector2(cell)) + Vector3(0, TILE_TOP, 0)


func _grid_to_world(g: Vector2) -> Vector3:
	return Vector3((g.x - GRID_CENTER.x) * STEP, 0, (g.y - GRID_CENTER.y) * STEP)


# ================================================================ เกม
func roll_dice() -> void:
	if _busy:
		return # ยังทอย/เดินอยู่
	_busy = true
	_results.clear()
	_pending = dice.size()
	roll_button.disabled = true
	dice_label.text = "Rolling..."
	for d in dice:
		d.roll()


func _on_die_rolled(value: int) -> void:
	_results.append(value)
	_pending -= 1
	if _pending > 0:
		return
	var total := _results[0] + _results[1]
	var text := "Rolled: %d + %d = %d" % [_results[0], _results[1], total]
	if _results[0] == _results[1]:
		text += "  DOUBLE!"
	dice_label.text = text
	bag_button.disabled = true
	equip_button.disabled = true
	await _walk(total)
	steps_label.text = ""
	await _land(current)
	await _end_day()
	_busy = false
	roll_button.disabled = false
	bag_button.disabled = false
	equip_button.disabled = false
	hud.refresh(player, day)


## เดินตามจำนวนก้าว ถ้าเจอทางแยกให้ผู้เล่นเลือก
func _walk(steps: int) -> void:
	var first_step := true
	for i in steps:
		steps_label.text = "Steps left: %d" % (steps - i)
		var options := _neighbors(current)
		# ห้ามเดินย้อนกลับ ยกเว้นก้าวแรก หรือเจอทางตัน
		if not first_step and options.size() > 1:
			options.erase(came_from - current)
		var dir: Vector2i
		if options.size() == 1:
			dir = options[0]
		else:
			witch.end_walk(false)
			dir = await _ask_direction(options)
		first_step = false
		if not witch.walking:
			witch.begin_walk()
		came_from = current
		current += dir
		await witch.step_to(_tile_pos(current))
	witch.end_walk()
	steps_label.text = "Steps left: 0"


func _ask_direction(options: Array[Vector2i]) -> Vector2i:
	_choices = options
	steps_label.text += "  - Choose a way! (Arrow keys / buttons)"
	for d in dir_buttons:
		dir_buttons[d].visible = true
		dir_buttons[d].disabled = not options.has(d)
	for d in options:
		_markers.append(_make_marker(current + d))
	var chosen: Vector2i = await direction_chosen
	_choices = []
	for d in dir_buttons:
		dir_buttons[d].visible = false
	for m in _markers:
		m.queue_free()
	_markers.clear()
	return chosen


func _pick(dir: Vector2i) -> void:
	if _choices.has(dir):
		direction_chosen.emit(dir)


## ลูกศรเรืองแสงลอยอยู่เหนือช่องที่เลือกได้
func _make_marker(cell: Vector2i) -> Node3D:
	var marker := Node3D.new()
	marker.position = _tile_pos(cell) + Vector3(0, 0.55, 0)
	add_child(marker)
	var cone := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.2
	mesh.bottom_radius = 0.0
	mesh.height = 0.35
	cone.mesh = mesh
	cone.material_override = _glow_mat(Color(1.0, 0.85, 0.3), 2.5)
	cone.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	marker.add_child(cone)
	var ring := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.36
	torus.outer_radius = 0.44
	ring.mesh = torus
	ring.material_override = _glow_mat(Color(1.0, 0.85, 0.3), 1.5)
	ring.position = Vector3(0, -0.52, 0)
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	marker.add_child(ring)
	var bob := cone.create_tween().set_loops() # ผูกกับ cone จะหยุดเองเมื่อ marker ถูกลบ
	bob.tween_property(cone, "position:y", 0.15, 0.4).set_trans(Tween.TRANS_SINE)
	bob.tween_property(cone, "position:y", 0.0, 0.4).set_trans(Tween.TRANS_SINE)
	return marker


func _unhandled_input(event: InputEvent) -> void:
	if dialogs.is_open() or equip_window.is_open():
		return
	if not _choices.is_empty():
		if event.is_action_pressed("ui_up"):
			_pick(UP)
		elif event.is_action_pressed("ui_down"):
			_pick(DOWN)
		elif event.is_action_pressed("ui_left"):
			_pick(LEFT)
		elif event.is_action_pressed("ui_right"):
			_pick(RIGHT)
		return
	if event.is_action_pressed("ui_accept"): # Space หรือ Enter
		roll_dice()


# ================================================================ ระบบเกม: หยุดบนช่อง
func _land(cell: Vector2i) -> void:
	match tile_types.get(cell, "empty"):
		"castle":
			await _visit_castle()
		"town":
			await _visit_town(cell)
		"shop":
			await _visit_shop()
		"smithy":
			await _visit_smithy()
		"battle":
			var id: String = GameData.WILD_MONSTERS[randi() % GameData.WILD_MONSTERS.size()]
			await _fight(id)
		"item":
			var item: String = ["Herb", "Herb", "Big Herb", "Smoke Ball"][randi() % 4]
			if player.add_item(item):
				await dialogs.message("Item tile! You found a %s." % item)
			else:
				await dialogs.message("You found a %s, but your bag is full." % item)
		"gold":
			var amount := randi_range(10, 40)
			if player.job == "Rogue":
				amount = roundi(amount * 1.25)
			player.gold += amount
			await dialogs.message("Gold tile! You found %d Gold." % amount)
		"trap":
			if randf() < 0.5:
				var lost := roundi(player.gold * 0.15)
				player.gold -= lost
				await dialogs.message("Trap! A pickpocket stole %d Gold." % lost)
			else:
				var dmg := randi_range(4, 9)
				player.hp = maxi(1, player.hp - dmg)
				await dialogs.message("Trap! Falling rocks hit you for %d damage." % dmg)
	hud.refresh(player, day)


## จบวัน: วันเพิ่ม + เก็บภาษีจากเมืองที่เป็นของเรา
func _end_day() -> void:
	day += 1
	var tax := 0
	for t in player.towns:
		tax += GameData.TOWNS[t].tax
	if tax > 0:
		player.gold += tax
		await dialogs.message("Day %d begins. Your towns paid %d Gold in taxes." % [day, tax])


func _fight(monster_id: String) -> String:
	var battle := Battle.new()
	add_child(battle)
	var result: String = await battle.start(player, monster_id)
	battle.queue_free()
	if result == "lose":
		await _defeated()
	hud.refresh(player, day)
	return result


## แพ้: กลับปราสาท เสียเงิน 30% HP เหลือครึ่ง
func _defeated() -> void:
	var lost := roundi(player.gold * 0.3)
	player.gold -= lost
	player.hp = maxi(1, int(player.max_hp() / 2.0))
	current = CASTLE_TILE
	came_from = NO_TILE
	witch.position = _tile_pos(current)
	witch.facing = Witch.Dir.DOWN
	await dialogs.message("You wake up at the castle... (lost %d Gold)" % lost)


func _visit_castle() -> void:
	while true:
		var pick := await dialogs.choose("Welcome home to the castle.", ["Rest (full HP)", "Change Job", "Leave"])
		match pick:
			0:
				player.hp = player.max_hp()
				hud.refresh(player, day)
				await dialogs.message("You rest well. HP fully restored!")
			1:
				var jobs: Array = GameData.JOBS.keys()
				var labels: Array = []
				for j in jobs:
					labels.append("%s - %s%s" % [j, GameData.JOBS[j].desc, "  (current)" if j == player.job else ""])
				labels.append("Back")
				var j_pick := await dialogs.choose("Choose a job. (Level is kept)", labels)
				if j_pick < jobs.size() and jobs[j_pick] != player.job:
					player.change_job(jobs[j_pick])
					hud.refresh(player, day)
					await dialogs.message("You are now a %s!" % player.job)
			_:
				return


func _visit_town(cell: Vector2i) -> void:
	var town: Dictionary = GameData.TOWNS[cell]
	if player.towns.has(cell):
		var healed := player.heal(roundi(player.max_hp() * 0.3))
		await dialogs.message("The people of %s cheer for you! (+%d HP)" % [town.name, healed])
		return
	var pick := await dialogs.choose("%s is ruled by the %s!\nFight to free the town?" % [town.name, town.guard], ["Fight!", "Not now"])
	if pick != 0:
		return
	var result := await _fight(town.guard)
	if result == "win":
		player.towns.append(cell)
		if town_guards.has(cell):
			town_guards[cell].queue_free()
			town_guards.erase(cell)
		hud.refresh(player, day)
		await dialogs.message("%s is free! It will pay you %d Gold every day." % [town.name, town.tax])
		if player.towns.size() == GameData.TOWNS.size():
			await dialogs.message("All towns are free! You saved the kingdom in %d days!" % day)


## ร้านไอเทม (ช่อง Shop) ขายของใช้ / อาวุธต้องไปซื้อที่ร้าน Smithy
func _visit_shop() -> void:
	while true:
		var labels: Array = []
		for it in GameData.ITEM_SHOP_STOCK:
			labels.append("%s  %dG  - %s" % [it, GameData.ITEMS[it].price, GameData.ITEMS[it].desc])
		labels.append("Leave")
		var pick := await dialogs.choose("Item Shop - You have %d Gold.\n(Weapons & armor are sold at the Smithy by the castle.)" % player.gold, labels)
		if pick >= GameData.ITEM_SHOP_STOCK.size():
			return
		var item: String = GameData.ITEM_SHOP_STOCK[pick]
		var price: int = GameData.ITEMS[item].price
		if player.gold < price:
			await dialogs.message("Not enough Gold!")
			continue
		if not player.add_item(item):
			await dialogs.message("Your bag is full!")
			continue
		player.gold -= price
		hud.refresh(player, day)


# ================================================================ ร้านอาวุธ (Smithy)
func _visit_smithy() -> void:
	var text := "Smithy \"Iron & Ember\"\n\"Welcome, traveler! Gold for steel - fair and square.\""
	while true:
		var pick := await dialogs.choose("%s\nYou have %d Gold." % [text, player.gold], ["Buy", "Sell", "Equip", "Leave"])
		match pick:
			0:
				await _smithy_buy()
			1:
				await _smithy_sell()
			2:
				await equip_window.open(player)
				hud.refresh(player, day)
			_:
				return
		text = "Smithy \"Iron & Ember\"\n\"Anything else?\""


func _smithy_buy() -> void:
	var cats: Array = GameData.SMITHY_STOCK.keys()
	while true:
		var cat_labels: Array = []
		for c in cats:
			cat_labels.append(CATEGORY_NAMES[c])
		cat_labels.append("Back")
		var c_pick := await dialogs.choose("What are you looking for? (Gold %d)" % player.gold, cat_labels)
		if c_pick >= cats.size():
			return
		await _smithy_buy_list(cats[c_pick])


func _smithy_buy_list(cat: String) -> void:
	var stock: Array = GameData.SMITHY_STOCK[cat]
	while true:
		var labels: Array = []
		for it in stock:
			labels.append("%s  %dG   %s%s" % [it, GameData.ITEMS[it].price, GameData.stat_text(it), "   (owned)" if player.owns(it) else ""])
		labels.append("Back")
		var pick := await dialogs.choose("%s - Gold %d   Gear bag %d/%d" % [CATEGORY_NAMES[cat], player.gold, player.gear.size(), GameData.MAX_GEAR], labels)
		if pick >= stock.size():
			return
		var item: String = stock[pick]
		var price: int = GameData.ITEMS[item].price
		if player.gold < price:
			await dialogs.message("Not enough Gold! (%s costs %dG, you have %dG)" % [item, price, player.gold])
			continue
		if player.gear.size() >= GameData.MAX_GEAR:
			await dialogs.message("Your gear bag is full! Sell something first.")
			continue
		var confirm := await dialogs.choose("Buy %s for %dG?\n%s\nIf equipped: %s" % [item, price, GameData.ITEMS[item].desc, _compare_text(item)], ["Buy", "Cancel"])
		if confirm != 0:
			continue
		player.gold -= price
		player.add_gear(item)
		hud.refresh(player, day)
		var eq := await dialogs.choose("You bought %s! Equip it now?" % item, ["Equip now", "Keep in gear bag"])
		if eq == 0:
			var old := player.equip(item)
			hud.refresh(player, day)
			await dialogs.message("Equipped %s.%s" % [item, " (%s went to your gear bag)" % old if old != "" else ""])


func _smithy_sell() -> void:
	while true:
		if player.gear.is_empty():
			await dialogs.message("You have no spare gear to sell.\n(Unequip something in the Equip window first.)")
			return
		var labels: Array = []
		for it in player.gear:
			labels.append("%s  -> %dG   %s" % [it, GameData.sell_price(it), GameData.stat_text(it)])
		labels.append("Back")
		var pick := await dialogs.choose("Sell which gear? (I pay half price)  Gold %d" % player.gold, labels)
		if pick >= player.gear.size():
			return
		var item: String = player.gear[pick]
		var value := GameData.sell_price(item)
		var confirm := await dialogs.choose("Sell %s for %dG?" % [item, value], ["Sell", "Cancel"])
		if confirm != 0:
			continue
		player.gear.remove_at(pick)
		player.gold += value
		hud.refresh(player, day)


## เทียบค่าพลังถ้าสวม item เช่น "ATK 6->12, SPD 6->5"
func _compare_text(item: String) -> String:
	var parts := PackedStringArray()
	for k in GameData.STAT_KEYS:
		var cur := player.stat(k)
		var nv := player.preview_stat(k, item)
		if nv != cur:
			parts.append("%s %d→%d" % [str(k).to_upper(), cur, nv])
	return ", ".join(parts) if not parts.is_empty() else "no stat change"


## หน้าต่างสวมใส่อุปกรณ์ (ปุ่ม Equip)
func _open_equip() -> void:
	if _busy or dialogs.is_open() or equip_window.is_open():
		return
	_busy = true
	roll_button.disabled = true
	await equip_window.open(player)
	hud.refresh(player, day)
	_busy = false
	roll_button.disabled = false


## ใช้ไอเทมนอกการต่อสู้
func _open_bag() -> void:
	if _busy or dialogs.is_open() or equip_window.is_open():
		return
	_busy = true
	roll_button.disabled = true
	while true:
		var labels: Array = []
		for it in player.items:
			labels.append("%s - %s" % [it, GameData.ITEMS[it].desc])
		labels.append("Close")
		var pick := await dialogs.choose("Bag (%d/%d)" % [player.items.size(), GameData.MAX_ITEMS], labels)
		if pick >= player.items.size():
			break
		var item: String = player.items[pick]
		var heal: int = GameData.ITEMS[item].get("heal", 0)
		if heal > 0:
			player.items.remove_at(pick)
			var healed := player.heal(heal)
			hud.refresh(player, day)
			await dialogs.message("Used %s. Recovered %d HP." % [item, healed])
		else:
			await dialogs.message("%s can only be used in battle." % item)
	_busy = false
	roll_button.disabled = false


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
		s.position = _tile_pos(cell) + Vector3(0, height / 2.0, -0.15)
		add_child(s)
		town_guards[cell] = s


# ================================================================ ปราสาท
func _build_castle() -> void:
	var castle := Sprite3D.new()
	castle.texture = load("res://castle_sheet.png")
	castle.hframes = 4
	castle.frame = 0
	var height := 3.4
	castle.pixel_size = height / castle.texture.get_height()
	castle.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	castle.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	castle.shaded = true
	castle.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	var base := _tile_pos(CASTLE_TILE)
	castle.position = Vector3(base.x, height / 2.0, base.z - 1.3)
	add_child(castle)

	# คบเพลิงหน้าประตูปราสาท (แสงกะพริบ)
	for side in [-1, 1]:
		var torch := OmniLight3D.new()
		torch.light_color = Color(1.0, 0.6, 0.3)
		torch.light_energy = 1.6
		torch.omni_range = 2.5
		torch.position = Vector3(base.x + side * 0.55, 0.8, base.z - 0.6)
		add_child(torch)
		_torches.append(torch)


# ================================================================ กล้อง/แสง
func _build_environment() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.1, 0.09, 0.11)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.5, 0.55, 0.7)
	env.ambient_light_energy = 0.45
	env.tonemap_mode = Environment.TONE_MAPPER_AGX # สีนุ่มแบบภาพยนตร์ ไฮไลต์ไม่แตก
	env.tonemap_exposure = 1.15
	env.glow_enabled = true # ไฟตะเกียง/หน้าต่างเรืองแสง ฟุ้งเป็นวง
	env.glow_intensity = 0.7
	env.glow_strength = 1.0
	env.glow_bloom = 0.03 # ฟุ้งทั้งภาพนิดเดียว ส่วนใหญ่ฟุ้งเฉพาะไฟที่สว่างจัด
	env.glow_hdr_threshold = 1.1
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SCREEN
	var glow_levels := [0.0, 0.6, 0.8, 0.7, 0.5, 0.0, 0.0]
	for i in glow_levels.size():
		env.set_glow_level(i, glow_levels[i])
	env.ssao_enabled = true # เงาตามซอกมุม
	env.ssao_intensity = 2.2
	env.ssil_enabled = true # แสงสะท้อนสีจากพื้นผิวข้าง ๆ
	env.fog_enabled = true
	env.fog_light_color = Color(0.55, 0.45, 0.36)
	env.fog_density = 0.01
	# หมอกปริมาตร: ทำให้เห็นลำแสงแดดลอดเงา และไฟตะเกียงเป็นวงฟุ้ง
	env.volumetric_fog_enabled = true
	env.volumetric_fog_density = 0.022
	env.volumetric_fog_albedo = Color(0.95, 0.9, 0.82)
	env.volumetric_fog_anisotropy = 0.6
	env.volumetric_fog_length = 40.0
	env.volumetric_fog_ambient_inject = 0.15
	env.adjustment_enabled = true
	env.adjustment_saturation = 1.1
	env.adjustment_contrast = 1.08
	var world_env := WorldEnvironment.new()
	world_env.environment = env
	add_child(world_env)

	# แสงแดดยามเย็น สีอุ่น เงานุ่ม
	var sun := DirectionalLight3D.new()
	sun.light_color = Color(1.0, 0.8, 0.58)
	sun.light_energy = 1.25
	sun.light_angular_distance = 1.2 # เงาขอบนุ่ม (ยิ่งไกลวัตถุยิ่งเบลอ)
	sun.light_volumetric_fog_energy = 1.6
	sun.shadow_enabled = true
	sun.shadow_blur = 1.5
	sun.directional_shadow_max_distance = 30.0
	sun.rotation_degrees = Vector3(-40, -35, 0)
	add_child(sun)

	# กล้องเอียงมองลง + เลนส์แคบ = ดูเหมือนโมเดลจิ๋ว (ตามตัวละครใน _process)
	camera = Camera3D.new()
	camera.fov = 30.0
	# Tilt-shift: โฟกัสคมแค่แถบกลางรอบตัวละคร ฉากหน้า/หลังเบลอแรง
	var focus := CAMERA_OFFSET.length()
	var attrs := CameraAttributesPractical.new()
	attrs.dof_blur_far_enabled = true # ฉากหลังเบลอ
	attrs.dof_blur_far_distance = focus + 0.8
	attrs.dof_blur_far_transition = 2.5
	attrs.dof_blur_near_enabled = true # ฉากหน้าเบลอ
	attrs.dof_blur_near_distance = focus - 1.2
	attrs.dof_blur_near_transition = 1.4
	attrs.dof_blur_amount = 0.24
	camera.attributes = attrs
	add_child(camera)
	camera.look_at_from_position(CAMERA_OFFSET, Vector3(0, 0, 0.2))
	camera.current = true


## ฝุ่น/ละอองแสงลอยอ้อยอิ่งทั่วกระดาน (เรืองแสงจับ Glow)
func _build_motes() -> void:
	var p := GPUParticles3D.new()
	p.amount = 160
	p.lifetime = 9.0
	p.preprocess = 9.0 # มีละอองตั้งแต่เปิดเกม
	p.visibility_aabb = AABB(Vector3(-12, -2, -10), Vector3(24, 8, 22))
	p.position = Vector3(0, 1.3, 0.8)
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(9, 1.4, 7)
	pm.direction = Vector3(0.3, 1, 0)
	pm.spread = 60.0
	pm.initial_velocity_min = 0.03
	pm.initial_velocity_max = 0.12
	pm.gravity = Vector3(0, 0.015, 0)
	pm.turbulence_enabled = true # ลอยวนไปมา
	pm.turbulence_noise_strength = 0.6
	pm.turbulence_noise_scale = 3.0
	pm.scale_min = 0.5
	pm.scale_max = 1.3
	var ramp := Gradient.new() # ค่อย ๆ สว่างขึ้นแล้วจางหาย
	ramp.set_color(0, Color(1, 0.85, 0.55, 0))
	ramp.set_color(1, Color(1, 0.85, 0.55, 0))
	ramp.add_point(0.25, Color(1, 0.88, 0.6, 1))
	ramp.add_point(0.75, Color(1, 0.8, 0.5, 0.8))
	var ramp_tex := GradientTexture1D.new()
	ramp_tex.gradient = ramp
	pm.color_ramp = ramp_tex
	p.process_material = pm
	var quad := QuadMesh.new()
	quad.size = Vector2(0.07, 0.07)
	var dot := GradientTexture2D.new() # จุดกลมขอบนุ่ม
	dot.width = 32
	dot.height = 32
	dot.fill = GradientTexture2D.FILL_RADIAL
	dot.fill_from = Vector2(0.5, 0.5)
	dot.fill_to = Vector2(0.5, 0.0)
	dot.gradient = Gradient.new()
	dot.gradient.set_color(0, Color(1, 1, 1, 1))
	dot.gradient.set_color(1, Color(1, 1, 1, 0))
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.vertex_color_use_as_albedo = true
	m.albedo_texture = dot
	m.albedo_color = Color(1.6, 1.3, 0.9) # เกิน 1 = เรืองแสงผ่าน Glow
	quad.material = m
	p.draw_pass_1 = quad
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(p)


## Post-process ทับภาพ 3D (อยู่ใต้ UI): ไล่สีอุ่น/เย็น + ขอบภาพมืด + เกรนฟิล์มบาง ๆ
func _build_post_fx() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 0 # UI หลักอยู่ layer 1 ขึ้นไป จึงไม่โดนเอฟเฟกต์
	add_child(layer)
	var rect := ColorRect.new()
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sh := Shader.new()
	sh.code = POST_FX_SHADER
	var mat := ShaderMaterial.new()
	mat.shader = sh
	rect.material = mat
	layer.add_child(rect)


const POST_FX_SHADER := """
shader_type canvas_item;
uniform sampler2D screen_tex : hint_screen_texture, filter_linear;
uniform vec3 shadow_tint = vec3(0.9, 0.95, 1.1);   // เงาอมฟ้า
uniform vec3 light_tint = vec3(1.07, 1.0, 0.88);   // ส่วนสว่างอมส้ม
uniform float vignette = 0.55;
uniform float grain = 0.018;

float hash(vec2 p) { return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453); }

void fragment() {
	vec3 c = texture(screen_tex, SCREEN_UV).rgb;
	float l = dot(c, vec3(0.299, 0.587, 0.114));
	c *= mix(shadow_tint, light_tint, smoothstep(0.15, 0.75, l));
	vec2 d = SCREEN_UV - 0.5;
	d.y *= 1.25; // มืดบน-ล่างมากกว่าซ้าย-ขวานิดนึง
	c *= 1.0 - vignette * smoothstep(0.3, 0.85, length(d));
	c += (hash(SCREEN_UV * 731.0 + fract(TIME) * 37.0) - 0.5) * grain;
	COLOR = vec4(c, 1.0);
}
"""


func _build_ground() -> void:
	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(60, 60)
	ground.mesh = plane
	ground.material_override = _mat("grass")
	add_child(ground)


# ================================================================ ของตกแต่ง
func _build_props() -> void:
	var blocked: Array[Vector2] = [] # จุดที่มีของแล้ว (พิกัดกริด) กันพุ่มไม้ทับ

	# บ่อน้ำในวงซ้าย
	_well(_grid_to_world(Vector2(1.5, 2)))
	blocked.append(Vector2(1.5, 2))

	# ต้นไม้ + ถังไม้ในวงขวา
	_tree(_grid_to_world(Vector2(4.6, 1.8)))
	blocked.append(Vector2(4.6, 1.8))
	for g in [Vector2(5.3, 2.8), Vector2(5.0, 3.1)]:
		add_child(_cylinder(0.25, 0.55, _grid_to_world(g) + Vector3(0, 0.275, 0), _mat("wood")))
		blocked.append(g)

	# บ้านสองข้างทางขึ้นปราสาท
	_house(_grid_to_world(Vector2(0.2, -1.7)), 2.4, "WEAPONS & ARMOR") # ร้านอาวุธ (ช่อง Smithy อยู่หน้าบ้าน)
	_house(_grid_to_world(Vector2(5.8, -1.8)), 2.2)
	for g in [Vector2(0.2, -1.7), Vector2(5.8, -1.8)]:
		for dx in [-1.0, 0.0, 1.0]:
			for dy in [-0.6, 0.0, 0.6]:
				blocked.append(g + Vector2(dx, dy))
	for g in [Vector2(1.6, -1.1), Vector2(1.6, -1.6)]: # ทั่ง + เตาหน้าร้านอาวุธ
		blocked.append(g)

	# ตะเกียงตามทางแยก
	var lanterns := [
		Vector2(2.4, -0.6), Vector2(3.6, -0.6), Vector2(-0.6, -0.6), Vector2(6.6, -0.6),
		Vector2(-0.6, 4.6), Vector2(6.6, 4.6), Vector2(2.4, 4.6), Vector2(3.6, 4.6),
		Vector2(-1.6, 1.4), Vector2(7.6, 2.6),
	]
	for g in lanterns:
		_lantern(_grid_to_world(g))
		blocked.append(g)

	# พุ่มไม้ดอกสุ่มรอบ ๆ (ไม่ทับช่องเดินและของอื่น)
	var placed := 0
	var tries := 0
	while placed < 40 and tries < 2000:
		tries += 1
		var g := Vector2(_rng.randf_range(-4.0, 10.0), _rng.randf_range(-3.0, 7.5))
		if _near_tile(g, 0.85) or _near_any(g, blocked, 0.9):
			continue
		if absf(g.x - 3.0) < 2.0 and g.y < -1.5:
			continue # เว้นหน้าปราสาท
		_bush(_grid_to_world(g))
		blocked.append(g)
		placed += 1


func _near_tile(g: Vector2, dist: float) -> bool:
	for cell in tiles:
		if g.distance_to(Vector2(cell)) < dist:
			return true
	return false


func _near_any(g: Vector2, points: Array[Vector2], dist: float) -> bool:
	for p in points:
		if g.distance_to(p) < dist:
			return true
	return false


func _well(pos: Vector3) -> void:
	add_child(_cylinder(0.5, 0.5, pos + Vector3(0, 0.25, 0), _mat("wall")))
	var water := _cylinder(0.39, 0.05, pos + Vector3(0, 0.49, 0), null)
	var water_mat := StandardMaterial3D.new()
	water_mat.albedo_color = Color(0.12, 0.25, 0.32)
	water_mat.roughness = 0.05
	water_mat.metallic = 0.3
	water.material_override = water_mat
	add_child(water)
	for side in [-1, 1]:
		add_child(_box(Vector3(0.08, 0.9, 0.08), pos + Vector3(side * 0.44, 0.9, 0), _mat("wood")))
	var roof := MeshInstance3D.new()
	var prism := PrismMesh.new()
	prism.size = Vector3(1.2, 0.35, 0.7)
	roof.mesh = prism
	roof.material_override = _mat("roof")
	roof.position = pos + Vector3(0, 1.5, 0)
	add_child(roof)


func _tree(pos: Vector3) -> void:
	add_child(_cylinder(0.14, 1.0, pos + Vector3(0, 0.5, 0), _mat("wood")))
	var leaf := StandardMaterial3D.new()
	leaf.albedo_color = Color(0.2, 0.34, 0.17)
	leaf.roughness = 0.9
	for spec in [[Vector3(0, 1.3, 0), 0.6], [Vector3(0.25, 1.7, 0.1), 0.45], [Vector3(-0.25, 1.6, -0.1), 0.45]]:
		var s := MeshInstance3D.new()
		var sphere := SphereMesh.new()
		sphere.radius = spec[1]
		sphere.height = spec[1] * 1.8
		s.mesh = sphere
		s.material_override = leaf
		s.position = pos + spec[0]
		add_child(s)


func _house(pos: Vector3, width: float, shop_name := "") -> void:
	var depth := 1.6
	var height := 1.8
	add_child(_box(Vector3(width, height, depth), pos + Vector3(0, height / 2.0, 0), _mat("wall")))
	var roof := MeshInstance3D.new()
	var prism := PrismMesh.new()
	prism.size = Vector3(width + 0.3, 1.1, depth + 0.3)
	roof.mesh = prism
	roof.material_override = _mat("roof")
	roof.position = pos + Vector3(0, height + 0.55, 0)
	add_child(roof)
	var front_z := pos.z + depth / 2.0 + 0.02
	add_child(_box(Vector3(0.5, 0.9, 0.05), Vector3(pos.x, 0.45, front_z), _mat("wood", Color(0.7, 0.7, 0.7))))
	for side in [-1, 1]:
		add_child(_box(Vector3(0.36, 0.36, 0.05), Vector3(pos.x + side * width * 0.3, 1.15, front_z), _glow_mat(Color(1.0, 0.7, 0.35), 2.5)))
	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.7, 0.4)
	light.light_energy = 1.2
	light.omni_range = 3.0
	light.position = Vector3(pos.x, 1.2, front_z + 0.5)
	add_child(light)
	if shop_name != "":
		_shop_sign(Vector3(pos.x, 1.56, front_z), shop_name)
		# ทั่งตีเหล็ก + เตาไฟหน้าร้าน
		var iron := StandardMaterial3D.new()
		iron.albedo_color = Color(0.22, 0.22, 0.25)
		iron.metallic = 0.7
		iron.roughness = 0.4
		var anvil_x := pos.x + width * 0.5 + 0.35
		add_child(_box(Vector3(0.22, 0.3, 0.22), Vector3(anvil_x, 0.15, front_z - 0.2), _mat("wood", Color(0.6, 0.6, 0.6))))
		add_child(_box(Vector3(0.42, 0.14, 0.2), Vector3(anvil_x, 0.37, front_z - 0.2), iron))
		add_child(_box(Vector3(0.36, 0.22, 0.3), Vector3(anvil_x, 0.11, front_z - 0.75), _glow_mat(Color(1.0, 0.45, 0.15), 3.0)))
		var forge := OmniLight3D.new()
		forge.light_color = Color(1.0, 0.5, 0.2)
		forge.light_energy = 1.5
		forge.omni_range = 2.2
		forge.position = Vector3(anvil_x, 0.5, front_z - 0.5)
		add_child(forge)
		_torches.append(forge) # ให้ไฟกะพริบเหมือนคบเพลิง


## ป้ายร้านติดผนังหน้าบ้าน
func _shop_sign(pos: Vector3, text: String) -> void:
	add_child(_box(Vector3(1.5, 0.34, 0.05), pos + Vector3(0, 0, 0.03), _mat("wood", Color(0.55, 0.42, 0.3))))
	var label := Label3D.new()
	label.text = text
	label.font_size = 26
	label.outline_size = 8
	label.pixel_size = 0.0042
	label.modulate = Color(1.0, 0.86, 0.5)
	label.outline_modulate = Color(0.15, 0.08, 0.03)
	label.position = pos + Vector3(0, 0, 0.065)
	add_child(label)


func _lantern(pos: Vector3) -> void:
	add_child(_box(Vector3(0.1, 1.5, 0.1), pos + Vector3(0, 0.75, 0), _mat("wood")))
	add_child(_box(Vector3(0.24, 0.28, 0.24), pos + Vector3(0, 1.6, 0), _glow_mat(Color(1.0, 0.72, 0.35), 3.0)))
	add_child(_box(Vector3(0.3, 0.06, 0.3), pos + Vector3(0, 1.77, 0), _mat("wood", Color(0.5, 0.5, 0.5))))
	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.72, 0.4)
	light.light_energy = 1.4
	light.omni_range = 3.0
	light.position = pos + Vector3(0, 1.55, 0)
	add_child(light)


func _bush(pos: Vector3) -> void:
	var leaf := StandardMaterial3D.new()
	leaf.albedo_color = Color(0.22, 0.36, 0.18).lerp(Color(0.3, 0.42, 0.2), _rng.randf())
	leaf.roughness = 0.9
	var size := _rng.randf_range(0.3, 0.5)
	var bush := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = size
	sphere.height = size * 1.4
	bush.mesh = sphere
	bush.material_override = leaf
	bush.position = pos + Vector3(0, size * 0.55, 0)
	add_child(bush)
	if _rng.randf() < 0.3:
		return # บางพุ่มไม่มีดอก
	var petal := StandardMaterial3D.new()
	petal.albedo_color = [Color(0.95, 0.65, 0.72), Color(0.98, 0.92, 0.7), Color(0.85, 0.6, 0.9)][_rng.randi() % 3]
	for i in 6:
		var flower := MeshInstance3D.new()
		var f := SphereMesh.new()
		f.radius = 0.06
		f.height = 0.12
		flower.mesh = f
		flower.material_override = petal
		var a := _rng.randf() * TAU
		flower.position = bush.position + Vector3(cos(a) * size * 0.75, _rng.randf_range(0.0, size * 0.5), sin(a) * size * 0.75)
		add_child(flower)


# ================================================================ UI (2D ซ้อนบนจอ)
func _build_ui() -> void:
	var ui := CanvasLayer.new()
	add_child(ui)

	dice_label = _label(Vector2(24, 20), 28, "Press Space or click Roll")
	ui.add_child(dice_label)
	steps_label = _label(Vector2(24, 130), 22, "")
	ui.add_child(steps_label)

	roll_button = Button.new()
	roll_button.text = "Roll Dice"
	roll_button.position = Vector2(24, 70)
	roll_button.custom_minimum_size = Vector2(160, 50)
	roll_button.add_theme_font_size_override("font_size", 24)
	roll_button.focus_mode = Control.FOCUS_NONE # กัน Space กดปุ่มซ้ำ
	roll_button.pressed.connect(roll_dice)
	ui.add_child(roll_button)

	bag_button = Button.new()
	bag_button.text = "Bag"
	bag_button.position = Vector2(194, 70)
	bag_button.custom_minimum_size = Vector2(100, 50)
	bag_button.add_theme_font_size_override("font_size", 24)
	bag_button.focus_mode = Control.FOCUS_NONE
	bag_button.pressed.connect(_open_bag)
	ui.add_child(bag_button)

	equip_button = Button.new()
	equip_button.text = "Equip"
	equip_button.position = Vector2(304, 70)
	equip_button.custom_minimum_size = Vector2(110, 50)
	equip_button.add_theme_font_size_override("font_size", 24)
	equip_button.focus_mode = Control.FOCUS_NONE
	equip_button.pressed.connect(_open_equip)
	ui.add_child(equip_button)

	hud = Hud.new()
	add_child(hud)
	dialogs = Dialogs.new()
	add_child(dialogs)
	equip_window = EquipWindow.new()
	add_child(equip_window)

	var screen := get_viewport().get_visible_rect().size

	# ปุ่มเลือกทิศ (โชว์เฉพาะตอนถึงทางแยก)
	var pad_center := Vector2(110, screen.y - 110)
	var specs := {UP: ["Up", Vector2(0, -1)], DOWN: ["Down", Vector2(0, 1)], LEFT: ["Left", Vector2(-1, 0)], RIGHT: ["Right", Vector2(1, 0)]}
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
		dir_buttons[d] = b

	# ลูกเต๋า 2 ลูก มุมขวาล่างของจอ
	for i in 2:
		var die := Dice.new()
		die.position = Vector2(screen.x - 170 + i * 100, screen.y - 80)
		die.roll_duration = 0.8 + i * 0.25 # ลูกที่ 2 หยุดทีหลังนิดนึง
		die.rolled.connect(_on_die_rolled)
		ui.add_child(die)
		dice.append(die)


func _label(pos: Vector2, font_size: int, text: String) -> Label:
	var l := Label.new()
	l.position = pos
	l.text = text
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	l.add_theme_constant_override("outline_size", 8)
	return l


# ================================================================ ตัวช่วยสร้างวัตถุ
func _mat(texture_name: String, tint := Color.WHITE) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_texture = load("res://textures/%s.png" % texture_name)
	m.albedo_color = tint
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS # พิกเซลคม
	m.uv1_triplanar = true # แปะเท็กซ์เจอร์ 1 รูปต่อ 1 หน่วย ทุกด้านของกล่อง
	m.roughness = 0.9
	return m


func _glow_mat(color: Color, energy: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.emission_enabled = true
	m.emission = color
	m.emission_energy_multiplier = energy
	return m


func _box(size: Vector3, pos: Vector3, material: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = size
	mi.mesh = b
	mi.material_override = material
	mi.position = pos
	return mi


func _cylinder(radius: float, height: float, pos: Vector3, material: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var c := CylinderMesh.new()
	c.top_radius = radius
	c.bottom_radius = radius
	c.height = height
	mi.mesh = c
	mi.material_override = material
	mi.position = pos
	return mi

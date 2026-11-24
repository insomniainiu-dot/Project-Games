extends SceneTree
## เปิดหน้าจอ Equip / HUD / ต่อสู้ ด้วยอุปกรณ์ทุก tier แล้วถ่าย screenshot (ต้องรันแบบมีหน้าต่าง ไม่ใช่ --headless)
##   Godot --path . --script res://tools/ui_smoke.gd -- <โฟลเดอร์เก็บรูป>
## จับ runtime error ของโค้ด UI + ดูว่าข้อความล้น/โดนตัดไหม

var _out := "user://ui_smoke"


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		_out = args[0]
	DirAccess.make_dir_recursive_absolute(_out)
	_run()


func _shot(name: String) -> void:
	for i in 4:
		await process_frame
	var img := root.get_texture().get_image()
	img.save_png(_out.path_join(name + ".png"))
	print("shot: ", name)


## พิมพ์ Control ที่ล้นจอ (ขอบเกิน w x h) — ใช้หาตัวที่ดัน layout
func _report_wide(node: Node, w: float, h: float, depth := 0) -> void:
	for c in node.get_children():
		if c is Control:
			var r: Rect2 = (c as Control).get_global_rect()
			if r.end.x > w + 1 or r.end.y > h + 1 or r.position.y < -1:
				print("  overflow %s %s rect=%s min=%s %s" % ["  ".repeat(depth), c.get_class(), r, (c as Control).get_combined_minimum_size(),
					str(c.text).left(50) if "text" in c else ""])
		_report_wide(c, w, h, depth + 1)


func _player() -> PlayerStats:
	var p := PlayerStats.new()
	p.change_job("Vanguard")
	p.gain_exp(400)
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	var epic := ItemDB.create("Gravity Hammer", "epic", rng)
	var rare_armor := ItemDB.create("Mesh Armor", "rare", rng)
	var epic_acc := ItemDB.create("Lucky Chip", "epic", rng)
	for it in [epic, rare_armor, epic_acc]:
		p.add_gear(it)
		p.equip(it)
	for it in ["Siphon Edge", "Singularity Rod", ItemDB.create("Plasma Blade", "rare", rng), "Pulse Rifle"]:
		p.add_gear(it)
	p.add_gem("fireball")
	p.add_gem("deploy_drone")
	p.hp = p.max_hp()
	return p


func _run() -> void:
	await process_frame
	var p := _player()

	# ---- HUD
	var hud := Hud.new()
	root.add_child(hud)
	hud.refresh(p, 3)
	await _shot("01_hud")
	_report_wide(hud, 1152.0, 648.0)
	hud.queue_free()

	# ---- Equip window: หน้าแรก + hover ทุกชิ้น + gem
	var ew := EquipWindow.new()
	root.add_child(ew)
	ew.player = p
	ew.visible = true
	ew._refresh()
	await _shot("02_equip")
	_report_wide(ew, 1152.0, 648.0)
	for i in p.gear.size():
		ew._preview_equip(p.gear[i])
	ew._preview_equip(p.gear[0])
	await _shot("03_equip_hover_unique")
	ew._preview_remove("weapon")
	await _shot("04_equip_hover_equipped_epic")
	ew._preview_gem("fireball")
	ew._equip_gem("fireball")
	ew._remove_gem(0)
	ew._equip_gem("fireball")
	ew._equip(p.gear[0])
	await _shot("05_equip_after_swaps")
	ew.queue_free()

	# ---- ต่อสู้: ถือ Singularity Rod (ท่าติดอาวุธ) → ปุ่ม 4 ท่า
	p.equip("Singularity Rod")
	var ui := CCBattleUI.new()
	root.add_child(ui)
	ui.portraits = CCBridge.portraits("Bone Lord")
	ui.state = CCBattle.create_battle(CCBridge.config(p, "Bone Lord", 5))
	ui._shown_hp = [ui.state.units[0].hp, ui.state.units[1].hp]
	ui._build()
	ui._refresh()
	await _shot("06_battle_act")
	_report_wide(ui, 1152.0, 648.0)
	# เดินการต่อสู้ด้วย AI แล้ว render ทุก phase + ข้อความ log ทุก event
	var n := 0
	var defend_shot := false
	while ui.state.result == "" and n < 60:
		if CCBattle.phase(ui.state) == "defend" and not defend_shot:
			ui._refresh()
			await _shot("07_battle_defend")
			defend_shot = true
		var r := CCBattle.apply_action(ui.state, CCAi.choose(ui.state))
		ui.state = r.state
		ui._refresh()
		n += 1
	for e in ui.state.log:
		ui._append_log(e)
	ui._refresh()
	await _shot("08_battle_end")
	print("battle: %d actions, result %s" % [n, ui.state.result])
	ui.queue_free()

	# ---- ร้าน Smithy: ซื้อ gem + ขายของ Rare/Epic (กดปุ่มแทนผู้เล่น)
	var state := GameState.new()
	var dialogs := Dialogs.new()
	root.add_child(dialogs)
	var ew2 := EquipWindow.new()
	root.add_child(ew2)
	var shops := Shops.new()
	root.add_child(shops)
	shops.setup(state, dialogs, ew2)
	p.gold = 1000
	shops.visit_smithy(p) # ไม่ await: ขับด้วยการกดปุ่มด้านล่าง
	await _press(dialogs, "Buy")
	await _press(dialogs, "Skill Gems", "09_smithy_categories")
	await _press(dialogs, "Twin Shiv", "10_smithy_gem_list")
	await _press(dialogs, "Buy", "11_smithy_gem_confirm")
	await _press(dialogs, "OK", "12_smithy_gem_bought")
	await _press(dialogs, "Back")
	await _press(dialogs, "Back")
	await _press(dialogs, "Sell")
	await _press(dialogs, "Back", "13_smithy_sell_list")
	await _press(dialogs, "Leave")
	print("smithy: gold %d, gems %s, bag %s" % [p.gold, p.gems, p.gem_bag])

	# ---- ชนะผู้คุมเมือง: ดรอป Rare/Epic + Unique แน่นอน
	var te := TileEvents.new()
	te.set_process(false)
	te._state = state
	te._dialogs = dialogs
	root.add_child(te)
	var before := p.gear.size()
	te._victory(p, GameData.MONSTERS["Goblin Chief"])
	await _press(dialogs, "OK", "14_victory")
	await _press(dialogs, "Keep", "15_drop_gear")
	await _press(dialogs, "Equip", "16_drop_unique")
	for i in 4:
		await process_frame
	print("drops: gear %d -> %d, weapon %s" % [before, p.gear.size(), p.weapon])

	# ---- อีเวนต์บนกระดาน: ตัวเลือก D-F + ผล + ถอย (ใช้ตัวละครจริงเล่นแอนิเมชัน)
	var witch := Witch.new()
	root.add_child(witch)
	te._piece = witch
	p.renown = 20
	p.scrip = 6
	for c in [Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0)]:
		p.remember_step(c)
	te.run_event(p, "stalled_crawler")
	await _press(dialogs, "D.", "17_event_options")
	await _press(dialogs, "OK", "18_event_result")
	te.run_event(p, "broken_span")
	await _press(dialogs, "B.")
	await _press(dialogs, "OK", "19_event_pushed_back")
	# อีเวนต์ต่อสู้: เลือกสู้กับ Rockhide Grazer → เข้าหน้าต่อสู้จริง (ถ่ายรูปแล้วกดหนี)
	te.run_event(p, "rockhide_grazer")
	await _press(dialogs, "A.", "21_event_boss_options")
	await _press(dialogs, "OK")
	for i in 30:
		await process_frame
	await _shot("22_event_boss_battle")
	var battle_ui: Node = te.get_children().filter(func(c): return c is CCBattleUI).front() if te.get_children().any(func(c): return c is CCBattleUI) else null
	print("boss battle open: %s" % (battle_ui != null))
	if battle_ui != null:
		battle_ui.queue_free() # ปิดหน้าต่อสู้ (test ไม่ได้เล่นจนจบ)
		for i in 10:
			await process_frame
	# ---- เมืองฝ่าย: ฝ่ายดีซื้อของร้าน Syndicate → ติดตรา → สวมแล้วเข้าเมือง Concord ไม่ได้
	te._shops = shops
	p.gold = 3000
	while p.gear.size() > 5:
		p.gear.remove_at(0)
	var towns: Array = GameData.TOWNS.values()
	var syn_town: Dictionary = towns.filter(func(t): return t.faction == "syndicate")[0]
	var con_town: Dictionary = towns.filter(func(t): return t.faction == "concord")[0]
	te._visit_free_town(p, syn_town)
	await _press(dialogs, "OK")
	await _press(dialogs, "Syndicate Market", "23_town_menu")
	await _press(dialogs, "◆", "24_syndicate_stock")
	await _press(dialogs, "Buy", "25_cross_buy_confirm")
	await _press(dialogs, "OK", "26_cross_bought")
	await _press(dialogs, "Leave")
	await _press(dialogs, "Leave")
	var marked: String = p.gear[p.gear.size() - 1]
	p.equip(marked)
	te._visit_free_town(p, con_town)
	await _press(dialogs, "OK", "27_barred_at_gate")
	await _press(dialogs, "Leave")
	print("marked %s mark=%s barred=%s" % [marked, GameData.item(marked).get("mark", ""), p.barred_from("concord")])
	# ---- Fabricator: ตีบวกอาวุธที่สวม
	te._visit_free_town(p, syn_town)
	await _press(dialogs, "OK")
	await _press(dialogs, "Syndicate Fabricator")
	while p.gear.size() < 7: # ให้รายการยาวเกิน 8 → ต้องเลือกกลุ่มก่อน
		p.add_gear("Kevlar Vest")
	await _press(dialogs, "Equipped", "28_fabricator_groups")
	await _press(dialogs, GameData.display_name(p.weapon), "28b_fabricator_list")
	await _press(dialogs, "Overclock", "29_overclock_confirm")
	await _press(dialogs, "OK", "30_overclock_result")
	await _press(dialogs, "Leave")
	await _press(dialogs, "Leave")
	print("overclock: weapon %s plus %d" % [GameData.display_name(p.weapon), ItemDB.plus_of(p.weapon)])
	var hud2 := Hud.new()
	root.add_child(hud2)
	hud2.refresh(p, 4)
	await _shot("20_hud_karma")
	print("event: karma %d renown %d scrip %d tile %s" % [p.karma, p.renown, p.scrip, p.tile])
	print("UI smoke done")
	quit()


## รอ dialog เปิด (ถ่ายรูปถ้าให้ชื่อ) แล้วกดปุ่มแรกที่ข้อความขึ้นต้นด้วย label
func _press(d: Dialogs, label: String, shot := "") -> void:
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 4000: # รอได้ถึง 4 วินาที (แอนิเมชันเดิน/ถอยก่อน dialog)
		await process_frame
		if d.is_open():
			break
	if shot != "":
		await _shot(shot)
	for b in d._buttons.get_children():
		if (b as Button).text.begins_with(label):
			(b as Button).pressed.emit()
			for i in 3:
				await process_frame
			return
	push_error("UI smoke: no button '%s' in dialog: %s" % [label, d._label.text.left(80)])

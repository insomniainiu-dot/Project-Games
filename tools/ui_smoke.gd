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
	var epic := ItemDB.create("War Axe", "epic", rng)
	var rare_armor := ItemDB.create("Chain Mail", "rare", rng)
	var epic_acc := ItemDB.create("Lucky Charm", "epic", rng)
	for it in [epic, rare_armor, epic_acc]:
		p.add_gear(it)
		p.equip(it)
	for it in ["Siphon Edge", "Singularity Rod", ItemDB.create("Iron Blade", "rare", rng), "Hunter Bow"]:
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
	print("UI smoke done: %d actions, result %s" % [n, ui.state.result])
	quit()

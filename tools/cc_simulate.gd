extends SceneTree
## Simulation ระบบต่อสู้ช่องเช็ค: ฮีโร่ (AI) ทุกอาชีพ × เลเวล × มอนสเตอร์
##   Godot --headless --path . --script res://tools/cc_simulate.gd              # 300 ครั้งต่อช่อง (รวม 10,800)
##   Godot --headless --path . --script res://tools/cc_simulate.gd -- 1000 7    # ครั้งต่อช่อง / seed
## ฮีโร่ใช้อุปกรณ์เริ่มต้น + Herb 2 ลูก (เหมือนเริ่มเกม) เริ่มด้วย HP เต็ม

const LEVELS := [1, 3, 5]


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var per := int(args[0]) if args.size() > 0 else 300
	var rng := RandomNumberGenerator.new()
	rng.seed = int(args[1]) if args.size() > 1 else 1
	var t0 := Time.get_ticks_msec()
	var monsters: Array = GameData.MONSTERS.keys()
	print("\nCheck combat simulation - %d battles per cell, %d total" % [per, per * 3 * LEVELS.size() * monsters.size()])
	print("cell = win%% / HP left on win / avg rounds   (run = draw or 40-round cap)\n")
	var header := "%-14s" % "Job  Lv"
	for m in monsters:
		header += "%-26s" % m
	print(header)
	var skill_use := {}
	var perfects := 0
	var checks := 0
	for job in CCBalance.JOB_SKILL:
		for lv in LEVELS:
			var line := "%-14s" % ("%s %d" % [job, lv])
			for m in monsters:
				var wins := 0
				var hp_left := 0.0
				var rounds := 0
				for i in per:
					var p := _hero(job, lv)
					var s := CCBattle.create_battle(CCBridge.config(p, m, rng.randi()))
					while s.result == "":
						s = CCBattle.apply_action(s, CCAi.choose(s)).state
					rounds += s.round
					if s.result == "win":
						wins += 1
						hp_left += float(s.units[0].hp) / s.units[0].max_hp
					for e in s.log:
						if e.t == "check" and e.unit == 0:
							skill_use[e.skill] = skill_use.get(e.skill, 0) + 1
							checks += 1
							if e.perfect:
								perfects += 1
				line += "%-26s" % ("%3d%% / %3d%% / %.1f" % [roundi(100.0 * wins / per), roundi(100.0 * hp_left / maxi(1, wins)), float(rounds) / per])
			print(line)
	print("\nHero skill use: %s" % str(skill_use))
	print("Perfect checks (all slots passed): %d%% of hero checks" % roundi(100.0 * perfects / maxi(1, checks)))
	print("(%.1fs)" % ((Time.get_ticks_msec() - t0) / 1000.0))
	quit()


func _hero(job: String, lv: int) -> PlayerStats:
	var p := PlayerStats.new()
	p.change_job(job)
	if lv > 1:
		p.gain_exp(_exp_to(lv))
	p.hp = p.max_hp()
	return p


func _exp_to(lv: int) -> int:
	var total := 0
	for l in range(1, lv):
		total += GameData.EXP_TO_LEVEL * l
	return total

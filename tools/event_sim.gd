extends SceneTree
## Simulation การต่อสู้จากอีเวนต์ (EventData): อัตราชนะต่ออาชีพ × เลเวล
##   Godot --headless --path . --script res://tools/event_sim.gd -- 200
## ฮีโร่ใช้ของเริ่มต้น เริ่มด้วย HP เต็ม · ใช้ตัวเลือก/สเปกการต่อสู้จริงจาก EventData

const LEVELS := [1, 3, 5, 8]
const CASES := [
	["raider_checkpoint", "C", "Raiders (wild)"],
	["snared_stalker", "C", "Stalker (weak)"],
	["rockhide_grazer", "A", "Grazer (boss)"],
	["rockhide_grazer", "C", "Grazer+poacher"],
]


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var per := int(args[0]) if args.size() > 0 else 200
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	print("\nEvent fight simulation - %d battles per cell   (cell = win%% / avg rounds)\n" % per)
	var header := "%-16s" % "Job  Lv"
	for c in CASES:
		header += "%-18s" % c[2]
	print(header)
	for job in GameData.JOBS:
		for lv in LEVELS:
			var line := "%-16s" % ("%s %d" % [job, lv])
			for c in CASES:
				var wins := 0
				var rounds := 0
				for i in per:
					var p := _hero(job, lv)
					var req: Dictionary = EventRunner.resolve(p, c[0], c[1], rng).fight
					var s := CCBattle.create_battle(CCBridge.config(p, req.monster, rng.randi(), req.opts))
					while s.result == "":
						s = CCBattle.apply_action(s, CCAi.choose(s)).state
					rounds += s.round
					if s.result == "win":
						wins += 1
				line += "%-18s" % ("%3d%% / %.1f" % [roundi(100.0 * wins / per), float(rounds) / per])
			print(line)
	quit()


func _hero(job: String, lv: int) -> PlayerStats:
	var p := PlayerStats.new()
	p.change_job(job)
	var total := 0
	for l in range(1, lv):
		total += GameData.EXP_TO_LEVEL * l
	p.gain_exp(total)
	p.hp = p.max_hp()
	return p

extends SceneTree
## ให้ AI สองตัวสู้กัน N แมตช์ แล้วรายงาน win rate ของแต่ละอาชีพ (ดูสมดุล)
##   Godot --headless --path . --script res://tools/dd_simulate.gd                  # 10,000 แมตช์ seed 1
##   Godot --headless --path . --script res://tools/dd_simulate.gd -- 2000 1234     # จำนวนแมตช์ / seed


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var total := int(args[0]) if args.size() > 0 else 10000
	var seed := int(args[1]) if args.size() > 1 else 1
	_run(total, seed)
	quit()


func _blank() -> Dictionary:
	return {"games": 0, "wins": 0, "losses": 0, "draws": 0}


func _add(r: Dictionary, res: String) -> void:
	r.games += 1
	match res:
		"w":
			r.wins += 1
		"l":
			r.losses += 1
		_:
			r.draws += 1


func _pct(x: float, of: float) -> String:
	return "%.1f%%" % (100.0 * x / of) if of > 0 else "-"


func _run(total: int, seed: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var jobs: Array = DDJobs.IDS
	var by_job := {}
	var by_job_nm := {}
	var matrix := {}
	for a in jobs:
		by_job[a] = _blank()
		by_job_nm[a] = _blank()
		matrix[a] = {}
		for b in jobs:
			matrix[a][b] = _blank()
	var by_pers := {}
	for p in DDAi.PERSONALITIES:
		by_pers[p] = _blank()
	var moves := {}
	var first_wins := 0
	var decided := 0
	var ko := 0
	var draws := 0
	var rounds := 0
	var swipes := 0
	var reflects := 0
	var hp_left := 0.0

	var t0 := Time.get_ticks_msec()
	for i in total:
		var pair := [jobs[rng.randi_range(0, jobs.size() - 1)], jobs[rng.randi_range(0, jobs.size() - 1)]]
		var pers := [DDAi.PERSONALITIES[rng.randi_range(0, 1)], DDAi.PERSONALITIES[rng.randi_range(0, 1)]]
		var s := DDMatch.run_ai_match({"seed": rng.randi(),
			"fighters": [DDBattle.create_character("P1", pair[0]), DDBattle.create_character("P2", pair[1])]}, pers, rng.randi())
		rounds += s.round
		var last: Dictionary = s.log[s.log.size() - 1]
		if last.t == "battle_end" and last.reason == "ko":
			ko += 1
		var first_attacker := -1
		for e in s.log:
			if e.t == "round_start":
				first_attacker = e.attacker
				break
		for p in 2:
			var res := "d" if s.winner == DDBattle.DRAW else ("w" if s.winner == p else "l")
			_add(by_job[pair[p]], res)
			if pair[0] != pair[1]:
				_add(by_job_nm[pair[p]], res)
			_add(matrix[pair[p]][pair[1 - p]], res)
			_add(by_pers[pers[p]], res)
		if s.winner == DDBattle.DRAW:
			draws += 1
		else:
			decided += 1
			if s.winner == first_attacker:
				first_wins += 1
			hp_left += float(s.fighters[s.winner].hp) / s.fighters[s.winner].max_hp
		for e in s.log:
			match e.t:
				"swipe":
					swipes += 1
				"resolved":
					var o: Dictionary = e.outcome
					for side in ["attack", "defense"]:
						var m: String = o[side].move
						if not moves.has(m):
							moves[m] = {"used": 0, "failed": 0, "damage": 0}
						moves[m].used += 1
						if not o[side].valid:
							moves[m].failed += 1
					moves[o.attack.move].damage += o.damage_to_defender
					if o.damage_to_attacker > 0:
						reflects += 1
		if (i + 1) % 1000 == 0:
			printerr("  %d / %d matches..." % [i + 1, total])
	var secs := (Time.get_ticks_msec() - t0) / 1000.0

	print("\nDice Duel simulation - %d matches, seed %d (%.1fs)\n" % [total, seed, secs])
	print("Win rate by job")
	print("%-10s %-7s %-8s %-8s %s" % ["Job", "Games", "Win", "Draw", "Win (no mirror)"])
	for j in jobs:
		var r: Dictionary = by_job[j]
		print("%-10s %-7d %-8s %-8s %s" % [DDJobs.NAMES[j], r.games, _pct(r.wins, r.games), _pct(r.draws, r.games), _pct(by_job_nm[j].wins, by_job_nm[j].games)])

	print("\nMatchup (row's win rate vs column)")
	var header := "%-10s" % ""
	for j in jobs:
		header += "%-10s" % DDJobs.NAMES[j]
	print(header)
	for a in jobs:
		var line := "%-10s" % DDJobs.NAMES[a]
		for b in jobs:
			line += "%-10s" % _pct(matrix[a][b].wins, matrix[a][b].games)
		print(line)

	print("\nPersonality")
	for p in DDAi.PERSONALITIES:
		print("  %-11s %s" % [p, _pct(by_pers[p].wins, by_pers[p].games)])

	print("\nOverview")
	print("  First attacker wins      %s (of decided games)" % _pct(first_wins, decided))
	print("  Ended by KO              %s" % _pct(ko, total))
	print("  Draws                    %s" % _pct(draws, total))
	print("  Average rounds           %.2f" % (float(rounds) / total))
	print("  Winner's HP left (avg)   %s" % _pct(hp_left, decided))
	print("  Swipes used              %d" % swipes)
	print("  Counter reflections      %d" % reflects)

	print("\nMove usage")
	print("  %-9s %-8s %-8s %s" % ["Move", "Used", "Failed", "Avg damage (attacks)"])
	var keys := moves.keys()
	keys.sort_custom(func(x, y): return moves[x].used > moves[y].used)
	for m in keys:
		var u: Dictionary = moves[m]
		var avg := "%.1f" % (float(u.damage) / u.used) if DDMoves.OFFENSE.has(m) else ""
		print("  %-9s %-8d %-8s %s" % [DDMoves.NAMES[m], u.used, _pct(u.failed, u.used), avg])

	var outliers := PackedStringArray()
	for j in jobs:
		var r: Dictionary = by_job_nm[j]
		var w := float(r.wins) / maxi(1, r.games)
		if w < 0.45 or w > 0.55:
			outliers.append(DDJobs.NAMES[j])
	if outliers.is_empty():
		print("\nOK: every job is within 45-55% win rate (excluding mirrors)")
	else:
		print("\nWARNING: jobs outside 45-55%% win rate (excluding mirrors): %s" % ", ".join(outliers))

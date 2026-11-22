class_name DDFormat
## แปลง event log เป็นข้อความ (ใช้ทั้ง UI, replay และ simulation)


static func dice_text(infos: Array) -> String:
	if infos.is_empty():
		return "(none)"
	var parts := PackedStringArray()
	for d in infos:
		parts.append(DDFaces.info_label(d))
	return " ".join(parts)


## dice = [build ของ P1, build ของ P2] ใช้แปลง face_index เป็นหน้าเต๋า
static func event_text(e: Dictionary, names: Array, dice: Array) -> String:
	match e.t:
		"battle_start":
			return "Battle: %s (%s) vs %s (%s)" % [names[0], DDJobs.NAMES.get(e.jobs[0], e.jobs[0]), names[1], DDJobs.NAMES.get(e.jobs[1], e.jobs[1])]
		"initiative":
			var s := "Initiative: %d+%s vs %d+%s" % [e.rolls[0], e.bonus[0], e.rolls[1], e.bonus[1]]
			return s + (" - tie, roll again" if e.attacker < 0 else " - %s attacks first" % names[e.attacker])
		"round_start":
			return "-- Round %d -- %s attacks (Focus %d / %d)" % [e.round, names[e.attacker], e.focus[0], e.focus[1]]
		"rolled":
			if e.dice.is_empty():
				return "%s rolled in secret" % names[e.player]
			var faces := PackedStringArray()
			for r in e.dice:
				faces.append(_face(dice, e.player, r.die_id, r.face_index))
			return "%s rolled %s" % [names[e.player], " ".join(faces)]
		"rerolled":
			var s := "%s rerolled a die%s" % [names[e.player], " (free)" if e.free else ""]
			if e.has("face_index"):
				s += " -> %s" % _face(dice, e.player, e.die_id, e.face_index)
			return s
		"shadow_read":
			var s := "%s used Shadow Read" % names[e.player]
			if e.has("die_id"):
				s += " and saw %s" % _face(dice, 1 - e.player, e.die_id, e.face_index)
			return s
		"placed":
			var s := "%s placed %d %s" % [names[e.player], e.count, "die" if e.count == 1 else "dice"]
			if e.has("move"):
				s += " (%s)" % DDMoves.NAMES.get(e.move, e.move)
			return s
		"reveal":
			var r: Dictionary = e.reveal
			return "REVEAL! %s: %s %s  |  %s: %s %s" % [
				names[r.attacker], DDMoves.NAMES[r.attack_move], dice_text(r.attack_dice),
				names[1 - r.attacker], DDMoves.NAMES[r.defense_move], dice_text(r.defense_dice)]
		"swipe":
			return "%s used Swipe! Swapped their die #%d with the opponent's die #%d" % [names[e.player], e.mine + 1, e.theirs + 1]
		"swipe_skipped":
			return "%s kept Swipe for later" % names[e.player]
		"resolved":
			var o: Dictionary = e.outcome
			var pw := " power %.1f" % o.attack.power if o.attack.valid else ""
			return "Result: %s%s vs %s - %s" % [DDMoves.NAMES[o.attack.move], pw, DDMoves.NAMES[o.defense.move], o.note]
		"hp":
			if e.cause == "heal":
				return "%s healed %d HP (%d left)" % [names[e.player], e.delta, e.hp]
			return "%s %s %d damage (%d HP left)" % [names[e.player], "took reflected" if e.cause == "reflect" else "took", -e.delta, e.hp]
		"focus":
			return "%s gained %d Focus (%d)" % [names[e.player], e.gained, e.focus]
		"battle_end":
			var pct := "HP %d%% / %d%%" % [roundi(e.hp_pct[0] * 100), roundi(e.hp_pct[1] * 100)]
			if e.winner == DDBattle.DRAW:
				return "Battle over: draw (%s)" % pct
			return "Battle over: %s wins%s" % [names[e.winner], " (KO)" if e.reason == "ko" else " (%s)" % pct]
	return str(e)


static func _face(dice: Array, p: int, die_id: String, face_index: int) -> String:
	for d in dice[p]:
		if d.id == die_id:
			return DDFaces.label(d.faces[face_index])
	return "?"

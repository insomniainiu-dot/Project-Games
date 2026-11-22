class_name DDBattle
## ตัวเดินเกม Dice Duel (pure: ไม่แตะ UI ไม่แก้ state เดิม คืน state ใหม่ทุกครั้ง)
## ทุกความสุ่มมาจาก state.rng_state → config + รายการ action = replay ได้ 100%
##
## ใช้:
##   var s := DDBattle.create_battle({"seed": 42, "fighters": [char_a, char_b]})
##   var r := DDBattle.apply_action(s, {"type": "place", "player": 0, "move": "slash", "dice": [{"die_id": "A-d1"}]})
##   if r.error != "": ...  else: s = r.state
##
## Action:
##   {"type": "reroll", "player", "die_id"}
##   {"type": "shadow_read", "player"}
##   {"type": "place", "player", "move", "dice": [{"die_id", "wild"(1-6 เฉพาะหน้า ✦)}]}
##   {"type": "swipe", "player", "mine": index, "theirs": index}
##   {"type": "skip_swipe", "player"}
##
## state.winner: -1 = ยังไม่จบ, 0/1 = ผู้ชนะ, 2 = เสมอ

const NONE := -1
const DRAW := 2


# ================================================================ สร้างตัวละคร / เต๋า
static func create_die(id: String, body := "standard", faces: Array = []) -> Dictionary:
	var f := faces.duplicate(true)
	if f.is_empty():
		for i in DDBodies.get_body(body).sides:
			f.append(DDFaces.num(i + 1))
	var face_runes := []
	face_runes.resize(f.size())
	face_runes.fill("")
	return {"id": id, "body": body, "faces": f, "face_runes": face_runes, "die_runes": []}


static func stats_for(job: String) -> Dictionary:
	var s: Dictionary = DDBalance.BASE_STATS.duplicate()
	var mods: Dictionary = DDBalance.JOB_STAT_MODS.get(job, {})
	for k in mods:
		s[k] += mods[k]
	return s


static func create_character(id: String, job: String, char_name := "") -> Dictionary:
	var dice := []
	for i in DDBalance.STARTING_DICE:
		dice.append(create_die("%s-d%d" % [id, i + 1]))
	return {"id": id, "name": char_name if char_name != "" else id, "job": job, "stats": stats_for(job), "dice": dice, "rune_bag": []}


# ================================================================ เริ่มการต่อสู้
## config = {"seed": int, "fighters": [char, char], "start_hp": [hp, hp] (ไม่ใส่ = เต็ม)}
static func create_battle(config: Dictionary) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = int(config.seed)
	var fighters := []
	for p in 2:
		fighters.append(_make_fighter(config.fighters[p], config.get("start_hp", [-1, -1])[p]))
	var s := {
		"config": config.duplicate(true), "rng_state": 0, "round": 0, "attacker": 0, "phase": "attack",
		"fighters": fighters, "placements": [null, null], "swipe_queue": [], "reveal": null,
		"winner": NONE, "log": [], "actions": [],
	}
	s.log.append({"t": "battle_start", "names": [fighters[0].character.name, fighters[1].character.name],
		"jobs": [fighters[0].character.job, fighters[1].character.job]})

	# ใครบุกก่อน: d6 + SP/5 เสมอทอยใหม่
	var bonus := [fighters[0].character.stats.sp / DDBalance.INITIATIVE_SP_DIVISOR,
		fighters[1].character.stats.sp / DDBalance.INITIATIVE_SP_DIVISOR]
	var attacker := NONE
	var tries := 0
	while attacker == NONE:
		var rolls := [rng.randi_range(1, DDBalance.INITIATIVE_DIE), rng.randi_range(1, DDBalance.INITIATIVE_DIE)]
		var t0: float = rolls[0] + bonus[0]
		var t1: float = rolls[1] + bonus[1]
		if not is_equal_approx(t0, t1):
			attacker = 0 if t0 > t1 else 1
		elif tries > 100:
			attacker = 0 # กันวนไม่จบ
		tries += 1
		s.log.append({"t": "initiative", "rolls": rolls, "bonus": bonus, "attacker": attacker})
	s.attacker = attacker
	_start_round(s, rng)
	s.rng_state = rng.state
	return s


static func _make_fighter(c: Dictionary, start_hp) -> Dictionary:
	var focus := 0
	for d in c.dice:
		focus += DDBodies.get_body(d.body).start_focus
	var max_hp: int = c.stats.hp
	var hp: int = max_hp if start_hp == null or int(start_hp) < 0 else clampi(int(start_hp), 1, max_hp)
	return {
		"character": c.duplicate(true), "hp": hp, "max_hp": max_hp, "focus": mini(DDBalance.FOCUS_MAX, focus),
		"rolled": [], "swipe_used": DDBalance.SWIPE_USES_PER_BATTLE <= 0, "swipe_count": 0,
		"shadow_read_used": false, "free_reroll_used": false,
		"peek": null, "placed_own_count": 0,
	}


static func _start_round(s: Dictionary, rng: RandomNumberGenerator) -> void:
	s.round += 1
	s.phase = "attack"
	s.placements = [null, null]
	s.swipe_queue = []
	for f in s.fighters:
		f.focus = mini(DDBalance.FOCUS_MAX, f.focus + DDBalance.FOCUS_PER_ROUND)
		f.shadow_read_used = false
		f.free_reroll_used = false
		f.peek = null
		f.placed_own_count = 0
		var rolled := []
		for d in f.character.dice:
			rolled.append({"die_id": d.id, "face_index": rng.randi_range(0, d.faces.size() - 1)})
		f.rolled = rolled
	s.log.append({"t": "round_start", "round": s.round, "attacker": s.attacker, "focus": [s.fighters[0].focus, s.fighters[1].focus]})
	for p in 2:
		s.log.append({"t": "rolled", "player": p, "dice": s.fighters[p].rolled.duplicate(true)})


# ================================================================ ตัวช่วย
static func other(p: int) -> int:
	return 1 - p


## ผู้เล่นที่ต้องทำ action ตอนนี้ (-1 = ไม่มี)
static func actor_of(s: Dictionary) -> int:
	match s.phase:
		"attack":
			return s.attacker
		"defend":
			return other(s.attacker)
		"swipe":
			return s.swipe_queue[0] if not s.swipe_queue.is_empty() else NONE
	return NONE


static func find_die(c: Dictionary, die_id: String) -> Dictionary:
	for d in c.dice:
		if d.id == die_id:
			return d
	return {}


static func find_rolled(f: Dictionary, die_id: String) -> Dictionary:
	for r in f.rolled:
		if r.die_id == die_id:
			return r
	return {}


## DieInfo ของเต๋า 1 ลูก (ตามหน้าที่ทอยได้ตอนนี้) — {} ถ้าไม่พบ
static func die_info(s: Dictionary, owner: int, die_id: String, wild := 0) -> Dictionary:
	var f: Dictionary = s.fighters[owner]
	var die := find_die(f.character, die_id)
	var rolled := find_rolled(f, die_id)
	if die.is_empty() or rolled.is_empty():
		return {}
	return make_info(owner, die, int(rolled.face_index), wild)


static func make_info(owner: int, die: Dictionary, face_index: int, wild := 0) -> Dictionary:
	var face: Dictionary = die.faces[face_index]
	var runes: Array = die.die_runes.duplicate()
	if die.face_runes[face_index] != "":
		runes.append(die.face_runes[face_index])
	return {"owner": owner, "die_id": die.id, "face": face, "body": die.body, "runes": runes,
		"wild": wild if face.k == "wild" else 0}


static func placement_infos(s: Dictionary, p: int) -> Array:
	var out := []
	if s.placements[p] == null:
		return out
	for pd in s.placements[p].dice:
		out.append(die_info(s, pd.owner, pd.die_id, pd.wild))
	return out


# ================================================================ apply_action
## คืน {"state": state ใหม่, "error": ""} — ถ้าผิดกติกา error จะไม่ว่าง และ state = ของเดิม
static func apply_action(prev: Dictionary, action: Dictionary) -> Dictionary:
	if prev.phase == "over":
		return {"state": prev, "error": "The battle is over."}
	var p: int = action.get("player", NONE)
	if p != actor_of(prev):
		return {"state": prev, "error": "It's not player %d's turn." % (p + 1)}

	var s: Dictionary = prev.duplicate(true)
	var rng := RandomNumberGenerator.new()
	rng.state = s.rng_state
	var me: Dictionary = s.fighters[p]
	var err := ""

	match action.get("type", ""):
		"reroll":
			err = _reroll(s, me, p, str(action.get("die_id", "")), rng)
		"shadow_read":
			err = _shadow_read(s, me, p, rng)
		"place":
			err = _place(s, p, str(action.get("move", "")), action.get("dice", []))
			if err == "":
				if s.phase == "attack":
					s.phase = "defend"
				else:
					_reveal(s, rng)
		"swipe":
			err = _swipe(s, me, p, int(action.get("mine", -1)), int(action.get("theirs", -1)), rng)
		"skip_swipe":
			if s.phase != "swipe":
				err = "Not the Swipe phase."
			else:
				s.log.append({"t": "swipe_skipped", "player": p})
				_next_swipe(s, rng)
		_:
			err = "Unknown action."

	if err != "":
		return {"state": prev, "error": err}
	s.rng_state = rng.state
	s.actions.append(action.duplicate(true))
	return {"state": s, "error": ""}


static func _reroll(s: Dictionary, me: Dictionary, p: int, die_id: String, rng: RandomNumberGenerator) -> String:
	if s.phase != "attack" and s.phase != "defend":
		return "You can only reroll before placing."
	var rd := find_rolled(me, die_id)
	var die := find_die(me.character, die_id)
	if rd.is_empty() or die.is_empty():
		return "No such die."
	var face: Dictionary = die.faces[rd.face_index]
	var free: bool = me.character.job == "warrior" and not me.free_reroll_used and face.k == "num" and int(face.v) == 1
	if free:
		me.free_reroll_used = true
	elif me.focus < DDBalance.REROLL_COST:
		return "Not enough Focus."
	else:
		me.focus -= DDBalance.REROLL_COST
	rd.face_index = rng.randi_range(0, die.faces.size() - 1)
	s.log.append({"t": "rerolled", "player": p, "die_id": die_id, "free": free, "face_index": rd.face_index})
	return ""


static func _shadow_read(s: Dictionary, me: Dictionary, p: int, rng: RandomNumberGenerator) -> String:
	if s.phase != "attack" and s.phase != "defend":
		return "Shadow Read works only while placing."
	if me.character.job != "ninja":
		return "Only a Ninja can Shadow Read."
	if me.shadow_read_used:
		return "Shadow Read was already used this round."
	var opp: Dictionary = s.fighters[other(p)]
	if opp.rolled.is_empty():
		return "The opponent has no dice."
	me.shadow_read_used = true
	me.peek = opp.rolled[rng.randi_range(0, opp.rolled.size() - 1)].duplicate()
	s.log.append({"t": "shadow_read", "player": p, "die_id": me.peek.die_id, "face_index": me.peek.face_index})
	return ""


static func _place(s: Dictionary, p: int, move: String, dice: Array) -> String:
	var me: Dictionary = s.fighters[p]
	if s.phase == "attack":
		if not DDMoves.offense_moves_for(me.character.job).has(move):
			return "%s can't attack with %s." % [DDJobs.NAMES.get(me.character.job, "?"), move]
		if dice.is_empty():
			return "An attack needs at least 1 die."
	elif s.phase == "defend":
		if not DDMoves.DEFENSE.has(move):
			return "%s is not a defense." % move
	else:
		return "Not the placing phase."
	var seen := {}
	var placed := []
	for d in dice:
		var id := str(d.get("die_id", ""))
		if seen.has(id):
			return "The same die was placed twice."
		seen[id] = true
		var info := die_info(s, p, id)
		if info.is_empty():
			return "No such die: %s" % id
		if info.face.k == "wild":
			var w := int(d.get("wild", 0))
			if w < 1 or w > 6:
				return "Choose a value 1-6 for the wild face."
			placed.append({"owner": p, "die_id": id, "wild": w})
		else:
			placed.append({"owner": p, "die_id": id, "wild": 0})
	s.placements[p] = {"move": move, "dice": placed}
	me.placed_own_count = placed.size()
	s.log.append({"t": "placed", "player": p, "count": placed.size(), "move": move})
	return ""


static func _reveal(s: Dictionary, rng: RandomNumberGenerator) -> void:
	var a: int = s.attacker
	var d := other(a)
	s.reveal = {
		"round": s.round, "attacker": a, "attack_move": s.placements[a].move, "defense_move": s.placements[d].move,
		"attack_dice": placement_infos(s, a), "defense_dice": placement_infos(s, d), "swipes": [], "outcome": null,
	}
	s.log.append({"t": "reveal", "reveal": s.reveal.duplicate(true)})
	var queue := []
	for p in [a, d]:
		var f: Dictionary = s.fighters[p]
		if f.character.job == "thief" and not f.swipe_used and f.focus >= DDBalance.SWIPE_FOCUS_COST \
				and not s.placements[p].dice.is_empty() and not s.placements[other(p)].dice.is_empty():
			queue.append(p)
	s.swipe_queue = queue
	if queue.is_empty():
		_resolve_round(s, rng)
	else:
		s.phase = "swipe"


static func _swipe(s: Dictionary, me: Dictionary, p: int, mine_i: int, theirs_i: int, rng: RandomNumberGenerator) -> String:
	if s.phase != "swipe":
		return "Not the Swipe phase."
	var mine: Array = s.placements[p].dice
	var theirs: Array = s.placements[other(p)].dice
	if DDBalance.SWIPE_RANDOM_TARGET:
		theirs_i = rng.randi_range(0, theirs.size() - 1) # เลือกได้แค่เต๋าของตัวเอง เต๋าอีกฝ่ายสุ่ม
	if mine_i < 0 or mine_i >= mine.size() or theirs_i < 0 or theirs_i >= theirs.size():
		return "Pick one of your dice and one of theirs."
	if me.focus < DDBalance.SWIPE_FOCUS_COST:
		return "Not enough Focus for Swipe."
	var tmp = mine[mine_i]
	mine[mine_i] = theirs[theirs_i]
	theirs[theirs_i] = tmp
	me.focus -= DDBalance.SWIPE_FOCUS_COST
	me.swipe_count += 1
	me.swipe_used = me.swipe_count >= DDBalance.SWIPE_USES_PER_BATTLE
	s.reveal.swipes.append({"player": p, "mine": mine_i, "theirs": theirs_i})
	s.reveal.attack_dice = placement_infos(s, s.attacker)
	s.reveal.defense_dice = placement_infos(s, other(s.attacker))
	s.log.append({"t": "swipe", "player": p, "mine": mine_i, "theirs": theirs_i})
	_next_swipe(s, rng)
	return ""


static func _next_swipe(s: Dictionary, rng: RandomNumberGenerator) -> void:
	s.swipe_queue.pop_front()
	if s.swipe_queue.is_empty():
		_resolve_round(s, rng)
	else:
		s.phase = "swipe"


static func _resolve_round(s: Dictionary, rng: RandomNumberGenerator) -> void:
	var a: int = s.attacker
	var d := other(a)
	var fa: Dictionary = s.fighters[a]
	var fd: Dictionary = s.fighters[d]
	var out := DDResolve.resolve_from_dice({
		"attacker": {"job": fa.character.job, "stats": fa.character.stats},
		"defender": {"job": fd.character.job, "stats": fd.character.stats},
		"attack_move": s.placements[a].move, "attack_dice": placement_infos(s, a),
		"defense_move": s.placements[d].move, "defense_dice": placement_infos(s, d),
	})
	s.reveal.outcome = out
	s.log.append({"t": "resolved", "outcome": out.duplicate(true), "attacker": a})

	if out.damage_to_defender > 0:
		fd.hp = maxi(0, fd.hp - out.damage_to_defender)
		s.log.append({"t": "hp", "player": d, "delta": -out.damage_to_defender, "hp": fd.hp, "cause": "damage"})
	if out.damage_to_attacker > 0:
		fa.hp = maxi(0, fa.hp - out.damage_to_attacker)
		s.log.append({"t": "hp", "player": a, "delta": -out.damage_to_attacker, "hp": fa.hp, "cause": "reflect"})
	# Sanctuary: ฮีลหลังรับดาเมจ (HP เหลือ 0 แล้วไม่ฟื้น)
	if out.heal_defender > 0 and fd.hp > 0:
		var before: int = fd.hp
		fd.hp = mini(fd.max_hp, fd.hp + out.heal_defender)
		if fd.hp > before:
			s.log.append({"t": "hp", "player": d, "delta": fd.hp - before, "hp": fd.hp, "cause": "heal"})

	for p in 2:
		var f: Dictionary = s.fighters[p]
		var unplaced: int = f.character.dice.size() - f.placed_own_count
		var gained := mini(DDBalance.FOCUS_MAX - f.focus, unplaced * DDBalance.FOCUS_PER_UNPLACED_DIE)
		if gained > 0:
			f.focus += gained
			s.log.append({"t": "focus", "player": p, "gained": gained, "focus": f.focus})

	var pct := [float(s.fighters[0].hp) / s.fighters[0].max_hp, float(s.fighters[1].hp) / s.fighters[1].max_hp]
	if fa.hp <= 0 or fd.hp <= 0:
		s.winner = d if fa.hp <= 0 else a
		s.phase = "over"
		s.log.append({"t": "battle_end", "winner": s.winner, "reason": "ko", "hp_pct": pct})
		return
	if s.round >= DDBalance.MAX_ROUNDS:
		if is_equal_approx(pct[0], pct[1]):
			s.winner = DRAW
		else:
			s.winner = 0 if pct[0] > pct[1] else 1
		s.phase = "over"
		s.log.append({"t": "battle_end", "winner": s.winner, "reason": "rounds", "hp_pct": pct})
		return
	s.attacker = d
	_start_round(s, rng)

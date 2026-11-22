extends SceneTree
## Unit test ของ Dice Duel — รันแบบ headless:
##   Godot --headless --path . --script res://tests/dd_tests.gd
## exit code 0 = ผ่านทั้งหมด

const F := preload("res://dice_duel/dd_faces.gd")

var _passed := 0
var _failed := 0
var _section := ""
var _uid := 0

const STATS := {"hp": 100, "at": 20, "df": 15, "mg": 15, "sp": 10}
## ค่าเต๋าที่ใช้ Counter ได้ (ตาม DDBalance.COUNTER_VALUES)
var CV: int = DDBalance.COUNTER_VALUES[0]


func _init() -> void:
	_rules_faces()
	_rules_bodies()
	_rules_runes()
	_rules_offense()
	_rules_defense()
	_rules_table()
	_rules_skills()
	_battle_start()
	_battle_turns()
	_battle_focus()
	_battle_flow()
	_battle_skills()
	_battle_end()
	_view_secrets()
	_replay_tests()
	_ai_tests()
	_meta_tests()
	print("\nDice Duel tests: %d passed, %d failed" % [_passed, _failed])
	quit(1 if _failed > 0 else 0)


# ================================================================ ตัวช่วย
func section(name: String) -> void:
	_section = name
	print("- ", name)


func check(cond: bool, what: String) -> void:
	if cond:
		_passed += 1
	else:
		_failed += 1
		print("  FAIL [%s] %s" % [_section, what])


func eq(actual, expected, what: String) -> void:
	var ok: bool = actual == expected
	if typeof(actual) == TYPE_FLOAT or typeof(expected) == TYPE_FLOAT:
		ok = absf(float(actual) - float(expected)) < 0.001
	if not ok:
		what += "  (got %s, expected %s)" % [actual, expected]
	check(ok, what)


func die(face: Dictionary, body := "standard", runes: Array = [], wild := 0, owner := 0) -> Dictionary:
	_uid += 1
	return {"owner": owner, "die_id": "t%d" % _uid, "face": face, "body": body, "runes": runes, "wild": wild if face.k == "wild" else 0}


func n(values: Array) -> Array:
	var out := []
	for v in values:
		out.append(die(F.num(v)))
	return out


func S(kind: String) -> Dictionary:
	return F.sym(kind)


func off(move: String, dice: Array, job := "thief") -> Dictionary:
	return DDMoves.evaluate_offense(move, dice, job, STATS)


func dfn(move: String, dice: Array, job := "thief") -> Dictionary:
	return DDMoves.evaluate_defense(move, dice, job, STATS)


func fight(am: String, ad: Array, dm: String, dd: Array, jobs := ["thief", "thief"]) -> Dictionary:
	return DDResolve.resolve_from_dice({
		"attacker": {"job": jobs[0], "stats": STATS}, "defender": {"job": jobs[1], "stats": STATS},
		"attack_move": am, "attack_dice": ad, "defense_move": dm, "defense_dice": dd})


## การต่อสู้ที่ P0 บุกก่อนแน่นอน (SP สูงมาก)
func battle(job0: String, job1: String, seed := 1, p1_fast := false) -> Dictionary:
	var a := DDBattle.create_character("A", job0, "Alice")
	var b := DDBattle.create_character("B", job1, "Bob")
	if p1_fast:
		b.stats.sp = 100
	else:
		a.stats.sp = 100
	return DDBattle.create_battle({"seed": seed, "fighters": [a, b]})


## บังคับผลทอยเต๋า d6 ธรรมดา (ค่า 1-6) — ใช้ใน test เท่านั้น
func force(s: Dictionary, p: int, values: Array) -> Dictionary:
	var c: Dictionary = s.duplicate(true)
	for i in values.size():
		c.fighters[p].rolled[i].face_index = values[i] - 1
	return c


func act(s: Dictionary, action: Dictionary) -> Dictionary:
	var r := DDBattle.apply_action(s, action)
	if r.error != "":
		check(false, "unexpected error: %s (%s)" % [r.error, action])
	return r.state


func err(s: Dictionary, action: Dictionary) -> bool:
	return DDBattle.apply_action(s, action).error != ""


func place_action(s: Dictionary, p: int, move: String, idx: Array) -> Dictionary:
	var dice := []
	for i in idx:
		dice.append({"die_id": s.fighters[p].character.dice[i].id})
	return {"type": "place", "player": p, "move": move, "dice": dice}


func place(s: Dictionary, p: int, move: String, idx: Array) -> Dictionary:
	return act(s, place_action(s, p, move, idx))


# ================================================================ กฎ: หน้าเต๋า
# AT 20, DF 15, MG 15 → Slash [3,4] = 34, Strike [4,4] = 72, Magic [5] = 26.25
func _rules_faces() -> void:
	section("faces")
	eq(F.condition_value(die(F.num(4)), "offense"), 4, "number counts as itself")
	eq(F.condition_value(die(S("sword")), "offense"), 6, "sword = 6 on offense")
	eq(F.condition_value(die(S("sword")), "defense"), 1, "sword = 1 on defense")
	eq(F.condition_value(die(S("shield")), "defense"), 6, "shield = 6 on defense")
	eq(F.condition_value(die(S("shield")), "offense"), 1, "shield = 1 on offense")
	eq(F.condition_value(die(S("wild"), "standard", [], 5), "defense"), 5, "wild uses the chosen value")
	check(dfn("ward", [die(S("wild"), "standard", [], 5)]).valid, "wild 5 counts as odd")
	check(not dfn("ward", [die(S("wild"), "standard", [], 4)]).valid, "wild 4 counts as even")
	eq(F.condition_value(die(S("skull")), "offense"), 0, "skull = 0")
	check(not off("strike", [die(S("skull")), die(F.num(6))]).valid, "skull breaks Strike")
	check(not off("magic", [die(S("skull"))]).valid, "skull breaks Magic")
	check(not off("berserk", [die(S("skull")), die(S("skull")), die(S("skull"))], "warrior").valid, "skull breaks Berserk")
	check(not dfn("counter", [die(S("skull"))]).valid, "skull breaks Counter")
	check(not dfn("ward", [die(S("skull"))]).valid, "skull breaks Ward")
	var sl := off("slash", [die(S("skull"))])
	check(sl.valid and is_equal_approx(sl.power, 20.0), "skull allowed in Slash (value 0)")
	var gd := dfn("guard", [die(S("skull"))])
	check(gd.valid and gd.reduction == 0.0, "skull allowed in Guard (value 0)")


func _rules_bodies() -> void:
	section("dice bodies")
	eq(F.condition_value(die(F.num(1), "heavy"), "offense"), 3, "Heavy: 1 -> 3")
	eq(F.condition_value(die(F.num(2), "heavy"), "offense"), 3, "Heavy: 2 -> 3")
	eq(F.condition_value(die(F.num(5), "heavy"), "offense"), 5, "Heavy: 5 stays")
	eq(F.condition_value(die(S("skull"), "heavy"), "offense"), 0, "Heavy: skull stays 0")
	eq(F.condition_value(die(S("sword"), "heavy"), "defense"), 1, "Heavy: symbols unaffected")
	eq(DDBattle.create_die("q", "quick").faces.size(), 4, "Quick is a d4")
	eq(DDBattle.create_die("s").faces.size(), 6, "Standard is a d6")


func _rules_runes() -> void:
	section("runes")
	eq(F.effective_value(die(F.num(4), "standard", ["twin"]), "offense"), 8, "Twin doubles even")
	eq(off("slash", [die(F.num(4), "standard", ["twin"])]).power, 36.0, "Twin in Slash power")
	eq(F.effective_value(die(F.num(3), "standard", ["twin"]), "offense"), 3, "Twin ignores odd")
	check(dfn("counter", [die(F.num(6), "standard", ["twin"])]).valid, "conditions use the pre-rune value (Counter 6+Twin ok)")
	check(not off("strike", [die(F.num(2), "standard", ["twin"]), die(F.num(4))]).valid, "Twin doesn't help Strike's sum condition")
	eq(F.effective_value(die(S("sword"), "standard", ["twin"]), "offense"), 12, "Twin + sword on offense = 12")
	eq(F.effective_value(die(S("sword"), "standard", ["twin"]), "defense"), 1, "Twin + sword on defense = 1")
	eq(off("magic", [die(F.num(5), "standard", ["spark"])]).power, 26.25 * 1.1, "Spark: Magic +10%")
	eq(off("slash", [die(F.num(5), "standard", ["spark"])]).power, 30.0, "Spark: no effect on Slash")


func _rules_offense() -> void:
	section("offense conditions")
	eq(off("slash", n([3, 4])).power, 34.0, "Slash 2 dice")
	check(not off("slash", n([1, 2, 3])).valid, "Slash max 2 dice")
	eq(off("strike", n([4, 4])).power, 72.0, "Strike power")
	check(not off("strike", n([3, 4])).valid, "Strike needs sum >= 8")
	check(not off("strike", n([6])).valid, "Strike needs exactly 2 (1 die)")
	check(not off("strike", n([6, 6, 6])).valid, "Strike needs exactly 2 (3 dice)")
	eq(off("magic", n([5])).power, 26.25, "Magic power")
	check(off("magic", n([4])).valid, "Magic accepts 4")
	check(not off("magic", n([3])).valid, "Magic rejects 3")
	eq(off("magic", [die(S("wild"), "standard", [], 2)]).power, 19.5, "Magic accepts wild (value 2)")
	check(not off("magic", n([5, 5])).valid, "Magic is 1 die for non-Magicians")


func _rules_defense() -> void:
	section("defense conditions")
	eq(dfn("guard", n([2, 3])).reduction, 3.75, "Guard reduction")
	var g0 := dfn("guard", [])
	check(g0.valid and g0.reduction == 0.0, "Guard with 0 dice")
	for v in range(1, 7):
		check(dfn("counter", n([v])).valid == DDBalance.COUNTER_VALUES.has(v), "Counter on %d follows COUNTER_VALUES %s" % [v, DDBalance.COUNTER_VALUES])
	check(not dfn("counter", n([CV, CV])).valid, "Counter is 1 die")
	check(dfn("counter", [die(S("shield"))]).valid, "Counter with shield (6)")
	check(not dfn("counter", [die(S("sword"))]).valid, "Counter with sword (1)")
	eq(dfn("ward", n([3, 5])).reduction, 9.6, "Ward reduction")
	check(not dfn("ward", n([3, 4])).valid, "Ward odd only")
	check(not dfn("ward", [die(S("shield"))]).valid, "Ward rejects shield (6)")


func _rules_table() -> void:
	section("result table (all 9 cells + special cases)")
	eq(fight("slash", n([3, 4]), "guard", n([2, 3])).damage_to_defender, 30, "Slash vs Guard = power - guard")
	var sc := fight("slash", n([3, 4]), "counter", n([CV]))
	check(sc.damage_to_defender == floori(34 * DDBalance.SLASH_VS_COUNTER_MULT) and sc.damage_to_attacker == 0,
		"Slash vs Counter = full x SLASH_VS_COUNTER_MULT (%s)" % DDBalance.SLASH_VS_COUNTER_MULT)
	eq(fight("slash", n([3, 4]), "counter", n([1])).damage_to_defender, floori(34 * DDBalance.SLASH_VS_COUNTER_MULT), "Slash vs Counter: multiplier applies once declared")
	eq(fight("slash", n([3, 4]), "ward", n([5])).damage_to_defender, 34, "Slash vs Ward = full")
	eq(fight("strike", n([4, 4]), "guard", n([6, 6, 6])).damage_to_defender, 72, "Strike vs Guard = full (breaks guard)")
	var stc := fight("strike", n([4, 4]), "counter", n([CV]))
	check(stc.damage_to_defender == 0 and stc.damage_to_attacker == 72, "Strike vs Counter = 100% reflected")
	eq(fight("strike", n([4, 4]), "ward", n([5])).damage_to_defender, 72, "Strike vs Ward = full")
	eq(fight("magic", n([5]), "guard", n([6, 6])).damage_to_defender, 26, "Magic vs Guard = full")
	eq(fight("magic", n([5]), "counter", n([CV])).damage_to_defender, 39, "Magic vs Counter = x1.5")
	eq(fight("magic", n([5]), "ward", n([3, 5])).damage_to_defender, 16, "Magic vs Ward = power - ward")
	var failed := fight("strike", n([3, 4]), "ward", n([5]))
	check(failed.damage_to_defender == 0 and failed.damage_to_attacker == 0, "failed attack = no damage")
	eq(fight("strike", n([4, 4]), "counter", n([4])).damage_to_defender, 72, "failed Counter = no defense")
	eq(fight("magic", n([5]), "ward", n([4])).damage_to_defender, 26, "failed Ward = no defense")
	eq(fight("magic", n([5]), "counter", n([3])).damage_to_defender, 39, "declared Counter vs Magic = x1.5 even if it failed")
	var big := STATS.duplicate()
	big.df = 200
	var zero := DDResolve.resolve_from_dice({"attacker": {"job": "thief", "stats": STATS}, "defender": {"job": "thief", "stats": big},
		"attack_move": "slash", "attack_dice": n([1]), "defense_move": "guard", "defense_dice": n([6, 6, 6])})
	eq(zero.damage_to_defender, 0, "damage floor is 0")
	var rounded := DDResolve.resolve_exchange({"move": "slash", "valid": true, "reason": "", "power": 10.99, "counts_as": "slash"},
		{"move": "ward", "valid": true, "reason": "", "reduction": 0.0, "heal": 0})
	eq(rounded.damage_to_defender, 10, "damage rounds down")


func _rules_skills() -> void:
	section("job skills (move rules)")
	var bz := off("berserk", n([4, 4, 4]), "warrior")
	check(bz.valid and is_equal_approx(bz.power, 132.0), "Berserk: 3 equal dice, power x3")
	check(not off("berserk", n([4, 4, 5]), "warrior").valid, "Berserk needs equal values")
	check(not off("berserk", n([4, 4, 4]), "thief").valid, "Berserk is Warrior only")
	check(off("berserk", [die(F.num(6)), die(S("sword")), die(S("wild"), "standard", [], 6)], "warrior").valid, "Berserk: 6 + sword + wild(6) are equal")
	eq(fight("berserk", n([4, 4, 4]), "guard", n([6, 6]), ["warrior", "thief"]).damage_to_defender, 132, "Berserk breaks Guard like Strike")
	var bc := fight("berserk", n([4, 4, 4]), "counter", n([CV]), ["warrior", "thief"])
	check(bc.damage_to_defender == 0 and bc.damage_to_attacker == 132, "Berserk is reflected by Counter")
	eq(off("magic", n([5, 3, 1]), "magician").power, 26.25 * 1.3, "Arcane Flow: +15% per odd extra die")
	eq(off("magic", n([5, 2]), "magician").power, 26.25, "Arcane Flow: even extra gives nothing")
	check(not off("magic", n([3, 5]), "magician").valid, "Arcane Flow: primary die still needs >= 4")
	eq(off("magic", [die(F.num(5), "standard", ["spark"]), die(F.num(3))], "magician").power, 26.25 * 1.25, "Arcane Flow + Spark add up")
	eq(dfn("guard", n([3, 4]), "cleric").heal, 14, "Sanctuary: heal sum x 2")
	eq(dfn("guard", n([3, 4]), "thief").heal, 0, "Sanctuary is Cleric only")
	eq(fight("slash", n([1]), "guard", n([3, 4]), ["thief", "cleric"]).heal_defender, 14, "Sanctuary heal in the outcome")


# ================================================================ การต่อสู้จริง
func _battle_start() -> void:
	section("battle start")
	var all_p0 := true
	var all_p1 := true
	for seed in 20:
		all_p0 = all_p0 and battle("thief", "thief", seed).attacker == 0
		all_p1 = all_p1 and battle("thief", "thief", seed, true).attacker == 1
	check(all_p0 and all_p1, "initiative = d6 + SP/5")
	var saw_tie := false
	for seed in 200:
		var s := DDBattle.create_battle({"seed": seed, "fighters": [DDBattle.create_character("A", "thief"), DDBattle.create_character("B", "thief")]})
		var ini: Array = s.log.filter(func(e): return e.t == "initiative")
		if ini.size() > 1:
			saw_tie = true
			check(ini[0].attacker == -1, "a tie is logged and rolled again")
			break
	check(saw_tie, "found a tie within 200 seeds")
	var s := battle("thief", "thief")
	check(s.round == 1 and s.phase == "attack" and s.fighters[0].rolled.size() == 3 and s.fighters[0].focus == 1, "round 1: all dice rolled, Focus +1")
	var a := DDBattle.create_character("A", "thief")
	a.stats.sp = 100
	a.dice[0] = DDBattle.create_die("A-q", "quick")
	var b := DDBattle.create_character("B", "thief")
	b.dice = [DDBattle.create_die("B-q1", "quick"), DDBattle.create_die("B-q2", "quick"), DDBattle.create_die("B-q3", "quick"), DDBattle.create_die("B-q4", "quick")]
	var q := DDBattle.create_battle({"seed": 3, "fighters": [a, b]})
	eq(q.fighters[0].focus, 2, "Quick: +1 Focus at battle start")
	eq(q.fighters[1].focus, DDBalance.FOCUS_MAX, "Quick: Focus capped at 3")
	check(q.fighters[0].rolled[0].face_index < 4, "Quick rolls a d4")
	var hurt := DDBattle.create_battle({"seed": 1, "fighters": [DDBattle.create_character("A", "thief"), DDBattle.create_character("B", "thief")], "start_hp": [40, -1]})
	check(hurt.fighters[0].hp == 40 and hurt.fighters[1].hp == 100, "start_hp keeps board HP")


func _battle_turns() -> void:
	section("turn order")
	var s := battle("thief", "thief")
	check(err(s, place_action(s, 1, "guard", [0])), "defender can't act first")
	check(err(s, place_action(s, 0, "guard", [0])), "attacker can't use a defense")
	var s2 := place(s, 0, "slash", [0])
	check(err(s2, place_action(s2, 1, "slash", [0])), "defender can't use an attack")
	check(err(s, place_action(s, 0, "slash", [0, 0])), "can't place the same die twice")
	check(err(s, place_action(s, 0, "slash", [])), "attack needs at least 1 die")
	var before := var_to_str(s)
	place(s, 0, "slash", [0])
	check(var_to_str(s) == before, "apply_action doesn't change the old state")


func _battle_focus() -> void:
	section("focus & reroll")
	var s := battle("thief", "thief")
	s = act(s, {"type": "reroll", "player": 0, "die_id": "A-d1"})
	eq(s.fighters[0].focus, 0, "reroll costs 1 Focus")
	check(err(s, {"type": "reroll", "player": 0, "die_id": "A-d1"}), "no Focus, no reroll")
	var t := force(battle("warrior", "ninja"), 0, [3, 3, 3])
	t = place(t, 0, "slash", [0])
	t = place(t, 1, "guard", [0, 1, 2])
	eq(t.round, 2, "next round started")
	eq(t.fighters[0].focus, 3, "unplaced dice give Focus (capped at 3)")
	eq(t.fighters[1].focus, 2, "placing all dice gives no extra Focus")
	var w := force(battle("warrior", "thief"), 0, [1, 1, 1])
	w.fighters[0].focus = 0
	w = act(w, {"type": "reroll", "player": 0, "die_id": "A-d1"})
	check(w.fighters[0].free_reroll_used and w.fighters[0].focus == 0, "Warrior: free reroll of a 1")
	check(err(w, {"type": "reroll", "player": 0, "die_id": "A-d2"}), "Warrior: free reroll only once per round")
	var w2 := force(battle("warrior", "thief"), 0, [2, 2, 2])
	w2 = act(w2, {"type": "reroll", "player": 0, "die_id": "A-d1"})
	check(not w2.fighters[0].free_reroll_used and w2.fighters[0].focus == 0, "Warrior: other faces cost Focus")


func _battle_flow() -> void:
	section("resolution in a real battle")
	var s := force(force(battle("warrior", "ninja"), 0, [3, 4, 1]), 1, [2, 3, 1])
	s = place(s, 0, "slash", [0, 1])
	s = place(s, 1, "guard", [0, 1])
	eq(s.fighters[1].hp, 70, "Slash vs Guard: 100 - 30")
	eq(s.attacker, 1, "attacker swaps after the round")
	var c := force(force(battle("warrior", "ninja"), 0, [4, 4, 1]), 1, [CV, 1, 1])
	c = place(c, 0, "strike", [0, 1])
	c = place(c, 1, "counter", [0])
	check(c.fighters[0].hp == 28 and c.fighters[1].hp == 100, "Strike vs Counter: attacker takes the reflection")


func _battle_skills() -> void:
	section("skills in a real battle")
	var s := force(force(battle("warrior", "thief"), 0, [4, 4, 1]), 1, [1, 6, 6])
	s.fighters[1].focus = DDBalance.FOCUS_MAX
	s = place(s, 0, "strike", [0, 1])
	s = place(s, 1, "guard", [0])
	check(s.phase == "swipe" and DDBattle.actor_of(s) == 1, "Swipe: Thief gets to decide after the reveal")
	s = act(s, {"type": "swipe", "player": 1, "mine": 0, "theirs": 0})
	check(not s.reveal.outcome.attack.valid, "Swipe: swapping a 1 in breaks the Strike")
	eq(s.fighters[1].hp, 100, "Swipe: no damage taken")
	check(s.fighters[1].swipe_used, "Swipe: marked as used")
	s.fighters[1].focus = DDBalance.FOCUS_MAX
	s = place(s, 1, "slash", [0])
	s = place(s, 0, "guard", [0])
	check(s.phase != "swipe", "Swipe: only once per battle")

	if DDBalance.SWIPE_FOCUS_COST > 0:
		var poor := force(force(battle("warrior", "thief"), 0, [4, 4, 1]), 1, [1, 6, 6])
		poor.fighters[1].focus = DDBalance.SWIPE_FOCUS_COST - 1
		poor = place(poor, 0, "strike", [0, 1])
		poor = place(poor, 1, "guard", [0])
		check(poor.phase != "swipe", "Swipe isn't offered without enough Focus")

	var t := force(force(battle("thief", "thief"), 0, [4, 4, 1]), 1, [CV, 2, 2])
	t.fighters[0].focus = DDBalance.FOCUS_MAX
	t.fighters[1].focus = DDBalance.FOCUS_MAX
	t = place(t, 0, "strike", [0, 1])
	t = place(t, 1, "counter", [0])
	eq(t.swipe_queue, [0, 1], "two Thieves: attacker decides first")
	var t2 := act(t, {"type": "swipe", "player": 0, "mine": 1, "theirs": 0})
	check(t2.phase == "swipe", "second Thief still gets to decide")
	eq(t2.fighters[0].focus, DDBalance.FOCUS_MAX - DDBalance.SWIPE_FOCUS_COST, "Swipe costs SWIPE_FOCUS_COST Focus")
	t = act(t, {"type": "skip_swipe", "player": 0})
	t = act(t, {"type": "skip_swipe", "player": 1})
	eq(t.fighters[0].hp, 28, "Swipe can be skipped")

	var nj := battle("thief", "ninja")
	nj = place(nj, 0, "slash", [0])
	nj = act(nj, {"type": "shadow_read", "player": 1})
	var peek: Dictionary = nj.fighters[1].peek
	check(peek.face_index == DDBattle.find_rolled(nj.fighters[0], peek.die_id).face_index, "Shadow Read shows a real die")
	check(DDView.get_player_view(nj, 1).me.peek != null, "Ninja sees the peek")
	var opp_ev: Array = DDView.get_player_view(nj, 0).log.filter(func(e): return e.t == "shadow_read")
	check(opp_ev.size() == 1 and not opp_ev[0].has("die_id"), "the opponent doesn't see which die was read")
	check(err(nj, {"type": "shadow_read", "player": 1}), "Shadow Read once per round")
	var nj2 := battle("ninja", "thief")
	check(not err(nj2, {"type": "shadow_read", "player": 0}), "Ninja can Shadow Read as attacker")
	check(err(battle("thief", "ninja"), {"type": "shadow_read", "player": 0}), "other jobs can't Shadow Read")

	var cl := force(force(battle("warrior", "cleric"), 0, [1, 1, 1]), 1, [6, 6, 6])
	cl = place(cl, 0, "slash", [0])
	cl = place(cl, 1, "guard", [0, 1, 2])
	eq(cl.fighters[1].hp, 100, "Sanctuary: heal can't go over max HP")
	var cl2 := force(force(battle("warrior", "cleric"), 0, [6, 6, 1]), 1, [2, 1, 1])
	cl2 = place(cl2, 0, "slash", [0, 1])
	cl2 = place(cl2, 1, "guard", [0])
	eq(cl2.fighters[1].hp, 62, "Sanctuary: 100 - 42 + 4")

	var bz := force(force(battle("warrior", "thief"), 0, [4, 4, 4]), 1, [1, 1, 1])
	bz = place(bz, 0, "berserk", [0, 1, 2])
	bz = place(bz, 1, "guard", [])
	check(bz.fighters[1].hp == 0 and bz.winner == 0, "Berserk in a real battle")
	var nb := battle("thief", "thief")
	check(err(nb, place_action(nb, 0, "berserk", [0, 1, 2])), "only Warriors can place Berserk")


func _battle_end() -> void:
	section("battle end")
	var s := force(battle("thief", "thief"), 0, [6, 6, 1])
	s.fighters[1].hp = 5
	s = place(s, 0, "slash", [0])
	s = place(s, 1, "ward", [])
	check(s.phase == "over" and s.winner == 0, "HP 0 ends the battle")
	check(err(s, place_action(s, 1, "slash", [0])), "no actions after the end")

	var even := _play_out(battle("thief", "thief"))
	check(even.round == DDBalance.MAX_ROUNDS and even.winner == DDBattle.DRAW, "6 rounds, equal HP% = draw")
	var hurt := battle("thief", "thief")
	hurt.fighters[0].hp = 60
	hurt.fighters[1].max_hp = 200
	hurt.fighters[1].hp = 100
	eq(_play_out(hurt).winner, 0, "after 6 rounds higher HP% wins (60% vs 50%)")


func _play_out(s: Dictionary) -> Dictionary:
	while s.phase != "over":
		s = place(s, s.attacker, "strike", [0]) # ท่าล้มทุกรอบ ไม่มีดาเมจ
		s = place(s, 1 - s.attacker, "guard", [])
	return s


func _view_secrets() -> void:
	section("no secret leaks (get_player_view)")
	var s := battle("thief", "thief")
	var v := DDView.get_player_view(s, 1)
	check(v.me.dice.size() == 3, "I see my own dice")
	check(not v.opponent.has("rolled") and not v.opponent.has("peek") and not v.has("fighters"), "no raw opponent state")
	var opp_rolled: Array = v.log.filter(func(e): return e.t == "rolled" and e.player == 0)
	check(opp_rolled.all(func(e): return e.dice.is_empty()), "opponent's roll events are blank")
	var p := place(s, 0, "strike", [0, 1])
	var dv := DDView.get_player_view(p, 1)
	eq(dv.opponent.placed_count, 2, "defender sees how many dice were placed")
	check(not JSON.stringify(dv).contains("\"strike\""), "defender can't see the attack move")
	eq(DDView.get_player_view(p, 0).me.placement.move, "strike", "attacker sees their own move")
	var r := act(s, {"type": "reroll", "player": 0, "die_id": "A-d1"})
	var rr: Array = DDView.get_player_view(r, 1).log.filter(func(e): return e.t == "rerolled")
	check(rr.size() == 1 and not rr[0].has("face_index"), "opponent's reroll result is hidden")
	var own: Array = DDView.get_player_view(r, 0).log.filter(func(e): return e.t == "rerolled")
	check(own[0].has("face_index"), "own reroll result is visible")
	var rv := force(battle("warrior", "ninja"), 0, [3, 4, 1])
	rv = place(rv, 0, "slash", [0, 1])
	rv = place(rv, 1, "guard", [0])
	eq(DDView.get_player_view(rv, 1).reveal.attack_move, "slash", "after the reveal both sides see it")


func _replay_tests() -> void:
	section("replay")
	var cfg := {"seed": 777, "fighters": [DDBattle.create_character("A", "thief"), DDBattle.create_character("B", "ninja")]}
	var final := DDMatch.run_ai_match(cfg, ["aggressive", "bluffer"], 99)
	check(var_to_str(DDReplay.replay(DDReplay.to_replay(final))) == var_to_str(final), "config + actions rebuild the same state")
	eq(DDReplay.replay(DDReplay.to_replay(final), 3).actions.size(), 3, "replay can stop at any step")
	var back := DDReplay.from_json(DDReplay.to_json(DDReplay.to_replay(final)))
	check(var_to_str(DDReplay.replay(back)) == var_to_str(final), "replay survives JSON")
	var cfg2 := {"seed": 5, "fighters": [DDBattle.create_character("A", "warrior"), DDBattle.create_character("B", "cleric")]}
	check(var_to_str(DDMatch.run_ai_match(cfg2, ["bluffer", "aggressive"], 3)) == var_to_str(DDMatch.run_ai_match(cfg2, ["bluffer", "aggressive"], 3)), "same seed = same AI decisions")


func _ai_tests() -> void:
	section("AI")
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	var ok := true
	for i in 200:
		var jobs := [DDJobs.IDS[rng.randi_range(0, 4)], DDJobs.IDS[rng.randi_range(0, 4)]]
		var s := DDMatch.run_ai_match({"seed": rng.randi(), "fighters": [DDBattle.create_character("A", jobs[0]), DDBattle.create_character("B", jobs[1])]},
			[DDAi.PERSONALITIES[rng.randi_range(0, 1)], DDAi.PERSONALITIES[rng.randi_range(0, 1)]], rng.randi())
		ok = ok and s.phase == "over"
	check(ok, "200 AI matches (all jobs) finish with legal moves")
	var ok2 := true
	for i in 60:
		var fighters := []
		for id in ["A", "B"]:
			var c := DDBattle.create_character(id, DDJobs.IDS[rng.randi_range(0, 4)])
			c.dice[0] = DDBattle.create_die(id + "-x", "heavy", [S("wild"), S("skull"), S("sword"), S("shield"), F.num(2), S("wild")])
			c.dice[1] = DDBattle.create_die(id + "-q", "quick")
			c.dice[1].die_runes.append("twin")
			c.dice[2].face_runes[4] = "spark"
			fighters.append(c)
		var s := DDMatch.run_ai_match({"seed": rng.randi(), "fighters": fighters}, ["aggressive", "bluffer"], rng.randi())
		ok2 = ok2 and s.phase == "over"
	check(ok2, "AI handles special faces, bodies and runes")


func _meta_tests() -> void:
	section("outside-battle systems")
	var c := DDBattle.create_character("A", "thief")
	var d := DDMeta.deface_face(c, 0, 5)
	check(d.dice[0].faces[5].k == "skull" and c.dice[0].faces[5].k == "num", "defaceFace turns a face into a skull (pure)")
	check(DDMeta.deface_face(c, 9, 0).is_empty() and DDMeta.deface_face(c, 0, 6).is_empty(), "defaceFace checks indexes")
	eq(DDMeta.upgrade_face(c, 1, 0, S("sword")).dice[1].faces[0].k, "sword", "upgradeFace")
	var w := DDBattle.create_character("W", "thief")
	var l := DDBattle.create_character("L", "thief")
	l.dice[0].die_runes.append("twin")
	l.dice[1].face_runes[2] = "spark"
	var r1 := DDMeta.steal_rune(w, l, "twin")
	check(r1.loser.dice[0].die_runes.is_empty() and r1.winner.rune_bag == ["twin"], "stealRune from a die")
	var r2 := DDMeta.steal_rune(r1.winner, r1.loser, "spark")
	check(r2.loser.dice[1].face_runes[2] == "" and r2.winner.rune_bag == ["twin", "spark"], "stealRune from a face")
	check(DDMeta.steal_rune(r2.winner, r2.loser, "twin").is_empty(), "stealRune fails when the loser has none")
	var players := [DDBattle.create_character("A", "thief"), DDBattle.create_character("B", "thief"), DDBattle.create_character("C", "thief")]
	var out := DDMeta.give_underdog_die(players, [10, 3, 7])
	check(out[1].dice.size() == 4 and out[0].dice.size() == 3 and out[2].dice.size() == 3, "Underdog Die goes to last place")
	var faces: Array = out[1].dice[3].faces
	check(faces.size() == 6 and faces[4].k == "wild" and faces[5].k == "wild" and faces[3].v == 4, "Underdog Die = [1,2,3,4,wild,wild]")
	eq(DDMeta.give_underdog_die(out, [10, 3, 7])[1].dice.size(), 4, "Underdog Die is not given twice")

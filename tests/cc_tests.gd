extends SceneTree
## Unit test ของระบบต่อสู้ช่องเช็ค:  Godot --headless --path . --script res://tests/cc_tests.gd
## สเตตัส 100 + Focus 1 = โอกาสผ่าน 100% ใช้บังคับผลให้แน่นอนใน test

var _passed := 0
var _failed := 0
var _section := ""
const NO_DEF := {"none": 1}


func _init() -> void:
	_formulas()
	_turns()
	_focus()
	_effects()
	_defense_turn()
	_items_and_flee()
	_end_and_replay()
	_ai()
	print("\nCheck combat tests: %d passed, %d failed" % [_passed, _failed])
	quit(1 if _failed > 0 else 0)


func section(n: String) -> void:
	_section = n
	print("- ", n)


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
	check(ok, what if ok else "%s  (got %s, expected %s)" % [what, actual, expected])


func unit(stats: Dictionary, job := "", guarding := false) -> Dictionary:
	return {"name": "U", "job": job, "stats": stats, "hp": stats.hp, "max_hp": stats.hp, "focus": 0,
		"guarding": guarding, "stunned": false, "burn": 0, "burn_damage": 0}


func st(hp: int, atk: int, def: int, mag: int, spd: int) -> Dictionary:
	return {"hp": hp, "atk": atk, "def": def, "mag": mag, "spd": spd}


func battle(job: String, hero_stats: Dictionary, mon_stats: Dictionary, mon_actions := {"attack": 1}, items := [], seed := 1, mon_def := NO_DEF) -> Dictionary:
	return CCBattle.create_battle({"seed": seed,
		"hero": {"name": "Hero", "job": job, "stats": hero_stats, "items": items},
		"monster": {"name": "Mon", "stats": mon_stats, "actions": mon_actions, "defense": mon_def, "gold": 100}})


func act(s: Dictionary, a: Dictionary) -> Dictionary:
	var r := CCBattle.apply_action(s, a)
	check(r.error == "", "unexpected error: %s" % r.error)
	return r.state


func err(s: Dictionary, a: Dictionary) -> bool:
	return CCBattle.apply_action(s, a).error != ""


func events(s: Dictionary, t: String, from := 0) -> Array:
	return s.log.slice(from).filter(func(e): return e.t == t)


# ================================================================
func _formulas() -> void:
	section("formulas")
	eq(CCBattle.chance(0), 0.40, "chance at stat 0")
	eq(CCBattle.chance(6), 0.55, "chance at stat 6")
	eq(CCBattle.chance(100), CCBalance.CHANCE_MAX / 100.0, "chance capped without Focus")
	eq(CCBattle.chance(-100), CCBalance.CHANCE_MIN / 100.0, "chance floor")
	eq(CCBattle.chance(0, 2), (40 + 2 * CCBalance.FOCUS_CHANCE_BONUS) / 100.0, "Focus adds % per point")
	eq(CCBattle.chance(100, 1), CCBalance.CHANCE_MAX_WITH_FOCUS / 100.0, "Focus can push past the normal cap")
	var a := unit(st(30, 10, 4, 10, 5))
	var t := unit(st(30, 0, 4, 6, 5))
	var am: float = CCBalance.ACTIONS.attack.mult
	var phys := 4 * CCBalance.PHYS_REDUCE_PER_DEF
	eq(CCBattle.damage_for(a, t, "attack", 0), 0, "0 successes = miss")
	eq(CCBattle.damage_for(a, t, "attack", 2), maxi(1, floori(10 * am * 2 / 3.0 - phys)), "damage scales with successes")
	eq(CCBattle.damage_for(a, t, "attack", 3), floori(10 * am * CCBalance.CRIT_MULT - phys), "perfect attack = critical")
	eq(CCBattle.damage_for(a, t, "spell", 2), floori(10 * CCBalance.ACTIONS.spell.mult), "perfect spell ignores resist")
	eq(CCBattle.damage_for(a, unit(st(30, 0, 100, 100, 5)), "attack", 1), CCBalance.MIN_DAMAGE_ON_HIT, "a hit deals at least the minimum")
	eq(CCBattle.damage_for(a, unit(st(30, 0, 4, 6, 5), "", true), "attack", 3), floori(floori(10 * am * CCBalance.CRIT_MULT - phys) * CCBalance.GUARD_DAMAGE_MULT), "Guard halves")
	# วิธีป้องกัน
	eq(CCBattle.defense_effect(t, a, "block", 0).mult, 1.0, "Block 0/2 = no cut")
	eq(CCBattle.defense_effect(t, a, "block", 1).mult, 1.0 - CCBalance.BLOCK_CUT_PER_SUCCESS, "Block 1/2")
	var b2 := CCBattle.defense_effect(t, a, "block", 2)
	check(is_equal_approx(b2.mult, 1.0 - 2 * CCBalance.BLOCK_CUT_PER_SUCCESS) and b2.focus == 1, "Block 2/2 cuts more and gives Focus")
	check(CCBattle.defense_effect(t, a, "dodge", 1).dodged, "Dodge pass = no damage")
	eq(CCBattle.defense_effect(t, a, "dodge", 0).mult, CCBalance.DODGE_FAIL_MULT, "Dodge fail = take more")
	var c1 := CCBattle.defense_effect(a, t, "counter", 1)
	check(c1.mult == 1.0 and c1.counter == maxi(1, floori(10 * CCBalance.COUNTER_POWER_MULT * 0.5 - phys)), "Counter 1/2 strikes back, full damage taken")
	eq(CCBattle.defense_effect(a, t, "counter", 2).mult, CCBalance.COUNTER_PERFECT_DAMAGE_MULT, "Counter perfect halves damage")
	eq(CCBattle.defense_effect(a, t, "counter", 0).counter, 0, "Counter 0/2 doesn't strike back")
	eq(CCBattle.apply_mult(10, 0.0), 0, "mult 0 = no damage")
	eq(CCBattle.apply_mult(1, 0.4), CCBalance.MIN_DAMAGE_ON_HIT, "a cut hit still deals the minimum")
	eq(CCBattle.defense_stat("block", "spell"), "mag", "Block checks MAG against magic")
	eq(CCBattle.defense_stat("block", "attack"), "def", "Block checks DEF against physical")
	check(CCBattle.skills_for({"job": "Mage"}) == ["attack", "spell", "fireball"], "Mage skills")


func _turns() -> void:
	section("turn order")
	var s := battle("Fighter", st(30, 10, 5, 5, 8), st(30, 5, 0, 1, 5))
	check(CCBattle.current(s) == CCBattle.HERO and CCBattle.phase(s) == "act", "faster hero acts first")
	var tie := battle("Fighter", st(30, 10, 5, 5, 5), st(30, 5, 0, 1, 5))
	eq(CCBattle.phase(tie), "act", "speed tie: hero first")
	var slow := battle("Fighter", st(30, 10, 5, 5, 3), st(30, 5, 0, 1, 9))
	check(CCBattle.phase(slow) == "defend" and slow.pending.skill == "attack", "faster monster announces its attack first")
	eq(events(slow, "intent").size(), 1, "intent is logged so the player sees what's coming")
	check(err(slow, {"type": "skill", "skill": "attack", "focus": 0}), "must defend before acting")
	check(err(s, {"type": "defend", "defense": "block", "focus": 0}), "can't defend on your own turn")
	check(err(s, {"type": "skill", "skill": "fireball", "focus": 0}), "Fighter can't Fireball")
	var g := act(s, {"type": "guard"})
	eq(g.units[0].focus, mini(CCBalance.FOCUS_MAX, CCBalance.FOCUS_START + CCBalance.FOCUS_ON_GUARD), "Guard gives Focus")
	eq(CCBattle.phase(g), "defend", "after your turn the monster attacks and you defend")


func _focus() -> void:
	section("focus = +% chance")
	var s := battle("Fighter", st(30, 100, 5, 5, 8), st(500, 1, 0, 1, 5))
	var a := act(s, {"type": "skill", "skill": "attack", "focus": 1})
	var c: Dictionary = events(a, "check")[0]
	check(is_equal_approx(c.chance, 1.0) and c.slots == [1, 1, 1] and c.perfect, "Focus raises every slot's chance")
	eq(a.units[0].focus, CCBalance.FOCUS_START - 1, "Focus spent")
	check(err(s, {"type": "skill", "skill": "attack", "focus": 9}), "can't spend more Focus than you have")
	var m := battle("Mage", st(30, 5, 5, 10, 8), st(200, 1, 0, 1, 5))
	check(err(m, {"type": "skill", "skill": "fireball", "focus": CCBalance.FOCUS_START}), "job skill costs Focus on top of the % boost")


func _effects() -> void:
	section("perfect bonuses")
	var f := battle("Fighter", st(30, 100, 5, 5, 8), st(500, 1, 0, 1, 5))
	var hb := act(f, {"type": "skill", "skill": "heavy_blow", "focus": 1})
	check(events(hb, "effect").any(func(e): return e.effect == "stun"), "Heavy Blow perfect stuns")
	check(events(hb, "stunned").size() == 1 and events(hb, "intent").is_empty(), "stunned monster skips its turn")
	eq(CCBattle.phase(hb), "act", "back to the hero")

	var m := battle("Mage", st(30, 5, 5, 100, 8), st(1000, 1, 0, 9, 5), {"guard": 1})
	var fb := act(m, {"type": "skill", "skill": "fireball", "focus": 1})
	eq(events(fb, "damage")[0].amount, floori(100 * CCBalance.ACTIONS.fireball.mult), "Fireball perfect ignores resist")
	var burns: Array = events(fb, "damage").filter(func(e): return e.cause == "burn")
	check(burns.size() == 1 and burns[0].amount == 50, "burn ticks at the monster's turn (MAG x 0.5)")

	var r := battle("Rogue", st(30, 10, 5, 5, 100), st(200, 1, 0, 1, 5), {"guard": 1})
	var ts := act(r, {"type": "skill", "skill": "twin_stab", "focus": 1})
	eq(events(ts, "damage").size(), 2, "Twin Stab perfect hits twice")
	eq(ts.stolen_gold, 25, "Twin Stab perfect steals 25% of the gold reward")


func _defense_turn() -> void:
	section("defense turn")
	var base := battle("Fighter", st(600, 100, 100, 100, 60), st(500, 100, 0, 1, 100))
	check(CCBattle.phase(base) == "defend", "setup: monster attacks first")
	var d := act(base, {"type": "defend", "defense": "dodge", "focus": 1})
	var mon_check: Dictionary = events(d, "check")[0]
	if mon_check.successes > 0:
		check(events(d, "dodge").size() == 1 and events(d, "damage").is_empty(), "Dodge with 100% = no damage")
	eq(d.units[0].focus, CCBalance.FOCUS_START - 1, "defense Focus is spent")
	eq(CCBattle.phase(d), "act", "after defending it's the hero's turn")

	var b := act(base, {"type": "defend", "defense": "block", "focus": 1})
	var bc: Array = events(b, "check")
	var hits: Array = events(b, "damage")
	if bc[0].successes > 0:
		var hero := unit(st(600, 100, 100, 100, 60))
		var want := CCBattle.apply_mult(CCBattle.damage_for(b.units[1], hero, "attack", bc[0].successes), 1.0 - 2 * CCBalance.BLOCK_CUT_PER_SUCCESS)
		check(bc.size() == 2 and bc[1].defense and bc[1].successes == 2, "Block rolls its own check")
		eq(hits[0].amount, want, "perfect Block cuts 60%")
		check(events(b, "effect").any(func(e): return e.effect == "focus"), "perfect Block gives Focus")

	var c := act(base, {"type": "defend", "defense": "counter", "focus": 1})
	if events(c, "check")[0].successes > 0:
		var back: Array = events(c, "damage").filter(func(e): return e.cause == "counter")
		check(back.size() == 1 and back[0].unit == CCBattle.MONSTER and back[0].amount == floori(100 * CCBalance.COUNTER_POWER_MULT), "Counter strikes back")

	var mag := battle("Fighter", st(60, 1, 0, 100, 1), st(500, 1, 0, 100, 9), {"spell": 1})
	var w := act(mag, {"type": "defend", "defense": "block", "focus": 0})
	var wc: Array = events(w, "check")
	if wc.size() == 2:
		eq(wc[1].chance, CCBattle.chance(100), "Block uses MAG against a spell")

	# มอนสเตอร์ก็ป้องกันด้วย
	var md := battle("Fighter", st(30, 10, 5, 5, 8), st(500, 1, 0, 1, 100), {"guard": 1}, [], 2, {"dodge": 1})
	var hit := act(md, {"type": "skill", "skill": "attack", "focus": 2})
	var mc: Array = events(hit, "check")
	if mc[0].successes > 0:
		check(mc.size() == 2 and mc[1].unit == CCBattle.MONSTER and mc[1].skill == "dodge", "monster rolls its defense")


func _items_and_flee() -> void:
	section("items & flee")
	var bag := ["Herb", "Power Tonic", "Iron Tonic", "Fire Bomb", "Poison Dart", "Smoke Ball"]
	# ตาบุก: แฮโร่เร็วกว่า มอนสเตอร์ตีเบา
	var atk := battle("Mage", st(40, 5, 5, 10, 8), st(200, 1, 0, 1, 5), {"guard": 1}, bag)
	check(err(atk, {"type": "item", "item": "Herb"}), "Herb is not for the attack turn")
	check(err(atk, {"type": "item", "item": "Power Tonic"}), "buff items are not for the attack turn")
	check(err(atk, {"type": "item", "item": "Big Herb"}), "can't use an item you don't have")
	var bomb := act(atk, {"type": "item", "item": "Fire Bomb"})
	var bd: Array = events(bomb, "damage")
	check(bd.size() == 1 and bd[0].unit == CCBattle.MONSTER and bd[0].amount == 12 and bd[0].cause == "item", "Fire Bomb always deals 12")
	check(not bomb.items.has("Fire Bomb"), "item is used up")
	var dart := act(atk, {"type": "item", "item": "Poison Dart"})
	var ticks: Array = events(dart, "damage").filter(func(e): return e.cause == "burn")
	check(ticks.size() == 1 and ticks[0].amount == 4 and dart.units[1].burn == 2, "Poison Dart: 4 damage per turn for 3 turns")
	eq(act(atk, {"type": "item", "item": "Smoke Ball"}).result, "run", "Smoke Ball works on the attack turn")
	eq(act(battle("Mage", st(40, 5, 5, 10, 100), st(200, 1, 0, 1, 5)), {"type": "flee", "focus": 1}).result, "run", "Flee on the attack turn")
	check(err(atk, {"type": "defend", "defense": "block", "focus": 0}), "can't defend on the attack turn")

	# ตาป้องกัน: มอนสเตอร์เร็วกว่าและประกาศโจมตี
	var dfn := battle("Fighter", st(400, 5, 5, 5, 1), st(200, 30, 0, 1, 9), {"attack": 1}, bag)
	dfn.units[0].hp = 100
	check(CCBattle.phase(dfn) == "defend", "setup: defense turn")
	check(err(dfn, {"type": "item", "item": "Fire Bomb"}), "attack items are not for the defense turn")
	var h := act(dfn, {"type": "item", "item": "Herb"})
	var he: Dictionary = events(h, "item")[0]
	var taken := 0
	for e in events(h, "damage"):
		taken += e.amount
	check(he.heal == 20 and h.units[0].hp == 120 - taken, "Herb heals 20 before the hit")
	check(events(h, "check").all(func(e): return not e.get("defense", false)), "using an item gives up the defense roll")
	var tonic := act(dfn, {"type": "item", "item": "Power Tonic"})
	check(tonic.units[0].stats.atk == 9 and tonic.units[0].stats.mag == 9, "Power Tonic: ATK/MAG +4 for the battle")
	eq(act(dfn, {"type": "item", "item": "Iron Tonic"}).units[0].stats.def, 10, "Iron Tonic: DEF +5")
	var smoke := act(dfn, {"type": "item", "item": "Smoke Ball"})
	check(smoke.result == "run" and events(smoke, "damage").is_empty(), "Smoke Ball escapes before the hit")
	var full := act(battle("Fighter", st(40, 5, 100, 5, 1), st(200, 1, 0, 1, 9), {"attack": 1}, ["Herb"]), {"type": "item", "item": "Herb"})
	check(full.units[0].hp <= 40, "heal can't go over max HP")

	var fast := battle("Fighter", st(400, 5, 5, 5, 60), st(200, 30, 0, 1, 100))
	var away := act(fast, {"type": "flee", "focus": 1})
	check(away.result == "run" and events(away, "damage").is_empty(), "Flee on the defense turn escapes before the hit")
	var slow := battle("Fighter", st(400, 5, 5, 5, -100), st(200, 100, 0, 1, 9))
	var stuck := act(slow, {"type": "flee", "focus": 0})
	if stuck.result != "run":
		check(events(stuck, "flee_failed").size() == 1 and events(stuck, "check").filter(func(e): return e.unit == CCBattle.MONSTER).size() == 1,
			"failed flee: the monster's attack lands with no defense")


func _end_and_replay() -> void:
	section("end & replay")
	var w := act(battle("Fighter", st(30, 100, 5, 5, 8), st(5, 1, 0, 1, 5)), {"type": "skill", "skill": "attack", "focus": 1})
	eq(w.result, "win", "monster at 0 HP = win")
	check(err(w, {"type": "guard"}), "no actions after the end")
	var l := battle("Fighter", st(30, 1, 0, 1, 1), st(200, 100, 0, 1, 9), {"attack": 1}, [], 3)
	for i in 40:
		if l.result != "":
			break
		l = act(l, {"type": "defend", "defense": "block", "focus": 0} if CCBattle.phase(l) == "defend" else {"type": "guard"})
	eq(l.result, "lose", "hero at 0 HP = lose")
	var r := battle("Rogue", st(40, 9, 5, 6, 8), st(60, 12, 6, 8, 7), {"attack": 2, "spell": 1, "guard": 1}, ["Herb"], 77, {"block": 1, "dodge": 1, "counter": 1})
	while r.result == "":
		r = act(r, CCAi.choose(r))
	check(var_to_str(CCBattle.replay(r.config, r.actions)) == var_to_str(r), "config + actions rebuild the same battle")
	eq(CCBattle.replay(r.config, r.actions, 1).actions.size(), 1, "replay stops at any step")


func _ai() -> void:
	section("AI")
	var ok := true
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	for job in CCBalance.JOB_SKILL:
		for mon in GameData.MONSTERS:
			for i in 10:
				var p := PlayerStats.new()
				p.change_job(job)
				p.hp = p.max_hp()
				var s := CCBattle.create_battle(CCBridge.config(p, mon, rng.randi()))
				var n := 0
				while s.result == "" and n < 300:
					var r := CCBattle.apply_action(s, CCAi.choose(s))
					ok = ok and r.error == ""
					s = r.state
					n += 1
				ok = ok and s.result != ""
	check(ok, "AI finishes every job vs every monster with legal actions (attack + defense)")

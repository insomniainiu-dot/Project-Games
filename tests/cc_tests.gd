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
	_jobs()
	_passive_mods()
	_crit()
	_weapons_and_gems()
	_uniques()
	_tiers()
	_save()
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
	check(CCBattle.skills_for({"job": "Psion"}) == ["attack", "spell", "fireball"], "Psion skills")


func _turns() -> void:
	section("turn order")
	var s := battle("Vanguard", st(30, 10, 5, 5, 8), st(30, 5, 0, 1, 5))
	check(CCBattle.current(s) == CCBattle.HERO and CCBattle.phase(s) == "act", "faster hero acts first")
	var tie := battle("Vanguard", st(30, 10, 5, 5, 5), st(30, 5, 0, 1, 5))
	eq(CCBattle.phase(tie), "act", "speed tie: hero first")
	var slow := battle("Vanguard", st(30, 10, 5, 5, 3), st(30, 5, 0, 1, 9))
	check(CCBattle.phase(slow) == "defend" and slow.pending.skill == "attack", "faster monster announces its attack first")
	eq(events(slow, "intent").size(), 1, "intent is logged so the player sees what's coming")
	check(err(slow, {"type": "skill", "skill": "attack", "focus": 0}), "must defend before acting")
	check(err(s, {"type": "defend", "defense": "block", "focus": 0}), "can't defend on your own turn")
	check(err(s, {"type": "skill", "skill": "fireball", "focus": 0}), "Vanguard can't Fireball")
	var g := act(s, {"type": "guard"})
	eq(g.units[0].focus, mini(CCBalance.FOCUS_MAX, CCBalance.FOCUS_START + CCBalance.FOCUS_ON_GUARD), "Guard gives Focus")
	eq(CCBattle.phase(g), "defend", "after your turn the monster attacks and you defend")


func _focus() -> void:
	section("focus = +% chance")
	var s := battle("Vanguard", st(30, 100, 5, 5, 8), st(500, 1, 0, 1, 5))
	var a := act(s, {"type": "skill", "skill": "attack", "focus": 1})
	var c: Dictionary = events(a, "check")[0]
	check(is_equal_approx(c.chance, 1.0) and c.slots == [1, 1, 1] and c.perfect, "Focus raises every slot's chance")
	eq(a.units[0].focus, CCBalance.FOCUS_START - 1, "Focus spent")
	check(err(s, {"type": "skill", "skill": "attack", "focus": 9}), "can't spend more Focus than you have")
	var m := battle("Psion", st(30, 5, 5, 10, 8), st(200, 1, 0, 1, 5))
	check(err(m, {"type": "skill", "skill": "fireball", "focus": CCBalance.FOCUS_START}), "job skill costs Focus on top of the % boost")


func _effects() -> void:
	section("perfect bonuses")
	var f := battle("Vanguard", st(30, 100, 5, 5, 8), st(500, 1, 0, 1, 5))
	var hb := act(f, {"type": "skill", "skill": "heavy_blow", "focus": 1})
	check(events(hb, "effect").any(func(e): return e.effect == "stun"), "Heavy Blow perfect stuns")
	check(events(hb, "stunned").size() == 1 and events(hb, "intent").is_empty(), "stunned monster skips its turn")
	eq(CCBattle.phase(hb), "act", "back to the hero")

	var m := battle("Psion", st(30, 5, 5, 100, 8), st(1000, 1, 0, 9, 5), {"guard": 1})
	var fb := act(m, {"type": "skill", "skill": "fireball", "focus": 1})
	eq(events(fb, "damage")[0].amount, floori(100 * CCBalance.ACTIONS.fireball.mult), "Fireball perfect ignores resist")
	var burns: Array = events(fb, "damage").filter(func(e): return e.cause == "burn")
	check(burns.size() == 1 and burns[0].amount == 50, "burn ticks at the monster's turn (MAG x 0.5)")

	var r := battle("Infiltrator", st(30, 10, 5, 5, 100), st(200, 1, 0, 1, 5), {"guard": 1})
	var ts := act(r, {"type": "skill", "skill": "twin_stab", "focus": 1})
	eq(events(ts, "damage").size(), 2, "Twin Stab perfect hits twice")
	eq(ts.stolen_gold, 25, "Twin Stab perfect steals 25% of the gold reward")
	_new_job_skills()


func _new_job_skills() -> void:
	section("Charged Shot + Deploy Drone (T-059)")
	# Charged Shot: Perfect ไม่สน ARM, ไม่ Perfect โดนลดตามปกติ
	var a := unit(st(30, 10, 4, 10, 5))
	var t := unit(st(30, 0, 20, 6, 5))
	var cm: float = CCBalance.ACTIONS.charged_shot.mult
	eq(CCBattle.damage_for(a, t, "charged_shot", 4), floori(10 * cm), "Charged Shot perfect ignores ARM")
	eq(CCBattle.damage_for(a, t, "charged_shot", 3), maxi(1, floori(10 * cm * 3 / 4.0 - 20 * CCBalance.PHYS_REDUCE_PER_DEF)), "Charged Shot 3/4 is reduced by ARM")
	eq(CCBattle.skills_for({"job": "Marksman"}), ["attack", "spell", "charged_shot"], "Marksman skills")
	eq(CCBattle.skills_for({"job": "Engineer"}), ["attack", "spell", "deploy_drone"], "Engineer skills")

	# Deploy Drone: ศัตรูป้องกันไม่ได้, ไม่ตีตรง ๆ, Perfect = 5 ตา
	# มอนสเตอร์แค่ Guard → apply_action เดินต่อจนถึงต้นตาถัดไปของฮีโร่ = โดรนยิงนัดแรกไปแล้วใน state ที่ได้
	var e := battle("Engineer", st(400, 5, 5, 100, 8), st(1000, 1, 0, 1, 5), {"guard": 1}, [], 1, {"block": 1})
	var dd := act(e, {"type": "skill", "skill": "deploy_drone", "focus": 1})
	var per := floori(100 * CCBalance.DRONE_DAMAGE_PER_MAG)
	check(events(dd, "check").size() == 1, "monster can't defend a drone deploy")
	var fx: Array = events(dd, "effect").filter(func(x): return x.effect == "drone")
	check(fx.size() == 1 and fx[0].turns == CCBalance.DRONE_TURNS_PERFECT, "perfect deploy = 5 turns")
	var shots: Array = events(dd, "damage")
	check(shots.size() == 1 and shots[0].cause == "drone" and shots[0].amount == per and shots[0].unit == CCBattle.MONSTER,
		"no direct hit; drone fires at the start of the owner's next turn (TEC x %s)" % CCBalance.DRONE_DAMAGE_PER_MAG)
	eq(dd.units[0].drone, CCBalance.DRONE_TURNS_PERFECT - 1, "drone turns count down")
	eq(dd.units[0].focus, CCBalance.FOCUS_START - 1 - 1, "drone costs 1 Focus + focus spent")
	var g := act(act(dd, {"type": "guard"}), {"type": "guard"})
	eq(g.units[0].drone, CCBalance.DRONE_TURNS_PERFECT - 3, "one shot per turn")
	# ปล่อยซ้ำ = รีเซ็ต ไม่ซ้อน
	var again := act(g, {"type": "skill", "skill": "deploy_drone", "focus": 1})
	eq(again.units[0].drone, CCBalance.DRONE_TURNS_PERFECT - 1, "redeploy refreshes turns (no stacking)")
	# ผ่านแค่ 1/2 = 3 ตา, 0/2 = ไม่มีโดรน
	var got := -1
	var missed := false
	for sd in 60:
		var w := battle("Engineer", st(400, 5, 5, 0, 8), st(1000, 1, 0, 1, 5), {"guard": 1}, [], sd)
		var r := act(w, {"type": "skill", "skill": "deploy_drone", "focus": 0})
		var c: int = events(r, "check")[0].successes
		if c == 1 and got < 0:
			got = events(r, "effect").filter(func(x): return x.effect == "drone")[0].turns
		if c == 0 and not missed:
			missed = true
			check(r.units[0].drone == 0 and events(r, "miss").size() == 1, "0/2 = no drone")
	eq(got, CCBalance.DRONE_TURNS, "1/2 deploy = 3 turns")
	check(missed, "found a 0/2 deploy to test")
	# โดรนฆ่าศัตรูได้
	var kill := act(battle("Engineer", st(400, 5, 5, 100, 8), st(per, 1, 0, 1, 5), {"guard": 1}), {"type": "skill", "skill": "deploy_drone", "focus": 1})
	eq(kill.result, "win", "drone damage can win the battle")
	# replay ยังตรง
	var rp := CCBattle.replay(e.config, again.actions)
	eq(rp.units[1].hp, again.units[1].hp, "replay matches with drones")
	# AI: โดรนใหม่คุ้มกว่าปล่อยซ้ำตอนโดรนยังเหลือหลายตา
	check(CCAi.drone_value(e, "deploy_drone", 1) > CCAi.drone_value(dd, "deploy_drone", 1), "AI values a fresh drone more than a redeploy")


func _defense_turn() -> void:
	section("defense turn")
	var base := battle("Vanguard", st(600, 100, 100, 100, 60), st(500, 100, 0, 1, 100))
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

	var mag := battle("Vanguard", st(60, 1, 0, 100, 1), st(500, 1, 0, 100, 9), {"spell": 1})
	var w := act(mag, {"type": "defend", "defense": "block", "focus": 0})
	var wc: Array = events(w, "check")
	if wc.size() == 2:
		eq(wc[1].chance, CCBattle.chance(100), "Block uses MAG against a spell")

	# มอนสเตอร์ก็ป้องกันด้วย
	var md := battle("Vanguard", st(30, 10, 5, 5, 8), st(500, 1, 0, 1, 100), {"guard": 1}, [], 2, {"dodge": 1})
	var hit := act(md, {"type": "skill", "skill": "attack", "focus": 2})
	var mc: Array = events(hit, "check")
	if mc[0].successes > 0:
		check(mc.size() == 2 and mc[1].unit == CCBattle.MONSTER and mc[1].skill == "dodge", "monster rolls its defense")


func _items_and_flee() -> void:
	section("items & flee")
	var bag := ["Medkit", "Stim Shot", "Armor Gel", "Plasma Grenade", "Toxin Dart", "Smoke Bomb"]
	# ตาบุก: แฮโร่เร็วกว่า มอนสเตอร์ตีเบา
	var atk := battle("Psion", st(40, 5, 5, 10, 8), st(200, 1, 0, 1, 5), {"guard": 1}, bag)
	check(err(atk, {"type": "item", "item": "Medkit"}), "Herb is not for the attack turn")
	check(err(atk, {"type": "item", "item": "Stim Shot"}), "buff items are not for the attack turn")
	check(err(atk, {"type": "item", "item": "Big Medkit"}), "can't use an item you don't have")
	var bomb := act(atk, {"type": "item", "item": "Plasma Grenade"})
	var bd: Array = events(bomb, "damage")
	check(bd.size() == 1 and bd[0].unit == CCBattle.MONSTER and bd[0].amount == 12 and bd[0].cause == "item", "Fire Bomb always deals 12")
	check(not bomb.items.has("Plasma Grenade"), "item is used up")
	var dart := act(atk, {"type": "item", "item": "Toxin Dart"})
	var ticks: Array = events(dart, "damage").filter(func(e): return e.cause == "burn")
	check(ticks.size() == 1 and ticks[0].amount == 4 and dart.units[1].burn == 2, "Poison Dart: 4 damage per turn for 3 turns")
	eq(act(atk, {"type": "item", "item": "Smoke Bomb"}).result, "run", "Smoke Ball works on the attack turn")
	eq(act(battle("Psion", st(40, 5, 5, 10, 100), st(200, 1, 0, 1, 5)), {"type": "flee", "focus": 1}).result, "run", "Flee on the attack turn")
	check(err(atk, {"type": "defend", "defense": "block", "focus": 0}), "can't defend on the attack turn")

	# ตาป้องกัน: มอนสเตอร์เร็วกว่าและประกาศโจมตี
	var dfn := battle("Vanguard", st(400, 5, 5, 5, 1), st(200, 30, 0, 1, 9), {"attack": 1}, bag)
	dfn.units[0].hp = 100
	check(CCBattle.phase(dfn) == "defend", "setup: defense turn")
	check(err(dfn, {"type": "item", "item": "Plasma Grenade"}), "attack items are not for the defense turn")
	var h := act(dfn, {"type": "item", "item": "Medkit"})
	var he: Dictionary = events(h, "item")[0]
	var taken := 0
	for e in events(h, "damage"):
		taken += e.amount
	check(he.heal == 20 and h.units[0].hp == 120 - taken, "Herb heals 20 before the hit")
	check(events(h, "check").all(func(e): return not e.get("defense", false)), "using an item gives up the defense roll")
	var tonic := act(dfn, {"type": "item", "item": "Stim Shot"})
	check(tonic.units[0].stats.atk == 9 and tonic.units[0].stats.mag == 9, "Power Tonic: ATK/MAG +4 for the battle")
	eq(act(dfn, {"type": "item", "item": "Armor Gel"}).units[0].stats.def, 10, "Iron Tonic: DEF +5")
	var smoke := act(dfn, {"type": "item", "item": "Smoke Bomb"})
	check(smoke.result == "run" and events(smoke, "damage").is_empty(), "Smoke Ball escapes before the hit")
	var full := act(battle("Vanguard", st(40, 5, 100, 5, 1), st(200, 1, 0, 1, 9), {"attack": 1}, ["Medkit"]), {"type": "item", "item": "Medkit"})
	check(full.units[0].hp <= 40, "heal can't go over max HP")

	var fast := battle("Vanguard", st(400, 5, 5, 5, 60), st(200, 30, 0, 1, 100))
	var away := act(fast, {"type": "flee", "focus": 1})
	check(away.result == "run" and events(away, "damage").is_empty(), "Flee on the defense turn escapes before the hit")
	var slow := battle("Vanguard", st(400, 5, 5, 5, -100), st(200, 100, 0, 1, 9))
	var stuck := act(slow, {"type": "flee", "focus": 0})
	if stuck.result != "run":
		check(events(stuck, "flee_failed").size() == 1 and events(stuck, "check").filter(func(e): return e.unit == CCBattle.MONSTER).size() == 1,
			"failed flee: the monster's attack lands with no defense")


func _end_and_replay() -> void:
	section("end & replay")
	var w := act(battle("Vanguard", st(30, 100, 5, 5, 8), st(5, 1, 0, 1, 5)), {"type": "skill", "skill": "attack", "focus": 1})
	eq(w.result, "win", "monster at 0 HP = win")
	check(err(w, {"type": "guard"}), "no actions after the end")
	var l := battle("Vanguard", st(30, 1, 0, 1, 1), st(200, 100, 0, 1, 9), {"attack": 1}, [], 3)
	for i in 40:
		if l.result != "":
			break
		l = act(l, {"type": "defend", "defense": "block", "focus": 0} if CCBattle.phase(l) == "defend" else {"type": "guard"})
	eq(l.result, "lose", "hero at 0 HP = lose")
	var r := battle("Infiltrator", st(40, 9, 5, 6, 8), st(60, 12, 6, 8, 7), {"attack": 2, "spell": 1, "guard": 1}, ["Medkit"], 77, {"block": 1, "dodge": 1, "counter": 1})
	while r.result == "":
		r = act(r, CCAi.choose(r))
	check(var_to_str(CCBattle.replay(r.config, r.actions)) == var_to_str(r), "config + actions rebuild the same battle")
	eq(CCBattle.replay(r.config, r.actions, 1).actions.size(), 1, "replay stops at any step")


func _ai() -> void:
	section("AI")
	var ok := true
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	for job in GameData.JOBS:
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


func _jobs() -> void:
	section("jobs (T-058)")
	eq(GameData.JOBS.keys(), ["Vanguard", "Marksman", "Engineer", "Psion", "Infiltrator"], "5 sci-fi jobs")
	var ok := true
	for j in GameData.JOBS:
		var d: Dictionary = GameData.JOBS[j]
		for k in GameData.STAT_KEYS:
			ok = ok and d.base.has(k) and d.grow.has(k)
	check(ok, "every job has base + grow for every stat")
	for j in CCBalance.JOB_SKILL:
		check(GameData.JOBS.has(j), "JOB_SKILL key %s is a real job" % j)
	for j in DDBoardBridge.JOB_MAP:
		check(GameData.JOBS.has(j), "Dice Duel JOB_MAP key %s is a real job" % j)
	var p := PlayerStats.new()
	eq(p.job, GameData.START_JOB, "new player starts as START_JOB")
	eq(p.gold_mult(), 1.0, "no gold bonus by default")
	p.change_job("Infiltrator")
	eq(p.gold_mult(), 1.25, "Infiltrator gold bonus")
	p.change_job("Marksman")
	eq(p.stat("atk"), GameData.JOBS.Marksman.base.atk + GameData.ITEMS[p.weapon].get("atk", 0), "change job recalculates stats")
	eq(p.stat("lck"), GameData.JOBS.Marksman.base.lck, "LCK comes from the job")
	eq(CCBridge.hero_config(p).stats.lck, p.stat("lck"), "bridge passes LCK into battle")
	eq(CCBridge.monster_config("Goblin").stats.lck, 0, "monsters default to LCK 0")
	eq(GameData.stat_label("lck"), "LCK", "LCK label")
	ok = true
	for j in GameData.JOBS:
		var b: Dictionary = GameData.JOBS[j].base
		ok = ok and b.atk + b.def + b.mag + b.spd + b.lck == 28
	check(ok, "every job's starting ATK+ARM+TEC+SPD+LCK = 28")
	ok = true
	for j in GameData.JOBS:
		ok = ok and CCBalance.JOB_SKILL.has(j) and CCBalance.ACTIONS.has(CCBalance.JOB_SKILL[j])
	check(ok, "every job has a job skill")
	eq(CCBalance.ACTIONS.heavy_blow.name, "Breach Strike", "skills use sci-fi names")
	eq(GameData.stat_label("mag"), "TEC", "MAG shows as TEC")
	eq(GameData.stat_label("def"), "ARM", "DEF shows as ARM")
	eq(GameData.stat_text("Servo Bracer"), "ATK+3", "item stat text uses labels")
	eq(GameData.stat_text("Neuro Earpiece"), "TEC+4", "item stat text: TEC")


# ================================================================ LCK / คริ (T-070)
func _crit() -> void:
	section("LCK crit (T-070)")
	eq(CCBattle.crit_chance(unit(st(30, 10, 4, 10, 5))), 0.0, "no lck key = 0% crit")
	var lu := unit(st(30, 10, 4, 10, 5))
	lu.stats.lck = 10
	eq(CCBattle.crit_chance(lu), 10 * CCBalance.CRIT_PER_LCK / 100.0, "LCK 10 = 10% crit")
	lu.stats.lck = 999
	eq(CCBattle.crit_chance(lu), CCBalance.CRIT_CHANCE_MAX / 100.0, "crit chance is capped")
	# ดาเมจ
	var a := unit(st(30, 10, 4, 10, 5))
	var t := unit(st(30, 0, 4, 6, 5))
	var sm: float = CCBalance.ACTIONS.spell.mult
	var am: float = CCBalance.ACTIONS.attack.mult
	var phys := 4 * CCBalance.PHYS_REDUCE_PER_DEF
	eq(CCBattle.damage_for(a, t, "spell", 1, -1, true), maxi(1, floori(10 * sm * 0.5 * CCBalance.CRIT_MULT - 6 * CCBalance.MAGIC_REDUCE_PER_MAG)), "crit x1.5 on a non-Perfect spell")
	eq(CCBattle.damage_for(a, t, "attack", 2, -1, true), maxi(1, floori(10 * am * 2 / 3.0 * CCBalance.CRIT_MULT - phys)), "crit on a 2/3 Attack")
	eq(CCBattle.damage_for(a, t, "attack", 3, -1, true), CCBattle.damage_for(a, t, "attack", 3), "Perfect Attack crit doesn't stack twice")
	eq(CCBattle.damage_for(mu(st(30, 10, 4, 10, 5), {"crit_mult.attack": 1.8}), t, "attack", 2, -1, true), maxi(1, floori(10 * am * 2 / 3.0 * 1.8 - phys)), "Breacher boosts LCK crits on Attack too")
	# ในการต่อสู้: LCK 0 ไม่กิน rng (seed เดิมให้ผลเดิม)
	var h0 := st(500, 10, 0, 10, 5)
	var h1 := h0.duplicate()
	h1.lck = 0
	var b0 := act(battle("Psion", h0, st(500, 1, 0, 0, 1), {"guard": 1}, [], 7), {"type": "skill", "skill": "spell", "focus": 0})
	var b1 := act(battle("Psion", h1, st(500, 1, 0, 0, 1), {"guard": 1}, [], 7), {"type": "skill", "skill": "spell", "focus": 0})
	eq(b1.rng_state, b0.rng_state, "LCK 0 uses no extra random rolls")
	# ในการต่อสู้: LCK สูง → คริราว ๆ เพดาน 50%
	var hits := 0
	var crits := 0
	var crit_dmg_ok := true
	for sd in 300:
		var hs := st(500, 10, 0, 100, 5)
		hs.lck = 1000
		var b := act(battle("Psion", hs, st(5000, 1, 0, 0, 1), {"guard": 1}, [], sd), {"type": "skill", "skill": "spell", "focus": 0})
		var dm: Array = events(b, "damage")
		if dm.is_empty():
			continue
		hits += 1
		var is_crit := events(b, "effect").any(func(e): return e.effect == "crit")
		if is_crit:
			crits += 1
			var chk: Dictionary = events(b, "check")[0]
			crit_dmg_ok = crit_dmg_ok and dm[0].amount == CCBattle.damage_for(b.units[0], {"stats": st(5000, 1, 0, 0, 1), "guarding": false}, "spell", chk.successes, -1, true)
	check(hits > 250 and crits > hits * 0.4 and crits < hits * 0.6, "LCK 1000 crits about 50%% of hits (%d/%d)" % [crits, hits])
	check(crit_dmg_ok, "logged crit hits deal crit damage")


# ================================================================ อาวุธกำหนด Attack + Skill Gem
func _weapons_and_gems() -> void:
	section("weapon attacks + skill gems")
	# ท่า Attack ของแต่ละประเภทอาวุธ
	eq(CCBalance.weapon_attack("melee").slots, CCBalance.ACTIONS.attack.slots, "melee = classic Attack")
	eq(CCBalance.weapon_attack("heavy").slots, 4, "heavy Attack = 4 slots")
	eq(CCBalance.weapon_attack("bow").check, "spd", "bow Attack checks SPD")
	eq(CCBalance.weapon_attack("rod").kind, "magic", "rod Attack is tech")
	eq(CCBalance.weapon_attack("rod").cost, 0, "weapon attacks keep base keys (cost 0)")
	for it in GameData.ITEMS:
		if GameData.ITEMS[it].type == "weapon":
			check(CCBalance.WEAPON_TYPES.has(GameData.weapon_type(it)), "%s has a known weapon type" % it)
	eq(GameData.weapon_type("Medkit"), "", "non-weapons have no weapon type")
	# ดาเมจ / โอกาสตามอาวุธ
	var a := unit(st(30, 10, 4, 20, 9))
	var t := unit(st(30, 0, 4, 6, 5))
	a.attack_def = CCBalance.weapon_attack("rod")
	eq(CCBattle.action_chance(a, "attack"), CCBattle.chance(20), "rod Attack checks TEC")
	eq(CCBattle.damage_for(a, t, "attack", 3), floori(20 * 1.3 * CCBalance.CRIT_MULT - 6 * CCBalance.MAGIC_REDUCE_PER_MAG), "rod Attack: TEC power, resist by TEC")
	eq(CCBattle.defense_stat("block", "attack", a), "mag", "Block vs a rod Attack checks TEC")
	eq(CCBattle.defense_stat("block", "attack"), "def", "Block vs a plain Attack still checks ARM")
	a.attack_def = CCBalance.weapon_attack("bow")
	eq(CCBattle.damage_for(a, unit(st(30, 0, 20, 6, 5)), "attack", 2), floori(10 * CCBalance.weapon_attack("bow").mult), "bow Perfect ignores ARM, no auto-crit")
	# ในการต่อสู้
	var hs := st(400, 100, 5, 5, 8)
	var s := CCBattle.create_battle({"seed": 1, "hero": {"name": "H", "job": "Vanguard", "stats": hs, "attack_def": CCBalance.weapon_attack("heavy"), "gems": ["fireball"]},
		"monster": {"name": "M", "stats": st(5000, 1, 0, 1, 5), "actions": {"guard": 1}, "defense": NO_DEF}})
	eq(CCBattle.skills_for(s.units[0]), ["attack", "fireball"], "skills = Attack + socketed gems")
	check(err(s, {"type": "skill", "skill": "heavy_blow", "focus": 0}), "job skill not socketed = can't use it")
	check(err(s, {"type": "skill", "skill": "spell", "focus": 0}), "Tech Attack is a gem now")
	var h := act(s, {"type": "skill", "skill": "attack", "focus": 1})
	var c: Dictionary = events(h, "check")[0]
	check(c.slots.size() == 4 and c.name == "Cleave", "engine rolls the weapon's Attack (Cleave, 4 slots)")
	eq(CCBattle.replay(s.config, h.actions).units[1].hp, h.units[1].hp, "replay matches with weapon attacks")
	eq(CCBattle.clean_gems(["spell", "spell", "nope", "fireball", "twin_stab"]), ["spell", "fireball"], "gems: known, unique, max 2")
	# PlayerStats
	var p := PlayerStats.new()
	eq(Array(p.gems), CCBalance.default_gems(GameData.START_JOB), "new player starts with Tech Attack + job gem")
	p.change_job("Vanguard")
	eq(Array(p.gems), ["spell", "heavy_blow"], "change job swaps the job gem")
	check(p.gem_bag.has("fireball"), "old job gem goes to the gem bag")
	check(not p.add_gem("fireball"), "can't add a gem you own")
	check(p.add_gem("twin_stab") and p.gem_bag.has("twin_stab"), "new gem goes to the bag when slots are full")
	eq(p.set_gem(0, "twin_stab"), "spell", "swap a gem in, old one back to the bag")
	eq(Array(p.gems), ["twin_stab", "heavy_blow"], "gem slots after swap")
	eq(p.remove_gem(1), "heavy_blow", "remove a gem")
	eq(CCBridge.hero_config(p).gems, ["twin_stab"], "bridge passes socketed gems")
	eq(CCBridge.hero_config(p).attack_def.name, "Strike", "Vanguard's Service Baton = melee Strike")
	p.add_gear("Gravity Hammer")
	p.equip("Gravity Hammer")
	eq(CCBridge.hero_config(p).attack_def.slots, 4, "Gravity Hammer gives Cleave through the bridge")
	# อาวุธเริ่มต้นต่ออาชีพ
	for j in GameData.JOBS:
		var sw: String = GameData.JOBS[j].get("start_weapon", "")
		check(GameData.item(sw).get("type", "") == "weapon" and GameData.item(sw).price == 0, "%s starts with a real, free weapon" % j)
		var q := PlayerStats.new()
		q.change_job(j)
		eq(q.weapon, sw, "%s gets its own start weapon on job change" % j)
		check(q.active_gems().has(CCBalance.JOB_SKILL[j]), "%s's job gem works with its start weapon" % j)
	eq(PlayerStats.new().weapon, GameData.JOBS[GameData.START_JOB].start_weapon, "new player holds the start job's weapon")
	var kept := PlayerStats.new()
	kept.add_gear("Plasma Blade")
	kept.equip("Plasma Blade")
	kept.change_job("Marksman")
	eq(kept.weapon, "Plasma Blade", "a bought weapon is kept on job change")
	# gem ผูกประเภทอาวุธ
	check(CCBalance.gem_fits("charged_shot", "bow") and not CCBalance.gem_fits("charged_shot", "melee"), "Charged Shot needs a Rifle")
	check(CCBalance.gem_fits("fireball", "") and CCBalance.gem_fits("spell", "heavy"), "gems without requirements work with anything")
	eq(CCBalance.gem_requirement_text("heavy_blow"), "needs Blade / Heavy", "requirement text")
	eq(kept.gems.has("charged_shot"), true, "setup: Marksman socketed Charged Shot")
	check(not kept.active_gems().has("charged_shot") and not CCBridge.hero_config(kept).gems.has("charged_shot"), "Charged Shot with a Blade is socketed but not usable in battle")
	kept.add_gear("Pulse Rifle")
	kept.equip("Pulse Rifle")
	check(CCBridge.hero_config(kept).gems.has("charged_shot"), "switching to a Rifle turns it back on")


# ================================================================ อาวุธ Unique
func _uniques() -> void:
	section("unique weapons")
	var uniques := GameData.unique_items()
	check(uniques.size() >= 5, "there are unique weapons")
	for it in uniques:
		var d: Dictionary = GameData.ITEMS[it]
		check(not d.get("pros", []).is_empty() and not d.get("cons", []).is_empty(), "%s has pros and cons" % it)
		check(not d.has("grants") or CCBalance.ACTIONS.has(d.grants), "%s grants a real skill" % it)
		check(not GameData.SMITHY_STOCK.weapon.has(it), "%s is not sold in the shop" % it)
	eq(GameData.display_name("Voidreaver"), "★ Voidreaver", "uniques show a star")
	# merge mods: _mult คูณ, ตัวเลขบวก
	var mm := CCBalance.merge_mods({"attack_mult": 0.6, "start_barrier": 5}, {"attack_mult": 1.3, "start_barrier": 12, "no_dodge": true})
	check(is_equal_approx(mm.attack_mult, 0.78) and mm.start_barrier == 17 and mm.no_dodge, "merge_mods: x for _mult, + for numbers")
	var mo := CCBalance.merge_mods({"crit_mult.attack": 1.8, "dodge_penalty": 0}, {"crit_mult.attack": 1.6, "dodge_penalty": -20})
	check(is_equal_approx(mo["crit_mult.attack"], 1.8) and mo.dodge_penalty == 0, "merge_mods: override keys keep the better value")
	# PlayerStats + bridge
	var p := PlayerStats.new()
	var hp0 := p.max_hp()
	eq(p.preview_stat("hp", "Siphon Edge"), roundi(hp0 * 0.85), "preview counts the unique's HP -15%")
	p.add_gear("Siphon Edge")
	p.equip("Siphon Edge")
	eq(p.max_hp(), roundi(hp0 * 0.85), "Siphon Edge: max HP -15%")
	var cfg := CCBridge.hero_config(p)
	eq(cfg.granted, ["blood_siphon"], "bridge passes the granted skill")
	eq(Array(p.gems).size(), 2, "granted skill doesn't use a gem slot")
	var b := CCBattle.create_battle({"seed": 1, "hero": cfg, "monster": CCBridge.monster_config("Goblin")})
	check(CCBattle.skills_for(b.units[0]).has("blood_siphon") and CCBattle.skills_for(b.units[0]).size() == 4, "skills = Attack + 2 gems + weapon skill")
	p.add_gear("Voidreaver")
	p.equip("Voidreaver")
	var vm: Dictionary = CCBridge.hero_config(p).mods
	check(vm.get("no_dodge", false) and is_equal_approx(vm.get("attack_mult", 1.0), GameData.ITEMS.Voidreaver.mods.attack_mult), "Voidreaver mods reach the battle")
	eq(CCBridge.hero_config(p).granted, [], "swapping weapons drops the granted skill")
	# Blood Siphon: ฟื้น HP 50% ของดาเมจ
	var hs := st(400, 100, 5, 5, 8)
	var sb := CCBattle.create_battle({"seed": 1, "hero": {"name": "H", "job": "", "stats": hs, "hp": 100, "gems": [], "granted": ["blood_siphon"]},
		"monster": {"name": "M", "stats": st(5000, 1, 0, 1, 5), "actions": {"guard": 1}, "defense": NO_DEF}})
	var sr := act(sb, {"type": "skill", "skill": "blood_siphon", "focus": 1})
	var dealt: int = events(sr, "damage").filter(func(e): return e.unit == CCBattle.MONSTER)[0].amount
	var heals: Array = events(sr, "heal").filter(func(e): return e.cause == "drain")
	check(heals.size() == 1 and heals[0].amount == floori(dealt * 0.5), "Blood Siphon heals 50%% of %d" % dealt)
	check(err(CCBattle.create_battle({"seed": 1, "hero": {"name": "H", "job": "", "stats": hs, "gems": []},
		"monster": {"name": "M", "stats": st(50, 1, 0, 1, 5), "actions": {"guard": 1}, "defense": NO_DEF}}), {"type": "skill", "skill": "blood_siphon", "focus": 0}),
		"no unique = no weapon skill")
	# Singularity: จ่าย 2 Focus + 10% HP, ไม่ทำให้ตาย
	var sg := CCBattle.create_battle({"seed": 1, "hero": {"name": "H", "job": "", "stats": st(100, 5, 5, 100, 8), "gems": [], "granted": ["singularity"]},
		"monster": {"name": "M", "stats": st(5000, 1, 0, 1, 5), "actions": {"guard": 1}, "defense": NO_DEF}})
	sg.units[0].focus = 3
	var sgr := act(sg, {"type": "skill", "skill": "singularity", "focus": 1})
	var paid: Array = events(sgr, "damage").filter(func(e): return e.cause == "hp_cost")
	check(paid.size() == 1 and paid[0].amount == 10, "Singularity costs 10% max HP")
	eq(sgr.units[0].focus, 0, "Singularity costs 2 Focus (+1 spent)")
	check(events(sgr, "effect").any(func(e): return e.effect == "stun"), "Singularity Perfect stuns")
	var low := sg.duplicate(true)
	low.units[0].hp = 1
	eq(CCBattle.hp_cost_for(low.units[0], "singularity"), 0, "HP cost never kills you")
	# AI ใช้ท่าติดอาวุธได้ไม่ error
	var q := PlayerStats.new()
	for it in uniques:
		q.add_gear(it)
		q.equip(it)
		q.hp = q.max_hp()
		var s := CCBattle.create_battle(CCBridge.config(q, "Goblin Chief", 3))
		var n := 0
		var ok := true
		while s.result == "" and n < 300:
			var r := CCBattle.apply_action(s, CCAi.choose(s))
			ok = ok and r.error == ""
			s = r.state
			n += 1
		check(ok and s.result != "", "AI fights legally with %s" % it)


# ================================================================ Rare / Epic (ItemDB)
func _tiers() -> void:
	section("rare / epic gear")
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	eq(ItemDB.create("Plasma Blade", "common", rng), "Plasma Blade", "common = plain base name")
	var ok_count := true
	var ok_slots := true
	var ok_unique := true
	for i in 200:
		var tier: String = ["rare", "epic"][i % 2]
		var base: String = ["Plasma Blade", "Mesh Armor", "Lucky Chip"][i % 3]
		var id := ItemDB.create(base, tier, rng)
		var rec := ItemDB.record(id)
		var r: Array = ItemDB.TIERS[tier].affixes
		ok_count = ok_count and rec.affixes.size() >= r[0] and rec.affixes.size() <= r[1]
		var seen := {}
		for a in rec.affixes:
			ok_slots = ok_slots and ItemDB.AFFIXES[a.id].slots.has(GameData.ITEMS[base].type)
			ok_unique = ok_unique and not seen.has(a.id)
			seen[a.id] = true
	check(ok_count, "affix count follows the tier (rare 1-2, epic 3-4)")
	check(ok_slots, "affixes only roll on slots they allow")
	check(ok_unique, "no duplicate affix on one item")
	# ค่ารวม
	var id := ItemDB.register({"base": "Plasma Blade", "tier": "epic", "affixes": [
		{"id": "atk", "value": 3}, {"id": "attack_dmg", "value": 10}, {"id": "first_slot", "value": 8}]})
	check(id.begins_with("Plasma Blade#") and ItemDB.is_instance(id), "instance id = base#n")
	var d := GameData.item(id)
	eq(d.atk, GameData.ITEMS["Plasma Blade"].atk + 3, "stat affix adds to the base stat")
	check(is_equal_approx(d.mods.attack_mult, 1.1) and d.mods["first_slot_bonus.attack"] == 8, "mod affixes become battle mods")
	eq(GameData.ITEMS["Plasma Blade"].get("mods", {}), {}, "base item data is untouched")
	eq(GameData.rarity(id), "epic", "rarity of an instance")
	eq(GameData.display_name(id), "◆ Plasma Blade (Epic)", "display name")
	eq(GameData.weapon_type(id), "melee", "instance keeps its weapon type")
	eq(GameData.sell_price(id), int(roundi(110 * 2.5) * GameData.SELL_RATE), "epic sells for more")
	check(GameData.item_lines(id).contains("• +3 ATK") and GameData.item_lines(id).contains("Attack damage +10%"), "affix text")
	# PlayerStats + bridge
	var p := PlayerStats.new()
	var atk0 := p.stat("atk")
	var start_atk: int = GameData.item(p.weapon).get("atk", 0)
	eq(p.preview_stat("atk", id), atk0 - start_atk + 9, "preview a rolled weapon (start weapon -> ATK 9)")
	p.add_gear(id)
	p.equip(id)
	eq(p.weapon, id, "equip by instance id")
	eq(p.stat("atk"), atk0 - start_atk + 9, "rolled stats count")
	var cfg := CCBridge.hero_config(p)
	check(is_equal_approx(cfg.mods.attack_mult, 1.1) and cfg.attack_def.name == "Strike", "affix mods + weapon attack reach the battle")
	eq(p.preview_remove_stat("atk", "weapon"), atk0 - start_atk, "preview removing it")
	var id2 := ItemDB.register({"base": "Plasma Blade", "tier": "rare", "affixes": [{"id": "atk", "value": 1}]})
	p.add_gear(id2)
	check(p.owns(id) and p.owns(id2) and id != id2, "two rolled copies of the same base are separate items")
	# ดรอป
	var drops := {}
	for i in 400:
		drops[GameData.rarity(ItemDB.random_drop(rng))] = drops.get(GameData.rarity(ItemDB.random_drop(rng)), 0) + 1
	check(drops.keys().all(func(k): return k == "rare" or k == "epic") and drops.get("rare", 0) > drops.get("epic", 0), "drops are rare/epic, rare more often (%s)" % str(drops))
	# Dice Duel ยังอ่านอุปกรณ์ได้
	var c := DDBoardBridge.player_character(p)
	check(c.dice.size() > 0, "Dice Duel bridge reads rolled gear")


# ================================================================ เซฟ / โหลด
func _save() -> void:
	section("save / load")
	var path := "user://test_save.json"
	var rng := RandomNumberGenerator.new()
	rng.seed = 21
	var s := GameState.new()
	var p := s.player
	p.change_job("Engineer")
	p.gain_exp(500)
	p.gold = 777
	p.items.assign(["Medkit", "Plasma Grenade"])
	var epic := ItemDB.create("Mesh Armor", "epic", rng)
	var rare := ItemDB.create("Plasma Blade", "rare", rng)
	p.add_gear(epic)
	p.equip(epic)
	p.add_gear(rare)
	p.add_gear("Voidreaver")
	p.add_gem("fireball")
	p.towns.append(GameData.TOWNS.keys()[0])
	p.tile = Vector2i(3, 5)
	p.allocate(PassiveTree.NODES.keys().filter(func(k): return p.can_allocate(k))[0])
	p.hp = 20
	s.day = 9
	var want := var_to_str(p.to_dict())
	var want_epic := ItemDB.record(epic)
	check(SaveGame.save(s, path), "save writes the file")
	eq(SaveGame.saved_day(path), 9, "saved day readable for the Continue button")
	# จำลองเปิดเกมใหม่: ล้างข้อมูล Rare/Epic ในหน่วยความจำ
	ItemDB._instances.clear()
	var s2 := GameState.new()
	check(SaveGame.load_into(s2, path), "load succeeds")
	eq(var_to_str(s2.player.to_dict()), want, "every player field round-trips")
	eq(s2.day, 9, "day round-trips")
	eq(ItemDB.record(epic), want_epic, "rolled Epic affixes are restored with the same id")
	eq(s2.player.stat("def"), p.stat("def"), "restored gear gives the same stats")
	eq(s2.player.towns, p.towns, "freed towns round-trip (Vector2i)")
	var fresh := ItemDB.create("Plasma Blade", "rare", rng)
	check(fresh != epic and fresh != rare, "new rolls after loading don't reuse saved ids")
	# ไฟล์เสีย / ไอเทมที่ไม่รู้จัก
	var bad := GameState.new()
	check(not SaveGame.apply(bad, {"version": 999, "player": {}}), "other save versions are refused")
	var d := SaveGame.to_dict(s)
	d.player.weapon = "Removed Sword"
	d.player.gear.append("Old Thing")
	var s3 := GameState.new()
	check(SaveGame.apply(s3, d), "save with unknown items still loads")
	check(s3.player.weapon == "" and not s3.player.gear.has("Old Thing"), "unknown items are dropped instead of crashing")
	SaveGame.delete(path)
	check(not SaveGame.has_save(path), "delete removes the file")


# ================================================================ Passive mods (T-062)
func mu(stats: Dictionary, mods: Dictionary) -> Dictionary:
	var u := unit(stats)
	u.mods = mods
	return u


func mb(job: String, hero_stats: Dictionary, mon_stats: Dictionary, mods: Dictionary, mon_actions := {"guard": 1}, seed := 1, mon_def := NO_DEF, items := []) -> Dictionary:
	return CCBattle.create_battle({"seed": seed,
		"hero": {"name": "Hero", "job": job, "stats": hero_stats, "items": items, "mods": mods},
		"monster": {"name": "Mon", "stats": mon_stats, "actions": mon_actions, "defense": mon_def, "gold": 100}})


func _passive_mods() -> void:
	section("passive mods: formulas (T-062)")
	var a := unit(st(30, 10, 4, 10, 5))
	var t := unit(st(30, 0, 4, 6, 5))
	var am: float = CCBalance.ACTIONS.attack.mult
	var phys := 4 * CCBalance.PHYS_REDUCE_PER_DEF
	# ป้องกัน
	eq(CCBattle.defense_chance(mu(st(30, 0, 6, 0, 5), {"check_bonus.block": 10}), "block", "attack", 0), CCBattle.chance(6, 0, 10), "Reinforced Plating: Block +10%")
	eq(CCBattle.defense_chance(mu(st(30, 0, 0, 6, 5), {"check_bonus.block_tec": 15}), "block", "spell", 0), CCBattle.chance(6, 0, 15), "Psi Shield: Block vs tech +15%")
	eq(CCBattle.defense_chance(mu(st(30, 0, 6, 0, 5), {"check_bonus.block_tec": 15}), "block", "attack", 0), CCBattle.chance(6), "Psi Shield: no bonus vs physical")
	eq(CCBattle.defense_chance(mu(st(30, 0, 0, 0, 6), {"dodge_penalty": 0}), "dodge", "attack", 0), CCBattle.chance(6), "Light Step: Dodge has no penalty")
	eq(CCBattle.defense_effect(mu(st(30, 0, 4, 6, 5), {"block_cut": 0.4}), a, "block", 1).mult, 0.6, "Juggernaut: Block cuts 40% per slot")
	check(not CCBattle.can_defend_with(mu(st(30, 0, 4, 6, 5), {"no_dodge": true}), "dodge"), "Juggernaut: no Dodge")
	eq(CCBattle.defense_effect(mu(st(30, 10, 4, 6, 5), {"counter_mult": 1.0}), t, "counter", 1).counter, maxi(1, floori(10 * 1.0 * 0.5 - phys)), "Point Blank: Counter x1.0")
	# ดาเมจ
	eq(CCBattle.damage_for(mu(st(30, 10, 4, 10, 5), {"crit_mult.attack": 1.8}), t, "attack", 3), floori(10 * am * 1.8 - phys), "Breacher: crit x1.8")
	var cm: float = CCBalance.ACTIONS.charged_shot.mult
	eq(CCBattle.damage_for(mu(st(30, 10, 4, 10, 5), {"long_skill_mult": 1.4}), t, "charged_shot", 3), floori(10 * cm * 0.75 * 1.4 - phys), "One Shot: 4-slot move x1.4")
	eq(CCBattle.damage_for(mu(st(30, 10, 4, 10, 5), {"short_skill_mult": 0.6}), t, "spell", 2), floori(10 * CCBalance.ACTIONS.spell.mult * 0.6), "One Shot: 2-slot move x0.6")
	eq(CCBattle.damage_for(mu(st(30, 10, 4, 10, 5), {"short_skill_mult": 0.6}), t, "attack", 2), CCBattle.damage_for(a, t, "attack", 2), "One Shot: 3-slot Attack unchanged")
	eq(CCBattle.damage_for(mu(st(30, 10, 4, 10, 5), {"attack_mult": 0.6}), t, "attack", 2), maxi(1, floori(10 * am * 2 / 3.0 * 0.6 - phys)), "Full Automation: Attack x0.6")
	eq(CCBattle.damage_for(mu(st(30, 10, 4, 10, 5), {"perfect_mult": 2.0, "imperfect_mult": 0.7}), t, "attack", 3), floori(10 * am * CCBalance.CRIT_MULT * 2.0 - phys), "All or Nothing: Perfect x2")
	eq(CCBattle.damage_for(mu(st(30, 10, 4, 10, 5), {"perfect_mult": 2.0, "imperfect_mult": 0.7}), t, "attack", 2), maxi(1, floori(10 * am * 2 / 3.0 * 0.7 - phys)), "All or Nothing: non-Perfect x0.7")
	var armored := unit(st(30, 0, 20, 6, 5))
	eq(CCBattle.damage_for(mu(st(30, 20, 4, 10, 5), {"perfect_armor_pierce": 0.25}), armored, "attack", 3), floori(20 * am * CCBalance.CRIT_MULT - 20 * CCBalance.PHYS_REDUCE_PER_DEF * 0.75), "Weak Point: Perfect ignores 25% ARM")
	eq(CCBattle.full_power(mu(st(30, 4, 4, 20, 5), {"attack_uses_avg_tec": true}), "attack"), 12.0 * am, "Smart Rounds: Attack uses (ATK+TEC)/2")
	eq(CCBattle.full_power(mu(st(30, 30, 4, 2, 5), {"attack_uses_avg_tec": true}), "attack"), 30.0 * am, "Smart Rounds: keeps ATK if higher")
	# โดรน
	var dr := mu(st(30, 5, 5, 10, 5), {"drone_mult": 2.0, "drone_turns": 1})
	eq(CCBattle.drone_damage(dr), floori(10 * CCBalance.DRONE_DAMAGE_PER_MAG * 2.0), "Full Automation: drone x2")
	eq(CCBattle.drone_turns(dr, false), CCBalance.DRONE_TURNS + 1, "Overclocked Drones: +1 turn")
	var nl := mu(st(30, 5, 5, 10, 5), {"drone_check_bonus": 5})
	eq(CCBattle.action_chance(nl, "spell"), CCBattle.chance(10), "Neural Link: no bonus without a drone")
	nl.drone = 2
	eq(CCBattle.action_chance(nl, "spell"), CCBattle.chance(10, 0, 5), "Neural Link: +5% TEC with a drone")
	eq(CCBattle.action_chance(nl, "attack"), CCBattle.chance(5), "Neural Link: ATK checks unchanged")
	# ทอย: Steady Aim / Second Chance
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	var first := 0
	var second := 0
	for i in 2000:
		var r: Dictionary = CCBattle._roll_for(unit(st(1, 1, 1, 1, 1)), 2, 0.0, 20.0, rng)
		first += r.slots[0]
		second += r.slots[1]
	check(first > 300 and first < 500 and second == 0, "Steady Aim: only the first slot gets +20%% (%d/2000)" % first)
	var rr := unit(st(1, 1, 1, 1, 1))
	rr.reroll = 1
	var r1: Dictionary = CCBattle._roll_for(rr, 3, 0.0, 0.0, rng)
	check(r1.rerolled == 0 and rr.reroll == 0, "Second Chance: first failed slot re-rolled once")
	eq(CCBattle._roll_for(rr, 3, 0.0, 0.0, rng).rerolled, -1, "Second Chance: only once per battle")

	section("passive mods: battle flow (T-062)")
	var df := mb("Psion", st(40, 5, 5, 10, 8), st(200, 1, 0, 1, 5), {"start_focus": 1, "start_barrier": 10, "reroll_first_fail": 1})
	eq(df.units[0].focus, mini(CCBalance.FOCUS_MAX, CCBalance.FOCUS_START + 1), "Deep Focus: +1 Focus at start")
	eq(df.units[0].barrier, 10, "Kinetic Barrier: starts with 10")
	eq(df.units[0].reroll, 1, "Second Chance: ready at start")
	var hit := mb("Vanguard", st(400, 5, 0, 5, 1), st(200, 30, 0, 1, 9), {"start_barrier": 10}, {"attack": 1})
	var taken := act(hit, {"type": "defend", "defense": "block", "focus": 0})
	var bar: Array = events(taken, "barrier")
	var dmg: Array = events(taken, "damage")
	if not dmg.is_empty():
		check(bar.size() == 1 and dmg[0].amount + bar[0].amount == 400 - dmg[0].hp + bar[0].amount and taken.units[0].barrier == 10 - bar[0].amount, "Kinetic Barrier absorbs damage first")
	var jug := mb("Vanguard", st(400, 5, 5, 5, 1), st(200, 30, 0, 1, 9), {"no_dodge": true}, {"attack": 1})
	check(err(jug, {"type": "defend", "defense": "dodge", "focus": 0}), "Juggernaut: Dodge is refused")
	var gs := mb("Vanguard", st(100, 5, 5, 5, 8), st(200, 1, 0, 1, 5), {"guard_heal_pct": 10})
	gs.units[0].hp = 50
	var gh := act(gs, {"type": "guard"})
	check(events(gh, "heal").any(func(e): return e.cause == "guard" and e.amount == 10), "Adrenal Surge: Guard heals 10% max HP")
	var slow := mb("Marksman", st(100, 5, 5, 5, 1), st(200, 1, 0, 1, 9), {"first_strike": true})
	eq(CCBattle.phase(slow), "act", "Quick Draw: slower hero acts first in round 1")
	var after := act(slow, {"type": "guard"})
	eq(after.order, [CCBattle.MONSTER, CCBattle.HERO], "Quick Draw: round 2 is back to normal order")
	var rg := mb("Engineer", st(100, 5, 5, 5, 8), st(200, 1, 0, 1, 5), {"regen": 2})
	rg.units[0].hp = 50
	var rg2 := act(rg, {"type": "guard"})
	check(events(rg2, "heal").any(func(e): return e.cause == "regen" and e.amount == 2), "Auto-Repair: +2 HP at the start of your turn")
	var fb := act(mb("Psion", st(30, 5, 5, 100, 8), st(1000, 1, 0, 9, 5), {"burn_turns": 1, "poison_bonus": 1}), {"type": "skill", "skill": "fireball", "focus": 1})
	var burn_ticks: Array = events(fb, "damage").filter(func(e): return e.cause == "burn")
	check(burn_ticks.size() == 1 and burn_ticks[0].amount == 51 and fb.units[1].burn == CCBalance.BURN_TURNS + 1 - 1, "Plasma Feed +1 turn, Toxic Mind +1 damage")
	var dart := act(mb("Psion", st(40, 5, 5, 10, 8), st(200, 1, 0, 1, 5), {"poison_bonus": 1}, {"guard": 1}, 1, NO_DEF, ["Toxin Dart"]), {"type": "item", "item": "Toxin Dart"})
	check(events(dart, "damage").filter(func(e): return e.cause == "burn")[0].amount == 5, "Toxic Mind: Poison Dart +1 damage")
	var amb := mb("Vanguard", st(30, 100, 5, 5, 8), st(500, 1, 0, 1, 5), {"first_turn_attack_slots": 1})
	eq(CCBattle.slots_for(amb, CCBattle.HERO, "attack"), 4, "Ambush: Attack has 4 slots in round 1")
	var amb2 := act(amb, {"type": "skill", "skill": "attack", "focus": 1})
	eq(events(amb2, "check")[0].slots.size(), 4, "Ambush: engine rolls 4 slots")
	eq(CCBattle.slots_for(amb2, CCBattle.HERO, "attack"), 3, "Ambush: back to 3 slots after round 1")
	# replay ยังตรงเมื่อมี mods
	var rp := CCBattle.replay(amb.config, amb2.actions)
	eq(rp.units[1].hp, amb2.units[1].hp, "replay matches with mods")

	section("passive mods: player side (T-062)")
	var p := PlayerStats.new()
	p.gain_exp(100000)
	var mag_before := p.stat("mag")
	var hp_before := p.max_hp()
	var path: Array = ["psi_l", "deep_focus", "psi_out", "psi_shield", "glass_mind"]
	check(p.set_tree(path), "can reach Glass Mind")
	var raw_mag := p.stat_with("mag", ["psi_l", "deep_focus", "psi_out", "psi_shield"])
	eq(p.stat("mag"), roundi(raw_mag * 1.3), "Glass Mind: TEC +30%")
	eq(p.max_hp(), roundi((hp_before + 5) * 0.75), "Glass Mind: max HP -25%")
	check(p.stat("mag") > mag_before, "Glass Mind is a net TEC gain")
	var cfg := CCBridge.hero_config(p)
	check(cfg.mods.get("start_focus") == 1 and cfg.mods.has("stat_pct.mag"), "bridge passes passive mods into battle")
	var b := CCBattle.create_battle({"seed": 1, "hero": cfg, "monster": CCBridge.monster_config(GameData.MONSTERS.keys()[0])})
	eq(b.units[0].focus, mini(CCBalance.FOCUS_MAX, CCBalance.FOCUS_START + 1), "Deep Focus works through the bridge")
	var r := PlayerStats.new()
	r.change_job("Infiltrator")
	r.gain_exp(100000)
	check(r.set_tree(["shadow_r", "pickpocket"]), "take Pickpocket")
	eq(r.gold_mult(), 1.45, "Pickpocket: +20% credits on top of the Infiltrator bonus")

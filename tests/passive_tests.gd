extends SceneTree
## Unit test ของ Passive Tree (T-060 / T-061):  Godot --headless --path . --script res://tests/passive_tests.gd

var _passed := 0
var _failed := 0
var _section := ""


func _init() -> void:
	_data()
	_rules()
	_player()
	print("\nPassive tree tests: %d passed, %d failed" % [_passed, _failed])
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
	check(ok, what if ok else "%s  (got %s, expected %s)" % [what, actual, expected])


func lv(n: int) -> PlayerStats:
	var p := PlayerStats.new()
	p.level = n
	return p


# ================================================================
func _data() -> void:
	section("tree data (T-060)")
	var errors := PassiveTree.validate()
	for e in errors:
		print("    ", e)
	check(errors.is_empty(), "PassiveTree.validate() finds no problems")
	eq(PassiveTree.NODES.size(), 51, "51 nodes")
	for job in GameData.JOBS:
		check(PassiveTree.start_of(job) != "", "%s has a start node" % job)
	check(PassiveTree.neighbors("assault_in").has("hub") and PassiveTree.neighbors("hub").has("assault_in"), "links work both ways")
	var ok := true
	for k in PassiveTree.NODES:
		ok = ok and PassiveTree.unit_pos(k).length() <= 1.1
	check(ok, "every node fits on one screen (radius <= 1.1)")
	# โหนดไม่ซ้อนกันบนจอ
	var too_close := ""
	var keys := PassiveTree.NODES.keys()
	for i in keys.size():
		for j in range(i + 1, keys.size()):
			if PassiveTree.unit_pos(keys[i]).distance_to(PassiveTree.unit_pos(keys[j])) < 0.09:
				too_close = "%s / %s" % [keys[i], keys[j]]
	eq(too_close, "", "no two nodes overlap on screen")
	eq(PassiveTree.stats_text("assault_in"), "+5 HP", "stat text")
	eq(PassiveTree.stats_text("machine_in"), "+2 TEC", "stat text uses sci-fi labels")
	eq(PassiveTree.title("juggernaut"), "Juggernaut", "named node title")
	var inactive := []
	for k in PassiveTree.NODES:
		if not PassiveTree.is_active(k):
			inactive.append(k)
	eq(inactive, [], "every node's effect is active (T-062)")
	_ai_builds()


## AI สู้จบได้ด้วยบิลด์เต็ม (เส้นทางแนะนำ + Keystone ของแฉกตัวเอง + สะพาน) ไม่มี action ผิดกติกา
func _ai_builds() -> void:
	var keystone := {"Vanguard": ["juggernaut"], "Marksman": ["one_shot"], "Engineer": ["full_automation"], "Psion": ["glass_mind"], "Infiltrator": ["all_or_nothing"]}
	var bridges := {"Vanguard": ["point_blank"], "Marksman": ["smart_rounds"], "Engineer": ["neural_link"], "Psion": ["toxic_mind"], "Infiltrator": ["ambush"]}
	var rng := RandomNumberGenerator.new()
	rng.seed = 9
	var ok := true
	var built := true
	for job in GameData.JOBS:
		var p := PlayerStats.new()
		p.change_job(job)
		p.gain_exp(100000)
		var tree: Array = GameData.JOBS[job].suggested + keystone[job]
		var arm: String = PassiveTree.NODES[PassiveTree.start_of(job)].arm
		tree.append(arm + "_r" if bridges[job][0] in PassiveTree.neighbors(arm + "_r") else arm + "_l")
		tree.append(bridges[job][0])
		var uniq := []
		for id in tree:
			if not uniq.has(id):
				uniq.append(id)
		built = built and p.set_tree(uniq)
		p.hp = p.max_hp()
		for mon in GameData.MONSTERS:
			for i in 5:
				var s := CCBattle.create_battle(CCBridge.config(p, mon, rng.randi()))
				var n := 0
				while s.result == "" and n < 300:
					var r := CCBattle.apply_action(s, CCAi.choose(s))
					ok = ok and r.error == ""
					s = r.state
					n += 1
				ok = ok and s.result != ""
	check(built, "full builds (suggested + keystone + bridge) are valid trees")
	check(ok, "AI finishes battles with every keystone build, no illegal actions")


func _rules() -> void:
	section("allocation rules")
	check(PassiveTree.can_allocate([], "psi_l", "Psion"), "can take a node next to your start")
	check(not PassiveTree.can_allocate([], "deep_focus", "Psion"), "can't skip ahead")
	check(not PassiveTree.can_allocate([], "psi_start", "Psion"), "start is free, not allocatable")
	check(not PassiveTree.can_allocate(["psi_in", "hub", "assault_in"], "assault_start", "Psion"), "can't take another job's start")
	check(PassiveTree.can_allocate(["psi_in", "hub"], "assault_in", "Psion"), "hub reaches other arms")
	check(PassiveTree.can_allocate(["psi_r"], "toxic_mind", "Psion"), "bridge reaches the next arm")
	check(PassiveTree.can_allocate(["psi_r", "toxic_mind"], "shadow_l", "Psion"), "walk across a bridge")
	check(not PassiveTree.can_allocate(["psi_l"], "psi_l", "Psion"), "can't take the same node twice")
	check(PassiveTree.is_connected_tree(["psi_l", "deep_focus"], "Psion"), "connected path")
	check(not PassiveTree.is_connected_tree(["deep_focus"], "Psion"), "floating node = not connected")
	check(not PassiveTree.can_refund(["psi_l", "deep_focus"], "psi_l", "Psion"), "can't remove a node others depend on")
	check(PassiveTree.can_refund(["psi_l", "deep_focus"], "deep_focus", "Psion"), "can remove a leaf")
	check(PassiveTree.can_refund(["psi_l", "deep_focus", "psi_out", "plasma_feed", "psi_r"], "psi_l", "Psion"), "can remove when another path still connects")
	eq(PassiveTree.stat_bonus(["psi_l", "psi_r", "hub"], "mag"), 3, "stat bonus sums (+2 TEC, hub +1)")
	eq(PassiveTree.stat_bonus(["psi_l", "hub"], "hp"), 8, "stat bonus HP")
	var m := PassiveTree.mods(["deep_focus", "plasma_feed"])
	check(m.get("start_focus") == 1 and m.get("burn_turns") == 1, "mods are collected for T-062")
	# เส้นทางแนะนำต้องลงได้ตามลำดับ
	for job in GameData.JOBS:
		var a := []
		var ok := true
		for id in GameData.JOBS[job].suggested:
			ok = ok and PassiveTree.can_allocate(a, id, job)
			a.append(id)
		check(ok, "%s suggested path can be taken in order" % job)


func _player() -> void:
	section("player points (T-061)")
	var p := lv(1)
	eq(p.passive_points(), 0, "Lv1 = 0 points")
	check(not p.allocate("psi_l"), "can't allocate without points")
	p = lv(3)
	eq(p.unspent_points(), 2, "Lv3 = 2 points")
	var mag := p.stat("mag")
	var hp := p.max_hp()
	check(p.allocate("psi_r"), "allocate a node")
	eq(p.stat("mag"), mag + 2, "node stats count in stat()")
	check(p.allocate("psi_l"), "allocate a second node")
	eq(p.max_hp(), hp + 5, "HP node raises max HP")
	eq(p.unspent_points(), 0, "points spent")
	check(not p.allocate("plasma_feed"), "no points left")
	p.level = 4
	check(p.allocate("plasma_feed"), "level up gives a point")
	eq(p.stat_with("mag", []), mag, "stat_with([]) = no passive")
	eq(p.gain_exp(GameData.EXP_TO_LEVEL * 4), 1, "gain_exp levels up")
	eq(p.unspent_points(), 1, "gain_exp gives a passive point")

	section("per-job trees")
	var mine: Array = p.allocated().duplicate()
	p.change_job("Vanguard")
	eq(p.allocated(), [], "new job starts with an empty tree")
	eq(p.unspent_points(), p.passive_points(), "all points free for the new job")
	check(p.allocate("assault_in"), "allocate on the new job's arm")
	check(not p.allocate("psi_l"), "Vanguard can't reach Psion's arm directly")
	p.change_job("Psion")
	eq(p.allocated(), mine, "switching back restores the old tree")

	section("set_tree / reset")
	var q := lv(4)
	check(q.set_tree(["psi_l", "deep_focus", "psi_out"]), "set_tree accepts a connected tree")
	check(not q.set_tree(["deep_focus"]), "set_tree rejects a floating node")
	check(not q.set_tree(["psi_l", "deep_focus", "psi_out", "plasma_feed"]), "set_tree rejects too many nodes")
	check(not q.set_tree(["psi_start"]), "set_tree rejects start nodes")
	eq(q.allocated(), ["psi_l", "deep_focus", "psi_out"], "rejected set_tree keeps the old tree")
	q.hp = q.max_hp()
	eq(q.reset_tree(), 3, "reset refunds every node")
	eq(q.unspent_points(), 3, "points back after reset")
	check(q.hp <= q.max_hp(), "HP clamped after losing HP nodes")
	eq(lv(5).reset_cost(), 0, "reset is free up to Lv5")
	eq(lv(6).reset_cost(), 60, "reset costs 10 x level after Lv5")

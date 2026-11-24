extends SceneTree
## Unit test ของระบบฝ่าย + อีเวนต์บนกระดาน:  Godot --headless --path . --script res://tests/event_tests.gd

var _passed := 0
var _failed := 0
var _section := ""

const KNOWN_EFFECTS := ["karma", "renown", "scrip", "fatigue", "gold_pct", "lose_gold_pct", "hp_pct", "item", "use_item",
	"reward", "back", "skip", "steal", "coupon", "ally", "fight", "loan", "scrip_next", "open_shop"]


func _init() -> void:
	_data()
	_karma()
	_options()
	_effects()
	_board_effects()
	_battle_link()
	_fights()
	_shops()
	_debts()
	_save()
	_fuzz()
	print("\nEvent tests: %d passed, %d failed" % [_passed, _failed])
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


func rng(seed: int) -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new()
	r.seed = seed
	return r


func _all_effects(o: Dictionary) -> Array:
	var out: Array = []
	for k in ["cost", "alt", "effects"]:
		out.append_array(o.get(k, []))
	if o.has("check"):
		out.append_array(o.check["pass"])
		out.append_array(o.check["fail"])
	if o.has("roll"):
		out.append_array(o.roll.effects)
	for e in out.duplicate():
		if e[0] == "fight":
			out.append_array(e[1].get("win", []))
			out.append_array(e[1].get("lose", []))
	return out


## ทุกชุด effect ของตัวเลือก (ใช้เช็คว่า fight อยู่ท้ายชุด)
func _effect_lists(o: Dictionary) -> Array:
	var out: Array = [o.get("effects", []), o.get("alt", []), o.get("cost", [])]
	if o.has("check"):
		out.append(o.check["pass"])
		out.append(o.check["fail"])
	if o.has("roll"):
		out.append(o.roll.effects)
	return out


# ================================================================
func _data() -> void:
	section("event data")
	check(EventData.EVENTS.size() >= 11, "at least 11 events")
	for id in EventData.EVENTS:
		var ev: Dictionary = EventData.EVENTS[id]
		check(ev.has("title") and ev.has("text"), "%s has title + text" % id)
		var keys: Array = ev.options.map(func(o): return o.key)
		check(keys.has("A") and keys.has("B") and keys.has("C"), "%s has A/B/C" % id)
		for o in ev.options:
			check(o.has("label"), "%s/%s has a label" % [id, o.key])
			check(o.get("need", "") == "" or EventData.FACTION_NAMES.has(o.need), "%s/%s need is a faction" % [id, o.key])
			check(o.key != "D" or o.has("need"), "%s/D is gated by a faction" % id)
			for e in _all_effects(o):
				check(KNOWN_EFFECTS.has(e[0]), "%s/%s effect %s is known" % [id, o.key, e[0]])
				if e[0] == "item" or e[0] == "use_item":
					check(GameData.ITEMS.has(e[1]), "%s/%s item %s exists" % [id, o.key, e[1]])
			if o.has("check"):
				var st: String = o.check.get("stat", "")
				check(st == "" or GameData.STAT_KEYS.has(st), "%s/%s check stat %s exists" % [id, o.key, st])
			for lst in _effect_lists(o):
				for i in lst.size():
					if lst[i][0] == "fight":
						check(i == lst.size() - 1, "%s/%s fight is the last effect of its list" % [id, o.key])
						var mon: String = lst[i][1].get("monster", EventData.WILD_FIGHT)
						check(mon == EventData.WILD_FIGHT or GameData.MONSTERS.has(mon), "%s/%s monster %s exists" % [id, o.key, mon])
	check(GameData.TILE_PATTERN.has("event") and GameData.TILE_TYPES.has("event"), "event tile is on the board")


func _karma() -> void:
	section("karma + factions")
	var p := PlayerStats.new()
	eq(p.karma, EventData.KARMA_START, "start karma")
	eq(p.faction(), "concord", "start in the Concord")
	eq(p.add_karma(-20), "", "karma 0 is still Concord")
	eq(p.add_karma(-1), "syndicate", "below 0 switches to the Syndicate")
	eq(p.add_karma(EventData.KARMA_RETURN - 1 - p.karma), "", "back to %d: still Syndicate" % (EventData.KARMA_RETURN - 1))
	check(p.syndicate, "Karma 0-9 after falling stays Syndicate (no flip-flop)")
	eq(p.add_karma(1), "concord", "reaching KARMA_RETURN returns to the Concord")
	var q := PlayerStats.new()
	check(not q.meets("concord"), "D-C needs Karma %d (start 20 can't)" % EventData.D_CONCORD_KARMA)
	q.add_karma(EventData.D_CONCORD_KARMA - q.karma)
	check(q.meets("concord") and not q.meets("syndicate"), "Karma 40 unlocks D-C")
	q.add_karma(-100)
	check(q.meets("syndicate") and not q.meets("concord"), "Syndicate unlocks D-S")
	check(not q.meets("freeport"), "D-F needs renown")
	q.renown = EventData.D_FREEPORT_RENOWN
	check(q.meets("freeport"), "Renown 20 unlocks D-F")


func _options() -> void:
	section("options")
	var p := PlayerStats.new()
	eq(EventRunner.visible_options(p, "stalled_crawler").size(), 3, "D-F hidden without renown")
	p.renown = 20
	var opts := EventRunner.visible_options(p, "stalled_crawler")
	eq(opts.size(), 4, "D-F shown with renown")
	var d: Dictionary = opts[3]
	check(not EventRunner.availability(p, d).ok, "D-F needs 5 Scrip")
	p.scrip = 5
	check(EventRunner.availability(p, d).ok, "affordable with 5 Scrip")
	check(EventRunner.describe(p, d).contains("Scrip -5") and EventRunner.describe(p, d).contains("Freeport"), "label shows cost + faction")
	EventRunner.resolve(p, "stalled_crawler", "D", rng(1))
	check(p.scrip == 0 and p.renown == 23, "paying Scrip takes it away (5 -> 0), Renown +3")
	# alt: ไม่มี Medkit ยังเลือกได้ แต่ใช้ผลสำรอง
	var s := PlayerStats.new()
	s.items.clear()
	var a := EventRunner.option("suit_breach", "A")
	check(EventRunner.availability(s, a).ok, "no Medkit: suit_breach A is still available (alt)")
	check(EventRunner.describe(s, a).contains("Lose 1 turn"), "label shows the alt effects")
	# เช็คใช้ค่าพลัง
	var ck: Dictionary = EventRunner.option("dropped_chip", "A").check
	var fast := PlayerStats.new()
	fast.change_job("Infiltrator")
	check(EventRunner.check_chance(fast, ck) > EventRunner.check_chance(PlayerStats.new(), ck), "higher SPD = better chase check")
	eq(EventRunner.check_chance(p, {"base": 500}), EventData.CHECK_MAX / 100.0, "check chance is capped")
	eq(EventRunner.check_chance(p, {"base": 0, "stat": ""}), EventData.CHECK_MIN / 100.0, "check chance has a floor")


func _effects() -> void:
	section("effects")
	var p := PlayerStats.new()
	p.gold = 95
	var r := EventRunner.resolve(p, "stalled_crawler", "A", rng(1))
	check(p.fatigue == 1 and p.karma == EventData.KARMA_START + 1, "A: Fatigue +1, Karma +1")
	check(r.lines.size() >= 3, "result lines describe what happened")
	eq(p.recent_events, ["stalled_crawler"], "event is remembered")
	# ทองคิดเป็น % ปัดขึ้น + ขั้นต่ำ + เพดาน
	eq(EventRunner._gold_amount(p, ["gold_pct", 10, 1]), 10, "10% of 95 rounds up to 10")
	p.gold = 0
	eq(EventRunner._gold_amount(p, ["gold_pct", 10, 2]), 2, "minimum applies")
	p.gold = 100000
	eq(EventRunner._gold_amount(p, ["gold_pct", 10, 1]), p.level * EventData.GOLD_PCT_CAP_PER_LEVEL, "capped by level")
	# จ่ายเงิน
	var c := PlayerStats.new()
	c.gold = 50
	EventRunner.resolve(c, "crash_memorial", "A", rng(1))
	check(c.gold == 45 and c.karma == EventData.KARMA_START + 2, "donate: -10% gold, Karma +2")
	# HP ไม่ทำให้ตาย
	var h := PlayerStats.new()
	h.hp = 1
	EventRunner._apply(h, ["hp_pct", -50], rng(1), {"lines": PackedStringArray(), "back_path": [], "faction": ""})
	eq(h.hp, 1, "HP loss never kills")
	# ถูกขโมย
	var st := PlayerStats.new()
	var before_items := st.items.size()
	var before_gold := st.gold
	EventRunner._steal(st, rng(3), {"lines": PackedStringArray(), "back_path": [], "faction": ""})
	check(st.items.size() == before_items - 1 or st.gold < before_gold, "steal takes an item or credits")
	# รางวัล tier ตามเลเวล
	var counts := {}
	var rr := rng(5)
	for i in 600:
		var t := EventRunner.reward_tier(12, 0, rr)
		counts[t] = counts.get(t, 0) + 1
	check(counts.has("epic") and counts.common > counts.epic, "Lv 12 rewards include some Epic (%s)" % str(counts))
	eq(EventRunner.reward_tier(1, 0, rng(1)), "common", "Lv 1 rewards are Common")
	eq(EventRunner.reward_tier(1, 1, rng(1)), "rare", "better tier = one step up")
	eq(EventRunner.reward_tier(12, 5, rng(1)), "epic", "tier shift caps at Epic")
	# เปลี่ยนฝ่ายผ่านอีเวนต์
	var k := PlayerStats.new()
	k.karma = 0
	var kr := EventRunner.resolve(k, "suit_breach", "C", rng(1))
	check(k.syndicate and kr.faction == "syndicate" and "\n".join(kr.lines).contains("Redline Syndicate"), "crossing below 0 is announced")
	# คูปอง
	var cp := PlayerStats.new()
	cp.karma = 45
	EventRunner.resolve(cp, "lost_child", "D", rng(1))
	eq(cp.coupons.get("concord", 0), 1, "D-C gives a Concord coupon")
	check(cp.items.has("Medkit"), "and a Medkit")


func _board_effects() -> void:
	section("back / skip / trail")
	var p := PlayerStats.new()
	for c in [Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0)]:
		p.remember_step(c)
	p.tile = Vector2i(3, 0)
	var path := p.step_back(2)
	eq(path, [Vector2i(2, 0), Vector2i(1, 0)] as Array[Vector2i], "back 2 walks the trail in reverse")
	eq(p.tile, Vector2i(1, 0), "position updated")
	eq(p.came_from, Board.NO_TILE, "free to pick any way after being pushed back")
	eq(p.step_back(5).size(), 1, "can't go back further than the trail")
	for i in 30:
		p.remember_step(Vector2i(i, 9))
	eq(p.trail.size(), EventData.TRAIL_SIZE, "trail is capped")
	var s := PlayerStats.new()
	EventRunner.resolve(s, "ion_storm", "B", rng(1))
	eq(s.skip_turns, 1, "skip adds a lost turn")


func _battle_link() -> void:
	section("fatigue -> battle")
	var p := PlayerStats.new()
	p.fatigue = 1
	var b := CCBattle.create_battle(CCBridge.config(p, "Goblin", 1))
	eq(b.units[0].focus, CCBalance.FOCUS_START - 1, "Fatigue 1 = start with 1 less Focus")
	p.fatigue = 9
	eq(CCBattle.create_battle(CCBridge.config(p, "Goblin", 1)).units[0].focus, 0, "Focus never starts below 0")


func _fights() -> void:
	section("combat events (step 2)")
	# ตัวคูณมอนสเตอร์
	var s1 := EventData.fight_scale(1, false)
	check(is_equal_approx(s1.hp, 1.0) and is_equal_approx(s1.atk, 1.0), "Lv 1, normal = x1")
	var s5 := EventData.fight_scale(5, true, {"atk": 0.7})
	check(is_equal_approx(s5.hp, 1.4 * EventData.MINI_BOSS_MULT) and is_equal_approx(s5.atk, 1.4 * EventData.MINI_BOSS_MULT * 0.7) and is_equal_approx(s5.def, 1.4),
		"Lv 5 mini-boss weakened: HP x2.1, ATK x1.47, ARM x1.4")
	var mc := CCBridge.monster_config("Goblin", {"hp": 2.0, "atk": 0.5})
	check(mc.stats.hp == 56 and mc.stats.atk == 5 and mc.stats.spd == GameData.MONSTERS.Goblin.spd, "monster_config scales stats (SPD unchanged)")
	# อีเวนต์ส่งคำขอต่อสู้
	var p := PlayerStats.new()
	p.gain_exp(200)
	var r := EventRunner.resolve(p, "raider_checkpoint", "C", rng(2))
	check(GameData.WILD_MONSTERS.has(r.fight.monster), "wild fight picks a wild monster")
	check(is_equal_approx(r.fight.opts.scale.hp, EventData.fight_scale(p.level, false, {}, 1.4).hp), "fight scales with level x raider power 1.4")
	check(r.fight.opts.scale.def == EventData.fight_scale(p.level, false).def, "power doesn't touch ARM")
	var g := EventRunner.resolve(p, "rockhide_grazer", "A", rng(2))
	check(g.fight.monster == "Rockhide Grazer" and g.fight.boss and g.fight.exp_mult == 2.0, "mini-boss request: x1.5, EXP x2")
	var h := EventRunner.resolve(p, "rockhide_grazer", "C", rng(2))
	eq(h.fight.opts.hero_mods, {"attack_mult": 1.2}, "poacher helps: hero ATK x1.2")
	var cfg := CCBridge.config(p, h.fight.monster, 1, h.fight.opts)
	check(is_equal_approx(cfg.hero.mods.get("attack_mult", 1.0), 1.2) and cfg.monster.stats.hp > GameData.MONSTERS["Rockhide Grazer"].hp,
		"bridge applies hero buff + boss scaling")
	# ผลหลังสู้
	var w := PlayerStats.new()
	var k0 := w.karma
	EventRunner.after_fight(w, g.fight, "win", rng(1))
	eq(w.karma, k0 + 3, "win effects apply (Karma +3)")
	var l := PlayerStats.new()
	l.remember_step(Vector2i(1, 1))
	var lost := EventRunner.after_fight(l, {"lose": [["back", 1], ["skip", 1]]}, "lose", rng(1))
	check(lost.back_path.is_empty() and l.skip_turns == 1, "real defeat skips 'back' (already sent home) but keeps the rest")
	var fr := PlayerStats.new()
	fr.gold = 100
	EventRunner.after_fight(fr, EventRunner.resolve(fr, "pit_duelist", "A", rng(1)).fight, "lose", rng(1))
	eq(fr.gold, 90, "friendly duel loss pays 10%")
	check(EventRunner.after_fight(PlayerStats.new(), g.fight, "run", rng(1)).lines.is_empty(), "running away gives nothing")
	# สัตว์พันธมิตร
	var a := PlayerStats.new()
	EventRunner.resolve(a, "snared_stalker", "A", rng(1))
	eq(a.ally_turns, 1, "treating the stalker gives an ally")
	var b := CCBattle.create_battle(CCBridge.config(a, "Goblin", 1))
	check(b.units[0].drone == 1 and b.units[0].drone_damage == EventData.ally_damage(a.level), "ally fights like a drone from turn 1")
	var shot: Array = b.log.filter(func(e): return e.t == "damage" and e.cause == "drone")
	check(not shot.is_empty() or CCBattle.phase(b) == "defend", "ally shoots at the start of the hero's turn")
	var weak := EventRunner.resolve(PlayerStats.new(), "snared_stalker", "C", rng(1))
	check(weak.fight.monster == "Dust Stalker" and is_equal_approx(weak.fight.opts.scale.atk, 0.7), "weakened stalker: ATK x0.7")
	# ไอเทมอีเวนต์
	check(not CCBattle.item_usable("Sedative Dart", "attack") and not CCBattle.item_usable("Sedative Dart", "defense"), "Sedative Dart isn't a battle item")
	var dart := PlayerStats.new()
	dart.karma = 45
	dart.items.assign(["Sedative Dart"])
	var dr := EventRunner.resolve(dart, "rockhide_grazer", "D", rng(1))
	check(dr.fight.is_empty() and not dart.items.has("Sedative Dart") and dart.karma == 48, "Sedative Dart calms the grazer without a fight")
	# การต่อสู้จริงจบได้ทุกแบบ (AI)
	var ok := true
	for id in ["raider_checkpoint", "pit_duelist", "snared_stalker", "rockhide_grazer"]:
		for lv in [1, 5]:
			var q := PlayerStats.new()
			q.gain_exp(_exp_to(lv))
			q.hp = q.max_hp()
			var rq := EventRunner.resolve(q, id, "C" if id != "pit_duelist" else "A", rng(lv))
			var s := CCBattle.create_battle(CCBridge.config(q, rq.fight.monster, lv, rq.fight.opts))
			var n := 0
			while s.result == "" and n < 300:
				s = CCBattle.apply_action(s, CCAi.choose(s)).state
				n += 1
			ok = ok and s.result != ""
	check(ok, "event fights finish with the AI at Lv 1 and 5")


func _shops() -> void:
	section("faction shops + marks (step 3)")
	var p := PlayerStats.new()
	eq(FactionShop.rank(p), 1, "Karma 20 = Concord rank 1")
	p.karma = 45
	eq(FactionShop.rank(p), 2, "Karma 45 = rank 2")
	p.karma = 85
	eq(FactionShop.rank(p), 3, "Karma 85 = rank 3")
	var s := PlayerStats.new()
	s.add_karma(-30)
	eq(FactionShop.rank(s), 1, "Karma -10 = Syndicate rank 1")
	s.add_karma(-40)
	eq(FactionShop.rank(s), 2, "Karma -50 = Syndicate rank 2")
	s.add_karma(55)
	check(s.syndicate and FactionShop.rank(s) == 1, "Karma 5 while still Syndicate = rank 1")
	# ราคา
	var rng1 := rng(7)
	var id := ItemDB.create("Plasma Blade", "rare", rng1)
	var base: int = GameData.item(id).price
	var c := PlayerStats.new()
	eq(FactionShop.price(c, id, "concord"), roundi(base * 0.9), "own faction rank 1: -10%")
	eq(FactionShop.price(c, id, "syndicate"), roundi(base * 1.25), "other faction: +25%")
	eq(FactionShop.price(c, id, "concord", true), roundi(base * 0.9 * 0.75), "coupon: another -25%")
	# ซื้อฝ่ายเดียวกัน + คูปอง
	c.gold = 5000
	c.coupons = {"concord": 1}
	var hp0 := c.hp
	var r := FactionShop.buy(c, id, "concord")
	check(r.ok and not r.marked and c.gear.has(id) and c.hp == hp0, "own-faction buy: no mark, no HP cost")
	check(r.coupon and c.coupons.concord == 0 and c.gold == 5000 - r.price, "coupon used once, gold paid")
	# ซื้อข้ามฝ่าย → ตรา Syndicate
	var id2 := ItemDB.create("Plasma Blade", "rare", rng1)
	var r2 := FactionShop.buy(c, id2, "syndicate")
	check(r2.ok and r2.marked and c.hp == hp0 - FactionShop.CROSS_HP_COST, "cross buy: marked, costs 5 HP")
	var d := GameData.item(id2)
	check(d.mark == "syndicate" and d.karma_per_battle == -FactionShop.MARK_KARMA and d.mods.has("attack_mult"), "Syndicate mark: attack x1.1, Karma -2 per battle")
	check(GameData.item_lines(id2).contains("Syndicate Mark"), "mark shows in item text")
	check(not c.barred_from("concord"), "a marked item in the bag doesn't bar you")
	c.equip(id2)
	check(c.barred_from("concord") and not c.barred_from("syndicate"), "wearing a Syndicate mark bars Concord towns")
	eq(c.karma_per_battle(), -2, "wearing it drifts Karma -2 per battle")
	# ตรา Concord (ฝ่ายชั่วซื้อของฝ่ายดี)
	var bad := PlayerStats.new()
	bad.add_karma(-30)
	bad.gold = 5000
	var id3 := ItemDB.create("Kevlar Vest", "rare", rng1)
	var spd0: int = GameData.item(id3).get("spd", 0)
	FactionShop.buy(bad, id3, "concord")
	check(GameData.item(id3).mark == "concord" and GameData.item(id3).spd == spd0 + 1 and GameData.item(id3).karma_per_battle == 2, "Concord mark: SPD +1, Karma +2")
	bad.equip(id3)
	check(bad.barred_from("syndicate") and not bad.barred_from("concord"), "Concord mark bars Syndicate towns")
	# เงิน/กระเป๋าไม่พอ
	var poor := PlayerStats.new()
	poor.gold = 0
	check(not FactionShop.buy(poor, ItemDB.create("Plasma Blade", "rare", rng1), "concord").ok, "can't buy without gold")
	# สต็อก
	var stock := FactionShop.roll_stock(PlayerStats.new(), rng1)
	check(stock.size() == FactionShop.STOCK_SIZE and stock.all(func(it): return GameData.rarity(it) == "rare"), "Lv 1 stock = 4 Rare items")
	# Freeport Exchange
	var f := PlayerStats.new()
	eq(FactionShop.exchange_price(f, "Sedative Dart"), 2, "dart costs 2 Scrip")
	f.renown = 20
	eq(FactionShop.exchange_price(f, "Sedative Dart"), 1, "Renown 20: 1 Scrip off")
	check(not FactionShop.buy_exchange(f, "Sedative Dart").ok, "no Scrip = no sale")
	f.scrip = 10
	check(FactionShop.buy_exchange(f, "Sedative Dart").ok and f.items.has("Sedative Dart") and f.scrip == 9, "bought a dart with Scrip")
	check(FactionShop.buy_exchange(f, "charged_shot").ok and f.owns_gem("charged_shot"), "gems are sold for Scrip")
	check(not FactionShop.buy_exchange(f, "charged_shot").ok, "can't buy a gem twice")
	for k in FactionShop.EXCHANGE_STOCK:
		check(GameData.ITEMS.has(k) or CCBalance.GEMS.has(k), "exchange item %s exists" % k)
	check(not GameData.ITEM_SHOP_STOCK.has("Sedative Dart"), "Sedative Dart moved to the Exchange")
	for cell in GameData.TOWNS:
		check(FactionShop.SHOP_NAMES.has(GameData.TOWNS[cell].get("faction", "")), "%s has a faction shop" % GameData.TOWNS[cell].name)


func _debts() -> void:
	section("loans, guild bonus, secret shop (step 3)")
	var p := PlayerStats.new()
	p.gold = 100
	EventRunner.resolve(p, "loan_broker", "C", rng(1))
	check(p.gold == 130 and p.debts.size() == 1 and p.debts[0].amount == 45 and p.debts[0].turns == EventData.LOAN_TURNS, "loan: +30 Gold, owe 45 in 5 turns")
	for i in EventData.LOAN_TURNS - 1:
		EventRunner.tick_debts(p, rng(1))
	check(p.debts.size() == 1 and p.gold == 130, "nothing collected before it's due")
	var r := EventRunner.tick_debts(p, rng(1))
	check(p.debts.is_empty() and p.gold == 85 and r.back_path.is_empty(), "due with enough gold: 45 auto-collected")
	var q := PlayerStats.new()
	q.gold = 0
	q.debts = [{"amount": 40, "turns": 1}]
	for c in [Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0)]:
		q.remember_step(c)
	var items0 := q.items.size()
	var r2 := EventRunner.tick_debts(q, rng(2))
	check(q.debts.is_empty() and r2.back_path.size() == 3 and (q.items.size() < items0 or q.gold == 0), "can't pay: robbed + pushed back 3, debt cleared")
	# Scrip ค้างจ่ายจากกิลด์
	var g := PlayerStats.new()
	g.renown = 20
	g.scrip = 3
	EventRunner.resolve(g, "guild_job_board", "D", rng(1))
	check(g.scrip == 0 and g.pending_scrip == 1, "recruit: pay 3 Scrip, 1 waiting")
	EventRunner.resolve(g, "stalled_crawler", "B", rng(1))
	check(g.scrip == 1 and g.pending_scrip == 0, "the waiting Scrip arrives at the next event")
	# ร้านลับ
	var s := PlayerStats.new()
	s.add_karma(-30)
	var o := EventRunner.resolve(s, "fugitive_signal", "D", rng(1))
	eq(o.open_shop, "syndicate", "smuggling opens the secret Syndicate Market")


func _exp_to(lv: int) -> int:
	var total := 0
	for l in range(1, lv):
		total += GameData.EXP_TO_LEVEL * l
	return total


func _save() -> void:
	section("save v2")
	var s := GameState.new()
	var p := s.player
	p.add_karma(-30)
	p.renown = 7
	p.scrip = 3
	p.fatigue = 2
	p.skip_turns = 1
	p.remember_step(Vector2i(1, 2))
	p.coupons = {"concord": 2}
	p.recent_events.assign(["ion_storm"])
	p.ally_turns = 1
	p.debts = [{"amount": 30, "turns": 2}]
	p.pending_scrip = 1
	p.gold = 9999
	var marked := ItemDB.create("Mesh Armor", "rare", rng(4))
	FactionShop.buy(p, marked, "concord") # ผู้เล่นอยู่ Syndicate → ได้ตรา Concord
	var d := SaveGame.to_dict(s)
	var s2 := GameState.new()
	check(SaveGame.apply(s2, JSON.parse_string(JSON.stringify(d))), "v2 save loads through JSON")
	eq(var_to_str(s2.player.to_dict()), var_to_str(p.to_dict()), "faction/event fields round-trip")
	ItemDB._instances.erase(marked)
	SaveGame.apply(GameState.new(), JSON.parse_string(JSON.stringify(d)))
	eq(GameData.item(marked).get("mark", ""), "concord", "item marks survive save/load")
	var old := d.duplicate(true)
	old.version = 1
	for k in ["karma", "syndicate", "renown", "scrip", "fatigue", "skip_turns", "trail", "coupons", "recent_events", "ally_turns", "debts", "pending_scrip"]:
		old.player.erase(k)
	var s3 := GameState.new()
	check(SaveGame.apply(s3, old), "v1 save still loads")
	check(s3.player.karma == EventData.KARMA_START and not s3.player.syndicate and s3.player.renown == 0, "v1 save gets default karma/renown")


## ทุกอีเวนต์ × ทุกตัวเลือก × ผู้เล่นหลายแบบ: ไม่ error, HP ≥ 1, เงิน ≥ 0
func _fuzz() -> void:
	section("every event x every option")
	var ok := true
	var r := rng(42)
	for i in 300:
		var p := PlayerStats.new()
		p.change_job(GameData.JOBS.keys()[i % GameData.JOBS.size()])
		p.gold = r.randi_range(0, 400)
		p.karma = r.randi_range(-60, 60)
		p.syndicate = p.karma < 0
		p.renown = r.randi_range(0, 30)
		p.scrip = r.randi_range(0, 6)
		if i % 3 == 0:
			p.items.clear()
		for c in r.randi_range(0, 5):
			p.remember_step(Vector2i(c, 0))
		var id := EventRunner.pick(p, r)
		for o in EventRunner.visible_options(p, id):
			if EventRunner.availability(p, o).ok:
				var res := EventRunner.resolve(p, id, o.key, r)
				ok = ok and not res.lines.is_empty()
				if not res.fight.is_empty():
					ok = ok and GameData.MONSTERS.has(res.fight.monster)
					EventRunner.after_fight(p, res.fight, ["win", "lose", "run"][r.randi_range(0, 2)], r)
		ok = ok and p.hp >= 1 and p.gold >= 0 and p.gear.size() <= GameData.MAX_GEAR and p.items.size() <= GameData.MAX_ITEMS
	check(ok, "300 random players run every available option safely")
	var seen := {}
	var pr := PlayerStats.new()
	for i in 200:
		seen[EventRunner.pick(pr, r)] = true
		EventRunner._remember(pr, EventRunner.pick(pr, r))
	eq(seen.size(), EventData.EVENTS.size(), "every event can come up")

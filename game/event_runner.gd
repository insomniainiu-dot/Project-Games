class_name EventRunner
## ตัวรันอีเวนต์บนกระดาน (ข้อมูลอยู่ที่ EventData) — ไม่แตะ UI: แก้ PlayerStats แล้วคืนข้อความผล
## ความสุ่มทั้งหมดมาจาก rng ที่ส่งเข้ามา → test ได้
##   var id := EventRunner.pick(player, rng)
##   var r := EventRunner.resolve(player, id, "A", rng)   # {"lines", "back_path", "faction"}
## การเดินถอย (back_path) ตำแหน่งผู้เล่นเปลี่ยนแล้ว — ฝั่ง UI แค่เล่นแอนิเมชันตาม


## สุ่มอีเวนต์ตามน้ำหนัก ไม่ซ้ำกับอีเวนต์ล่าสุด
static func pick(player: PlayerStats, rng: RandomNumberGenerator) -> String:
	var pool := {}
	for id in EventData.EVENTS:
		if not player.recent_events.has(id):
			pool[id] = int(EventData.EVENTS[id].get("weight", 10))
	if pool.is_empty():
		pool = {EventData.EVENTS.keys()[0]: 1}
	return CCBattle._pick(pool, rng)


static func option(event_id: String, key: String) -> Dictionary:
	for o in EventData.EVENTS[event_id].options:
		if o.key == key:
			return o
	return {}


## ตัวเลือกที่แสดงได้ (D ที่ไม่ผ่านเงื่อนไขจะถูกซ่อน — ผู้เล่นไม่รู้ว่ามี)
static func visible_options(player: PlayerStats, event_id: String) -> Array:
	return EventData.EVENTS[event_id].options.filter(func(o): return player.meets(o.get("need", "")))


## เลือกได้ไหม: {"ok": bool, "reason": ""} — ถ้าจ่าย cost ไม่ได้แต่มี alt ยังเลือกได้
static func availability(player: PlayerStats, opt: Dictionary) -> Dictionary:
	if not player.meets(opt.get("need", "")):
		return {"ok": false, "reason": "Requires %s." % _need_text(opt.need)}
	if not can_pay(player, opt.get("cost", [])) and not opt.has("alt"):
		return {"ok": false, "reason": "You can't afford it (%s)." % ", ".join(_effect_texts(player, _cost_effects(opt.cost)))}
	return {"ok": true, "reason": ""}


static func can_pay(player: PlayerStats, cost: Array) -> bool:
	for c in cost:
		match c[0]:
			"scrip":
				if player.scrip < int(c[1]):
					return false
			"use_item":
				if not player.items.has(c[1]):
					return false
			"lose_gold_pct":
				if player.gold < _gold_amount(player, c):
					return false
	return true


## โอกาสผ่านเช็ค (0..1)
static func check_chance(player: PlayerStats, check: Dictionary) -> float:
	var c := float(check.get("base", 50))
	var stat: String = check.get("stat", "")
	if stat != "":
		c += (player.stat(stat) - EventData.CHECK_STAT_BASE) * EventData.CHECK_PER_STAT
	return clampf(c, EventData.CHECK_MIN, EventData.CHECK_MAX) / 100.0


## ข้อความปุ่มตัวเลือก เช่น "A. Help fix it  [Fatigue +1, Karma +1, Reward]"
static func describe(player: PlayerStats, opt: Dictionary) -> String:
	var parts := PackedStringArray()
	var paying: bool = can_pay(player, opt.get("cost", []))
	if paying:
		parts.append_array(_effect_texts(player, _cost_effects(opt.get("cost", []))))
		parts.append_array(_effect_texts(player, opt.get("effects", [])))
	else:
		parts.append_array(_effect_texts(player, opt.get("alt", [])))
	if opt.has("check"):
		var ck: Dictionary = opt.check
		var stat: String = ck.get("stat", "")
		parts.append("%s check %d%%" % [GameData.stat_label(stat) if stat != "" else "Luck", roundi(check_chance(player, ck) * 100)])
	if opt.has("roll"):
		parts.append("%d%% chance: %s" % [opt.roll.chance, ", ".join(_effect_texts(player, opt.roll.effects))])
	var tag := "" if opt.get("need", "") == "" else " (%s)" % EventData.FACTION_NAMES[opt.need]
	var text := "%s. %s%s" % [opt.key, opt.label, tag]
	if not parts.is_empty():
		text += "  [%s]" % ", ".join(parts)
	return text


# ================================================================ คิดผล
## ผล: {"lines", "back_path", "faction", "fight"} — fight ไม่ว่าง = ฝั่ง UI ต้องสู้ แล้วเรียก after_fight(...)
static func resolve(player: PlayerStats, event_id: String, key: String, rng: RandomNumberGenerator) -> Dictionary:
	var opt := option(event_id, key)
	var out := _new_out()
	_remember(player, event_id)
	if player.pending_scrip > 0: # รางวัลค้างจากอีเวนต์กิลด์ครั้งก่อน
		_apply(player, ["scrip", player.pending_scrip], rng, out)
		player.pending_scrip = 0
	if opt.is_empty() or not availability(player, opt).ok:
		out.lines.append("Nothing happens.")
		return out
	if can_pay(player, opt.get("cost", [])):
		_apply_all(player, _cost_effects(opt.get("cost", [])), rng, out)
		_apply_all(player, opt.get("effects", []), rng, out)
	else:
		_apply_all(player, opt.alt, rng, out)
	if opt.has("check"):
		var ok := rng.randf() < check_chance(player, opt.check)
		out.lines.append("Check %s!" % ("passed" if ok else "failed"))
		_apply_all(player, opt.check["pass"] if ok else opt.check["fail"], rng, out)
	if opt.has("roll") and rng.randf() * 100.0 < float(opt.roll.chance):
		_apply_all(player, opt.roll.effects, rng, out)
	if out.lines.is_empty():
		out.lines.append("You move on.")
	return out


static func _new_out() -> Dictionary:
	return {"lines": PackedStringArray(), "back_path": [], "faction": "", "fight": {}, "open_shop": ""}


## จบวัน: นับถอยหลังหนี้ ครบกำหนดแล้ว เงินพอ = หักอัตโนมัติ / ไม่พอ = ถูกขโมย + ถอย (หนี้ถูกยกไป)
static func tick_debts(player: PlayerStats, rng: RandomNumberGenerator) -> Dictionary:
	var out := _new_out()
	var keep: Array = []
	for d in player.debts:
		d.turns -= 1
		if d.turns > 0:
			keep.append(d)
			continue
		if player.gold >= int(d.amount):
			player.gold -= int(d.amount)
			out.lines.append("A Syndicate collector takes the %d Gold you owe." % d.amount)
		else:
			out.lines.append("You couldn't repay %d Gold. The Syndicate collects... their way." % d.amount)
			_apply(player, ["steal"], rng, out)
			_apply(player, ["back", EventData.LOAN_PENALTY_BACK], rng, out)
	player.debts = keep
	return out


## หลังสู้ในอีเวนต์จบ: ใส่ผล win / lose ของอีเวนต์ (แพ้แบบจริงจังถูกส่งกลับปราสาทแล้ว จึงข้าม "back")
## result = "win" / "lose" / "run" (หนี = ไม่ได้อะไรเพิ่ม)
static func after_fight(player: PlayerStats, fight: Dictionary, result: String, rng: RandomNumberGenerator) -> Dictionary:
	var out := _new_out()
	match result:
		"win":
			_apply_all(player, fight.get("win", []), rng, out)
		"lose":
			var lose: Array = fight.get("lose", [])
			if not fight.get("friendly", false):
				lose = lose.filter(func(e): return e[0] != "back")
			_apply_all(player, lose, rng, out)
	return out


## สเปกการต่อสู้จากข้อมูลอีเวนต์ → คำขอที่ TileEvents.fight ใช้ได้เลย
static func _fight_request(player: PlayerStats, spec: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
	var monster: String = spec.get("monster", EventData.WILD_FIGHT)
	if monster == EventData.WILD_FIGHT:
		monster = GameData.WILD_MONSTERS[rng.randi_range(0, GameData.WILD_MONSTERS.size() - 1)]
	var opts := {"scale": EventData.fight_scale(player.level, spec.get("boss", false), spec.get("weak", {}), float(spec.get("power", 1.0)))}
	if spec.has("hero_mods"):
		opts.hero_mods = spec.hero_mods
	return {"monster": monster, "opts": opts, "friendly": spec.get("friendly", false), "exp_mult": float(spec.get("exp_mult", 1.0)),
		"boss": spec.get("boss", false), "win": spec.get("win", []), "lose": spec.get("lose", [])}


## cost เขียนเป็นจำนวนที่ "จ่าย" (บวก) → แปลงเป็น effect: ["scrip", 5] = Scrip −5
static func _cost_effects(cost: Array) -> Array:
	var out := []
	for c in cost:
		if c[0] == "scrip":
			out.append(["scrip", -int(c[1])])
		else:
			out.append(c) # use_item / lose_gold_pct เป็นการเสียอยู่แล้ว
	return out


static func _remember(player: PlayerStats, event_id: String) -> void:
	player.recent_events.append(event_id)
	while player.recent_events.size() > EventData.RECENT_EVENTS:
		player.recent_events.remove_at(0)


static func _apply_all(player: PlayerStats, effects: Array, rng: RandomNumberGenerator, out: Dictionary) -> void:
	for e in effects:
		_apply(player, e, rng, out)


static func _apply(player: PlayerStats, e: Array, rng: RandomNumberGenerator, out: Dictionary) -> void:
	match e[0]:
		"karma":
			var switched := player.add_karma(int(e[1]))
			out.lines.append("Karma %+d (now %d)" % [e[1], player.karma])
			if switched != "":
				out.faction = switched
				out.lines.append("You are now with the %s!" % EventData.FACTION_NAMES[switched])
		"renown":
			player.renown += int(e[1])
			out.lines.append("Renown %+d (now %d)" % [e[1], player.renown])
		"scrip":
			player.scrip += int(e[1])
			out.lines.append("Scrip %+d" % e[1])
		"fatigue":
			player.fatigue += int(e[1])
			out.lines.append("Fatigue +%d (next battle starts with %d less Focus)" % [e[1], e[1]])
		"gold_pct":
			var g := _gold_amount(player, e)
			player.gold += g
			out.lines.append("+%d Gold" % g)
		"lose_gold_pct":
			var g := mini(player.gold, _gold_amount(player, e))
			player.gold -= g
			out.lines.append("-%d Gold" % g)
		"hp_pct":
			var amount := ceili(player.max_hp() * absf(e[1]) / 100.0)
			if e[1] > 0:
				out.lines.append("Recovered %d HP" % player.heal(amount))
			else:
				var before := player.hp
				player.hp = maxi(1, player.hp - amount)
				out.lines.append("Lost %d HP" % (before - player.hp))
		"item":
			if player.add_item(e[1]):
				out.lines.append("Got %s" % e[1])
			else:
				var g := int(GameData.ITEMS[e[1]].price / 2)
				player.gold += g
				out.lines.append("Bag full: sold %s for %d Gold" % [e[1], g])
		"use_item":
			player.items.erase(e[1])
			out.lines.append("Used %s" % e[1])
		"reward":
			for i in int(e[1]):
				_reward(player, int(e[2]) if e.size() > 2 else 0, rng, out)
		"back":
			var path := player.step_back(int(e[1]))
			out.back_path.append_array(path)
			out.lines.append("Pushed back %d tile%s" % [path.size(), "" if path.size() == 1 else "s"])
		"skip":
			player.skip_turns += int(e[1])
			out.lines.append("You lose %d turn%s" % [e[1], "" if int(e[1]) == 1 else "s"])
		"steal":
			_steal(player, rng, out)
		"coupon":
			player.coupons[e[1]] = int(player.coupons.get(e[1], 0)) + 1
			out.lines.append("Got a %s shop coupon" % EventData.FACTION_NAMES[e[1]])
		"loan":
			var g := _gold_amount(player, e)
			var owe := ceili(g * EventData.LOAN_INTEREST)
			player.gold += g
			player.debts.append({"amount": owe, "turns": EventData.LOAN_TURNS})
			out.lines.append("Borrowed %d Gold. You owe %d within %d turns." % [g, owe, EventData.LOAN_TURNS])
		"scrip_next":
			player.pending_scrip += int(e[1])
			out.lines.append("+%d Scrip waiting for you at the next event" % e[1])
		"open_shop":
			out.open_shop = e[1]
			out.lines.append("A hidden %s opens its doors to you." % FactionShop.SHOP_NAMES[e[1]])
		"ally":
			player.ally_turns = maxi(player.ally_turns, int(e[1]))
			out.lines.append("A grateful creature will fight beside you next battle (%d dmg/turn)" % EventData.ally_damage(player.level))
		"fight": # ต้องเป็น effect สุดท้ายของชุด (ผลหลังสู้อยู่ใน win / lose)
			out.fight = _fight_request(player, e[1], rng)
			out.lines.append("%s: %s!" % ["MINI-BOSS" if out.fight.boss else ("Friendly duel" if out.fight.friendly else "Fight"), out.fight.monster])
		_:
			push_error("EventRunner: unknown effect %s" % str(e))


## "X% ของเงินที่ถือ" ปัดขึ้น อย่างน้อยตามที่กำหนด ไม่เกิน เลเวล × GOLD_PCT_CAP_PER_LEVEL
static func _gold_amount(player: PlayerStats, e: Array) -> int:
	var g := maxi(ceili(player.gold * float(e[1]) / 100.0), int(e[2]) if e.size() > 2 else 0)
	return mini(g, player.level * EventData.GOLD_PCT_CAP_PER_LEVEL)


## [รางวัลสุ่ม] 1 ชิ้น — shift = เลื่อน tier ของอุปกรณ์ขึ้นกี่ขั้น
static func _reward(player: PlayerStats, shift: int, rng: RandomNumberGenerator, out: Dictionary) -> void:
	match CCBattle._pick(EventData.REWARD_WEIGHTS, rng):
		"credits":
			_apply(player, ["gold_pct", 10, 1], rng, out)
		"consumable":
			var stock: Array = GameData.ITEM_SHOP_STOCK
			_apply(player, ["item", stock[rng.randi_range(0, stock.size() - 1)]], rng, out)
		"gear":
			var tier := reward_tier(player.level, shift, rng)
			var bases := []
			for cat in GameData.SMITHY_STOCK:
				bases.append_array(GameData.SMITHY_STOCK[cat])
			var id := ItemDB.create(bases[rng.randi_range(0, bases.size() - 1)], tier, rng)
			if player.add_gear(id):
				out.lines.append("Got %s" % GameData.display_name(id))
			else:
				var g := GameData.sell_price(id)
				player.gold += g
				out.lines.append("Gear bag full: sold %s for %d Gold" % [GameData.display_name(id), g])


## tier ของอุปกรณ์รางวัลตามเลเวล แล้วเลื่อนขึ้น shift ขั้น (สูงสุด Epic)
static func reward_tier(level: int, shift: int, rng: RandomNumberGenerator) -> String:
	var weights: Dictionary = EventData.REWARD_GEAR_TIERS[0][1]
	for row in EventData.REWARD_GEAR_TIERS:
		if level >= int(row[0]):
			weights = row[1]
	var i: int = EventData.TIER_ORDER.find(CCBattle._pick(weights, rng))
	return EventData.TIER_ORDER[mini(i + shift, EventData.TIER_ORDER.size() - 1)]


## ถูกขโมย: ไอเทมใช้แล้วหมด 1 ชิ้น หรือ 10% ของเงิน (ไม่ขโมยของที่สวม)
static func _steal(player: PlayerStats, rng: RandomNumberGenerator, out: Dictionary) -> void:
	if not player.items.is_empty() and rng.randf() < 0.5:
		var it: String = player.items[rng.randi_range(0, player.items.size() - 1)]
		player.items.erase(it)
		out.lines.append("Stolen: %s" % it)
	else:
		_apply(player, ["lose_gold_pct", 10, 1], rng, out)


# ================================================================ ข้อความ
static func _need_text(need: String) -> String:
	match need:
		"concord":
			return "Beacon Concord, Karma %d+" % EventData.D_CONCORD_KARMA
		"syndicate":
			return "Redline Syndicate"
		"freeport":
			return "Freeport Renown %d+" % EventData.D_FREEPORT_RENOWN
	return need


static func _effect_texts(player: PlayerStats, effects: Array) -> PackedStringArray:
	var out := PackedStringArray()
	for e in effects:
		match e[0]:
			"karma", "renown", "scrip":
				out.append("%s %+d" % [str(e[0]).capitalize(), e[1]])
			"fatigue":
				out.append("Fatigue +%d" % e[1])
			"gold_pct":
				out.append("+%d Gold" % _gold_amount(player, e))
			"lose_gold_pct":
				out.append("-%d Gold" % _gold_amount(player, e))
			"hp_pct":
				out.append("HP %+d%%" % e[1])
			"item":
				out.append(str(e[1]))
			"use_item":
				out.append("uses a %s" % e[1])
			"reward":
				var s := "Reward" if int(e[1]) == 1 else "Reward x%d" % e[1]
				out.append(s + (" (better tier)" if e.size() > 2 and int(e[2]) > 0 else ""))
			"back":
				out.append("Back %d" % e[1])
			"skip":
				out.append("Lose %d turn" % e[1])
			"steal":
				out.append("Robbed")
			"coupon":
				out.append("Shop coupon")
			"ally":
				out.append("Ally next battle")
			"loan":
				var g := _gold_amount(player, e)
				out.append("+%d Gold now, owe %d in %d turns" % [g, ceili(g * EventData.LOAN_INTEREST), EventData.LOAN_TURNS])
			"scrip_next":
				out.append("Scrip +%d later" % e[1])
			"open_shop":
				out.append("Secret shop")
			"fight":
				var spec: Dictionary = e[1]
				var who: String = spec.get("monster", EventData.WILD_FIGHT)
				var label := "Mini-boss" if spec.get("boss", false) else ("Duel" if spec.get("friendly", false) else "Fight")
				out.append("%s%s" % [label, "" if who == EventData.WILD_FIGHT else " " + who])
				var win := _effect_texts(player, spec.get("win", []))
				if not win.is_empty():
					out.append("win: " + ", ".join(win))
	return out

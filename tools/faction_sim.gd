extends SceneTree
## Simulation ระบบฝ่าย + อีเวนต์ + Overclock (docs/faction_event_design.md ขั้น 5)
##   Godot --headless --path . --script res://tools/faction_sim.gd -- 300 30
##     อาร์กิวเมนต์: จำนวนรอบต่อแนวทาง / จำนวนอีเวนต์ต่อรอบ
## ผู้เล่น AI เจออีเวนต์ต่อกัน N ครั้ง (การต่อสู้ในอีเวนต์ใช้ CCBattle + CCAi จริง) ด้วย 4 แนวทาง:
##   good = เลือก Karma มากสุด · evil = Karma น้อยสุด · guild = D-F ถ้าได้ ไม่งั้น Renown/Scrip มากสุด แล้วค่อยดี · random

const STYLES := ["good", "evil", "guild", "random"]
const LEVEL := 4 ## เลเวลผู้เล่นตอนจำลอง (กลางเกม)
const START_GOLD := 150
const GOLD_TILE_AVG := 25.0 ## ช่อง gold ให้เฉลี่ย 10–40 → ใช้เทียบ "เงินต่ออีเวนต์"


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var runs := int(args[0]) if args.size() > 0 else 300
	var per_run := int(args[1]) if args.size() > 1 else 30
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	print("\nFaction / event simulation - %d runs x %d events per style (Lv %d, start %d Gold)\n" % [runs, per_run, LEVEL, START_GOLD])
	print("%-8s %8s %8s %8s %8s %8s %8s %8s %8s %8s %8s" % ["style", "karma", "synd%", "dc@", "renown", "df@", "scrip", "gold/ev", "items", "turns-", "fights"])
	for style in STYLES:
		var s := _run_style(style, runs, per_run, rng)
		print("%-8s %8.1f %7d%% %8s %8.1f %8s %8.1f %8.1f %8.2f %8.2f %8.2f" % [style, s.karma, roundi(s.synd * 100), s.dc_at, s.renown, s.df_at,
			s.scrip, s.gold_per_event, s.items_per_event, s.turns_lost_per_event, s.fights_per_event])
	print("\n(karma/renown/scrip = average after %d events · synd%% = runs that ended in the Syndicate" % per_run)
	print(" dc@ / df@ = median event number when D-C (Karma 40) / D-F (Renown 20) unlocked, '-' = under half the runs")
	print(" gold/ev = net Gold per event incl. selling rewards at half price · compare: Gold tile = %.0f" % GOLD_TILE_AVG)
	print(" items = consumables + gear gained per event · turns- = lost turns + tiles pushed back per event)")
	_overclock(rng)
	quit()


# ================================================================ อีเวนต์
func _run_style(style: String, runs: int, per_run: int, rng: RandomNumberGenerator) -> Dictionary:
	var tot := {"karma": 0.0, "synd": 0.0, "renown": 0.0, "scrip": 0.0, "gold": 0.0, "items": 0.0, "lost": 0.0, "fights": 0.0}
	var dc_hits := []
	var df_hits := []
	for r in runs:
		var p := PlayerStats.new()
		p.change_job(GameData.JOBS.keys()[r % GameData.JOBS.size()])
		p.gain_exp(_exp_to(LEVEL))
		p.gold = START_GOLD
		var dc := -1
		var df := -1
		var value0 := _wealth(p)
		for i in per_run:
			p.hp = p.max_hp() # ระหว่างอีเวนต์ถือว่าพักฟื้นได้ (วัดแค่ผลของอีเวนต์)
			for c in 4:
				p.remember_step(Vector2i(i, c))
			var id := EventRunner.pick(p, rng)
			var opt := _choose(style, p, id, rng)
			var before_skip := p.skip_turns
			var res := EventRunner.resolve(p, id, opt.key, rng)
			tot.lost += float(p.skip_turns - before_skip + res.back_path.size())
			if not res.fight.is_empty():
				tot.fights += 1.0
				var outcome := _fight(p, res.fight, rng)
				var after := EventRunner.after_fight(p, res.fight, outcome, rng)
				tot.lost += float(after.back_path.size())
			p.skip_turns = 0
			p.fatigue = 0
			if dc < 0 and p.meets("concord"):
				dc = i + 1
			if df < 0 and p.meets("freeport"):
				df = i + 1
		tot.karma += p.karma
		tot.synd += 1.0 if p.syndicate else 0.0
		tot.renown += p.renown
		tot.scrip += p.scrip
		tot.gold += _wealth(p) - value0
		tot.items += float(p.items.size() + p.gear.size())
		if dc > 0:
			dc_hits.append(dc)
		if df > 0:
			df_hits.append(df)
	var n := float(runs)
	var ev := n * per_run
	return {"karma": tot.karma / n, "synd": tot.synd / n, "renown": tot.renown / n, "scrip": tot.scrip / n,
		"gold_per_event": tot.gold / ev, "items_per_event": tot.items / ev, "turns_lost_per_event": tot.lost / ev,
		"fights_per_event": tot.fights / ev, "dc_at": _median_text(dc_hits, runs), "df_at": _median_text(df_hits, runs)}


## มูลค่ารวม = เงิน + ของทุกชิ้นถ้าขายครึ่งราคา (ไม่นับของที่สวมตั้งแต่ต้น)
func _wealth(p: PlayerStats) -> float:
	var w := float(p.gold)
	for it in p.items:
		w += GameData.ITEMS[it].price / 2.0
	for it in p.gear:
		w += GameData.sell_price(it)
	return w


func _choose(style: String, p: PlayerStats, id: String, rng: RandomNumberGenerator) -> Dictionary:
	var opts: Array = EventRunner.visible_options(p, id).filter(func(o): return EventRunner.availability(p, o).ok)
	if style == "random":
		return opts[rng.randi_range(0, opts.size() - 1)]
	var best: Dictionary = opts[0]
	var best_score := -INF
	for o in opts:
		var k := _sum(o, "karma")
		var score := 0.0
		match style:
			"good":
				score = k * 10 + _sum(o, "renown")
			"evil":
				score = -k * 10 + _sum(o, "gold_pct") * 0.1
			"guild":
				score = (_sum(o, "renown") + _sum(o, "scrip")) * 10 + k
		score += rng.randf() * 0.01 # เสมอกันสุ่ม
		if score > best_score:
			best_score = score
			best = o
	return best


## ผลรวมของ effect ชนิดหนึ่งในตัวเลือก (นับทุกชุด: effects / check pass / fight win — ค่าคาดหวังแบบหยาบ)
func _sum(o: Dictionary, kind: String) -> float:
	var lists: Array = [o.get("effects", [])]
	if o.has("check"):
		lists.append(o.check["pass"])
	var total := 0.0
	for lst in lists:
		for e in lst:
			if e[0] == kind:
				total += float(e[1])
			elif e[0] == "fight":
				for w in e[1].get("win", []):
					if w[0] == kind:
						total += float(w[1])
	if kind == "scrip":
		for c in o.get("cost", []):
			if c[0] == "scrip":
				total -= float(c[1])
	return total


func _fight(p: PlayerStats, fight: Dictionary, rng: RandomNumberGenerator) -> String:
	var s := CCBattle.create_battle(CCBridge.config(p, fight.monster, rng.randi(), fight.opts))
	while s.result == "":
		s = CCBattle.apply_action(s, CCAi.choose(s)).state
	CCBridge.apply_result(p, s)
	p.ally_turns = 0
	return s.result


func _median_text(hits: Array, runs: int) -> String:
	if hits.size() * 2 < runs:
		return "-"
	hits.sort()
	return str(hits[hits.size() / 2])


func _exp_to(lv: int) -> int:
	var total := 0
	for l in range(1, lv):
		total += GameData.EXP_TO_LEVEL * l
	return total


# ================================================================ Overclock
## ค่าใช้จ่ายเฉลี่ย (Gold + ครั้ง) จนถึง +N ที่ Fabricator ฝ่ายเดียวกัน / Smithy / มี Stabilizer ทุกครั้งตั้งแต่ +2
func _overclock(rng: RandomNumberGenerator) -> void:
	print("\nOverclock: average Gold (and attempts) to reach +N on a Rare Plasma Blade (tier price %d)" % ItemDB.base_price(ItemDB.create("Plasma Blade", "rare", rng)))
	print("%-28s %14s %14s %14s %14s %14s" % ["venue", "+1", "+2", "+3", "+4", "+5"])
	for setup in [["own faction (+15%)", "concord", false], ["Smithy", "smithy", false], ["rival faction (-15%)", "syndicate", false],
			["own faction + Stabilizer", "concord", true]]:
		var line := "%-28s" % setup[0]
		for target in range(1, Overclock.MAX_PLUS + 1):
			var gold := 0.0
			var tries := 0.0
			var stabs := 0.0
			var runs := 400
			for r in runs:
				var p := PlayerStats.new()
				p.gold = 10000000
				var id := ItemDB.create("Plasma Blade", "rare", rng)
				p.add_gear(id)
				var g0 := p.gold
				var n := 0
				while ItemDB.plus_of(id) < target and n < 500:
					var use: bool = setup[2] and ItemDB.plus_of(id) >= 1
					if use:
						p.items.assign([Overclock.STABILIZER])
						stabs += 1.0
					Overclock.attempt(p, id, setup[1], use, rng)
					n += 1
				gold += g0 - p.gold
				tries += n
			line += "%14s" % ("%d (%.1f)" % [roundi(gold / runs), tries / runs])
			if setup[2] and target == Overclock.MAX_PLUS:
				line += "  stabilizers to +5: %.1f" % (stabs / runs / 1.0)
		print(line)
	var rare := ItemDB.create("Plasma Blade", "rare", rng)
	var gains := PackedStringArray()
	for n in range(0, Overclock.MAX_PLUS + 1):
		ItemDB.set_plus(rare, n)
		gains.append("+%d: ATK %d" % [n, GameData.item(rare).atk])
	print("Stat curve (Rare Plasma Blade): %s" % "  ".join(gains))

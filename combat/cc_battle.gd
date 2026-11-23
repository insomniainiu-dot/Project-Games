class_name CCBattle
## ระบบต่อสู้แบบ "ช่องเช็ค" (1 ต่อ 1 ไม่มีตำแหน่งยืน) — pure: ไม่แตะ UI ไม่แก้ state เดิม
## ทุกความสุ่มมาจาก state.rng_state → config + รายการ action = replay ได้ 100%
##
## เทิร์นของผู้เล่น: เลือกท่า (+ Focus เพิ่ม %) → มอนสเตอร์ป้องกันอัตโนมัติ (สุ่มตาม cc_defense)
## เทิร์นของมอนสเตอร์: engine ประกาศท่า (state.pending) → ผู้เล่นเลือกวิธีป้องกัน (+ Focus) → คิดผล
##
## config = {
##   "seed": int,
##   "hero": {"name", "job", "stats": {hp, atk, def, mag, spd, lck (ไม่ใส่ = 0)}, "hp": HP ปัจจุบัน, "items": [...],
##            "attack_def": ท่า Attack จากอาวุธ (CCBalance.weapon_attack, ไม่ใส่ = ACTIONS.attack),
##            "gems": [Skill Gem สูงสุด 2] (ไม่ใส่ = CCBalance.default_gems(job))},
##   "monster": {"name", "stats", "actions": {ท่า: น้ำหนัก}, "defense": {วิธีป้องกัน: น้ำหนัก}, "gold"},
## }
## Action ของผู้เล่น:
##   ตาบุก     : {"type": "skill", "skill": "attack"/gem ที่ใส่ไว้, "focus": n}
##               {"type": "guard"} / {"type": "item", "item": ไอเทมโจมตี} / {"type": "flee", "focus": n}
##   ตาป้องกัน : {"type": "defend", "defense": "block"/"dodge"/"counter", "focus": n}
##               {"type": "item", "item": ไอเทมฮีล/เสริมพลัง} (สละการป้องกัน) / {"type": "flee", "focus": n} (พลาด = รับเต็ม ๆ)
## state.result: "" = ยังไม่จบ, "win" / "lose" / "run"

const HERO := 0
const MONSTER := 1


# ================================================================ ตัวช่วยคำนวณ (UI/AI ใช้ได้)
## โอกาสผ่านต่อช่อง (0..1) — Focus แต้มละ +FOCUS_CHANCE_BONUS%, bonus = % เพิ่มจาก Passive (ไม่ทะลุเพดานปกติ)
static func chance(stat_value: float, focus := 0, bonus := 0.0) -> float:
	var c := clampf(CCBalance.CHANCE_BASE + stat_value * CCBalance.CHANCE_PER_STAT + bonus, CCBalance.CHANCE_MIN, CCBalance.CHANCE_MAX)
	if focus > 0:
		c = minf(c + focus * CCBalance.FOCUS_CHANCE_BONUS, CCBalance.CHANCE_MAX_WITH_FOCUS)
	return c / 100.0


# ---------------------------------------------------------------- Passive mods
## ค่า mod จาก Passive Tree ของตัวละคร (มอนสเตอร์ไม่มี) — คีย์ดูที่ PassiveTree.NODES
static func mod(unit: Dictionary, key: String, default = 0):
	return unit.get("mods", {}).get(key, default)


## ข้อมูลท่าของ unit นี้: Attack มาจากอาวุธที่ถือ (unit.attack_def) ท่าอื่นมาจาก CCBalance.ACTIONS
static func action_def(unit: Dictionary, skill: String) -> Dictionary:
	if skill == "attack" and not unit.get("attack_def", {}).is_empty():
		return unit.attack_def
	return CCBalance.ACTIONS[skill]


## จำนวนช่องของท่า (Ambush: ตาแรกของการต่อสู้ Attack +1 ช่อง)
static func slots_for(s: Dictionary, who: int, skill: String) -> int:
	var n: int = action_def(s.units[who], skill).slots
	if skill == "attack" and s.get("round", 0) == 1:
		n += int(mod(s.units[who], "first_turn_attack_slots"))
	return n


## โอกาสผ่านต่อช่องของท่า (รวม Neural Link: มีโดรนอยู่ เช็ค TEC +5%)
static func action_chance(unit: Dictionary, skill: String, focus := 0) -> float:
	var d := action_def(unit, skill)
	var bonus := 0.0
	if d.check == "mag" and unit.get("drone", 0) > 0:
		bonus += float(mod(unit, "drone_check_bonus"))
	return chance(unit.stats[d.check], focus, bonus)


## ท่าที่ใช้ได้ = Attack (จากอาวุธ) + Skill Gem ที่ใส่ไว้ (ไม่ระบุ gems = gem เริ่มต้นของอาชีพ)
static func skills_for(unit: Dictionary) -> Array:
	var out: Array = ["attack"] + unit.get("gems", CCBalance.default_gems(unit.get("job", "")))
	for g in unit.get("granted", []): # ท่าติดอาวุธ Unique
		if not out.has(g):
			out.append(g)
	return out


## กรอง gem ให้ถูกต้อง: ต้องมีใน GEMS, ไม่ซ้ำ, ไม่เกิน GEM_SLOTS ช่อง
static func clean_gems(gems: Array) -> Array:
	var out := []
	for g in gems:
		if CCBalance.GEMS.has(g) and not out.has(g) and out.size() < CCBalance.GEM_SLOTS:
			out.append(g)
	return out


static func full_power(actor: Dictionary, skill: String) -> float:
	var d := action_def(actor, skill)
	if d.power == "":
		return 0.0
	var p := float(actor.stats[d.power])
	if skill == "attack" and mod(actor, "attack_uses_avg_tec", false): # Smart Rounds
		p = maxf(p, (actor.stats.atk + actor.stats.mag) / 2.0)
	return p * d.mult


static func reduction(target: Dictionary, kind: String, pierce: bool) -> float:
	if pierce:
		return 0.0
	if kind == "phys":
		return target.stats.def * CCBalance.PHYS_REDUCE_PER_DEF
	if kind == "magic":
		return target.stats.mag * CCBalance.MAGIC_REDUCE_PER_MAG
	return 0.0


## โอกาสคริ (0..1) จาก LCK — มอนสเตอร์/หน่วยที่ไม่มี lck = 0
static func crit_chance(unit: Dictionary) -> float:
	var c := clampf(float(unit.stats.get("lck", 0)) * CCBalance.CRIT_PER_LCK, 0.0, CCBalance.CRIT_CHANCE_MAX)
	return c / 100.0


## ท่านี้ผ่านครบแล้วคริแน่นอนไหม (Perfect ของ Attack)
static func auto_crit(skill: String, perfect: bool, actor := {}) -> bool:
	return perfect and action_def(actor, skill).perfect.has("crit")


## ดาเมจเมื่อผ่าน successes ช่อง (ก่อนคิดเทิร์นป้องกัน) — slots = จำนวนช่องจริง (-1 = ตามท่า)
## crit = ทอยคริจาก LCK ติด (Perfect ของ Attack คริเองอยู่แล้ว ไม่ซ้อน)
static func damage_for(actor: Dictionary, target: Dictionary, skill: String, successes: int, slots := -1, crit := false) -> int:
	var d := action_def(actor, skill)
	if successes <= 0 or d.kind == "flee" or d.kind == "drone":
		return 0
	var n: int = d.slots if slots < 0 else slots
	var perfect: bool = successes >= n
	var raw := full_power(actor, skill) * successes / float(n)
	if crit or auto_crit(skill, perfect, actor):
		raw *= float(mod(actor, "crit_mult." + skill, CCBalance.CRIT_MULT)) # Breacher
	# ตัวคูณจาก Passive
	if n >= 4:
		raw *= float(mod(actor, "long_skill_mult", 1.0)) # One Shot
	elif n <= 2:
		raw *= float(mod(actor, "short_skill_mult", 1.0))
	if skill == "attack":
		raw *= float(mod(actor, "attack_mult", 1.0)) # Full Automation
	raw *= float(mod(actor, "perfect_mult" if perfect else "imperfect_mult", 1.0)) # All or Nothing
	var red := reduction(target, d.kind, perfect and d.perfect.has("pierce"))
	if perfect and d.kind == "phys":
		red *= 1.0 - float(mod(actor, "perfect_armor_pierce", 0.0)) # Weak Point
	raw -= red
	var dmg := maxi(CCBalance.MIN_DAMAGE_ON_HIT, floori(raw))
	if target.guarding:
		dmg = maxi(CCBalance.MIN_DAMAGE_ON_HIT, floori(dmg * CCBalance.GUARD_DAMAGE_MULT))
	return dmg


## โอกาสผ่านต่อช่องของวิธีป้องกัน (รวม chance_mod ของวิธีนั้น + Focus) — attacker = คนตี (Attack ของอาวุธ Psi Rod เป็นเวท)
static func defense_chance(defender: Dictionary, defense: String, attack_skill: String, focus: int, attacker := {}) -> float:
	var cm: float = CCBalance.DEFENSES[defense].get("chance_mod", 0.0)
	if defense == "dodge":
		cm = float(mod(defender, "dodge_penalty", cm)) # Light Step: ไม่มีโทษ
	var bonus := 0.0
	if defense == "block":
		bonus += float(mod(defender, "check_bonus.block")) # Reinforced Plating
		if action_def(attacker, attack_skill).kind == "magic":
			bonus += float(mod(defender, "check_bonus.block_tec")) # Psi Shield
	var c := chance(defender.stats[defense_stat(defense, attack_skill, attacker)], focus, bonus) * 100.0 + cm
	return clampf(c, CCBalance.CHANCE_MIN, CCBalance.CHANCE_MAX_WITH_FOCUS) / 100.0


## สเตตัสที่ใช้เช็คการป้องกัน (Block เจอเวทใช้ MAG)
static func defense_stat(defense: String, attack_skill: String, attacker := {}) -> String:
	var dd: Dictionary = CCBalance.DEFENSES[defense]
	if action_def(attacker, attack_skill).kind == "magic" and dd.has("check_magic"):
		return dd.check_magic
	return dd.check


## ผลของการป้องกันเมื่อผ่าน ds ช่อง: {"mult": ตัวคูณดาเมจที่โดน, "dodged", "counter": ดาเมจตีสวน, "focus": Focus ที่ได้}
static func defense_effect(defender: Dictionary, attacker: Dictionary, defense: String, ds: int) -> Dictionary:
	var out := {"mult": 1.0, "dodged": false, "counter": 0, "focus": 0}
	if defense == "" or not CCBalance.DEFENSES.has(defense):
		return out
	var n: int = CCBalance.DEFENSES[defense].slots
	var perfect := ds >= n
	match defense:
		"block":
			out.mult = maxf(0.0, 1.0 - float(mod(defender, "block_cut", CCBalance.BLOCK_CUT_PER_SUCCESS)) * ds) # Juggernaut
			if perfect:
				out.focus = 1
		"dodge":
			if ds > 0:
				out.dodged = true
				out.mult = 0.0
			else:
				out.mult = CCBalance.DODGE_FAIL_MULT
		"counter":
			if ds > 0:
				var raw: float = defender.stats.atk * float(mod(defender, "counter_mult", CCBalance.COUNTER_POWER_MULT)) * ds / float(n) - attacker.stats.def * CCBalance.PHYS_REDUCE_PER_DEF # Point Blank
				out.counter = maxi(CCBalance.MIN_DAMAGE_ON_HIT, floori(raw))
			if perfect:
				out.mult = CCBalance.COUNTER_PERFECT_DAMAGE_MULT
	return out


## HP ที่ต้องจ่ายเพื่อใช้ท่า (hp_cost × Max HP) — ไม่เกิน HP ปัจจุบัน - 1
static func hp_cost_for(actor: Dictionary, skill: String) -> int:
	var f := float(action_def(actor, skill).get("hp_cost", 0.0))
	if f <= 0.0:
		return 0
	return clampi(ceili(actor.max_hp * f), 0, maxi(0, actor.hp - 1))


## ดาเมจโดรนต่อตา ถ้า actor ปล่อยโดรนตอนนี้ (Full Automation ×2)
static func drone_damage(actor: Dictionary) -> int:
	return maxi(1, floori(actor.stats.mag * CCBalance.DRONE_DAMAGE_PER_MAG * float(mod(actor, "drone_mult", 1.0))))


## จำนวนตาของโดรน (Overclocked Drones +1)
static func drone_turns(actor: Dictionary, perfect: bool) -> int:
	return (CCBalance.DRONE_TURNS_PERFECT if perfect else CCBalance.DRONE_TURNS) + int(mod(actor, "drone_turns"))


## ใช้วิธีป้องกันนี้ได้ไหม (Juggernaut: Dodge ไม่ได้)
static func can_defend_with(defender: Dictionary, defense: String) -> bool:
	return not (defense == "dodge" and mod(defender, "no_dodge", false))


## ท่านี้ศัตรูป้องกันได้ไหม (Flee / Deploy Drone ไม่ใช่การโจมตี)
static func defendable(skill: String) -> bool:
	var kind: String = CCBalance.ACTIONS[skill].kind
	return kind != "flee" and kind != "drone"


static func apply_mult(dmg: int, mult: float) -> int:
	if mult <= 0.0:
		return 0
	return maxi(CCBalance.MIN_DAMAGE_ON_HIT, floori(dmg * mult))


# ================================================================ เริ่มการต่อสู้
static func create_battle(config: Dictionary) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = int(config.seed)
	var h: Dictionary = config.hero
	var m: Dictionary = config.monster
	var hero := _unit(h.name, h.get("job", ""), h.stats, int(h.get("hp", h.stats.hp)))
	hero.mods = h.get("mods", {}).duplicate()
	hero.focus = mini(CCBalance.FOCUS_MAX, CCBalance.FOCUS_START + int(mod(hero, "start_focus"))) # Deep Focus
	hero.barrier = int(mod(hero, "start_barrier")) # Kinetic Barrier
	hero.reroll = int(mod(hero, "reroll_first_fail")) # Second Chance
	hero.attack_def = h.get("attack_def", {}).duplicate(true) # ว่าง = ACTIONS.attack
	if h.has("gems"):
		hero.gems = clean_gems(h.gems)
	hero.granted = h.get("granted", []).filter(func(g): return CCBalance.ACTIONS.has(g) and g != "attack" and g != "flee")
	var monster := _unit(m.name, "", m.stats, int(m.stats.hp))
	var s := {
		"config": config.duplicate(true), "rng_state": 0, "round": 0, "order": [], "turn": 0,
		"units": [hero, monster], "items": h.get("items", []).duplicate(), "result": "",
		"pending": null, "stolen_gold": 0, "log": [], "actions": [],
	}
	s.log.append({"t": "start", "hero": hero.name, "monster": monster.name})
	_new_round(s)
	_advance(s, rng)
	s.rng_state = rng.state
	return s


static func _unit(n: String, job: String, stats: Dictionary, hp: int) -> Dictionary:
	return {"name": n, "job": job, "stats": stats.duplicate(), "hp": clampi(hp, 1, int(stats.hp)), "max_hp": int(stats.hp),
		"focus": 0, "guarding": false, "stunned": false, "burn": 0, "burn_damage": 0, "drone": 0, "drone_damage": 0,
		"mods": {}, "barrier": 0, "reroll": 0}


static func _new_round(s: Dictionary) -> void:
	s.round += 1
	var hero_first: bool = s.units[HERO].stats.spd >= s.units[MONSTER].stats.spd
	if s.round == 1 and mod(s.units[HERO], "first_strike", false): # Quick Draw
		hero_first = true
	s.order = [HERO, MONSTER] if hero_first else [MONSTER, HERO]
	s.turn = 0
	s.log.append({"t": "round", "round": s.round, "order": s.order.duplicate()})


## ใครต้องทำ action (-1 = จบแล้ว) — ตาป้องกันก็เป็นของผู้เล่น
static func current(s: Dictionary) -> int:
	if s.result != "":
		return -1
	return HERO if s.pending != null else s.order[s.turn]


## "act" = ตาผู้เล่นเลือกท่า, "defend" = ผู้เล่นเลือกวิธีป้องกัน, "over"
static func phase(s: Dictionary) -> String:
	if s.result != "":
		return "over"
	return "defend" if s.pending != null else "act"


## เดินเทิร์นต่อจนถึงตาที่ผู้เล่นต้องตัดสินใจ
static func _advance(s: Dictionary, rng: RandomNumberGenerator) -> void:
	while s.result == "" and s.pending == null:
		var who: int = s.order[s.turn]
		var u: Dictionary = s.units[who]
		if not u.get("_started", false):
			u._started = true
			u.guarding = false # Guard หมดเมื่อถึงตาตัวเอง
			var regen := int(mod(u, "regen")) # Auto-Repair
			if regen > 0 and u.hp < u.max_hp:
				var before: int = u.hp
				u.hp = mini(u.max_hp, u.hp + regen)
				s.log.append({"t": "heal", "unit": who, "amount": u.hp - before, "hp": u.hp, "cause": "regen"})
			if u.burn > 0:
				u.burn -= 1
				_hurt(s, who, u.burn_damage, "burn")
				if s.result != "":
					return
			if u.get("drone", 0) > 0: # โดรนยิงเองทุกต้นตาของเจ้าของ (มึนก็ยังยิง)
				u.drone -= 1
				_hurt(s, 1 - who, u.drone_damage, "drone")
				if s.result != "":
					return
			if u.stunned:
				u.stunned = false
				s.log.append({"t": "stunned", "unit": who})
				_end_turn(s)
				continue
		if who == HERO:
			return
		_monster_turn(s, rng)
		if s.pending == null:
			_end_turn(s)


static func _end_turn(s: Dictionary) -> void:
	if s.result != "":
		return
	s.units[s.order[s.turn]].erase("_started")
	s.turn += 1
	if s.turn >= s.order.size():
		if s.round >= CCBalance.MAX_ROUNDS:
			_finish(s, "run")
			return
		_new_round(s)


# ================================================================ action ของผู้เล่น
## คืน {"state": state ใหม่, "error": ""}
static func apply_action(prev: Dictionary, action: Dictionary) -> Dictionary:
	if prev.result != "":
		return {"state": prev, "error": "The battle is over."}
	if current(prev) != HERO:
		return {"state": prev, "error": "Not your turn."}
	var s: Dictionary = prev.duplicate(true)
	var rng := RandomNumberGenerator.new()
	rng.state = s.rng_state
	var hero: Dictionary = s.units[HERO]
	var focus := int(action.get("focus", 0))
	var type := str(action.get("type", ""))

	if focus < 0 or focus > hero.focus:
		return {"state": prev, "error": "Not enough Focus."}

	if s.pending != null:
		# ---- ตาป้องกัน: ป้องกัน / ใช้ไอเทม (สละการป้องกัน) / หนี
		var skill: String = s.pending.skill
		match type:
			"defend":
				var defense := str(action.get("defense", ""))
				if not CCBalance.DEFENSES.has(defense):
					return {"state": prev, "error": "Unknown defense."}
				if not can_defend_with(hero, defense):
					return {"state": prev, "error": "You can't %s (Juggernaut)." % CCBalance.DEFENSES[defense].name}
				hero.focus -= focus
				s.pending = null
				_exchange(s, MONSTER, skill, 0, defense, focus, rng)
			"item":
				var err := _use_item(s, str(action.get("item", "")), "defense")
				if err != "":
					return {"state": prev, "error": err}
				s.pending = null
				if s.result == "":
					_exchange(s, MONSTER, skill, 0, "", 0, rng) # ไม่ได้ป้องกัน รับเต็ม ๆ
			"flee":
				hero.focus -= focus
				s.pending = null
				_exchange(s, HERO, "flee", focus, "", 0, rng)
				if s.result == "":
					_exchange(s, MONSTER, skill, 0, "", 0, rng) # หนีไม่พ้น รับเต็ม ๆ
			_:
				return {"state": prev, "error": "Choose how to defend first (defend, item or flee)."}
		_end_turn(s)
	else:
		# ---- ตาบุก
		match type:
			"skill", "flee":
				var skill := "flee" if type == "flee" else str(action.get("skill", ""))
				if skill != "flee" and not skills_for(hero).has(skill):
					return {"state": prev, "error": "You can't use %s." % skill}
				var cost: int = action_def(hero, skill).get("cost", 0)
				if focus + cost > hero.focus:
					return {"state": prev, "error": "Not enough Focus."}
				hero.focus -= focus + cost
				var defense := "" if not defendable(skill) else _pick(s.config.monster.get("defense", {"block": 1}), rng)
				_exchange(s, HERO, skill, focus, defense, 0, rng)
			"guard":
				hero.guarding = true
				hero.focus = mini(CCBalance.FOCUS_MAX, hero.focus + CCBalance.FOCUS_ON_GUARD)
				s.log.append({"t": "guard", "unit": HERO})
				var gh := floori(hero.max_hp * float(mod(hero, "guard_heal_pct")) / 100.0) # Adrenal Surge
				if gh > 0 and hero.hp < hero.max_hp:
					var before: int = hero.hp
					hero.hp = mini(hero.max_hp, hero.hp + gh)
					s.log.append({"t": "heal", "unit": HERO, "amount": hero.hp - before, "hp": hero.hp, "cause": "guard"})
			"item":
				var err := _use_item(s, str(action.get("item", "")), "attack")
				if err != "":
					return {"state": prev, "error": err}
			"defend":
				return {"state": prev, "error": "Nothing to defend against right now."}
			_:
				return {"state": prev, "error": "Unknown action."}
		_end_turn(s)
	_advance(s, rng)
	s.rng_state = rng.state
	s.actions.append(action.duplicate(true))
	return {"state": s, "error": ""}


# ================================================================ ไอเทม
## ไอเทมใช้ได้ในเทิร์นนี้ไหม (turn = "attack" / "defense")
static func item_usable(item: String, turn: String) -> bool:
	var when: String = GameData.ITEMS.get(item, {}).get("battle", "")
	return when == "any" or (when != "" and when == turn)


## ใช้ไอเทม คืนข้อความ error ("" = สำเร็จ)
static func _use_item(s: Dictionary, item: String, turn: String) -> String:
	if not s.items.has(item):
		return "You don't have %s." % item
	if not item_usable(item, turn):
		var when: String = GameData.ITEMS.get(item, {}).get("battle", "")
		return "%s can't be used in battle." % item if when == "" else "%s is for your %s turn." % [item, when]
	s.items.erase(item)
	var data: Dictionary = GameData.ITEMS[item]
	var hero: Dictionary = s.units[HERO]
	var mon: Dictionary = s.units[MONSTER]
	var ev := {"t": "item", "unit": HERO, "item": item, "heal": 0}
	if data.has("heal"):
		var before: int = hero.hp
		hero.hp = mini(hero.max_hp, hero.hp + int(data.heal))
		ev.heal = hero.hp - before
	if data.has("buff"):
		for k in data.buff:
			hero.stats[k] += int(data.buff[k])
		ev.buff = data.buff.duplicate()
	s.log.append(ev)
	if data.get("escape", false):
		_finish(s, "run")
	if data.has("damage"):
		_hurt(s, MONSTER, int(data.damage), "item")
	if data.has("poison") and s.result == "":
		mon.burn = int(data.poison.turns)
		mon.burn_damage = int(data.poison.damage) + int(mod(hero, "poison_bonus")) # Toxic Mind
		s.log.append({"t": "effect", "unit": MONSTER, "effect": "poison"})
	return ""


# ================================================================ คิดผลการโจมตี 1 ครั้ง
## ทอยช่องเช็คของ unit: first_bonus = % เพิ่มเฉพาะช่องแรก (Steady Aim), Second Chance = ช่องแรกที่พลาดทอยใหม่ 1 ครั้งต่อการต่อสู้
## คืน {"slots", "rerolled": index ช่องที่ทอยใหม่ หรือ -1}
static func _roll_for(unit: Dictionary, n: int, p: float, first_bonus: float, rng: RandomNumberGenerator) -> Dictionary:
	var ps := []
	for i in n:
		ps.append(p)
	if n > 0 and first_bonus > 0.0:
		ps[0] = minf(p + first_bonus / 100.0, maxf(p, CCBalance.CHANCE_MAX / 100.0))
	var out := []
	for i in n:
		out.append(1 if rng.randf() < ps[i] else 0)
	var rerolled := -1
	if unit.get("reroll", 0) > 0 and out.has(0):
		rerolled = out.find(0)
		unit.reroll -= 1
		out[rerolled] = 1 if rng.randf() < ps[rerolled] else 0
	return {"slots": out, "rerolled": rerolled}


static func _exchange(s: Dictionary, who: int, skill: String, focus: int, defense: String, def_focus: int, rng: RandomNumberGenerator) -> void:
	var actor: Dictionary = s.units[who]
	var d := action_def(actor, skill)
	var target_id := 1 - who
	var target: Dictionary = s.units[target_id]
	var n := slots_for(s, who, skill)
	var hp_cost := hp_cost_for(actor, skill)
	if hp_cost > 0: # จ่าย HP ก่อนทอย (ไม่ทำให้ตาย)
		actor.hp -= hp_cost
		s.log.append({"t": "damage", "unit": who, "amount": hp_cost, "hp": actor.hp, "cause": "hp_cost"})
	var p := action_chance(actor, skill, focus)
	var first_bonus := float(mod(actor, "first_slot_bonus." + skill))
	var r := _roll_for(actor, n, p, first_bonus, rng)
	var slots: Array = r.slots
	var successes: int = slots.count(1)
	var perfect: bool = successes == n
	s.log.append({"t": "check", "unit": who, "skill": skill, "name": d.name, "chance": p, "focus": focus, "slots": slots, "successes": successes, "perfect": perfect, "rerolled": r.rerolled})

	if d.kind == "flee":
		if successes > 0:
			_finish(s, "run")
		else:
			s.log.append({"t": "flee_failed", "unit": who})
		return
	if d.kind == "drone":
		if successes > 0:
			actor.drone = drone_turns(actor, perfect and d.perfect.has("long_drone"))
			actor.drone_damage = drone_damage(actor)
			s.log.append({"t": "effect", "unit": who, "effect": "drone", "turns": actor.drone, "damage": actor.drone_damage})
		else:
			s.log.append({"t": "miss", "unit": who})
		return
	if successes == 0:
		s.log.append({"t": "miss", "unit": who})
		target.focus += def_focus # ไม่ต้องป้องกัน คืน Focus
		return

	# ---- เทิร์นป้องกัน
	var eff := defense_effect(target, actor, "", 0)
	if CCBalance.DEFENSES.has(defense):
		var dd: Dictionary = CCBalance.DEFENSES[defense]
		var dp := defense_chance(target, defense, skill, def_focus, actor)
		var dr := _roll_for(target, dd.slots, dp, 0.0, rng)
		var dslots: Array = dr.slots
		var ds: int = dslots.count(1)
		s.log.append({"t": "check", "unit": target_id, "skill": defense, "defense": true, "chance": dp, "focus": def_focus,
			"slots": dslots, "successes": ds, "perfect": ds == dd.slots, "rerolled": dr.rerolled})
		eff = defense_effect(target, actor, defense, ds)
	if eff.dodged:
		s.log.append({"t": "dodge", "unit": target_id})
		return
	if eff.focus > 0 and target_id == HERO:
		target.focus = mini(CCBalance.FOCUS_MAX, target.focus + eff.focus)
		s.log.append({"t": "effect", "unit": target_id, "effect": "focus"})

	# ---- คริ: Perfect ของ Attack = คริแน่นอน, ท่าอื่นทอยจาก LCK ครั้งเดียวต่อการใช้ท่า (ตี 2 ครั้งใช้ผลเดียวกัน)
	var crit := auto_crit(skill, perfect, actor)
	if not crit:
		var cc := crit_chance(actor)
		if cc > 0.0:
			crit = rng.randf() < cc
	if crit:
		s.log.append({"t": "effect", "unit": who, "effect": "crit"})

	var hits := 2 if perfect and d.perfect.has("double") else 1
	var dealt := 0
	for h in hits:
		var dmg := apply_mult(damage_for(actor, target, skill, successes, n, crit), eff.mult)
		dealt += dmg
		_hurt(s, target_id, dmg, "hit")
		if s.result != "":
			break
	var drain := floori(dealt * float(d.get("drain", 0.0))) # Blood Siphon
	if drain > 0 and actor.hp > 0 and actor.hp < actor.max_hp:
		var before: int = actor.hp
		actor.hp = mini(actor.max_hp, actor.hp + drain)
		s.log.append({"t": "heal", "unit": who, "amount": actor.hp - before, "hp": actor.hp, "cause": "drain"})
	if s.result != "":
		return
	if perfect:
		if d.perfect.has("stun"):
			target.stunned = true
			s.log.append({"t": "effect", "unit": target_id, "effect": "stun"})
		if d.perfect.has("burn"):
			target.burn = CCBalance.BURN_TURNS + int(mod(actor, "burn_turns")) # Plasma Feed
			target.burn_damage = maxi(1, floori(actor.stats.mag * CCBalance.BURN_DAMAGE_PER_MAG)) + int(mod(actor, "poison_bonus")) # Toxic Mind
			s.log.append({"t": "effect", "unit": target_id, "effect": "burn"})
		if d.perfect.has("steal") and who == HERO:
			var gold := floori(int(s.config.monster.get("gold", 0)) * CCBalance.STEAL_GOLD_RATIO)
			s.stolen_gold += gold
			s.log.append({"t": "effect", "unit": target_id, "effect": "steal", "gold": gold})
	if eff.counter > 0:
		_hurt(s, who, eff.counter, "counter")


static func _hurt(s: Dictionary, who: int, dmg: int, cause: String) -> void:
	var u: Dictionary = s.units[who]
	var absorbed := mini(dmg, int(u.get("barrier", 0))) # Kinetic Barrier ดูดดาเมจก่อน
	if absorbed > 0:
		u.barrier -= absorbed
		dmg -= absorbed
		s.log.append({"t": "barrier", "unit": who, "amount": absorbed, "left": u.barrier})
	u.hp = maxi(0, u.hp - dmg)
	s.log.append({"t": "damage", "unit": who, "amount": dmg, "hp": u.hp, "cause": cause})
	if u.hp <= 0:
		_finish(s, "lose" if who == HERO else "win")


static func _finish(s: Dictionary, result: String) -> void:
	if s.result != "":
		return
	s.result = result
	s.pending = null
	s.log.append({"t": "end", "result": result})


# ================================================================ AI มอนสเตอร์
static func _pick(weights: Dictionary, rng: RandomNumberGenerator) -> String:
	var total := 0
	for k in weights:
		total += int(weights[k])
	var r := rng.randi_range(1, maxi(1, total))
	for k in weights:
		r -= int(weights[k])
		if r <= 0:
			return k
	return weights.keys()[0] if not weights.is_empty() else ""


static func _monster_turn(s: Dictionary, rng: RandomNumberGenerator) -> void:
	var pick := _pick(s.config.monster.get("actions", {"attack": 1}), rng)
	if pick == "guard":
		s.units[MONSTER].guarding = true
		s.log.append({"t": "guard", "unit": MONSTER})
		return
	# ประกาศท่า แล้วรอผู้เล่นเลือกวิธีป้องกัน
	s.pending = {"skill": pick}
	s.log.append({"t": "intent", "unit": MONSTER, "skill": pick, "name": action_def(s.units[MONSTER], pick).name})


# ================================================================ replay
static func replay(config: Dictionary, actions: Array, steps := -1) -> Dictionary:
	var s := create_battle(config)
	var n: int = actions.size() if steps < 0 else mini(steps, actions.size())
	for i in n:
		s = apply_action(s, actions[i]).state
	return s

class_name DDAi
## AI แบบง่าย — ตัดสินใจจาก PlayerView เท่านั้น (เห็นข้อมูลเท่าคนเล่น ไม่โกง)
## - เลือกท่าที่ผลคาดหวังดีที่สุด เดาท่าอีกฝ่ายจากจำนวนเต๋าที่วาง
## - สุ่ม DDBalance.AI_RANDOMNESS (20%) เลือกท่าที่ใช้ได้แบบสุ่ม กันอ่านทางง่าย
## - personality: "aggressive" (ชอบพลังดิบ) / "bluffer" (ชอบ Slash 2 ลูกหลอกว่าเป็น Strike)

const PERSONALITIES := ["aggressive", "bluffer"]


static func choose_action(view: Dictionary, personality: String, rng: RandomNumberGenerator) -> Dictionary:
	var p: int = view.player_id
	if view.phase == "swipe":
		return _choose_swipe(view)
	var attacking: bool = view.phase == "attack"
	if not attacking and view.me.job == "ninja" and not view.me.shadow_read_used:
		return {"type": "shadow_read", "player": p}
	var reroll := _choose_reroll(view, "offense" if attacking else "defense")
	if not reroll.is_empty():
		return reroll

	var cands := _offense_candidates(view, personality) if attacking else _defense_candidates(view, personality)
	var pick: Dictionary = cands[0]
	if rng.randf() < DDBalance.AI_RANDOMNESS:
		pick = cands[rng.randi_range(0, cands.size() - 1)]
	else:
		for c in cands:
			if c.score > pick.score:
				pick = c
	var dice := []
	for d in pick.infos:
		dice.append({"die_id": d.die_id, "wild": d.wild})
	return {"type": "place", "player": p, "move": pick.move, "dice": dice}


static func own_info(view: Dictionary, d: Dictionary, wild := 6) -> Dictionary:
	return DDBattle.make_info(view.player_id, d.die, int(d.face_index), wild)


# ---------------------------------------------------------------- reroll
static func _choose_reroll(view: Dictionary, ctx: String) -> Dictionary:
	var me: Dictionary = view.me
	if me.job == "warrior" and not me.free_reroll_used:
		for d in me.dice:
			if d.face.k == "num" and int(d.face.v) == 1:
				return {"type": "reroll", "player": view.player_id, "die_id": d.die.id}
	if me.focus < DDBalance.REROLL_COST:
		return {}
	var worst := {}
	var worst_value := 999
	for d in me.dice:
		var info := own_info(view, d)
		var v := -1 if DDFaces.is_skull(info) else (99 if DDFaces.is_wild(info) else DDFaces.condition_value(info, ctx))
		if v < worst_value:
			worst_value = v
			worst = d
	if not worst.is_empty() and worst_value <= 2:
		return {"type": "reroll", "player": view.player_id, "die_id": worst.die.id}
	return {}


# ---------------------------------------------------------------- สร้างตัวเลือก
static func _subsets(arr: Array) -> Array:
	var out := []
	for mask in 1 << arr.size():
		var s := []
		for i in arr.size():
			if mask & (1 << i):
				s.append(arr[i])
		out.append(s)
	return out


## ทุกแบบของค่า ✦ (wild เกิน 2 ลูกใช้ค่า fallback กันระเบิด)
static func _wild_variants(view: Dictionary, dice: Array, fallback: int) -> Array:
	var variants := [[]]
	var wilds := 0
	for d in dice:
		var options := [0]
		if d.face.k == "wild":
			wilds += 1
			options = [1, 2, 3, 4, 5, 6] if wilds <= 2 else [fallback]
		var next := []
		for v in variants:
			for o in options:
				var nv: Array = v.duplicate()
				nv.append(own_info(view, d, o))
				next.append(nv)
		variants = next
	return variants


static func _unplaced_bonus(view: Dictionary, used: int) -> float:
	if view.me.focus >= DDBalance.FOCUS_MAX:
		return 0.0
	return (view.me.dice.size() - used) * DDBalance.AI_FOCUS_VALUE


# ---------------------------------------------------------------- รุก
static func _offense_candidates(view: Dictionary, personality: String) -> Array:
	var me: Dictionary = view.me
	var opp: Dictionary = view.opponent
	var guard_red: float = opp.stats.df * 7 * DDBalance.GUARD_PER_PIP
	var ward_red: float = opp.stats.mg * 4 * DDBalance.WARD_PER_PIP
	# โอกาสที่อีกฝ่ายมีหน้าที่ใช้ Counter ได้อย่างน้อย 1 ลูก (คิดจาก d6)
	var miss := (6.0 - DDBalance.COUNTER_VALUES.size()) / 6.0
	var p_counter_ok := 1.0 - pow(miss, opp.dice.size())
	var out := []
	for subset in _subsets(me.dice):
		if subset.is_empty():
			continue
		for move in DDMoves.offense_moves_for(me.job):
			var orders := [subset]
			if move == "magic": # ลองทุกลูกเป็นลูกหลัก
				orders = []
				for i in subset.size():
					var o := [subset[i]]
					for j in subset.size():
						if j != i:
							o.append(subset[j])
					orders.append(o)
			for ordered in orders:
				for infos in _wild_variants(view, ordered, 6):
					var ev := DDMoves.evaluate_offense(move, infos, me.job, me.stats)
					if not ev.valid:
						continue
					var n: int = infos.size()
					var pd := [0.45, 0.2, 0.35] if n == 1 else ([0.35, 0.45, 0.2] if n == 2 else [0.3, 0.5, 0.2]) # guard, counter, ward
					var pw: float = ev.power
					var e := 0.0
					match ev.counts_as:
						"slash":
							e = pd[0] * maxf(0.0, pw - guard_red) + pd[1] * pw * DDBalance.SLASH_VS_COUNTER_MULT + pd[2] * pw
						"strike":
							e = pd[0] * pw + pd[1] * (p_counter_ok * -pw + (1.0 - p_counter_ok) * pw) + pd[2] * pw
						"magic":
							e = pd[0] * pw + pd[1] * pw * DDBalance.MAGIC_VS_COUNTER_MULT + pd[2] * maxf(0.0, pw - ward_red)
					var score := e + _unplaced_bonus(view, n)
					if pw >= opp.hp:
						score += 20.0
					if personality == "aggressive":
						score += DDBalance.AI_AGGRESSIVE_RAW_WEIGHT * pw
					if personality == "bluffer" and move == "slash" and n == 2:
						score *= DDBalance.AI_BLUFFER_SLASH_TWO_BONUS
					out.append({"move": move, "infos": infos, "score": score})
	return out


# ---------------------------------------------------------------- รับ
static func _threat(counts_as: String, power: float, p: float, valid := true) -> Dictionary:
	return {"p": p, "ev": {"move": counts_as, "valid": valid, "reason": "", "power": power, "counts_as": counts_as}}


## เดาท่าอีกฝ่ายจากจำนวนเต๋าที่วาง + อาชีพ
static func _predict_threats(view: Dictionary) -> Array:
	var opp: Dictionary = view.opponent
	var n: int = maxi(1, opp.placed_count)
	var at: float = opp.stats.at
	var mg: float = opp.stats.mg
	var slash1 := _threat("slash", at * (1.0 + 3.5 * DDBalance.SLASH_PER_PIP), 0.45)
	var magic1 := _threat("magic", mg * (1.0 + 5.0 * DDBalance.MAGIC_PER_PIP), 0.55)
	var strike := at * (1.0 + 9.0 * DDBalance.STRIKE_PER_PIP) * DDBalance.STRIKE_MULT
	if n == 1:
		return [slash1, magic1]
	if n == 2:
		if opp.job == "magician":
			return [_threat("strike", strike, 0.4), _threat("slash", at * (1.0 + 7.0 * DDBalance.SLASH_PER_PIP), 0.3),
				_threat("magic", mg * 1.75 * (1.0 + 0.5 * DDBalance.ARCANE_ODD_EXTRA_BONUS), 0.3)]
		return [_threat("strike", strike, 0.55), _threat("slash", at * (1.0 + 7.0 * DDBalance.SLASH_PER_PIP), 0.45)]
	if opp.job == "warrior":
		return [_threat("strike", at * (1.0 + 10.5 * DDBalance.BERSERK_PER_PIP) * DDBalance.BERSERK_MULT, 0.7),
			_threat("slash", 0.0, 0.3, false)]
	if opp.job == "magician":
		return [_threat("magic", mg * 1.75 * (1.0 + (n - 1) * 0.5 * DDBalance.ARCANE_ODD_EXTRA_BONUS), 0.8),
			_threat("slash", 0.0, 0.2, false)]
	return [_threat("slash", 0.0, 1.0, false)] # 3 ลูกแต่ไม่ใช่ Warrior/Magician = ท่าล้มแน่


static func _defense_candidates(view: Dictionary, personality: String) -> Array:
	var me: Dictionary = view.me
	var threats := _predict_threats(view)
	var out := []
	for subset in _subsets(me.dice):
		for move in DDMoves.DEFENSE:
			for infos in _wild_variants(view, subset, 5):
				var dv := DDMoves.evaluate_defense(move, infos, me.job, me.stats)
				if not dv.valid:
					continue
				var taken := 0.0
				var reflected := 0.0
				for t in threats:
					var o := DDResolve.resolve_exchange(t.ev, dv)
					taken += t.p * o.damage_to_defender
					reflected += t.p * o.damage_to_attacker
				var score := -taken + reflected + float(dv.heal) + _unplaced_bonus(view, infos.size())
				if personality == "aggressive":
					score += DDBalance.AI_AGGRESSIVE_RAW_WEIGHT * reflected
				out.append({"move": move, "infos": infos, "score": score})
	return out


# ---------------------------------------------------------------- Swipe
static func _choose_swipe(view: Dictionary) -> Dictionary:
	var p: int = view.player_id
	var r: Dictionary = view.reveal
	var am_attacker: bool = r.attacker == p
	var mine_list: Array = r.attack_dice if am_attacker else r.defense_dice
	var their_list: Array = r.defense_dice if am_attacker else r.attack_dice
	var base := _swipe_net(view, mine_list, their_list)
	var best := {"gain": 0.0, "mine": -1, "theirs": -1}
	for i in mine_list.size():
		var total := 0.0
		for j in their_list.size():
			var m := mine_list.duplicate()
			var t := their_list.duplicate()
			m[i] = their_list[j]
			t[j] = mine_list[i]
			var gain := _swipe_net(view, m, t) - base
			total += gain
			if not DDBalance.SWIPE_RANDOM_TARGET and gain > best.gain:
				best = {"gain": gain, "mine": i, "theirs": j}
		# เต๋าอีกฝ่ายถูกสุ่ม → ใช้ค่าเฉลี่ยของทุกลูก
		if DDBalance.SWIPE_RANDOM_TARGET and total / their_list.size() > best.gain:
			best = {"gain": total / their_list.size(), "mine": i, "theirs": 0}
	var threshold := DDBalance.AI_SWIPE_MIN_GAIN_RATIO * maxf(view.me.stats.at, view.me.stats.mg) \
		+ DDBalance.SWIPE_FOCUS_COST * DDBalance.AI_FOCUS_VALUE
	if best.mine >= 0 and best.gain >= threshold:
		return {"type": "swipe", "player": p, "mine": best.mine, "theirs": best.theirs}
	return {"type": "skip_swipe", "player": p}


## ผลสุทธิในมุมของเรา (ดาเมจที่อีกฝ่ายโดน − ที่เราโดน + ฮีล)
static func swipe_outcome(view: Dictionary, mine: Array, theirs: Array) -> Dictionary:
	var r: Dictionary = view.reveal
	var am_attacker: bool = r.attacker == view.player_id
	var att: Dictionary = view.me if am_attacker else view.opponent
	var def: Dictionary = view.opponent if am_attacker else view.me
	return DDResolve.resolve_from_dice({
		"attacker": {"job": att.job, "stats": att.stats}, "defender": {"job": def.job, "stats": def.stats},
		"attack_move": r.attack_move, "attack_dice": mine if am_attacker else theirs,
		"defense_move": r.defense_move, "defense_dice": theirs if am_attacker else mine,
	})


static func _swipe_net(view: Dictionary, mine: Array, theirs: Array) -> float:
	var o := swipe_outcome(view, mine, theirs)
	if view.reveal.attacker == view.player_id:
		return float(o.damage_to_defender - o.damage_to_attacker)
	return float(o.damage_to_attacker - o.damage_to_defender + o.heal_defender)

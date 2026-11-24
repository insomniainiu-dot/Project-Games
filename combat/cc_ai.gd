class_name CCAi
## AI ฝั่งฮีโร่ (ใช้ใน simulation) — เลือกท่า/วิธีป้องกันที่ผลคาดหวังดีที่สุด
## คิดจากการแจกแจงความน่าจะเป็นของช่องเช็คทั้งฝ่ายโจมตีและฝ่ายป้องกันจริง ๆ

const FOCUS_COST := 4.0 ## มูลค่า (เทียบเป็นดาเมจ) ของ Focus 1 แต้มที่ยังไม่ใช้
const KILL_BONUS := 25.0
const DEATH_PENALTY := 60.0


## ความน่าจะเป็นที่ผ่าน k ช่อง จาก n ช่อง (k = 0..n)
static func pmf(n: int, p: float) -> Array:
	var out := []
	for k in n + 1:
		var c := 1.0
		for i in k:
			c = c * (n - i) / float(i + 1)
		out.append(c * pow(p, k) * pow(1.0 - p, n - k))
	return out


## ค่าคาดหวังของการโจมตี 1 ครั้ง: taken = ดาเมจที่ฝ่ายรับโดน, counter = ดาเมจตีสวนที่คนตีโดน
static func exchange(s: Dictionary, attacker_id: int, skill: String, focus: int, defense: String, def_focus: int) -> Dictionary:
	var att: Dictionary = s.units[attacker_id]
	var tgt: Dictionary = s.units[1 - attacker_id]
	var d := CCBattle.action_def(att, skill)
	var n := CCBattle.slots_for(s, attacker_id, skill)
	var pa := pmf(n, CCBattle.action_chance(att, skill, focus)) # ประมาณ: ไม่คิดโบนัสช่องแรก / ทอยใหม่
	var pd := [1.0]
	if CCBalance.DEFENSES.has(defense):
		pd = pmf(CCBalance.DEFENSES[defense].slots, CCBattle.defense_chance(tgt, defense, skill, def_focus, att))
	var out := {"taken": 0.0, "counter": 0.0, "kill": 0.0, "perfect": 0.0}
	for k in range(1, n + 1):
		for j in pd.size():
			var prob: float = pa[k] * pd[j]
			var eff := CCBattle.defense_effect(tgt, att, defense if CCBalance.DEFENSES.has(defense) else "", j)
			var dmg := CCBattle.apply_mult(CCBattle.damage_for(att, tgt, skill, k, n), eff.mult)
			if k == n and d.perfect.has("double"):
				dmg *= 2
			dmg = maxi(0, dmg - int(tgt.get("barrier", 0)))
			out.taken += prob * dmg
			out.counter += prob * eff.counter
			if dmg >= tgt.hp:
				out.kill += prob
			if k == n and not eff.dodged:
				out.perfect += prob
	return out


static func _perfect_value(s: Dictionary, skill: String) -> float:
	var hero: Dictionary = s.units[CCBattle.HERO]
	var mon: Dictionary = s.units[CCBattle.MONSTER]
	var d := CCBattle.action_def(hero, skill)
	var v := 0.0
	if d.perfect.has("stun"):
		v += CCBattle.full_power(mon, "attack") * 0.5
	if d.perfect.has("burn"):
		v += CCBalance.BURN_TURNS * maxf(1.0, hero.stats.mag * CCBalance.BURN_DAMAGE_PER_MAG)
	return v


## มูลค่าคาดหวังของการปล่อยโดรน (ดาเมจรวมที่โดรนจะยิง ไม่เกิน HP ศัตรู) — โดรนเดิมยังเหลือหลายตา = ไม่คุ้มปล่อยซ้ำ
static func drone_value(s: Dictionary, skill: String, focus: int) -> float:
	var hero: Dictionary = s.units[CCBattle.HERO]
	var mon: Dictionary = s.units[CCBattle.MONSTER]
	var d: Dictionary = CCBalance.ACTIONS[skill]
	var p := pmf(d.slots, CCBattle.action_chance(hero, skill, focus))
	var per := float(CCBattle.drone_damage(hero))
	var left := float(hero.get("drone", 0))
	var v := 0.0
	for k in range(1, d.slots + 1):
		var turns := CCBattle.drone_turns(hero, k == d.slots and d.perfect.has("long_drone"))
		v += p[k] * minf(float(mon.hp), maxf(0.0, turns - left) * per)
	return v


static func choose(s: Dictionary) -> Dictionary:
	return choose_defense(s) if CCBattle.phase(s) == "defend" else choose_action(s)


const ITEM_COST := 8.0 ## มูลค่าของไอเทม 1 ชิ้น (กันใช้ทิ้งขว้าง)


static func choose_action(s: Dictionary) -> Dictionary:
	var hero: Dictionary = s.units[CCBattle.HERO]
	var mon: Dictionary = s.units[CCBattle.MONSTER]
	# ไอเทมโจมตี: ใช้ถ้าปิดเกมได้ หรือคุ้มกว่าตีปกติ
	var item_pick := {}
	var item_score := -INF
	for item in s.items:
		if not CCBattle.item_usable(item, "attack") or GameData.ITEMS[item].get("escape", false):
			continue
		var data: Dictionary = GameData.ITEMS[item]
		var v := float(data.get("damage", 0))
		if data.has("poison") and mon.burn <= 0:
			v += data.poison.turns * data.poison.damage
		if data.get("damage", 0) >= mon.hp:
			v += KILL_BONUS * 2
		if v - ITEM_COST > item_score:
			item_score = v - ITEM_COST
			item_pick = {"type": "item", "item": item}
	var weights: Dictionary = s.config.monster.get("defense", {"block": 1})
	var total := 0.0
	for k in weights:
		total += float(weights[k])
	var best := {"type": "guard"}
	var best_score: float = 3.0 + hero.max_hp * float(CCBattle.mod(hero, "guard_heal_pct")) / 100.0 # Guard ได้ Focus + ลดดาเมจ (+ ฮีลจาก Adrenal Surge)
	for skill in CCBattle.skills_for(hero):
		var cost: int = CCBattle.action_def(hero, skill).get("cost", 0)
		for f in range(0, hero.focus - cost + 1):
			var score := 0.0
			if not CCBattle.defendable(skill):
				score = drone_value(s, skill, f) - (f + cost) * FOCUS_COST
				if score > best_score:
					best_score = score
					best = {"type": "skill", "skill": skill, "focus": f}
				continue
			var drain := float(CCBattle.action_def(hero, skill).get("drain", 0.0))
			for defense in weights:
				var e := exchange(s, CCBattle.HERO, skill, f, defense, 0)
				var heal := minf(e.taken * drain, float(hero.max_hp - hero.hp))
				score += (float(weights[defense]) / total) * (e.taken + heal - e.counter + e.kill * KILL_BONUS + e.perfect * _perfect_value(s, skill))
			score -= (f + cost) * FOCUS_COST + CCBattle.hp_cost_for(hero, skill)
			if score > best_score:
				best_score = score
				best = {"type": "skill", "skill": skill, "focus": f}
	if item_score > best_score:
		return item_pick
	return best


static func choose_defense(s: Dictionary) -> Dictionary:
	var hero: Dictionary = s.units[CCBattle.HERO]
	var skill: String = s.pending.skill
	# HP ต่ำ: สละการป้องกันเพื่อฮีล (ถ้าฮีลแล้วรอดจากการโดนเต็ม ๆ)
	if hero.hp < hero.max_hp * CCBalance.HERO_AI_HEAL_BELOW:
		var mon: Dictionary = s.units[CCBattle.MONSTER]
		var worst := CCBattle.damage_for(mon, hero, skill, CCBattle.action_def(mon, skill).slots)
		for item in ["Big Medkit", "Medkit"]:
			if s.items.has(item) and hero.hp + int(GameData.ITEMS[item].heal) > worst:
				return {"type": "item", "item": item}
	var best := {}
	var best_score := -INF
	for defense in CCBalance.DEFENSES:
		if not CCBattle.can_defend_with(hero, defense):
			continue
		for f in range(0, hero.focus + 1):
			var e := exchange(s, CCBattle.MONSTER, skill, 0, defense, f)
			var score: float = -e.taken + e.counter - e.kill * DEATH_PENALTY - f * FOCUS_COST
			if score > best_score:
				best_score = score
				best = {"type": "defend", "defense": defense, "focus": f}
	return best

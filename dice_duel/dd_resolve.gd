class_name DDResolve
## ตารางผลรุก vs รับ (ดาเมจขั้นต่ำ 0 ปัดลงเป็นจำนวนเต็ม)
## Outcome = {"attack", "defense", "damage_to_defender", "damage_to_attacker", "heal_defender", "note"}


static func _dmg(x: float) -> int:
	return maxi(0, floori(x))


static func resolve_exchange(attack: Dictionary, defense: Dictionary) -> Dictionary:
	var heal: int = int(defense.heal) if defense.valid else 0
	if not attack.valid:
		return {
			"attack": attack, "defense": defense, "damage_to_defender": 0, "damage_to_attacker": 0,
			"heal_defender": heal, "note": "%s failed (%s)" % [DDMoves.NAMES[attack.move], attack.reason],
		}
	var p: float = attack.power
	var def: String = defense.move if defense.valid else "none"
	var to_def := p
	var to_att := 0.0
	var note := "Full power"
	match attack.counts_as:
		"slash":
			if def == "guard":
				to_def = p - float(defense.reduction)
				note = "Guard reduced it"
			elif defense.move == "counter" and DDBalance.SLASH_VS_COUNTER_MULT != 1.0:
				# ประกาศ Counter แล้วเดาผิด (นับตั้งแต่ประกาศ เหมือน Magic vs Counter)
				to_def = p * DDBalance.SLASH_VS_COUNTER_MULT
				note = "Counter guessed wrong x%s" % DDBalance.SLASH_VS_COUNTER_MULT
		"strike":
			if def == "counter":
				to_def = 0.0
				to_att = p * DDBalance.COUNTER_REFLECT
				note = "COUNTER! Reflected"
			elif def == "guard":
				note = "Broke through Guard"
		"magic":
			# ประกาศ Counter = เปิดช่องให้เวท ไม่ว่า Counter จะผ่านเงื่อนไขหรือไม่
			if defense.move == "counter":
				to_def = p * DDBalance.MAGIC_VS_COUNTER_MULT
				note = "Counter can't stop magic x%s" % DDBalance.MAGIC_VS_COUNTER_MULT
			elif def == "ward":
				to_def = p - float(defense.reduction)
				note = "Ward reduced it"
	if not defense.valid:
		note += " (%s failed: %s)" % [DDMoves.NAMES[defense.move], defense.reason]
	return {
		"attack": attack, "defense": defense, "damage_to_defender": _dmg(to_def),
		"damage_to_attacker": _dmg(to_att), "heal_defender": heal, "note": note,
	}


## input = {"attacker": {job, stats}, "defender": {job, stats}, "attack_move", "attack_dice", "defense_move", "defense_dice"}
static func resolve_from_dice(i: Dictionary) -> Dictionary:
	return resolve_exchange(
		DDMoves.evaluate_offense(i.attack_move, i.attack_dice, i.attacker.job, i.attacker.stats),
		DDMoves.evaluate_defense(i.defense_move, i.defense_dice, i.defender.job, i.defender.stats))

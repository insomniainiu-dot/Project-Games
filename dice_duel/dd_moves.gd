class_name DDMoves
## ตรวจเงื่อนไขท่า + คำนวณพลัง/การลดดาเมจ
## OffenseEval = {"move", "valid", "reason", "power": float, "counts_as": "slash"/"strike"/"magic"}
## DefenseEval = {"move", "valid", "reason", "reduction": float, "heal": int}

const NAMES := {
	"slash": "Slash", "strike": "Strike", "magic": "Magic", "berserk": "Berserk",
	"guard": "Guard", "counter": "Counter", "ward": "Ward",
}
const OFFENSE := ["slash", "strike", "magic", "berserk"]
const DEFENSE := ["guard", "counter", "ward"]

const HINTS := {
	"slash": "1-2 dice, any value. Power = AT x (1 + sum x 0.1). Reduced by Guard.",
	"strike": "Exactly 2 dice, sum >= 8. Power x2, breaks Guard. Reflected by Counter!",
	"magic": "1 die >= 4 or wild. Power = MG x (1 + value x 0.15). Cut by Ward, x1.5 vs Counter.",
	"berserk": "3 dice of equal value. Power x3, counts as Strike.",
	"guard": "Any dice. Cuts Slash damage by DF x sum x 0.05.",
	"counter": "1 die showing %s. Reflects a Strike (but Magic hits x1.5).",
	"ward": "Odd dice only. Cuts Magic damage by MG x sum x 0.08.",
}


## "6" หรือ "5 or 6" ตาม DDBalance.COUNTER_VALUES
static func counter_values_text() -> String:
	var parts := PackedStringArray()
	for v in DDBalance.COUNTER_VALUES:
		parts.append(str(v))
	return " or ".join(parts)


static func hint(move: String) -> String:
	return HINTS[move] % counter_values_text() if move == "counter" else HINTS[move]


static func offense_moves_for(job: String) -> Array:
	return ["slash", "strike", "magic", "berserk"] if job == "warrior" else ["slash", "strike", "magic"]


static func _rune_power_bonus(move: String, dice: Array) -> float:
	var bonus := 0.0
	for d in dice:
		for id in d.runes:
			bonus += DDRunes.get_rune(id).power_bonus(move)
	return bonus


static func _off_fail(move: String, counts_as: String, reason: String) -> Dictionary:
	return {"move": move, "valid": false, "reason": reason, "power": 0.0, "counts_as": counts_as}


static func evaluate_offense(move: String, dice: Array, job: String, stats: Dictionary) -> Dictionary:
	var counts_as := "strike" if move == "berserk" else move
	var sum := DDFaces.sum_effective(dice, "offense")
	var power := 0.0
	match move:
		"slash":
			if dice.size() < DDBalance.SLASH_MIN_DICE or dice.size() > DDBalance.SLASH_MAX_DICE:
				return _off_fail(move, counts_as, "Slash needs %d-%d dice" % [DDBalance.SLASH_MIN_DICE, DDBalance.SLASH_MAX_DICE])
			power = float(stats.at) * (1.0 + sum * DDBalance.SLASH_PER_PIP)
		"strike":
			if dice.size() != DDBalance.STRIKE_DICE:
				return _off_fail(move, counts_as, "Strike needs exactly %d dice" % DDBalance.STRIKE_DICE)
			if DDFaces.any_skull(dice):
				return _off_fail(move, counts_as, "Skull can't be used for Strike")
			if DDFaces.sum_condition(dice, "offense") < DDBalance.STRIKE_MIN_SUM:
				return _off_fail(move, counts_as, "Strike needs sum >= %d" % DDBalance.STRIKE_MIN_SUM)
			power = float(stats.at) * (1.0 + sum * DDBalance.STRIKE_PER_PIP) * DDBalance.STRIKE_MULT
		"magic":
			if dice.is_empty():
				return _off_fail(move, counts_as, "Magic needs a die")
			if dice.size() > 1 and job != "magician":
				return _off_fail(move, counts_as, "Magic uses 1 die (only Magician can add more)")
			if DDFaces.any_skull(dice):
				return _off_fail(move, counts_as, "Skull can't be used for Magic")
			var primary: Dictionary = dice[0]
			if not DDFaces.is_wild(primary) and DDFaces.condition_value(primary, "offense") < DDBalance.MAGIC_MIN_VALUE:
				return _off_fail(move, counts_as, "Magic needs a die >= %d or wild" % DDBalance.MAGIC_MIN_VALUE)
			var value := DDFaces.effective_value(primary, "offense")
			var odd_extras := 0
			for i in range(1, dice.size()):
				if DDFaces.is_odd(DDFaces.condition_value(dice[i], "offense")):
					odd_extras += 1
			var arcane := odd_extras * DDBalance.ARCANE_ODD_EXTRA_BONUS if job == "magician" else 0.0
			power = float(stats.mg) * (1.0 + value * DDBalance.MAGIC_PER_PIP) * (1.0 + arcane + _rune_power_bonus(move, dice))
			return {"move": move, "valid": true, "reason": "", "power": power, "counts_as": counts_as}
		"berserk":
			if job != "warrior":
				return _off_fail(move, counts_as, "Only a Warrior can Berserk")
			if dice.size() != DDBalance.BERSERK_DICE:
				return _off_fail(move, counts_as, "Berserk needs %d dice" % DDBalance.BERSERK_DICE)
			if DDFaces.any_skull(dice):
				return _off_fail(move, counts_as, "Skull can't be used for Berserk")
			var v0 := DDFaces.condition_value(dice[0], "offense")
			for d in dice:
				if DDFaces.condition_value(d, "offense") != v0:
					return _off_fail(move, counts_as, "Berserk needs dice of equal value")
			power = float(stats.at) * (1.0 + sum * DDBalance.BERSERK_PER_PIP) * DDBalance.BERSERK_MULT
		_:
			return _off_fail(move, "slash", "Unknown attack")
	power *= 1.0 + _rune_power_bonus(move, dice)
	return {"move": move, "valid": true, "reason": "", "power": power, "counts_as": counts_as}


static func _def_fail(move: String, reason: String) -> Dictionary:
	return {"move": move, "valid": false, "reason": reason, "reduction": 0.0, "heal": 0}


static func evaluate_defense(move: String, dice: Array, job: String, stats: Dictionary) -> Dictionary:
	var sum := DDFaces.sum_effective(dice, "defense")
	match move:
		"guard":
			var heal: int = sum * DDBalance.SANCTUARY_HEAL_PER_PIP if job == "cleric" else 0
			return {"move": move, "valid": true, "reason": "", "reduction": float(stats.df) * sum * DDBalance.GUARD_PER_PIP, "heal": heal}
		"counter":
			if dice.size() != 1:
				return _def_fail(move, "Counter needs exactly 1 die")
			if DDFaces.is_skull(dice[0]):
				return _def_fail(move, "Skull can't be used for Counter")
			if not DDBalance.COUNTER_VALUES.has(DDFaces.condition_value(dice[0], "defense")):
				return _def_fail(move, "Counter needs a %s" % counter_values_text())
			return {"move": move, "valid": true, "reason": "", "reduction": 0.0, "heal": 0}
		"ward":
			if DDFaces.any_skull(dice):
				return _def_fail(move, "Skull can't be used for Ward")
			for d in dice:
				if not DDFaces.is_odd(DDFaces.condition_value(d, "defense")):
					return _def_fail(move, "Ward takes odd numbers only")
			return {"move": move, "valid": true, "reason": "", "reduction": float(stats.mg) * sum * DDBalance.WARD_PER_PIP, "heal": 0}
	return _def_fail(move, "Unknown defense")

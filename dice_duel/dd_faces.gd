class_name DDFaces
## หน้าเต๋า + การคิดค่า
## Face = {"k": "num", "v": 1..6} | {"k": "sword"} | {"k": "shield"} | {"k": "wild"} | {"k": "skull"}
## DieInfo = {"owner", "die_id", "face", "body", "runes": [], "wild": 0 (= ยังไม่เลือก) / 1..6}
##   condition_value : ค่าหลัง Body ก่อน rune → ใช้ตรวจเงื่อนไขท่า
##   effective_value : ค่าหลัง rune → ใช้คิดพลัง/การลดดาเมจ

const SYMBOL := {"sword": "⚔", "shield": "🛡", "wild": "✦", "skull": "💀"}


static func num(v: int) -> Dictionary:
	return {"k": "num", "v": v}


static func sym(kind: String) -> Dictionary:
	return {"k": kind}


static func label(face: Dictionary) -> String:
	return str(face.v) if face.k == "num" else SYMBOL[face.k]


static func info_label(d: Dictionary) -> String:
	var s := label(d.face)
	if d.face.k == "wild" and int(d.get("wild", 0)) > 0:
		s += str(d.wild)
	if not d.runes.is_empty():
		s += "[%s]" % ",".join(PackedStringArray(d.runes))
	return s


## ค่าดิบของหน้าตามบริบท (ก่อน Body/rune)
static func raw_value(face: Dictionary, ctx: String, wild: int) -> int:
	match face.k:
		"num":
			return int(face.v)
		"sword":
			return 6 if ctx == "offense" else 1
		"shield":
			return 6 if ctx == "defense" else 1
		"wild":
			return wild if wild > 0 else 1
	return 0 # skull


static func condition_value(d: Dictionary, ctx: String) -> int:
	var v := raw_value(d.face, ctx, int(d.get("wild", 0)))
	return DDBodies.get_body(d.body).modify_value(d.face, v, ctx)


static func effective_value(d: Dictionary, ctx: String) -> int:
	var cond := condition_value(d, ctx)
	var v := cond
	for id in d.runes:
		v = DDRunes.get_rune(id).modify_value(d.face, cond, v, ctx)
	return v


static func is_skull(d: Dictionary) -> bool:
	return d.face.k == "skull"


static func is_wild(d: Dictionary) -> bool:
	return d.face.k == "wild"


static func is_odd(v: int) -> bool:
	return v % 2 == 1


static func sum_effective(dice: Array, ctx: String) -> int:
	var s := 0
	for d in dice:
		s += effective_value(d, ctx)
	return s


static func sum_condition(dice: Array, ctx: String) -> int:
	var s := 0
	for d in dice:
		s += condition_value(d, ctx)
	return s


static func any_skull(dice: Array) -> bool:
	for d in dice:
		if is_skull(d):
			return true
	return false

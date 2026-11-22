class_name DDMeta
## ระบบนอกการต่อสู้ (data model + ฟังก์ชัน ยังไม่มี UI)
## ทุกฟังก์ชันคืน Character ใหม่ ไม่แก้ของเดิม — index ผิดจะคืน {}


static func _valid(c: Dictionary, die_index: int, face_index: int) -> bool:
	return die_index >= 0 and die_index < c.dice.size() \
		and face_index >= 0 and face_index < c.dice[die_index].faces.size()


static func upgrade_face(player: Dictionary, die_index: int, face_index: int, new_face: Dictionary) -> Dictionary:
	if not _valid(player, die_index, face_index):
		return {}
	var c: Dictionary = player.duplicate(true)
	c.dice[die_index].faces[face_index] = new_face.duplicate()
	return c


## บทลงโทษผู้แพ้: เปลี่ยนหน้าเป็น 💀 (rune บนหน้านั้นยังอยู่)
static func deface_face(player: Dictionary, die_index: int, face_index: int) -> Dictionary:
	return upgrade_face(player, die_index, face_index, DDFaces.sym("skull"))


## ผู้ชนะขโมย rune ชนิด rune_id 1 อันจากผู้แพ้ (หาที่ตัวเต๋าก่อน → หน้าเต๋า → กระเป๋า rune)
## rune ที่ได้เข้า rune_bag ของผู้ชนะ — คืน {"winner", "loser"} หรือ {} ถ้าผู้แพ้ไม่มี
static func steal_rune(winner: Dictionary, loser: Dictionary, rune_id: String) -> Dictionary:
	var w: Dictionary = winner.duplicate(true)
	var l: Dictionary = loser.duplicate(true)
	var found := false
	for die in l.dice:
		var i: int = die.die_runes.find(rune_id)
		if i >= 0:
			die.die_runes.remove_at(i)
			found = true
			break
	if not found:
		for die in l.dice:
			var i: int = die.face_runes.find(rune_id)
			if i >= 0:
				die.face_runes[i] = ""
				found = true
				break
	if not found:
		var i: int = l.rune_bag.find(rune_id)
		if i >= 0:
			l.rune_bag.remove_at(i)
			found = true
	if not found:
		return {}
	w.rune_bag.append(rune_id)
	return {"winner": w, "loser": l}


static func underdog_faces() -> Array:
	return [DDFaces.num(1), DDFaces.num(2), DDFaces.num(3), DDFaces.num(4), DDFaces.sym("wild"), DDFaces.sym("wild")]


static func create_underdog_die(id: String) -> Dictionary:
	return DDBattle.create_die(id, "standard", underdog_faces())


## มอบ Underdog Die ให้ผู้เล่นคะแนนต่ำสุด (เสมอกันได้ทุกคนที่อยู่ท้าย ได้ไม่ซ้ำ)
static func give_underdog_die(players: Array, scores: Array) -> Array:
	var low: int = scores.min()
	var out := []
	for i in players.size():
		var c: Dictionary = players[i].duplicate(true)
		var id := "%s-underdog" % c.id
		if scores[i] == low and DDBattle.find_die(c, id).is_empty():
			c.dice.append(create_underdog_die(id))
		out.append(c)
	return out

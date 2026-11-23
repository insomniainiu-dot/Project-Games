class_name DDBoardBridge
## แปลงข้อมูลบอร์ดเกม (PlayerStats / มอนสเตอร์ใน GameData) เป็นตัวละคร Dice Duel

## อาชีพบนบอร์ด → อาชีพ Dice Duel
const JOB_MAP := {"Psion": "magician", "Vanguard": "warrior", "Infiltrator": "thief", "Marksman": "ninja", "Engineer": "cleric"}


static func player_character(p: PlayerStats) -> Dictionary:
	var c := DDBattle.create_character("hero", JOB_MAP.get(p.job, "warrior"), p.name)
	c.stats = {"hp": p.max_hp(), "at": p.stat("atk"), "df": p.stat("def"), "mg": p.stat("mag"), "sp": p.stat("spd")}
	# อุปกรณ์ให้ Body/Rune กับเต๋า: อาวุธ = ลูก 1, เกราะ = ลูก 2, เครื่องประดับ = ลูก 3
	var slots := [p.weapon, p.armor, p.accessory]
	for i in mini(slots.size(), c.dice.size()):
		if slots[i] == "":
			continue
		var item: Dictionary = GameData.ITEMS[slots[i]]
		if item.has("die_body"):
			c.dice[i] = DDBattle.create_die(c.dice[i].id, item.die_body)
		if item.has("die_rune"):
			c.dice[i].die_runes.append(item.die_rune)
	return c


static func monster_character(monster_id: String) -> Dictionary:
	var m: Dictionary = GameData.MONSTERS[monster_id]
	var c := DDBattle.create_character("mon", m.get("dd_job", "warrior"), monster_id)
	c.stats = {"hp": m.hp, "at": m.atk, "df": m.def, "mg": m.mag, "sp": m.spd}
	return c


static func config(p: PlayerStats, monster_id: String, seed: int) -> Dictionary:
	return {"seed": seed, "fighters": [player_character(p), monster_character(monster_id)], "start_hp": [p.hp, -1]}


static func portraits(monster_id: String) -> Array:
	var m: Dictionary = GameData.MONSTERS[monster_id]
	return [
		{"texture": load("res://witch_sheet.png"), "hframes": 4, "vframes": 6, "frame": 16},
		{"texture": load(m.sprite), "hframes": m.frames, "vframes": 2, "frame": 0, "tint": m.tint},
	]

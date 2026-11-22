class_name CCBridge
## แปลงข้อมูลบอร์ดเกม (PlayerStats / GameData.MONSTERS) เป็น config ของระบบต่อสู้ช่องเช็ค


static func hero_config(p: PlayerStats) -> Dictionary:
	var items := []
	for it in p.items:
		items.append(it)
	return {"name": p.name, "job": p.job, "hp": p.hp, "items": items,
		"stats": {"hp": p.max_hp(), "atk": p.stat("atk"), "def": p.stat("def"), "mag": p.stat("mag"), "spd": p.stat("spd")}}


static func monster_config(monster_id: String) -> Dictionary:
	var m: Dictionary = GameData.MONSTERS[monster_id]
	return {"name": monster_id, "gold": m.gold, "actions": m.get("cc_actions", {"attack": 1}), "defense": m.get("cc_defense", {"block": 1}),
		"stats": {"hp": m.hp, "atk": m.atk, "def": m.def, "mag": m.mag, "spd": m.spd}}


static func config(p: PlayerStats, monster_id: String, seed: int) -> Dictionary:
	return {"seed": seed, "hero": hero_config(p), "monster": monster_config(monster_id)}


## เขียนผลการต่อสู้กลับเข้า PlayerStats (HP, ไอเทมที่ใช้ไป, ทองที่ขโมยได้)
static func apply_result(p: PlayerStats, final: Dictionary) -> void:
	p.hp = final.units[CCBattle.HERO].hp
	p.items.assign(final.items)
	p.gold += final.stolen_gold


static func portraits(monster_id: String) -> Array:
	var m: Dictionary = GameData.MONSTERS[monster_id]
	return [
		{"texture": load("res://witch_sheet.png"), "hframes": 4, "vframes": 6, "frame": 16},
		{"texture": load(m.sprite), "hframes": m.frames, "vframes": 2, "frame": 0, "tint": m.tint},
	]

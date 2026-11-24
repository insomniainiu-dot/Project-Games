class_name CCBridge
## แปลงข้อมูลบอร์ดเกม (PlayerStats / GameData.MONSTERS) เป็น config ของระบบต่อสู้ช่องเช็ค


static func hero_config(p: PlayerStats) -> Dictionary:
	var items := []
	for it in p.items:
		items.append(it)
	var mods := p.battle_mods()
	if p.fatigue > 0: # Fatigue จากอีเวนต์: เริ่มการต่อสู้ด้วย Focus น้อยลง
		mods = CCBalance.merge_mods(mods, {"start_focus": -p.fatigue})
	return {"name": p.name, "job": p.job, "hp": p.hp, "items": items, "mods": mods,
		"attack_def": p.weapon_attack(), "gems": p.active_gems(), "granted": p.granted_skills(),
		"stats": {"hp": p.max_hp(), "atk": p.stat("atk"), "def": p.stat("def"), "mag": p.stat("mag"), "spd": p.stat("spd"), "lck": p.stat("lck")}}


## scale = ตัวคูณค่าพลังมอนสเตอร์ {"hp": x, "atk": x, "def": x, "mag": x, "gold": x} (อีเวนต์: ตามเลเวล / มินิบอส / อ่อนแรง)
static func monster_config(monster_id: String, scale := {}) -> Dictionary:
	var m: Dictionary = GameData.MONSTERS[monster_id]
	var s := func(k: String) -> int: return maxi(1, roundi(m[k] * float(scale.get(k, 1.0))))
	return {"name": monster_id, "gold": s.call("gold"), "actions": m.get("cc_actions", {"attack": 1}), "defense": m.get("cc_defense", {"block": 1}),
		"stats": {"hp": s.call("hp"), "atk": s.call("atk"), "def": s.call("def"), "mag": s.call("mag"), "spd": m.spd, "lck": m.get("lck", 0)}}


## opts (การต่อสู้จากอีเวนต์): "scale" = ตัวคูณมอนสเตอร์, "hero_mods" = บัฟชั่วคราว (เช่น พรานช่วย ATK +20%)
## สัตว์พันธมิตร (PlayerStats.ally_turns) ช่วยยิงแบบโดรนตั้งแต่ต้นการต่อสู้
static func config(p: PlayerStats, monster_id: String, seed: int, opts := {}) -> Dictionary:
	var hero := hero_config(p)
	if opts.has("hero_mods"):
		hero.mods = CCBalance.merge_mods(hero.mods, opts.hero_mods)
	if p.ally_turns > 0:
		hero.ally_turns = p.ally_turns
		hero.ally_damage = EventData.ally_damage(p.level)
	return {"seed": seed, "hero": hero, "monster": monster_config(monster_id, opts.get("scale", {}))}


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

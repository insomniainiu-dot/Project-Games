class_name PlayerStats
extends RefCounted
## ค่าสถานะผู้เล่น: เลเวล / HP / ค่าพลัง / เงิน / ไอเทม / อุปกรณ์ / อาชีพ

var name := "Witch"
var job: String = GameData.START_JOB
var level := 1
var xp := 0
var hp := 0
var gold := 50
var items: Array[String] = ["Medkit", "Medkit"]
var weapon: String = GameData.JOBS[GameData.START_JOB].start_weapon
var armor := "Flight Suit"
var accessory := ""
var gear: Array[String] = [] # อุปกรณ์สำรองที่มีแต่ยังไม่ได้สวม
var gems: Array[String] = [] # Skill Gem ที่ใส่อยู่ (สูงสุด CCBalance.GEM_SLOTS) — ท่า Attack มาจากอาวุธ
var gem_bag: Array[String] = [] # Skill Gem ที่มีแต่ยังไม่ได้ใส่
var towns: Array[Vector2i] = [] # เมืองที่ปลดปล่อยแล้ว
var trees := {} # Passive Tree แยกต่ออาชีพ: อาชีพ -> Array ของ node id ที่ลงแต้มไว้ (ไม่รวมจุดเริ่ม)

# ฝ่าย + อีเวนต์ (docs/faction_event_design.md) — เกณฑ์ต่าง ๆ อยู่ที่ EventData
var karma: int = EventData.KARMA_START
var syndicate := false # อยู่ Redline Syndicate (Karma < 0 แล้วยังไม่กลับถึง KARMA_RETURN)
var renown := 0 # ชื่อเสียง Freeport Guild
var scrip := 0 # สกุลเงินกิลด์
var fatigue := 0 # หัก Focus ตอนเริ่มการต่อสู้ครั้งถัดไป แล้วล้าง
var skip_turns := 0 # เทิร์นที่ต้องข้าม (อีเวนต์ "หยุด N")
var trail: Array[Vector2i] = [] # ช่องที่เพิ่งเดินผ่าน (ใหม่สุดท้ายสุด) ใช้ "ถอย N"
var coupons := {} # ฝ่าย -> จำนวนส่วนลดร้าน 1 ครั้ง (ร้านฝ่ายมาในขั้น 3)
var ally_turns := 0 # สัตว์พันธมิตรจากอีเวนต์ ช่วยในการต่อสู้ครั้งถัดไป (จำนวนตา)
var recent_events: Array[String] = [] # อีเวนต์ล่าสุด กันสุ่มซ้ำ

# ตำแหน่งบนกระดาน (เก็บที่ผู้เล่นแต่ละคน เผื่อมีหลายผู้เล่นใน Phase 2)
var tile: Vector2i = Board.CASTLE_TILE
var came_from: Vector2i = Board.NO_TILE # ช่องก่อนหน้า กันเดินย้อนกลับ

var _base := {}

const SLOTS := ["weapon", "armor", "accessory"]


func _init() -> void:
	_recalc_base()
	hp = max_hp()
	gems.assign(CCBalance.default_gems(job))


func _recalc_base() -> void:
	var j: Dictionary = GameData.JOBS[job]
	_base = {}
	for k in j.base:
		_base[k] = j.base[k] + j.grow[k] * (level - 1)


## ค่าพลังรวมอุปกรณ์ + Passive Tree
func stat(key: String) -> int:
	return stat_with(key, allocated())


## ค่าพลังถ้าต้น Passive เป็น nodes (ใช้ preview ในหน้า Passive)
func stat_with(key: String, nodes: Array) -> int:
	var v: int = _base.get(key, 0)
	for e in [weapon, armor, accessory]:
		if e != "":
			v += GameData.item(e).get(key, 0)
	v += PassiveTree.stat_bonus(nodes, key)
	var pct: int = PassiveTree.mods(nodes).get("stat_pct." + key, 0) # Keystone เช่น Glass Mind (TEC +30%, HP -25%)
	pct += int(gear_mods().get("stat_pct." + key, 0)) # Unique เช่น Siphon Edge (HP -15%)
	if pct != 0:
		v = roundi(v * (1.0 + pct / 100.0))
	return v


## ผลพิเศษจาก Passive Tree (ส่งเข้าระบบต่อสู้ผ่าน CCBridge)
func passive_mods() -> Dictionary:
	return PassiveTree.mods(allocated())


## ผลพิเศษจากอุปกรณ์ที่สวม (Unique + affix ของ Rare/Epic)
func gear_mods() -> Dictionary:
	var out := {}
	for e in [weapon, armor, accessory]:
		if e != "":
			out = CCBalance.merge_mods(out, GameData.item(e).get("mods", {}))
	return out


## Passive + อุปกรณ์ รวมกัน (ส่งเข้าระบบต่อสู้)
func battle_mods() -> Dictionary:
	return CCBalance.merge_mods(passive_mods(), gear_mods())


## ท่าติดอาวุธ Unique (ไม่กินช่อง gem)
func granted_skills() -> Array:
	var out := []
	for e in [weapon, armor, accessory]:
		if e != "" and GameData.item(e).has("grants"):
			out.append(GameData.item(e).grants)
	return out


# ---------------------------------------------------------------- Passive Tree
## โหนดที่ลงแต้มไว้ของอาชีพปัจจุบัน (แต่ละอาชีพจำต้นของตัวเอง)
func allocated() -> Array:
	return trees.get(job, [])


## แต้มทั้งหมด = 1 ต่อเลเวล (Lv2 ขึ้นไป) — เป็นของตัวละคร ใช้ได้กับทุกอาชีพ
func passive_points() -> int:
	return level - 1


func unspent_points() -> int:
	return passive_points() - allocated().size()


func can_allocate(id: String) -> bool:
	return unspent_points() > 0 and PassiveTree.can_allocate(allocated(), id, job)


func allocate(id: String) -> bool:
	if not can_allocate(id):
		return false
	var a := allocated().duplicate()
	a.append(id)
	trees[job] = a
	return true


## ตั้งต้นทั้งชุด (ปุ่ม Confirm ในหน้า Passive) — ต้องต่อกันครบและแต้มพอ
func set_tree(nodes: Array) -> bool:
	if nodes.size() > passive_points() or not PassiveTree.is_connected_tree(nodes, job):
		return false
	for id in nodes:
		if not PassiveTree.NODES.has(id) or PassiveTree.NODES[id].type == "start":
			return false
	trees[job] = nodes.duplicate()
	_clamp_hp()
	return true


## ราคารีเซ็ตต้นที่ปราสาท: ฟรีถึง Lv5 แล้ว 10 × เลเวล
func reset_cost() -> int:
	return 0 if level <= GameData.FREE_RESET_LEVEL else GameData.RESET_COST_PER_LEVEL * level


## คืนแต้มทั้งต้นของอาชีพปัจจุบัน คืนจำนวนโหนดที่คืน
func reset_tree() -> int:
	var n := allocated().size()
	trees.erase(job)
	_clamp_hp()
	return n


func max_hp() -> int:
	return stat("hp")


func exp_needed() -> int:
	return GameData.EXP_TO_LEVEL * level


## รับ exp แล้วคืนจำนวนเลเวลที่เพิ่ม
func gain_exp(amount: int) -> int:
	xp += amount
	var ups := 0
	while xp >= exp_needed():
		xp -= exp_needed()
		level += 1
		ups += 1
		_recalc_base()
		hp = min(hp + GameData.JOBS[job].grow.hp, max_hp())
	return ups


## ตัวคูณเงินที่ได้จากช่องกระดาน / มอนสเตอร์ ตามอาชีพ
func gold_mult() -> float:
	return float(GameData.JOBS[job].get("gold_mult", 1.0)) + float(passive_mods().get("gold_bonus", 0.0))


## เปลี่ยนอาชีพ: gem ของอาชีพเดิมที่ใส่อยู่ถูกแทนด้วย gem ของอาชีพใหม่ (ของเดิมเข้ากระเป๋า gem)
func change_job(new_job: String) -> void:
	var old_gem: String = CCBalance.JOB_SKILL.get(job, "")
	var new_gem: String = CCBalance.JOB_SKILL.get(new_job, "")
	# ยังถืออาวุธเริ่มต้นของอาชีพเดิม = สลับเป็นอาวุธเริ่มต้นของอาชีพใหม่ (ของเริ่มต้นราคา 0 ไม่เก็บไว้)
	if weapon == GameData.JOBS[job].get("start_weapon", "") or weapon == "":
		gear.erase(GameData.JOBS[new_job].start_weapon)
		weapon = GameData.JOBS[new_job].start_weapon
	job = new_job
	_recalc_base()
	hp = min(hp, max_hp())
	if new_gem == "" or new_gem == old_gem or gems.has(new_gem):
		return
	gem_bag.erase(new_gem)
	var i := gems.find(old_gem)
	if i >= 0:
		gems[i] = new_gem
		_add_to_gem_bag(old_gem)
	elif gems.size() < CCBalance.GEM_SLOTS:
		gems.append(new_gem)
	else:
		_add_to_gem_bag(new_gem)


# ---------------------------------------------------------------- Skill Gem
## gem ที่ใส่อยู่และใช้กับอาวุธที่ถือได้ (ส่งเข้าการต่อสู้) — gem ที่ไม่เข้ากับอาวุธยังอยู่ในช่องแต่ใช้ไม่ได้
func active_gems() -> Array:
	var wt := GameData.weapon_type(weapon)
	return Array(gems).filter(func(g): return CCBalance.gem_fits(g, wt))


func gem_fits_weapon(gem: String) -> bool:
	return CCBalance.gem_fits(gem, GameData.weapon_type(weapon))


func owns_gem(gem: String) -> bool:
	return gems.has(gem) or gem_bag.has(gem)


## ได้ gem ใหม่ (ซื้อ/ดรอป) — ช่องว่างจะใส่ให้เลย ไม่งั้นเข้ากระเป๋า gem; มีอยู่แล้ว = false
func add_gem(gem: String) -> bool:
	if not CCBalance.GEMS.has(gem) or owns_gem(gem):
		return false
	if gems.size() < CCBalance.GEM_SLOTS:
		gems.append(gem)
	else:
		gem_bag.append(gem)
	return true


## ใส่ gem จากกระเป๋าลงช่อง slot (ของเดิมในช่องกลับเข้ากระเป๋า) คืนชื่อ gem เดิม
func set_gem(slot: int, gem: String) -> String:
	if not gem_bag.has(gem) or slot < 0 or slot >= CCBalance.GEM_SLOTS:
		return ""
	gem_bag.erase(gem)
	if slot >= gems.size():
		gems.append(gem)
		return ""
	var old := gems[slot]
	gems[slot] = gem
	gem_bag.append(old)
	return old


## ถอด gem ออกจากช่อง (อย่างน้อยต้องเหลือ Attack ซึ่งมาจากอาวุธอยู่แล้ว เลยถอดหมดได้)
func remove_gem(slot: int) -> String:
	if slot < 0 or slot >= gems.size():
		return ""
	var old := gems[slot]
	gems.remove_at(slot)
	gem_bag.append(old)
	return old


func _add_to_gem_bag(gem: String) -> void:
	if gem != "" and not owns_gem(gem):
		gem_bag.append(gem)


## ท่า Attack จากอาวุธที่ถือ (ไม่มีอาวุธ = {} → ระบบต่อสู้ใช้ Attack พื้นฐาน)
func weapon_attack() -> Dictionary:
	var wt := GameData.weapon_type(weapon)
	return CCBalance.weapon_attack(wt) if wt != "" else {}


func heal(amount: int) -> int:
	var before := hp
	hp = min(hp + amount, max_hp())
	return hp - before


func add_item(item: String) -> bool:
	if items.size() >= GameData.MAX_ITEMS:
		return false
	items.append(item)
	return true


# ---------------------------------------------------------------- อุปกรณ์
func equipped(slot: String) -> String:
	match slot:
		"weapon":
			return weapon
		"armor":
			return armor
		"accessory":
			return accessory
	return ""


func _set_slot(slot: String, item: String) -> void:
	match slot:
		"weapon":
			weapon = item
		"armor":
			armor = item
		"accessory":
			accessory = item


## ค่าพลังถ้าสวม item แทนของเดิมในช่องเดียวกัน (ใช้เทียบก่อนสวม)
func preview_stat(key: String, item: String) -> int:
	var slot: String = GameData.item(item).type
	var cur := equipped(slot)
	_set_slot(slot, item) # สวมชั่วคราว (คิด % จาก Unique / affix ถูกต้อง) แล้วคืนของเดิม
	var v := stat(key)
	_set_slot(slot, cur)
	return v


## ค่าพลังถ้าถอดของในช่อง slot ออก
func preview_remove_stat(key: String, slot: String) -> int:
	var cur := equipped(slot)
	_set_slot(slot, "")
	var v := stat(key)
	_set_slot(slot, cur)
	return v


## อุปกรณ์ทั้งหมดที่มี (สวม + กระเป๋า)
func all_gear() -> Array:
	var out: Array = gear.duplicate() # Array(gear) ไม่ copy — ต่อของเข้า gear จริงเลย
	for e in [weapon, armor, accessory]:
		if e != "":
			out.append(e)
	return out


func owns(item: String) -> bool:
	return gear.has(item) or item == weapon or item == armor or item == accessory


func add_gear(item: String) -> bool:
	if gear.size() >= GameData.MAX_GEAR:
		return false
	gear.append(item)
	return true


## สวมอุปกรณ์ (ถ้าอยู่ในกระเป๋าอุปกรณ์จะถูกหยิบออก) ของเดิมกลับเข้ากระเป๋า คืนชื่อของเดิม
func equip(item: String) -> String:
	var slot: String = GameData.item(item).type
	var old := equipped(slot)
	gear.erase(item)
	_set_slot(slot, item)
	if old != "":
		gear.append(old)
	_clamp_hp()
	return old


## ถอดอุปกรณ์กลับเข้ากระเป๋า (กระเป๋าเต็มจะถอดไม่ได้)
func unequip(slot: String) -> bool:
	var cur := equipped(slot)
	if cur == "" or gear.size() >= GameData.MAX_GEAR:
		return false
	_set_slot(slot, "")
	gear.append(cur)
	_clamp_hp()
	return true


# ---------------------------------------------------------------- ฝ่าย / อีเวนต์
## "concord" / "syndicate"
func faction() -> String:
	return "syndicate" if syndicate else "concord"


## ปรับ Karma แล้วเช็คการเปลี่ยนฝ่าย คืนฝ่ายใหม่ถ้าเปลี่ยน ("" = ไม่เปลี่ยน)
func add_karma(n: int) -> String:
	karma += n
	if not syndicate and karma < 0:
		syndicate = true
		return "syndicate"
	if syndicate and karma >= EventData.KARMA_RETURN:
		syndicate = false
		return "concord"
	return ""


## ผ่านเงื่อนไขตัวเลือก D ไหม ("concord" / "syndicate" / "freeport")
func meets(need: String) -> bool:
	match need:
		"concord":
			return not syndicate and karma >= EventData.D_CONCORD_KARMA
		"syndicate":
			return syndicate
		"freeport":
			return renown >= EventData.D_FREEPORT_RENOWN
	return need == ""


## จำช่องที่เดินผ่าน (BoardWalker เรียกทุกก้าว)
func remember_step(cell: Vector2i) -> void:
	trail.append(cell)
	while trail.size() > EventData.TRAIL_SIZE:
		trail.remove_at(0)


## ถอยตามทางที่มาได้สูงสุด n ช่อง คืนช่องที่ผ่าน (ตามลำดับ) — ตำแหน่งผู้เล่นเปลี่ยนแล้ว
func step_back(n: int) -> Array[Vector2i]:
	var path: Array[Vector2i] = []
	for i in n:
		if trail.is_empty():
			break
		tile = trail.pop_back()
		path.append(tile)
	if not path.is_empty():
		came_from = Board.NO_TILE # ถอยแล้วเลือกทางใหม่ได้อิสระ
	return path


# ---------------------------------------------------------------- เซฟ / โหลด (SaveGame)
func to_dict() -> Dictionary:
	var town_list := []
	for t in towns:
		town_list.append([t.x, t.y])
	return {"name": name, "job": job, "level": level, "xp": xp, "hp": hp, "gold": gold,
		"items": items.duplicate(), "weapon": weapon, "armor": armor, "accessory": accessory,
		"gear": gear.duplicate(), "gems": gems.duplicate(), "gem_bag": gem_bag.duplicate(),
		"towns": town_list, "trees": trees.duplicate(true),
		"tile": [tile.x, tile.y], "came_from": [came_from.x, came_from.y],
		"karma": karma, "syndicate": syndicate, "renown": renown, "scrip": scrip, "fatigue": fatigue,
		"skip_turns": skip_turns, "trail": trail.map(func(c): return [c.x, c.y]), "coupons": coupons.duplicate(),
		"recent_events": recent_events.duplicate(), "ally_turns": ally_turns}


## เขียนทับค่าด้วยข้อมูลเซฟ (ค่าที่ไม่มีในเซฟคงเดิม)
func from_dict(d: Dictionary) -> void:
	name = d.get("name", name)
	job = d.get("job", job) if GameData.JOBS.has(d.get("job", "")) else job
	level = int(d.get("level", level))
	xp = int(d.get("xp", xp))
	gold = int(d.get("gold", gold))
	# ไอเทมที่ไม่รู้จักแล้ว (เปลี่ยนชื่อ/ลบออกจากเกม) ถูกทิ้ง ไม่ให้เกม crash
	var known := func(id): return not GameData.item(str(id)).is_empty()
	items.assign(d.get("items", items).filter(known))
	weapon = d.get("weapon", weapon) if d.get("weapon", "") == "" or known.call(d.weapon) else ""
	armor = d.get("armor", armor) if d.get("armor", "") == "" or known.call(d.armor) else ""
	accessory = d.get("accessory", accessory) if d.get("accessory", "") == "" or known.call(d.accessory) else ""
	gear.assign(d.get("gear", gear).filter(known))
	gems.assign(CCBattle.clean_gems(d.get("gems", gems)))
	gem_bag.assign(d.get("gem_bag", gem_bag).filter(func(g): return CCBalance.GEMS.has(g)))
	towns.clear()
	for t in d.get("towns", []):
		towns.append(Vector2i(int(t[0]), int(t[1])))
	trees = {}
	var tr: Dictionary = d.get("trees", {})
	for j in tr:
		trees[j] = Array(tr[j])
	if d.has("tile"):
		tile = Vector2i(int(d.tile[0]), int(d.tile[1]))
	if d.has("came_from"):
		came_from = Vector2i(int(d.came_from[0]), int(d.came_from[1]))
	# ฝ่าย / อีเวนต์ (เซฟ v1 ไม่มี = ใช้ค่าเริ่มต้น)
	karma = int(d.get("karma", karma))
	syndicate = bool(d.get("syndicate", syndicate))
	renown = int(d.get("renown", renown))
	scrip = int(d.get("scrip", scrip))
	fatigue = int(d.get("fatigue", fatigue))
	skip_turns = int(d.get("skip_turns", skip_turns))
	trail.clear()
	for c in d.get("trail", []):
		trail.append(Vector2i(int(c[0]), int(c[1])))
	coupons = {}
	var cp: Dictionary = d.get("coupons", {})
	for k in cp:
		coupons[k] = int(cp[k])
	recent_events.assign(d.get("recent_events", []).filter(func(e): return EventData.EVENTS.has(e)))
	ally_turns = int(d.get("ally_turns", ally_turns))
	_recalc_base()
	hp = clampi(int(d.get("hp", hp)), 1, max_hp())


func _clamp_hp() -> void:
	hp = clampi(hp, 1, max_hp())

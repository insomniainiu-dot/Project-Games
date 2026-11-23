class_name PlayerStats
extends RefCounted
## ค่าสถานะผู้เล่น: เลเวล / HP / ค่าพลัง / เงิน / ไอเทม / อุปกรณ์ / อาชีพ

var name := "Witch"
var job: String = GameData.START_JOB
var level := 1
var xp := 0
var hp := 0
var gold := 50
var items: Array[String] = ["Herb", "Herb"]
var weapon := "Oak Staff"
var armor := "Travel Cloak"
var accessory := ""
var gear: Array[String] = [] # อุปกรณ์สำรองที่มีแต่ยังไม่ได้สวม
var towns: Array[Vector2i] = [] # เมืองที่ปลดปล่อยแล้ว
var trees := {} # Passive Tree แยกต่ออาชีพ: อาชีพ -> Array ของ node id ที่ลงแต้มไว้ (ไม่รวมจุดเริ่ม)

# ตำแหน่งบนกระดาน (เก็บที่ผู้เล่นแต่ละคน เผื่อมีหลายผู้เล่นใน Phase 2)
var tile: Vector2i = Board.CASTLE_TILE
var came_from: Vector2i = Board.NO_TILE # ช่องก่อนหน้า กันเดินย้อนกลับ

var _base := {}

const SLOTS := ["weapon", "armor", "accessory"]


func _init() -> void:
	_recalc_base()
	hp = max_hp()


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
			v += GameData.ITEMS[e].get(key, 0)
	v += PassiveTree.stat_bonus(nodes, key)
	var pct: int = PassiveTree.mods(nodes).get("stat_pct." + key, 0) # Keystone เช่น Glass Mind (TEC +30%, HP -25%)
	if pct != 0:
		v = roundi(v * (1.0 + pct / 100.0))
	return v


## ผลพิเศษจาก Passive Tree (ส่งเข้าระบบต่อสู้ผ่าน CCBridge)
func passive_mods() -> Dictionary:
	return PassiveTree.mods(allocated())


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


func change_job(new_job: String) -> void:
	job = new_job
	_recalc_base()
	hp = min(hp, max_hp())


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
	var cur := equipped(GameData.ITEMS[item].type)
	var v := stat(key)
	if cur != "":
		v -= GameData.ITEMS[cur].get(key, 0)
	return v + GameData.ITEMS[item].get(key, 0)


func owns(item: String) -> bool:
	return gear.has(item) or item == weapon or item == armor or item == accessory


func add_gear(item: String) -> bool:
	if gear.size() >= GameData.MAX_GEAR:
		return false
	gear.append(item)
	return true


## สวมอุปกรณ์ (ถ้าอยู่ในกระเป๋าอุปกรณ์จะถูกหยิบออก) ของเดิมกลับเข้ากระเป๋า คืนชื่อของเดิม
func equip(item: String) -> String:
	var slot: String = GameData.ITEMS[item].type
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


func _clamp_hp() -> void:
	hp = clampi(hp, 1, max_hp())

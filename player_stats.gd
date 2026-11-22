class_name PlayerStats
extends RefCounted
## ค่าสถานะผู้เล่น: เลเวล / HP / ค่าพลัง / เงิน / ไอเทม / อุปกรณ์ / อาชีพ

var name := "Witch"
var job := "Mage"
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


## ค่าพลังรวมอุปกรณ์
func stat(key: String) -> int:
	var v: int = _base.get(key, 0)
	for e in [weapon, armor, accessory]:
		if e != "":
			v += GameData.ITEMS[e].get(key, 0)
	return v


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

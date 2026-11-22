class_name DDRunes
## Rune: เกาะที่หน้าเต๋า หรือที่ตัวเต๋า (มีผลทุกหน้า) — ระบบ hook ขยายต่อได้
##   modify_value : แก้ค่าที่ใช้คิดพลัง/การลดดาเมจ (ไม่กระทบการตรวจเงื่อนไขท่า)
##   power_bonus  : โบนัสพลังแบบ % ตามท่าที่ใช้ (บวกรวมกับโบนัสอื่นก่อนคูณ)
## เพิ่ม rune ใหม่: สร้าง inner class ที่ extends Rune แล้ว register() ใน _ensure()


class Rune:
	var id := ""
	var name := ""
	var desc := ""

	## cond = ค่าหลัง Body ก่อน rune (ค่าที่ใช้ตรวจเงื่อนไข), value = ค่าสะสมจาก rune ก่อนหน้า
	func modify_value(_face: Dictionary, _cond: int, value: int, _ctx: String) -> int:
		return value

	func power_bonus(_move: String) -> float:
		return 0.0


class Twin extends Rune:
	func _init() -> void:
		id = "twin"
		name = "Twin"
		desc = "Even face counts double."

	func modify_value(_face: Dictionary, cond: int, value: int, _ctx: String) -> int:
		return value * DDBalance.TWIN_MULT if cond > 0 and cond % 2 == 0 else value


class Spark extends Rune:
	func _init() -> void:
		id = "spark"
		name = "Spark"
		desc = "+%d%% power when used for Magic." % roundi(DDBalance.SPARK_MAGIC_BONUS * 100)

	func power_bonus(move: String) -> float:
		return DDBalance.SPARK_MAGIC_BONUS if move == "magic" else 0.0


static var _registry := {}


static func _ensure() -> void:
	if not _registry.is_empty():
		return
	register(Twin.new())
	register(Spark.new())


static func register(r: Rune) -> void:
	_registry[r.id] = r


static func get_rune(id: String) -> Rune:
	_ensure()
	assert(_registry.has(id), "Unknown rune: %s" % id)
	return _registry.get(id, Rune.new())


static func all() -> Dictionary:
	_ensure()
	return _registry

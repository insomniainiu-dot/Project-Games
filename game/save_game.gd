class_name SaveGame
## เซฟ / โหลดเกม (JSON ที่ user://save.json)
## เก็บ: วัน + PlayerStats ทุกค่า + ข้อมูล Rare/Epic ที่ผู้เล่นถืออยู่ (ItemDB instance ใช้ id เดิม)
## เซฟอัตโนมัติตอนจบวัน (TurnManager) · เปิดเกมถ้ามีเซฟจะถาม Continue / New Game (main.gd)

const PATH := "user://save.json"
const VERSION := 1


static func has_save(path := PATH) -> bool:
	return FileAccess.file_exists(path)


## state → Dictionary (ส่งเข้า JSON ได้ตรง ๆ)
static func to_dict(state: GameState) -> Dictionary:
	var p := state.player
	var instances := {}
	for id in p.all_gear():
		if ItemDB.is_instance(id):
			instances[id] = ItemDB.record(id)
	return {"version": VERSION, "day": state.day, "player": p.to_dict(), "items": instances}


## เขียนทับ state ด้วยข้อมูลเซฟ (แก้ในที่ ไม่สร้าง object ใหม่ — ระบบอื่นถือ reference ไว้อยู่)
static func apply(state: GameState, data: Dictionary) -> bool:
	if int(data.get("version", 0)) != VERSION or not data.has("player"):
		return false
	var items: Dictionary = data.get("items", {})
	for id in items:
		ItemDB.restore(id, items[id])
	state.day = int(data.get("day", 1))
	state.player.from_dict(data.player)
	return true


static func save(state: GameState, path := PATH) -> bool:
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		push_error("SaveGame: can't write %s (%s)" % [path, error_string(FileAccess.get_open_error())])
		return false
	f.store_string(JSON.stringify(to_dict(state), "\t"))
	return true


## โหลดเข้า state (false = ไม่มีไฟล์ / ไฟล์เสีย / คนละเวอร์ชัน — state ไม่ถูกแตะ)
static func load_into(state: GameState, path := PATH) -> bool:
	if not has_save(path):
		return false
	var data = JSON.parse_string(FileAccess.get_file_as_string(path))
	if typeof(data) != TYPE_DICTIONARY:
		push_error("SaveGame: %s is not valid JSON" % path)
		return false
	return apply(state, data)


## วันที่ในเซฟ (แสดงในปุ่ม Continue) — 0 = อ่านไม่ได้
static func saved_day(path := PATH) -> int:
	if not has_save(path):
		return 0
	var data = JSON.parse_string(FileAccess.get_file_as_string(path))
	return int(data.get("day", 0)) if typeof(data) == TYPE_DICTIONARY else 0


static func delete(path := PATH) -> void:
	if has_save(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))

class_name DDReplay
## Replay = {"version": 1, "config", "actions"} → สร้าง state ใหม่ได้ทุกขั้น

const SAVE_PATH := "user://dice_duel_last_replay.json"


static func to_replay(s: Dictionary) -> Dictionary:
	return {"version": 1, "config": s.config.duplicate(true), "actions": s.actions.duplicate(true)}


## เล่นซ้ำถึง action ที่ steps (-1 = ทั้งหมด)
static func replay(data: Dictionary, steps := -1) -> Dictionary:
	var s := DDBattle.create_battle(data.config)
	var n: int = data.actions.size() if steps < 0 else mini(steps, data.actions.size())
	for i in n:
		var r := DDBattle.apply_action(s, data.actions[i])
		assert(r.error == "", "Replay diverged at action %d: %s" % [i, r.error])
		s = r.state
	return s


static func to_json(data: Dictionary) -> String:
	return JSON.stringify(data, "  ")


## JSON ทำให้ตัวเลขเป็น float — แปลงกลับเป็น int ให้หมด (ทุกตัวเลขใน replay เป็นจำนวนเต็ม)
static func from_json(text: String) -> Dictionary:
	var parsed = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY or int(parsed.get("version", 0)) != 1:
		return {}
	return _ints(parsed)


static func _ints(v):
	match typeof(v):
		TYPE_FLOAT:
			return int(v)
		TYPE_DICTIONARY:
			var d := {}
			for k in v:
				d[k] = _ints(v[k])
			return d
		TYPE_ARRAY:
			var a := []
			for x in v:
				a.append(_ints(x))
			return a
	return v


static func save(data: Dictionary, path := SAVE_PATH) -> bool:
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return false
	f.store_string(to_json(data))
	return true


static func load_file(path := SAVE_PATH) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	return from_json(FileAccess.get_file_as_string(path))

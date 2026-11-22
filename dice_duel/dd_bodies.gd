class_name DDBodies
## Dice Body: คุณสมบัติประจำทั้งลูก (มาจากอาวุธ/โล่)
## เพิ่ม Body ใหม่: สร้าง inner class ที่ extends Body แล้ว register() ใน _ensure()


class Body:
	var id := "standard"
	var name := "Standard"
	var desc := "No effect."
	var sides := 6 ## จำนวนหน้าเมื่อสร้างเต๋าใหม่
	var start_focus := 0 ## Focus ที่ได้ตอนเริ่มการต่อสู้

	## ปรับค่าหลังทอย (ก่อน rune)
	func modify_value(_face: Dictionary, value: int, _ctx: String) -> int:
		return value


class Heavy extends Body:
	func _init() -> void:
		id = "heavy"
		name = "Heavy"
		desc = "Number faces roll at least %d." % DDBalance.HEAVY_MIN_ROLL

	func modify_value(face: Dictionary, value: int, _ctx: String) -> int:
		if face.k == "num" and value < DDBalance.HEAVY_MIN_ROLL:
			return DDBalance.HEAVY_MIN_ROLL
		return value


class Quick extends Body:
	func _init() -> void:
		id = "quick"
		name = "Quick"
		desc = "A d%d, but +%d Focus when the battle starts." % [DDBalance.QUICK_SIDES, DDBalance.QUICK_START_FOCUS]
		sides = DDBalance.QUICK_SIDES
		start_focus = DDBalance.QUICK_START_FOCUS


static var _registry := {}


static func _ensure() -> void:
	if not _registry.is_empty():
		return
	register(Body.new())
	register(Heavy.new())
	register(Quick.new())


static func register(b: Body) -> void:
	_registry[b.id] = b


static func get_body(id: String) -> Body:
	_ensure()
	assert(_registry.has(id), "Unknown dice body: %s" % id)
	return _registry.get(id, _registry["standard"])


static func all() -> Dictionary:
	_ensure()
	return _registry

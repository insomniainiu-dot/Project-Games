class_name GameState
extends RefCounted
## สถานะของเกมทั้งเกม (ผู้เล่น + วัน) ที่ระบบต่าง ๆ ใช้ร่วมกัน
## แก้ค่าแล้วเรียก notify() ให้ HUD (และอะไรก็ตามที่ฟัง changed) อัปเดตตาม
## ภายหลังใช้เป็นจุดเดียวสำหรับเซฟ/โหลด และขยายเป็นหลายผู้เล่นได้

signal changed

var player := PlayerStats.new()
var day := 1


func notify() -> void:
	changed.emit()

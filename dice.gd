class_name Dice
extends Node2D
## ลูกเต๋า 1 ลูก วาดด้วยโค้ด (ไม่ต้องใช้รูป) มีแอนิเมชันตอนทอย
## เรียก roll() เพื่อทอย แล้วรอสัญญาณ rolled(value)

signal rolled(value: int)

@export var size_px := 80.0
@export var face_color := Color(0.97, 0.95, 0.9)
@export var pip_color := Color(0.15, 0.12, 0.1)
@export var one_pip_color := Color(0.8, 0.1, 0.12)
@export var roll_duration := 0.8

var value := 1
var is_rolling := false

# ตำแหน่งจุดบนหน้าเต๋า (หน่วย -1..1)
const PIPS := {
	1: [Vector2(0, 0)],
	2: [Vector2(-1, -1), Vector2(1, 1)],
	3: [Vector2(-1, -1), Vector2(0, 0), Vector2(1, 1)],
	4: [Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 1), Vector2(1, 1)],
	5: [Vector2(-1, -1), Vector2(1, -1), Vector2(0, 0), Vector2(-1, 1), Vector2(1, 1)],
	6: [Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 0), Vector2(1, 0), Vector2(-1, 1), Vector2(1, 1)],
}


func _draw() -> void:
	var half := size_px / 2.0
	var box := StyleBoxFlat.new()
	box.bg_color = face_color
	box.set_corner_radius_all(int(size_px * 0.18))
	box.border_color = Color(0, 0, 0, 0.35)
	box.set_border_width_all(3)
	box.shadow_color = Color(0, 0, 0, 0.35)
	box.shadow_size = 6
	box.shadow_offset = Vector2(3, 5)
	draw_style_box(box, Rect2(-half, -half, size_px, size_px))

	var spacing := size_px * 0.27
	var radius := size_px * 0.09
	var color: Color = pip_color
	if value == 1:
		color = one_pip_color
		radius *= 1.5
	for p in PIPS[value]:
		draw_circle(p * spacing, radius, color)


## ทอยเต๋า: หน้าเต๋าจะสุ่มเปลี่ยนเร็ว ๆ แล้วค่อย ๆ ช้าลงจนหยุด
func roll() -> void:
	if is_rolling:
		return
	is_rolling = true
	var final_value := randi_range(1, 6)

	# หมุน + เด้ง
	rotation = 0.0
	var spin := create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	spin.tween_property(self, "rotation", TAU * 2.0, roll_duration)
	var bounce := create_tween().set_trans(Tween.TRANS_SINE)
	bounce.tween_property(self, "scale", Vector2(1.25, 1.25), roll_duration * 0.35)
	bounce.tween_property(self, "scale", Vector2.ONE, roll_duration * 0.65) \
		.set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)

	# สลับหน้าเต๋า ช่วงหลังจะช้าลง
	var steps := 12
	var weights: Array[float] = []
	var total := 0.0
	for i in steps:
		var w := 1.0 + i * 0.35
		weights.append(w)
		total += w
	var faces := create_tween()
	for w in weights:
		faces.tween_callback(_show_random_face)
		faces.tween_interval(roll_duration * w / total)
	faces.tween_callback(_finish_roll.bind(final_value))


func _show_random_face() -> void:
	var next := randi_range(1, 5)
	if next >= value:
		next += 1 # ไม่ให้ซ้ำหน้าเดิม จะได้เห็นว่าเปลี่ยน
	value = next
	queue_redraw()


func _finish_roll(final_value: int) -> void:
	value = final_value
	rotation = 0.0
	is_rolling = false
	queue_redraw()
	rolled.emit(value)

class_name Witch
extends Node3D
## ตัวละครแม่มดแบบ HD-2D: สไปรต์พิกเซล 2D (Sprite3D) ที่ยืนอยู่ในโลก 3D
## ใช้สไปรต์ชีต witch_sheet.png = 4 คอลัมน์ x 6 แถว
##   แถว 0-3 : เดิน ลง / ซ้าย / ขวา / ขึ้น (4 เฟรม)
##   แถว 4   : ยืนลง, กระพริบตาลง, ยืนซ้าย, กระพริบตาซ้าย
##   แถว 5   : ยืนขวา, กระพริบตาขวา, ยืนขึ้น, ยืนขึ้น(ท่าสลับ)

enum Dir { DOWN, LEFT, RIGHT, UP }

const HEIGHT := 1.25 # ความสูงตัวละครในหน่วยโลก 3D (1 ช่อง = 1.0)
const WALK_FPS := 8.0

# เฟรมยืนนิ่ง [ปกติ, กระพริบตา] ของแต่ละทิศ (เลขเฟรม = แถว*4 + คอลัมน์)
const IDLE_FRAMES := {
	Dir.DOWN: [16, 17],
	Dir.LEFT: [18, 19],
	Dir.RIGHT: [20, 21],
	Dir.UP: [22, 22], # หันหลังมองไม่เห็นตา
}

# ---- ปรับความมีชีวิตชีวาตรงนี้ ----
const BREATH_SPEED := 2.4     # วินาทีต่อการหายใจ 1 รอบ
const BREATH_AMOUNT := 0.025  # ตัวยืดขึ้นลงกี่ส่วน ตอนหายใจ
const SWAY_AMOUNT := 0.03     # โยกตัวซ้ายขวาเบา ๆ (หน่วยโลก)
const BLINK_TIME := 0.12      # ระยะเวลาหลับตา (วินาที)
const BLINK_MIN := 2.0        # กระพริบตาทุก ๆ 2-5 วินาที
const BLINK_MAX := 5.0

var facing: Dir = Dir.DOWN
var walking := false
var sprite: Sprite3D
var _anim_time := 0.0
var _idle_time := 0.0
var _base_y := 0.0
var _blink_wait := 0.0
var _blink_left := 0.0
var _double_blink := false


func _init() -> void:
	sprite = Sprite3D.new()
	sprite.texture = load("res://witch_sheet.png")
	sprite.hframes = 4
	sprite.vframes = 6
	var frame_height := sprite.texture.get_height() / 6.0
	sprite.pixel_size = HEIGHT / frame_height
	sprite.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y # หันเข้ากล้องเสมอ แต่ยืนตรง
	sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST # พิกเซลคม
	sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD # ทำให้เงาเป็นรูปตัวละคร
	sprite.shaded = true # รับแสงจากตะเกียง/แสงแดด
	sprite.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	_base_y = HEIGHT / 2.0 # ยกขึ้นให้เท้าแตะพื้นที่จุด position
	sprite.position.y = _base_y
	add_child(sprite)
	_blink_wait = randf_range(BLINK_MIN, BLINK_MAX)
	_update_frame()


func _process(delta: float) -> void:
	if walking:
		_anim_time += delta
		_idle_time = 0.0
	else:
		_anim_time = 0.0
		_idle_time += delta
		_update_blink(delta)
		_update_breathing()
	_update_frame()


func _update_frame() -> void:
	if walking:
		var col := int(_anim_time * WALK_FPS) % 4
		sprite.frame = int(facing) * 4 + col
	else:
		var idle: Array = IDLE_FRAMES[facing]
		sprite.frame = idle[1] if _blink_left > 0.0 else idle[0]


## กระพริบตาแบบสุ่ม บางครั้งกระพริบ 2 ครั้งติดกัน
func _update_blink(delta: float) -> void:
	if _blink_left > 0.0:
		_blink_left -= delta
		if _blink_left <= 0.0:
			if _double_blink:
				_double_blink = false
				_blink_wait = 0.15
			else:
				_blink_wait = randf_range(BLINK_MIN, BLINK_MAX)
		return
	_blink_wait -= delta
	if _blink_wait <= 0.0:
		_blink_left = BLINK_TIME
		_double_blink = randf() < 0.25


## หายใจ: ตัวยืด/หดเล็กน้อย เท้ายังติดพื้น + โยกตัวเบา ๆ
func _update_breathing() -> void:
	var t := _idle_time * TAU / BREATH_SPEED
	var breath := (sin(t) + 1.0) * 0.5 # 0..1
	var sy := 1.0 + breath * BREATH_AMOUNT
	var sx := 1.0 - breath * BREATH_AMOUNT * 0.4
	sprite.scale = Vector3(sx, sy, 1.0)
	sprite.position.y = _base_y * sy # ชดเชยให้เท้าไม่ลอย
	sprite.position.x = sin(t * 0.5) * SWAY_AMOUNT


func face_toward(direction: Vector3) -> void:
	if absf(direction.x) > absf(direction.z):
		facing = Dir.RIGHT if direction.x > 0 else Dir.LEFT
	elif direction.z != 0:
		facing = Dir.DOWN if direction.z > 0 else Dir.UP


## เริ่ม/จบการเดิน (ใช้ร่วมกับ step_to)
func begin_walk() -> void:
	walking = true
	sprite.scale = Vector3.ONE
	sprite.position = Vector3(0, _base_y, 0)


func end_walk(face_camera := true) -> void:
	walking = false
	if face_camera:
		facing = Dir.DOWN # หยุดแล้วหันหน้าเข้ากล้อง
	_blink_wait = randf_range(0.6, 1.5) # หยุดแล้วเดี๋ยวกระพริบตา


## เดิน 1 ก้าวไปยังจุด p พร้อมกระโดดเล็กน้อย (ใช้ await ได้)
func step_to(p: Vector3, step_time := 0.3) -> void:
	face_toward(p - position)
	var move := create_tween()
	move.tween_property(self, "position", p, step_time)
	var hop := create_tween()
	hop.tween_property(sprite, "position:y", _base_y + 0.12, step_time * 0.5) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	hop.tween_property(sprite, "position:y", _base_y, step_time * 0.5) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await move.finished


## เดินไปตามจุดทีละจุด (ใช้ await ได้)
func move_along(points: Array[Vector3], step_time := 0.3) -> void:
	begin_walk()
	for p in points:
		await step_to(p, step_time)
	end_walk()

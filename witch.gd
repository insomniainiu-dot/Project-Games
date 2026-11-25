class_name Witch
extends Node3D
## ตัวละครผู้เล่นแบบ HD-2D: สไปรต์พิกเซล 2D (Sprite3D) ที่ยืนอยู่ในโลก 3D
## (ชื่อคลาสยังเป็น Witch เพื่อไม่ต้องแก้โค้ดที่เรียกใช้ — ภาพเป็นตัว scout แล้ว)
## ใช้สไปรต์ชีต characters/scout_pixel/scout_sheet.png = 10 คอลัมน์ x 4 แถว (เฟรม 41x60)
##   แถว 0-3 : หันลง / ซ้าย / ขวา / ขึ้น
##   คอลัมน์ 0-3 : หายใจ (พัก, อกยก, หัวยกตาม, อกลง-หัวตามช้า)
##   คอลัมน์ 4-5 : ตาปิดครึ่ง, ตาปิดสนิท (วาดบนท่าพัก คอลัมน์ 0)
##   คอลัมน์ 6-9 : เดิน 4 เฟรม

enum Dir { DOWN, LEFT, RIGHT, UP }

const SHEET := "res://characters/scout_pixel/scout_sheet.png"
const COLS := 10
const ROWS := 4
const HEIGHT := 1.25 # ความสูงเฟรมในหน่วยโลก 3D (1 ช่อง = 1.0)
const FEET_PAD := 2  # พิกเซลว่างใต้เท้าในเฟรม
const WALK_FPS := 8.0
const WALK_COL := 6
const BLINK_HALF_COL := 4
const BLINK_SHUT_COL := 5

# ---- ปรับความมีชีวิตชีวาตรงนี้ ----
# ระยะเวลาของเฟรมหายใจ คอลัมน์ 0..3 (วินาที) รวม ~2.8 วิ/รอบ
const BREATH_TIMES := [1.2, 0.3, 1.0, 0.3]
const BLINK_HALF := 0.06      # ตาปิดครึ่ง (ขาลง/ขาขึ้น)
const BLINK_SHUT := 0.12      # ตาปิดสนิท
const BLINK_MIN := 2.0        # กระพริบตาทุก ๆ 2-5 วินาที
const BLINK_MAX := 5.0

var facing: Dir = Dir.DOWN
var walking := false
var sprite: Sprite3D
var _anim_time := 0.0
var _breath_col := 0
var _breath_left := 0.0
var _base_y := 0.0
var _blink_wait := 0.0
var _blink_t := -1.0 # < 0 = ไม่ได้กระพริบอยู่
var _double_blink := false


func _init() -> void:
	sprite = Sprite3D.new()
	sprite.texture = load(SHEET)
	sprite.hframes = COLS
	sprite.vframes = ROWS
	var frame_height := sprite.texture.get_height() / float(ROWS)
	sprite.pixel_size = HEIGHT / frame_height
	sprite.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y # หันเข้ากล้องเสมอ แต่ยืนตรง
	sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST # พิกเซลคม
	sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD # ทำให้เงาเป็นรูปตัวละคร
	sprite.shaded = true # รับแสงจากตะเกียง/แสงแดด
	sprite.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	# ยกขึ้นให้เท้าแตะพื้นที่จุด position
	_base_y = HEIGHT / 2.0 - FEET_PAD * sprite.pixel_size
	sprite.position.y = _base_y
	add_child(sprite)
	_blink_wait = randf_range(BLINK_MIN, BLINK_MAX)
	# สุ่มจังหวะหายใจเริ่มต้น ตัวละครหลายตัวจะได้ไม่หายใจพร้อมกัน
	_breath_col = randi() % BREATH_TIMES.size()
	_breath_left = randf() * float(BREATH_TIMES[_breath_col])
	_update_frame()


func _process(delta: float) -> void:
	if walking:
		_anim_time += delta
	else:
		_anim_time = 0.0
		_update_breathing(delta)
		_update_blink(delta)
	_update_frame()


func _update_frame() -> void:
	var row := int(facing) * COLS
	if walking:
		sprite.frame = row + WALK_COL + int(_anim_time * WALK_FPS) % 4
		return
	var col := _breath_col
	if _blink_t >= 0.0 and facing != Dir.UP:
		col = BLINK_SHUT_COL if _blink_t >= BLINK_HALF and _blink_t < BLINK_HALF + BLINK_SHUT else BLINK_HALF_COL
	sprite.frame = row + col


## หายใจด้วยเฟรมพิกเซล (อก/หัวขยับทีละ 1 px) — ไม่ยืดสไปรต์ พิกเซลเลยคม
func _update_breathing(delta: float) -> void:
	if _blink_t >= 0.0:
		return # ค้างท่าพักไว้ระหว่างกระพริบตา
	_breath_left -= delta
	if _breath_left <= 0.0:
		_breath_col = (_breath_col + 1) % BREATH_TIMES.size()
		_breath_left += float(BREATH_TIMES[_breath_col])


## กระพริบตาแบบสุ่ม บางครั้งกระพริบ 2 ครั้งติดกัน
## เฟรมกระพริบวาดบนท่าพัก จึงเริ่มกระพริบเฉพาะตอนหายใจอยู่ท่าพัก (คอลัมน์ 0)
func _update_blink(delta: float) -> void:
	if _blink_t >= 0.0:
		_blink_t += delta
		if _blink_t >= BLINK_HALF * 2.0 + BLINK_SHUT:
			_blink_t = -1.0
			if _double_blink:
				_double_blink = false
				_blink_wait = 0.12
			else:
				_blink_wait = randf_range(BLINK_MIN, BLINK_MAX)
		return
	_blink_wait -= delta
	if _blink_wait <= 0.0 and _breath_col == 0:
		_blink_t = 0.0
		if _double_blink == false:
			_double_blink = randf() < 0.25


func face_toward(direction: Vector3) -> void:
	if absf(direction.x) > absf(direction.z):
		facing = Dir.RIGHT if direction.x > 0 else Dir.LEFT
	elif direction.z != 0:
		facing = Dir.DOWN if direction.z > 0 else Dir.UP


## เริ่ม/จบการเดิน (ใช้ร่วมกับ step_to)
func begin_walk() -> void:
	walking = true
	_blink_t = -1.0
	sprite.position = Vector3(0, _base_y, 0)


func end_walk(face_camera := true) -> void:
	walking = false
	if face_camera:
		facing = Dir.DOWN # หยุดแล้วหันหน้าเข้ากล้อง
	_breath_col = 0
	_breath_left = float(BREATH_TIMES[0])
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

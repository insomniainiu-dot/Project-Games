class_name CutoutRig
extends Node2D
## ตัวละคร cutout / skeletal 2D (แนวเดียวกับ Spine): ชิ้นส่วนแยก + กระดูกหมุนได้
## วาดอยู่ใน SubViewport ความละเอียดต่ำ -> ออกมาเป็นพิกเซล แต่ขยับลื่นแบบอนิเมะ
## ตัวละคร placeholder: "Ryn" (Vanguard) วาดด้วย Polygon2D ล้วน เปลี่ยนเป็นรูปจริงทีละชิ้นได้ภายหลัง
##
## ท่าทาง = Dictionary { ชื่อ -> ค่า }:
##   องศากระดูก (torso, head, arm_*, sword, hips) + hips_x/hips_y (px) + foot_*_x/y (เป้าเท้า, IK)
##   ทิศองศา: 0 = ห้อยลง, ลบ = เหวี่ยงไปข้างหน้า, บวก = ไปข้างหลัง (ลำตัว/หัว: บวก = โน้มไปหน้า)

const VIEW := Vector2i(280, 240) # เผื่อที่ให้ดาบ/trail เหวี่ยงไม่ชนขอบ
const FEET := Vector2(140, 204) # จุดเท้าใน viewport (= ตำแหน่ง Node3D ในโลก)
const HIPS := Vector2(0, -49)
const LEG := 24.0 # ความยาวต้นขา = หน้าแข้ง

# ---- สี (ค่า > 1 = เรืองแสง เพราะ viewport เปิด HDR 2D) ----
const SKIN := Color(1.0, 0.84, 0.72)
const HAIR := Color(0.9, 0.92, 1.0)
const HAIR_SHADE := Color(0.6, 0.64, 0.82)
const COAT := Color(0.18, 0.22, 0.36)
const COAT_SHADE := Color(0.11, 0.13, 0.23)
const TRIM := Color(0.96, 0.72, 0.3)
const PANTS := Color(0.14, 0.14, 0.18)
const BOOT := Color(0.32, 0.23, 0.18)
const SCARF := Color(0.88, 0.16, 0.22)
const HILT := Color(0.32, 0.32, 0.38)
const BLADE := Color(0.5, 1.9, 2.7)
const BLADE_CORE := Color(2.4, 2.9, 3.1)
const EYE := Color(0.4, 2.0, 2.4)
const TRAIL := Color(0.55, 1.7, 2.6)

const ROT_BONES := ["hips", "torso", "head", "arm_b_up", "arm_b_lo", "arm_f_up", "arm_f_lo", "sword"]

const IDLE := {
	"hips_x": 0.0, "hips_y": 3.0, "hips": 0.0, "torso": 8.0, "head": -6.0,
	"arm_b_up": 25.0, "arm_b_lo": -35.0,
	"arm_f_up": -30.0, "arm_f_lo": -55.0, "sword": -45.0,
	"foot_f_x": 9.0, "foot_f_y": -3.0, "foot_b_x": -9.0, "foot_b_y": -3.0,
}

var mode := "idle" # idle / run / action (action = ท่าถูกคุมด้วย to_pose)
var facing := 1
var glow := 1.0 # ความสว่างดาบ (ชาร์จท่าไม้ตาย)
var trail_on := false
var move_velocity := Vector2.ZERO # ความเร็วตัวละครในโลก หน่วย px/s (ให้ผ้าปลิว/trail ค้างในโลก)
var pose: Dictionary = IDLE.duplicate()
var bones := {}

var _root: Node2D
var _blade: Polygon2D
var _blade_core: Polygon2D
var _scarf: Line2D
var _coat: Line2D
var _scarf_pts: Array[Vector2] = []
var _scarf_prev: Array[Vector2] = []
var _coat_pts: Array[Vector2] = []
var _coat_prev: Array[Vector2] = []
var _trail_node: Node2D
var _trail: Array = [] # [[อายุ, base, tip], ...]
var _time := 0.0
var _dt := 0.0
var _run_phase := 0.0
var _prev_dt := 1.0 / 60.0


func _init() -> void:
	_build()


# ================================================================ สร้างชิ้นส่วน
func _build() -> void:
	_root = Node2D.new()
	_root.position = FEET
	add_child(_root)
	var hips := _bone("hips", _root, HIPS)
	var torso := _bone("torso", hips, Vector2.ZERO)
	var head := _bone("head", torso, Vector2(1, -31))

	# --- ขา (หลังเข้ม / หน้าปกติ) คุมด้วย IK ---
	for side: String in ["b", "f"]:
		var shade := side == "b"
		var x := -3.0 if shade else 3.0
		var z := 4 if shade else 6
		var up := _bone("leg_%s_up" % side, hips, Vector2(x, 2))
		_part(up, _limb(LEG, 7, 6), _dark(PANTS, shade), z)
		var lo := _bone("leg_%s_lo" % side, up, Vector2(0, LEG))
		_part(lo, _circle(Vector2.ZERO, 3.2), _dark(PANTS, shade), z)
		_part(lo, _limb(10, 6, 6), _dark(PANTS, shade), z)
		_part(lo, _poly([Vector2(-3, 9), Vector2(3, 9), Vector2(2.6, LEG + 1), Vector2(-2.6, LEG + 1)]), _dark(BOOT, shade), z)
		var foot := _bone("foot_%s" % side, lo, Vector2(0, LEG))
		_part(foot, _poly([Vector2(-3, -1), Vector2(3, -1), Vector2(8, 2), Vector2(8, 3.5), Vector2(-3.5, 3.5)]), _dark(BOOT, shade), z)

	# --- ชายเสื้อหน้า (ติดสะโพก อยู่ระหว่างขาหลัง-ขาหน้า) ---
	_part(hips, _poly([Vector2(-9, -1), Vector2(9, -1), Vector2(11, 14), Vector2(4, 19), Vector2(-10, 13)]), COAT_SHADE, 5)

	# --- ลำตัว ---
	_part(torso, _poly([Vector2(-8, 2), Vector2(8, 2), Vector2(11, -25), Vector2(6, -31), Vector2(-6, -31), Vector2(-10, -25)]), COAT, 7)
	_part(torso, _poly([Vector2(3, -30), Vector2(6, -29), Vector2(5, 1), Vector2(2, 1)]), TRIM, 7)
	_part(torso, _poly([Vector2(-8.5, -3), Vector2(8.5, -3), Vector2(8.5, 0.5), Vector2(-8.5, 0.5)]), PANTS, 7)
	_part(torso, _poly([Vector2(2, -3.5), Vector2(6, -3.5), Vector2(6, 1), Vector2(2, 1)]), TRIM, 7)
	# ผ้าพันคอรอบคอ
	_part(torso, _poly([Vector2(-6, -33), Vector2(7, -33), Vector2(8, -27), Vector2(-7, -27)]), SCARF, 8)

	# --- หัว (หันขวา) ---
	_part(head, _poly([Vector2(-2.5, 1), Vector2(2.5, 1), Vector2(2.5, -4), Vector2(-2.5, -4)]), SKIN, 9)
	_part(head, _circle(Vector2(1, -11), 9.5, 14), SKIN, 9)
	_part(head, _poly([Vector2(5, -9), Vector2(7.5, -9), Vector2(7.5, -5.5), Vector2(5, -5.5)]), EYE, 10)
	_part(head, _poly([Vector2(4, -11), Vector2(8.5, -11.5), Vector2(8.5, -10.3), Vector2(4, -10)]), HAIR_SHADE, 10)
	_part(head, _poly([
		Vector2(10, -9), Vector2(11, -15), Vector2(7, -20), Vector2(1, -22), Vector2(-5, -21), Vector2(-9, -18),
		Vector2(-17, -21), Vector2(-11, -14), Vector2(-18, -12), Vector2(-11, -9), Vector2(-15, -4), Vector2(-9, -4),
		Vector2(-7, -1), Vector2(-4, -6), Vector2(1, -12), Vector2(3, -9), Vector2(5.5, -13), Vector2(8, -9.5),
	]), HAIR, 10)
	_part(head, _poly([Vector2(-9, -18), Vector2(-17, -21), Vector2(-11, -14), Vector2(-6, -15)]), HAIR_SHADE, 10)

	# --- แขน ---
	for side: String in ["b", "f"]:
		var shade := side == "b"
		var z := 3 if shade else 11
		var up := _bone("arm_%s_up" % side, torso, Vector2(-3 if shade else 3, -27))
		_part(up, _circle(Vector2.ZERO, 4.0), _dark(COAT, shade), z)
		_part(up, _limb(15, 6, 5), _dark(COAT, shade), z)
		_part(up, _poly([Vector2(-4, -3), Vector2(4, -3), Vector2(4, 2), Vector2(-4, 2)]), _dark(TRIM, shade), z)
		var lo := _bone("arm_%s_lo" % side, up, Vector2(0, 15))
		_part(lo, _circle(Vector2.ZERO, 2.6), _dark(COAT, shade), z)
		_part(lo, _limb(14, 5, 4), _dark(COAT, shade), z)
		_part(lo, _circle(Vector2(0, 14), 3.0), _dark(PANTS, shade), z + 2) # ถุงมือ (ทับด้ามดาบ)

	# --- ดาบพลาสมา (ใบดาบชี้ตาม +y ของกระดูก sword) ---
	var sword := _bone("sword", bones["arm_f_lo"], Vector2(0, 14))
	_part(sword, _poly([Vector2(-1.5, -5), Vector2(1.5, -5), Vector2(1.5, 4), Vector2(-1.5, 4)]), HILT, 12)
	_part(sword, _poly([Vector2(-5, 4), Vector2(5, 4), Vector2(5, 6.5), Vector2(-5, 6.5)]), TRIM, 12)
	_blade = _part(sword, _poly([Vector2(-2.6, 6.5), Vector2(2.6, 6.5), Vector2(2.2, 46), Vector2(0, 53), Vector2(-2.2, 46)]), BLADE, 12)
	_blade_core = _part(sword, _poly([Vector2(-0.8, 8), Vector2(0.8, 8), Vector2(0.6, 45), Vector2(-0.6, 45)]), BLADE_CORE, 12)

	# --- ผ้าพันคอ + ชายเสื้อหลัง: เส้นที่มีฟิสิกส์สปริง ---
	_scarf = _chain_line(5.0, SCARF, 2)
	_coat = _chain_line(10.0, COAT_SHADE, 1)
	for i in 7:
		_scarf_pts.append(Vector2.ZERO)
		_scarf_prev.append(Vector2.ZERO)
	for i in 4:
		_coat_pts.append(Vector2.ZERO)
		_coat_prev.append(Vector2.ZERO)

	# --- smear trail ของดาบ ---
	_trail_node = Node2D.new()
	_trail_node.z_index = 14
	_trail_node.z_as_relative = false
	_trail_node.draw.connect(_draw_trail)
	add_child(_trail_node)


func _ready() -> void:
	_apply_pose()
	_reset_chains() # ต้องอยู่ใน tree ก่อน ถึงจะใช้ to_global ได้


func _bone(bone_name: String, parent: Node2D, pos: Vector2) -> Node2D:
	var b := Node2D.new()
	b.name = bone_name
	b.position = pos
	parent.add_child(b)
	bones[bone_name] = b
	return b


func _part(parent: Node2D, pts: PackedVector2Array, color: Color, z: int) -> Polygon2D:
	var p := Polygon2D.new()
	p.polygon = pts
	p.color = color
	p.z_index = z
	p.z_as_relative = false
	parent.add_child(p)
	return p


func _chain_line(width: float, color: Color, z: int) -> Line2D:
	var l := Line2D.new()
	l.width = width
	l.default_color = color
	var curve := Curve.new()
	curve.add_point(Vector2(0, 1))
	curve.add_point(Vector2(1, 0.45))
	l.width_curve = curve
	l.joint_mode = Line2D.LINE_JOINT_ROUND
	l.z_index = z
	l.z_as_relative = false
	add_child(l)
	return l


static func _poly(pts: Array) -> PackedVector2Array:
	return PackedVector2Array(pts)


static func _limb(length: float, w0: float, w1: float) -> PackedVector2Array:
	return PackedVector2Array([Vector2(-w0 / 2, -1), Vector2(w0 / 2, -1), Vector2(w1 / 2, length + 1), Vector2(-w1 / 2, length + 1)])


static func _circle(c: Vector2, r: float, n := 10) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in n:
		pts.append(c + Vector2(r, 0).rotated(TAU * i / n))
	return pts


static func _dark(c: Color, shade: bool) -> Color:
	return c.darkened(0.32) if shade else c


# ================================================================ ทุกเฟรม
func _process(delta: float) -> void:
	_dt = delta
	_time += delta
	if mode != "action":
		var target := _procedural()
		var k := 1.0 - exp(-delta * 14.0)
		for key in target:
			pose[key] = lerpf(pose[key], target[key], k)
	_apply_pose()
	var g := glow
	_blade.color = Color(BLADE.r * g, BLADE.g * g, BLADE.b * g)
	_blade_core.color = Color(BLADE_CORE.r * g, BLADE_CORE.g * g, BLADE_CORE.b * g)
	_update_chains(delta)
	_update_trail(delta)


## ท่ายืน/วิ่งแบบคำนวณ (ไม่ต้องทำ keyframe)
func _procedural() -> Dictionary:
	var p: Dictionary = IDLE.duplicate()
	if mode == "run":
		_run_phase += _dt * 12.0
		var s := sin(_run_phase)
		var c := cos(_run_phase)
		p["hips_y"] = 3.0 - absf(c) * 4.0 # ตัวยกสูงตอนขาสวนกัน
		p["torso"] = 18.0 + absf(c) * 2.0
		p["head"] = -12.0
		p["foot_f_x"] = s * 15.0
		p["foot_f_y"] = -3.0 - maxf(0.0, c) * 9.0
		p["foot_b_x"] = -s * 15.0
		p["foot_b_y"] = -3.0 - maxf(0.0, -c) * 9.0
		p["arm_b_up"] = -s * 40.0
		p["arm_b_lo"] = -50.0
		p["arm_f_up"] = 35.0 + s * 8.0 # มือถือดาบลากไปข้างหลัง
		p["arm_f_lo"] = -25.0
		p["sword"] = 70.0
	else:
		var b := sin(_time * 2.4)
		p["torso"] += b * 1.5
		p["hips_y"] += (b * 0.5 + 0.5)
		p["arm_f_up"] += b * 2.0
		p["arm_b_up"] -= b * 2.0
		p["head"] += sin(_time * 1.3) * 1.5
		p["sword"] += sin(_time * 1.7) * 2.0
	return p


func _apply_pose() -> void:
	_root.scale.x = facing
	var hips: Node2D = bones["hips"]
	hips.position = HIPS + Vector2(pose["hips_x"], pose["hips_y"])
	for b in ROT_BONES:
		(bones[b] as Node2D).rotation_degrees = pose[b]
	_solve_leg("b", Vector2(-3, 2), Vector2(pose["foot_b_x"], pose["foot_b_y"]))
	_solve_leg("f", Vector2(3, 2), Vector2(pose["foot_f_x"], pose["foot_f_y"]))


## IK 2 กระดูก: หาองศาต้นขา/หน้าแข้งให้ข้อเท้าไปถึงเป้า (เข่างอไปข้างหน้าเสมอ) แล้วเท้าวางขนานพื้น
func _solve_leg(side: String, hip_local: Vector2, target: Vector2) -> void:
	var hips: Node2D = bones["hips"]
	var h := hips.position + hip_local.rotated(hips.rotation)
	var v := target - h
	var d := clampf(v.length(), 4.0, LEG * 2.0 - 0.01)
	var base := atan2(-v.x, v.y)
	var a := acos(clampf(d / (2.0 * LEG), -1.0, 1.0))
	var knee := PI - acos(clampf((2.0 * LEG * LEG - d * d) / (2.0 * LEG * LEG), -1.0, 1.0))
	var thigh := base - a
	(bones["leg_%s_up" % side] as Node2D).rotation = thigh - hips.rotation
	(bones["leg_%s_lo" % side] as Node2D).rotation = knee
	(bones["foot_%s" % side] as Node2D).rotation = -(thigh + knee)


# ================================================================ เล่นท่า
## เปลี่ยนท่าแบบ tween (ใช้ await ได้) — EXPO/OUT = ฟันฉับ, BACK/OUT = เลยแล้วเด้งกลับ
func to_pose(target: Dictionary, dur: float, trans := Tween.TRANS_QUAD, ease_type := Tween.EASE_OUT) -> void:
	var from: Dictionary = pose.duplicate()
	var apply := func(t: float) -> void:
		for key in target:
			pose[key] = lerpf(from[key], target[key], t)
	var tw := create_tween()
	tw.tween_method(apply, 0.0, 1.0, dur).set_trans(trans).set_ease(ease_type)
	await tw.finished


## ท่า = IDLE + ค่าที่เปลี่ยน
static func make_pose(over: Dictionary) -> Dictionary:
	var d: Dictionary = IDLE.duplicate()
	d.merge(over, true)
	return d


## จุดบนใบดาบ (0 = โคน, 1 = ปลาย) ในพิกัด viewport
func blade_point(t: float) -> Vector2:
	var sword: Node2D = bones["sword"]
	return to_local(sword.to_global(Vector2(0, lerpf(8.0, 53.0, t))))


# ================================================================ ผ้า / ชายเสื้อ (สปริง verlet)
func _reset_chains() -> void:
	for i in _scarf_pts.size():
		_scarf_pts[i] = _scarf_anchor() + Vector2(-facing * 5.0 * i, 2.0 * i)
		_scarf_prev[i] = _scarf_pts[i]
	for i in _coat_pts.size():
		_coat_pts[i] = _coat_anchor() + Vector2(-facing * 2.0 * i, 5.0 * i)
		_coat_prev[i] = _coat_pts[i]


func _scarf_anchor() -> Vector2:
	return to_local((bones["torso"] as Node2D).to_global(Vector2(-4, -29)))


func _coat_anchor() -> Vector2:
	return to_local((bones["hips"] as Node2D).to_global(Vector2(-6, 0)))


func _update_chains(delta: float) -> void:
	if delta <= 0.0:
		return # hitstop: ผ้าค้างกลางอากาศ
	var dt := minf(delta, 1.0 / 30.0) # เฟรมแรกช้า ๆ ไม่ให้ผ้าดีดกระเด็น
	var flutter := Vector2(-facing * (160.0 + sin(_time * 7.0) * 90.0), sin(_time * 11.0) * 60.0)
	_sim_chain(_scarf_pts, _scarf_prev, _scarf_anchor(), 5.5, dt, Vector2(0, 500) + flutter)
	_sim_chain(_coat_pts, _coat_prev, _coat_anchor(), 5.0, dt, Vector2(0, 800) + flutter * 0.3)
	_scarf.points = PackedVector2Array(_scarf_pts)
	_coat.points = PackedVector2Array(_coat_pts)
	_prev_dt = dt


## verlet แบบชดเชย dt (ผลเท่ากันทุก FPS) + หน่วงตามเวลา
func _sim_chain(pts: Array[Vector2], prev: Array[Vector2], anchor: Vector2, seg: float, dt: float, accel: Vector2) -> void:
	var shift := -move_velocity * dt # ตัวละครวิ่ง = ผ้าค้างอยู่ในโลก -> ลากตามหลัง
	var keep := exp(-5.0 * dt) * dt / _prev_dt
	pts[0] = anchor
	prev[0] = anchor
	for i in range(1, pts.size()):
		var p := pts[i] + shift
		var vel := (pts[i] - prev[i]) * keep
		prev[i] = p
		pts[i] = p + vel + accel * dt * dt
	for _iter in 3:
		for i in range(1, pts.size()):
			var d := pts[i] - pts[i - 1]
			var l := d.length()
			if l > 0.0001:
				pts[i] = pts[i - 1] + d / l * seg


# ================================================================ smear trail
func _update_trail(delta: float) -> void:
	var life := 0.11
	var shift := -move_velocity * delta
	for e in _trail:
		e[0] += delta
		e[1] += shift
		e[2] += shift
	while _trail.size() > 0 and _trail[0][0] > life:
		_trail.pop_front()
	if trail_on and delta > 0.0:
		_trail.append([0.0, blade_point(0.15), blade_point(1.0)])
	_trail_node.queue_redraw()


## วาดเป็นสามเหลี่ยมทีละคู่ (draw_primitive ไม่ต้อง triangulate จึงไม่พังตอนเส้นไขว้)
func _draw_trail() -> void:
	if _trail.size() < 2:
		return
	var life := 0.11
	var pts: Array[PackedVector2Array] = []
	for e in _trail:
		var fade := clampf(1.0 - e[0] / life, 0.0, 1.0)
		var tip: Vector2 = e[2]
		var base: Vector2 = tip.lerp(e[1], fade) # อันเก่าเรียวลงเข้าหาปลายดาบ
		pts.append(PackedVector2Array([base, tip]))
	var col := PackedColorArray([TRAIL, TRAIL, TRAIL])
	for i in pts.size() - 1:
		var a := pts[i]
		var b := pts[i + 1]
		_trail_node.draw_primitive(PackedVector2Array([a[0], a[1], b[1]]), col, PackedVector2Array())
		_trail_node.draw_primitive(PackedVector2Array([a[0], b[1], b[0]]), col, PackedVector2Array())

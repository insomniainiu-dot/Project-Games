class_name CutoutCharacter
extends Node3D
## ตัวละคร cutout 2D (CutoutRig) ที่ยืนในโลก 3D แบบ HD-2D
##   rig วาดลง SubViewport ความละเอียดต่ำ -> แปะบน quad billboard ที่รับแสง/ทอดเงา
##   shader: ตัดขอบพิกเซล, เส้นขอบเข้ม, สี > 1 ในรูป = เรืองแสง (ดาบ/ตา/trail ติด Glow)
##
##   var hero := CutoutCharacter.new(); add_child(hero)
##   hero.move(dir, delta)       # เดิน/วิ่ง
##   hero.attack()               # คอมโบ 3 จังหวะ
##   await hero.finisher(target) # ท่าไม้ตาย
##   hero.cue.connect(...)       # จังหวะให้ฉากทำกล้อง/เอฟเฟกต์ (focus, hit, launch, cutin, plunge, slam, end)

signal cue(cue_name: String, strength: float)

const PIXEL := 0.0135 # ขนาด 1 พิกเซลของ rig ในโลก 3D (ตัวสูง ~100px = ~1.35 หน่วย)
const SPEED := 3.0
const COMBO_RESET := 0.7

# ---- ท่าคอมโบ (หันขวา) ----
var WIND_1 := CutoutRig.make_pose({"torso": -8.0, "head": -4.0, "arm_f_up": 160.0, "arm_f_lo": -30.0, "sword": 30.0,
	"arm_b_up": -40.0, "arm_b_lo": -40.0, "hips_x": -3.0, "hips_y": 5.0, "foot_f_x": 12.0, "foot_b_x": -12.0})
var STRIKE_1 := CutoutRig.make_pose({"torso": 28.0, "head": 10.0, "arm_f_up": -70.0, "arm_f_lo": -20.0, "sword": 2.0,
	"arm_b_up": 50.0, "arm_b_lo": -20.0, "hips_x": 8.0, "hips_y": 8.0, "foot_f_x": 20.0, "foot_b_x": -16.0})
var WIND_2 := CutoutRig.make_pose({"torso": 20.0, "arm_f_up": 40.0, "arm_f_lo": -10.0, "sword": 20.0,
	"hips_x": 6.0, "hips_y": 8.0, "foot_f_x": 18.0, "foot_b_x": -16.0})
var STRIKE_2 := CutoutRig.make_pose({"torso": -15.0, "head": -10.0, "arm_f_up": -165.0, "arm_f_lo": -10.0, "sword": -10.0,
	"arm_b_up": 30.0, "hips_y": 0.0, "foot_f_x": 14.0, "foot_b_x": -12.0})
var WIND_3 := CutoutRig.make_pose({"torso": -5.0, "arm_f_up": 50.0, "arm_f_lo": -80.0, "sword": -55.0,
	"hips_x": -4.0, "hips_y": 5.0, "foot_f_x": 12.0, "foot_b_x": -12.0})
var STRIKE_3 := CutoutRig.make_pose({"torso": 25.0, "arm_f_up": -85.0, "arm_f_lo": -25.0, "sword": -5.0,
	"arm_b_up": 45.0, "hips_x": 12.0, "hips_y": 7.0, "foot_f_x": 24.0, "foot_b_x": -14.0})

# ---- ท่าไม้ตาย "Starfall Edge" ----
var CROUCH := CutoutRig.make_pose({"torso": 35.0, "head": 15.0, "arm_f_up": 70.0, "arm_f_lo": -20.0, "sword": 60.0,
	"arm_b_up": -60.0, "arm_b_lo": -30.0, "hips_y": 14.0, "foot_f_x": 18.0, "foot_b_x": -18.0})
var DASH := CutoutRig.make_pose({"torso": 20.0, "arm_f_up": -90.0, "arm_f_lo": -10.0, "sword": -30.0,
	"arm_b_up": 70.0, "hips_x": 10.0, "hips_y": 9.0, "foot_f_x": 22.0, "foot_b_x": -20.0})
var REVERSE := CutoutRig.make_pose({"torso": -5.0, "arm_f_up": 120.0, "arm_f_lo": -20.0, "sword": 10.0,
	"arm_b_up": -30.0, "hips_y": 7.0, "foot_f_x": 16.0, "foot_b_x": -16.0})
var SPIN := CutoutRig.make_pose({"torso": 30.0, "head": 8.0, "arm_f_up": -50.0, "arm_f_lo": -20.0, "sword": -30.0,
	"arm_b_up": 60.0, "hips_x": 8.0, "hips_y": 10.0, "foot_f_x": 20.0, "foot_b_x": -18.0})
var UPPER := CutoutRig.make_pose({"torso": -20.0, "head": -15.0, "arm_f_up": -170.0, "arm_f_lo": -10.0, "sword": -10.0,
	"arm_b_up": 40.0, "hips_y": -4.0, "foot_f_x": 6.0, "foot_f_y": -14.0, "foot_b_x": -6.0, "foot_b_y": -8.0})
var AIR := CutoutRig.make_pose({"torso": 10.0, "head": -10.0, "arm_f_up": 175.0, "arm_f_lo": -20.0, "sword": 0.0,
	"arm_b_up": -150.0, "arm_b_lo": -20.0, "hips_y": -2.0, "foot_f_x": 4.0, "foot_f_y": -18.0, "foot_b_x": -8.0, "foot_b_y": -12.0})
var PLUNGE := CutoutRig.make_pose({"torso": 40.0, "head": 20.0, "arm_f_up": -40.0, "arm_f_lo": -10.0, "sword": 10.0,
	"arm_b_up": 80.0, "hips_y": 6.0, "foot_f_x": 10.0, "foot_f_y": -10.0, "foot_b_x": -10.0, "foot_b_y": -4.0})
var LAND := CutoutRig.make_pose({"torso": 45.0, "head": 18.0, "arm_f_up": -50.0, "arm_f_lo": -10.0, "sword": 20.0,
	"arm_b_up": 70.0, "arm_b_lo": -30.0, "hips_y": 16.0, "foot_f_x": 18.0, "foot_b_x": -18.0})
var FLOURISH := CutoutRig.make_pose({"torso": 5.0, "arm_f_up": -60.0, "arm_f_lo": -30.0, "sword": -90.0, "hips_y": 2.0})

var rig: CutoutRig
var viewport: SubViewport
var quad: MeshInstance3D
var busy := false
var _blade_light: OmniLight3D
var _last_pos := Vector3.ZERO
var _combo := 0
var _since_attack := 99.0


func _ready() -> void:
	viewport = SubViewport.new()
	viewport.size = CutoutRig.VIEW
	viewport.transparent_bg = true
	viewport.use_hdr_2d = true # ให้สี > 1 ผ่านไปถึง shader 3D (= เรืองแสง)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(viewport)
	rig = CutoutRig.new()
	viewport.add_child(rig)

	quad = MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(CutoutRig.VIEW) * PIXEL
	q.center_offset = Vector3(0, (CutoutRig.FEET.y - CutoutRig.VIEW.y * 0.5) * PIXEL, 0) # เท้าอยู่ที่ y = 0
	quad.mesh = q
	var m := ShaderMaterial.new()
	m.shader = Shader.new()
	m.shader.code = SHADER
	m.set_shader_parameter("tex", viewport.get_texture())
	quad.material_override = m
	quad.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	add_child(quad)

	_blade_light = OmniLight3D.new()
	_blade_light.light_color = Color(0.4, 0.85, 1.0)
	_blade_light.omni_range = 1.8
	add_child(_blade_light)
	_last_pos = global_position


func _process(delta: float) -> void:
	_since_attack += delta
	if delta > 0.0:
		var vel := (global_position - _last_pos) / delta
		rig.move_velocity = Vector2(vel.x, -vel.y) / PIXEL
	_last_pos = global_position
	_blade_light.position = to_world(rig.blade_point(0.6)) + Vector3(0, 0, 0.15)
	_blade_light.light_energy = 0.35 * rig.glow * rig.glow


## พิกัด viewport ของ rig -> พิกัด local 3D (ประมาณ: billboard หันเข้ากล้องที่อยู่ทาง +z)
func to_world(p: Vector2) -> Vector3:
	return Vector3((p.x - CutoutRig.FEET.x) * PIXEL, (CutoutRig.FEET.y - p.y) * PIXEL, 0)


func set_facing(dir: int) -> void:
	rig.facing = dir


# ================================================================ เดิน
func move(dir: Vector3, delta: float) -> void:
	if busy:
		return
	if dir == Vector3.ZERO:
		rig.mode = "idle"
		return
	rig.mode = "run"
	if absf(dir.x) > 0.01:
		rig.facing = 1 if dir.x > 0.0 else -1
	position += dir.normalized() * SPEED * delta


# ================================================================ คอมโบ
func attack() -> void:
	if busy:
		return
	if _since_attack > COMBO_RESET:
		_combo = 0
	busy = true
	rig.mode = "action"
	var step := _combo % 3
	_combo += 1
	var wind: Dictionary = [WIND_1, WIND_2, WIND_3][step]
	var strike: Dictionary = [STRIKE_1, STRIKE_2, STRIKE_3][step]
	await rig.to_pose(wind, 0.1, Tween.TRANS_QUAD, Tween.EASE_OUT) # ง้าง (anticipation)
	rig.trail_on = true
	_slide(0.25 + 0.1 * step, 0.08)
	await rig.to_pose(strike, 0.07, Tween.TRANS_EXPO, Tween.EASE_OUT) # ฟันฉับ
	cue.emit("hit", 1.0 + 0.3 * step)
	await _wait(0.06)
	rig.trail_on = false
	await _wait(0.12) # ค้างท่า (follow-through) ให้ตาอ่านทัน
	_since_attack = 0.0
	busy = false
	rig.mode = "idle"


# ================================================================ ท่าไม้ตาย
## ท่าไม้ตาย: ย่อ -> ชาร์จ -> พุ่งฟัน 3 ครั้ง -> ฟันงัดขึ้น -> ลอยค้าง (cut-in) -> ทิ่มลงกระแทกพื้น
func finisher(target: Vector3) -> void:
	if busy:
		return
	busy = true
	rig.mode = "action"
	rig.facing = 1 if target.x >= position.x else -1
	var f := float(rig.facing)

	cue.emit("focus", 0.0)
	await rig.to_pose(CROUCH, 0.28, Tween.TRANS_BACK, Tween.EASE_OUT)
	cue.emit("charge", 0.0)
	var charge := create_tween()
	charge.tween_property(rig, "glow", 2.2, 0.35)
	await _wait(0.38)

	rig.trail_on = true
	_slide_to(Vector3(target.x - 0.85 * f, 0, target.z), 0.09)
	await rig.to_pose(DASH, 0.08, Tween.TRANS_EXPO, Tween.EASE_OUT)
	cue.emit("hit", 1.0)
	await rig.to_pose(REVERSE, 0.09, Tween.TRANS_EXPO, Tween.EASE_OUT)
	cue.emit("hit", 1.0)
	await rig.to_pose(SPIN, 0.09, Tween.TRANS_EXPO, Tween.EASE_OUT)
	cue.emit("hit", 1.5)

	var rise := create_tween()
	rise.tween_property(self, "position:y", 1.7, 0.24).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	await rig.to_pose(UPPER, 0.1, Tween.TRANS_EXPO, Tween.EASE_OUT)
	cue.emit("launch", 1.5)
	await rig.to_pose(AIR, 0.22, Tween.TRANS_SINE, Tween.EASE_OUT)
	rig.trail_on = false
	cue.emit("cutin", 0.0)
	await _wait(0.24) # เวลานี้ถูก slow-mo ยืดออก (ฉากคุม Engine.time_scale)

	cue.emit("plunge", 0.0)
	rig.trail_on = true
	var fall := create_tween()
	fall.tween_property(self, "position:y", 0.0, 0.11).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await rig.to_pose(PLUNGE, 0.11, Tween.TRANS_EXPO, Tween.EASE_OUT)
	if fall.is_running():
		await fall.finished
	await rig.to_pose(LAND, 0.05, Tween.TRANS_EXPO, Tween.EASE_OUT)
	cue.emit("slam", 3.0)
	rig.trail_on = false
	var cool := create_tween()
	cool.tween_property(rig, "glow", 1.0, 0.6)
	await _wait(0.4)
	await rig.to_pose(FLOURISH, 0.22, Tween.TRANS_BACK, Tween.EASE_OUT) # สะบัดดาบ
	await _wait(0.15)
	cue.emit("end", 0.0)
	busy = false
	rig.mode = "idle"


func _slide(dist: float, dur: float) -> void:
	var tw := create_tween()
	tw.tween_property(self, "position:x", position.x + dist * rig.facing, dur).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)


func _slide_to(p: Vector3, dur: float) -> void:
	var tw := create_tween()
	tw.tween_property(self, "position", p, dur).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)


func _wait(t: float) -> void:
	await get_tree().create_timer(t, false).timeout # ตาม time_scale (hitstop/slow-mo ยืดเวลาให้เอง)


const SHADER := """
shader_type spatial;
render_mode cull_disabled, diffuse_lambert_wrap;

uniform sampler2D tex : filter_nearest;
uniform vec3 outline_color = vec3(0.05, 0.04, 0.07);

bool solid(vec2 uv) {
	vec4 c = texture(tex, uv);
	return c.a > 0.5 && max(c.r, max(c.g, c.b)) < 1.2; // เส้นขอบไม่ล้อมส่วนที่เรืองแสง
}

void vertex() {
	// billboard แกน Y (ยืนตรง หันเข้ากล้อง) แบบเดียวกับ Sprite3D
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(
		vec4(normalize(cross(vec3(0.0, 1.0, 0.0), INV_VIEW_MATRIX[2].xyz)), 0.0),
		vec4(0.0, 1.0, 0.0, 0.0),
		vec4(normalize(cross(INV_VIEW_MATRIX[0].xyz, vec3(0.0, 1.0, 0.0))), 0.0),
		MODEL_MATRIX[3]);
	MODELVIEW_NORMAL_MATRIX = mat3(MODELVIEW_MATRIX);
}

void fragment() {
	vec2 px = 1.0 / vec2(textureSize(tex, 0));
	vec4 c = texture(tex, UV);
	vec3 col = c.rgb;
	if (c.a < 0.5) {
		bool edge = solid(UV + vec2(px.x, 0.0)) || solid(UV - vec2(px.x, 0.0))
			|| solid(UV + vec2(0.0, px.y)) || solid(UV - vec2(0.0, px.y));
		if (!edge) {
			discard;
		}
		col = outline_color;
	}
	ALBEDO = min(col, vec3(1.0));
	EMISSION = max(col - vec3(1.0), vec3(0.0)) * 1.5;
	ROUGHNESS = 0.85;
}
"""

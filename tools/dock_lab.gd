extends Node3D
## Dock Lab: ฉาก sci-fi "Dock 07" + ตัวละคร cutout "Ryn" (ท่าทางลื่นแบบ skeletal 2D อนิเมะ)
##   เปิด: Godot --path . res://tools/dock_lab.tscn
##   ถ่ายรูปแล้วปิด: Godot --path . res://tools/dock_lab.tscn -- shot=<ไฟล์.png>
##
## ปุ่ม: A/D (W/S) เดิน   J = คอมโบ 3 จังหวะ   K = ท่าไม้ตาย Starfall Edge
## ฉากนี้เป็นผู้กำกับ: รับ cue จากตัวละครแล้วทำกล้องซูม, hitstop, slow-mo, จอสั่น, cut-in, แสงวาบ

const AREA := Rect2(-6.0, -1.2, 12.5, 4.2) # ขอบเขตเดิน (x, z)
const VIEW_W := 1152.0
const VIEW_H := 648.0

const SPEEDLINE_SHADER := """
shader_type canvas_item;
uniform float amount = 0.0;
float hash(float n) { return fract(sin(n) * 43758.5453); }
void fragment() {
	vec2 p = UV - 0.5;
	p.x *= 1.78;
	float rays = 110.0;
	float u = (atan(p.y, p.x) / 6.2831 + 0.5) * rays;
	float id = floor(u);
	float h = hash(id + floor(TIME * 20.0) * 17.0);
	float inner = 0.3 + h * 0.25;
	float thin = 1.0 - abs(fract(u) - 0.5) * 2.0;
	float a = step(0.5, h) * smoothstep(inner, inner + 0.3, length(p)) * smoothstep(0.35, 1.0, thin);
	COLOR = vec4(0.85, 0.95, 1.0, a * amount);
}
"""

var lighting: SceneLighting
var env: Environment
var sun: DirectionalLight3D
var hero: CutoutCharacter
var focus: Node3D
var dummy: Node3D
var dummy_core: MeshInstance3D
var dummy_mat: StandardMaterial3D
var dummy_home := Vector3(1.8, 0, 0.6)

var _bar_top: ColorRect
var _bar_bottom: ColorRect
var _flash: ColorRect
var _speed: ShaderMaterial
var _cutin: Node2D
var _shake := 0.0
var _focus_mix := 0.0
var _base_scale := 1.0
var _ticks := 0
var _time := 0.0
var _auto_dir := Vector3.ZERO # ใช้ตอนถ่ายรูปอัตโนมัติ
var _hit_count := 0
var _base_exposure := 1.0


func _ready() -> void:
	lighting = SceneLighting.new()
	add_child(lighting)
	lighting.build()
	for c in lighting.get_children():
		if c is WorldEnvironment:
			env = (c as WorldEnvironment).environment
		elif c is DirectionalLight3D:
			sun = c
		elif c is MeshInstance3D:
			c.visible = false # ซ่อนพื้นหญ้า ใช้พื้นเหล็กแทน
	_style_environment()
	_build_set()
	_build_dummy()

	hero = CutoutCharacter.new()
	hero.position = Vector3(-2.5, 0, 0.6)
	add_child(hero)
	hero.cue.connect(_on_cue)
	focus = Node3D.new()
	add_child(focus)
	focus.position = hero.position
	lighting.follow(focus)

	_build_fx_ui()
	_ticks = Time.get_ticks_msec()
	_maybe_screenshot()


# ================================================================ บรรยากาศ
## พลบค่ำในอู่จอดยาน: แดดส้มต่ำ + ไฟนีออนฟ้า/ชมพู + พื้นเหล็กสะท้อน (SSR)
func _style_environment() -> void:
	env.background_color = Color(0.03, 0.03, 0.06)
	env.ambient_light_color = Color(0.35, 0.42, 0.65)
	env.ambient_light_energy = 0.55
	env.fog_light_color = Color(0.25, 0.3, 0.45)
	env.volumetric_fog_albedo = Color(0.7, 0.8, 1.0)
	env.volumetric_fog_density = 0.03
	env.ssr_enabled = true
	env.ssr_max_steps = 48
	env.adjustment_saturation = 1.15
	_base_exposure = env.tonemap_exposure
	sun.light_color = Color(1.0, 0.55, 0.4)
	sun.light_energy = 0.75
	sun.rotation_degrees = Vector3(-28, 35, 0)


func _build_set() -> void:
	var steel := MeshFactory.mat("stone", Color(0.32, 0.36, 0.44))
	steel.uv1_scale = Vector3(1.5, 1.5, 1.5)
	steel.metallic = 0.6
	steel.roughness = 0.3
	var dark_steel := MeshFactory.mat("wall", Color(0.26, 0.28, 0.35))
	dark_steel.uv1_scale = Vector3(2, 2, 2)
	var cyan := Color(0.3, 0.9, 1.0)
	var pink := Color(1.0, 0.25, 0.65)

	# พื้นดาดฟ้า + เส้นไฟนำทาง + แถบเตือนเหลือง-ดำ
	add_child(MeshFactory.box(Vector3(28, 0.1, 18), Vector3(0, -0.05, -1), steel))
	for z in [-1.6, 2.6]:
		add_child(MeshFactory.box(Vector3(26, 0.012, 0.06), Vector3(0, 0.006, z), MeshFactory.glow_mat(cyan, 2.0)))
	var yellow := MeshFactory.mat("stone", Color(0.95, 0.72, 0.12))
	var black := MeshFactory.mat("stone", Color(0.08, 0.08, 0.1))
	var i := 0
	for x in range(-20, 21):
		add_child(MeshFactory.box(Vector3(0.3, 0.012, 0.25), Vector3(x * 0.3, 0.006, -3.3), yellow if i % 2 == 0 else black))
		i += 1

	# ผนังโรงจอดยาน + ซี่โครงเหล็ก + หน้าต่างเรืองแสง
	add_child(MeshFactory.box(Vector3(28, 4.5, 0.4), Vector3(0, 2.25, -4.6), dark_steel))
	for x in range(-12, 13, 3):
		add_child(MeshFactory.box(Vector3(0.25, 4.5, 0.3), Vector3(x, 2.25, -4.35), steel))
	add_child(MeshFactory.box(Vector3(26, 0.22, 0.05), Vector3(0, 3.9, -4.37), MeshFactory.glow_mat(Color(0.45, 0.7, 1.0), 1.6)))

	# ประตูใหญ่กรอบนีออนชมพู + ป้ายโฮโลแกรม
	var door := StandardMaterial3D.new()
	door.albedo_color = Color(0.05, 0.05, 0.08)
	door.metallic = 0.5
	add_child(MeshFactory.box(Vector3(3, 2.6, 0.05), Vector3(0, 1.3, -4.37), door))
	add_child(MeshFactory.box(Vector3(3.2, 0.08, 0.06), Vector3(0, 2.65, -4.34), MeshFactory.glow_mat(pink, 3.0)))
	for side in [-1, 1]:
		add_child(MeshFactory.box(Vector3(0.08, 2.6, 0.06), Vector3(side * 1.6, 1.3, -4.34), MeshFactory.glow_mat(pink, 3.0)))
	_light(Vector3(0, 1.5, -3.7), pink, 1.6, 4.0)
	var sign_label := Label3D.new()
	sign_label.text = "DOCK 07"
	sign_label.font_size = 96
	sign_label.pixel_size = 0.006
	sign_label.outline_size = 0
	sign_label.modulate = Color(0.6, 1.7, 2.2)
	sign_label.position = Vector3(0, 3.15, -4.3)
	add_child(sign_label)

	# เสาไฟนีออนสลับฟ้า/ชมพู
	var n := 0
	for x in [-7.0, -3.5, 3.5, 7.0]:
		var col := cyan if n % 2 == 0 else pink
		add_child(MeshFactory.box(Vector3(0.35, 3.6, 0.35), Vector3(x, 1.8, -3.9), steel))
		add_child(MeshFactory.box(Vector3(0.06, 3.0, 0.06), Vector3(x, 1.8, -3.7), MeshFactory.glow_mat(col, 3.0)))
		_light(Vector3(x, 1.5, -3.3), col, 1.2, 3.5)
		n += 1

	# ตู้คอนเทนเนอร์ / ลังสินค้า / ถังเชื้อเพลิง
	add_child(MeshFactory.box(Vector3(2.2, 1.1, 1.1), Vector3(-5.2, 0.55, -2.6), MeshFactory.mat("wood", Color(0.8, 0.4, 0.2))))
	add_child(MeshFactory.box(Vector3(1.8, 1.1, 1.0), Vector3(-5.0, 1.65, -2.7), MeshFactory.mat("wood", Color(0.25, 0.55, 0.6))))
	add_child(MeshFactory.box(Vector3(0.9, 0.9, 0.9), Vector3(-3.4, 0.45, -2.9), MeshFactory.mat("wood", Color(0.55, 0.55, 0.6))))
	for p in [Vector3(4.8, 0.35, -2.4), Vector3(5.6, 0.35, -2.0), Vector3(5.1, 1.05, -2.3)]:
		add_child(MeshFactory.box(Vector3(0.7, 0.7, 0.7), p, MeshFactory.mat("wood", Color(0.7, 0.65, 0.55))))
	for p in [Vector3(6.6, 0.45, -1.0), Vector3(7.2, 0.45, -0.6)]:
		add_child(MeshFactory.cylinder(0.3, 0.9, p, MeshFactory.mat("wall", Color(0.75, 0.2, 0.18))))

	# ฉากหน้า (โดน DoF เบลอ ให้ภาพดูมีความลึก): ท่อใหญ่ + หลักกั้นไฟเหลือง
	var pipe := MeshFactory.cylinder(0.2, 28, Vector3(0, 0.25, 4.3), steel)
	pipe.rotation_degrees = Vector3(0, 0, 90)
	add_child(pipe)
	for x in [-4.0, 0.0, 4.0]:
		add_child(MeshFactory.cylinder(0.1, 0.7, Vector3(x, 0.35, 3.7), dark_steel))
		add_child(MeshFactory.box(Vector3(0.22, 0.08, 0.22), Vector3(x, 0.74, 3.7), MeshFactory.glow_mat(Color(1.0, 0.75, 0.2), 3.0)))

	# สปอตไลต์ส่องลาน = ลำแสงในหมอก
	var spot := SpotLight3D.new()
	spot.light_color = Color(0.85, 0.9, 1.0)
	spot.light_energy = 6.0
	spot.spot_range = 14.0
	spot.spot_angle = 22.0
	spot.light_volumetric_fog_energy = 2.0
	spot.shadow_enabled = true
	add_child(spot)
	spot.look_at_from_position(Vector3(6, 5, 2.5), Vector3(-0.5, 0, 0))

	# ละอองลอย (ใช้ของเดิมจาก Scenery)
	var motes := Scenery.new()
	add_child(motes)
	motes._build_motes()


func _light(pos: Vector3, color: Color, energy: float, light_range: float) -> OmniLight3D:
	var l := OmniLight3D.new()
	l.light_color = color
	l.light_energy = energy
	l.omni_range = light_range
	l.position = pos
	add_child(l)
	return l


# ================================================================ เป้าซ้อม
func _build_dummy() -> void:
	dummy = Node3D.new()
	dummy.position = dummy_home
	add_child(dummy)
	add_child(MeshFactory.cylinder(0.3, 0.03, dummy_home + Vector3(0, 0.015, 0), MeshFactory.glow_mat(Color(1.0, 0.3, 0.7), 0.5)))
	dummy_core = MeshInstance3D.new()
	var gem := SphereMesh.new() # ทรงเพชร 4 เหลี่ยม
	gem.radial_segments = 4
	gem.rings = 2
	gem.radius = 0.32
	gem.height = 0.9
	dummy_core.mesh = gem
	dummy_mat = StandardMaterial3D.new()
	dummy_mat.albedo_color = Color(0.35, 0.08, 0.25)
	dummy_mat.metallic = 0.6
	dummy_mat.roughness = 0.25
	dummy_mat.emission_enabled = true
	dummy_mat.emission = Color(1.0, 0.3, 0.7)
	dummy_mat.emission_energy_multiplier = 1.0
	dummy_core.material_override = dummy_mat
	dummy_core.position.y = 0.95
	dummy.add_child(dummy_core)
	var l := OmniLight3D.new()
	l.light_color = Color(1.0, 0.35, 0.7)
	l.light_energy = 0.8
	l.omni_range = 2.0
	l.position.y = 0.95
	dummy.add_child(l)


# ================================================================ ทุกเฟรม
func _process(delta: float) -> void:
	var now := Time.get_ticks_msec()
	var real_dt := (now - _ticks) / 1000.0
	_ticks = now
	_time += delta

	var dir := _auto_dir
	if Input.is_key_pressed(KEY_A): dir.x -= 1
	if Input.is_key_pressed(KEY_D): dir.x += 1
	if Input.is_key_pressed(KEY_W): dir.z -= 1
	if Input.is_key_pressed(KEY_S): dir.z += 1
	hero.move(dir, delta)
	hero.position.x = clampf(hero.position.x, AREA.position.x, AREA.end.x)
	hero.position.z = clampf(hero.position.z, AREA.position.y, AREA.end.y)

	# กล้อง: ปกติตามตัวละคร ตอนท่าไม้ตายเลื่อนไปกึ่งกลางระหว่างตัวละครกับเป้า
	var hero_flat := Vector3(hero.position.x, hero.position.y * 0.35, hero.position.z)
	var mid := (hero_flat + dummy.position) * 0.5
	focus.position = hero_flat.lerp(mid, _focus_mix)

	# จอสั่น (ใช้เวลาจริง ไม่โดน slow-mo)
	var cam := lighting.camera
	cam.h_offset = randf_range(-1.0, 1.0) * _shake * 0.12
	cam.v_offset = randf_range(-1.0, 1.0) * _shake * 0.12
	_shake = move_toward(_shake, 0.0, real_dt * 2.5)

	dummy_core.position.y = 0.95 + sin(_time * 2.0) * 0.06
	dummy_core.rotation.y += delta * 0.8


func _unhandled_input(event: InputEvent) -> void:
	var k := event as InputEventKey
	if k == null or not k.pressed or k.echo:
		return
	if k.keycode == KEY_J:
		hero.attack()
	elif k.keycode == KEY_K:
		hero.finisher(dummy.position)


# ================================================================ ผู้กำกับ (รับ cue จากตัวละคร)
func _on_cue(cue_name: String, strength: float) -> void:
	match cue_name:
		"focus":
			_ui_tween().tween_property(lighting.camera, "fov", 21.0, 0.35).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
			_letterbox(true)
			_ui_tween().tween_property(self, "_focus_mix", 1.0, 0.35)
			_ui_tween().tween_property(env, "tonemap_exposure", _base_exposure * 0.7, 0.3)
			_ui_tween().tween_method(_set_speed, 0.0, 0.5, 0.3)
		"charge":
			_burst(hero.position + Vector3(0, 0.8, 0.2), Color(0.5, 1.6, 2.4), 40, 0.6)
		"hit":
			if absf(dummy.position.x - hero.position.x) < 1.7:
				_hit(strength)
		"launch":
			_hit(strength)
			var up := create_tween()
			up.tween_property(dummy_core, "position:y", 2.2, 0.25).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		"cutin":
			_set_time_scale(0.3)
			_show_cutin()
		"plunge":
			_set_time_scale(1.0)
		"slam":
			_hit(strength)
			_flash_screen(0.85)
			_shockwave(hero.position)
			_burst(hero.position + Vector3(0, 0.2, 0.1), Color(0.6, 1.8, 2.6), 120, 1.0)
			_impact_light(hero.position + Vector3(0, 0.5, 0.3), Color(0.5, 0.9, 1.0), 9.0)
			dummy_core.position.y = 0.95
		"end":
			_ui_tween().tween_property(lighting.camera, "fov", 30.0, 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
			_letterbox(false)
			_ui_tween().tween_property(self, "_focus_mix", 0.0, 0.5)
			_ui_tween().tween_property(env, "tonemap_exposure", _base_exposure, 0.4)
			_ui_tween().tween_method(_set_speed, 0.5, 0.0, 0.3)


## โดนตี: ตัวเลขดาเมจ + ประกาย + เป้ากระเด็น/สว่างวาบ + จอสั่น + hitstop
func _hit(strength: float) -> void:
	var at := dummy.position + Vector3(0, dummy_core.position.y, 0.3)
	_damage_number(int(randf_range(820, 1240) * strength), at, strength >= 1.5)
	_burst(at, Color(0.6, 1.8, 2.6), int(24 * strength), 0.4)
	_impact_light(at, Color(0.6, 0.9, 1.0), 3.0 * strength)
	var knock := create_tween()
	var dirx := signf(dummy.position.x - hero.position.x)
	knock.tween_property(dummy_core, "position:x", 0.18 * dirx * strength, 0.04)
	knock.tween_property(dummy_core, "position:x", 0.0, 0.25).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	dummy_mat.emission = Color(1, 1, 1)
	dummy_mat.emission_energy_multiplier = 4.0
	var back := create_tween()
	back.tween_property(dummy_mat, "emission", Color(1.0, 0.3, 0.7), 0.2)
	back.parallel().tween_property(dummy_mat, "emission_energy_multiplier", 1.0, 0.2)
	_shake = minf(_shake + 0.35 * strength, 1.6)
	_hitstop(0.045 + 0.025 * strength)


func _hitstop(dur: float) -> void:
	Engine.time_scale = 0.0
	await get_tree().create_timer(dur, true, false, true).timeout
	Engine.time_scale = _base_scale


func _set_time_scale(s: float) -> void:
	_base_scale = s
	Engine.time_scale = s


func _ui_tween() -> Tween:
	var tw := create_tween()
	tw.set_ignore_time_scale(true)
	return tw


# ================================================================ เอฟเฟกต์ 3D
func _damage_number(value: int, at: Vector3, big: bool) -> void:
	var l := Label3D.new()
	l.text = str(value)
	l.font_size = 88 if big else 64
	l.outline_size = 20
	l.pixel_size = 0.005
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.no_depth_test = true
	l.modulate = Color(1.0, 0.85, 0.35) if big else Color(1, 1, 1)
	l.outline_modulate = Color(0.12, 0.05, 0.15)
	_hit_count += 1
	l.position = at + Vector3(randf_range(-0.4, 0.4), 0.15 + (_hit_count % 4) * 0.25, 0.2) # เรียงขั้นบันได ไม่ทับกัน
	l.scale = Vector3.ONE * 1.8
	add_child(l)
	var tw := create_tween()
	tw.tween_property(l, "scale", Vector3.ONE, 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(l, "position:y", l.position.y + 0.5, 0.7).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(l, "modulate:a", 0.0, 0.25)
	tw.parallel().tween_property(l, "outline_modulate:a", 0.0, 0.25)
	tw.tween_callback(l.queue_free)


func _impact_light(at: Vector3, color: Color, energy: float) -> void:
	var l := _light(at, color, energy, 4.0)
	l.light_volumetric_fog_energy = 3.0
	var tw := create_tween()
	tw.tween_property(l, "light_energy", 0.0, 0.35).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	tw.tween_callback(l.queue_free)


func _shockwave(at: Vector3) -> void:
	var ring := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.9
	torus.outer_radius = 1.0
	ring.mesh = torus
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = Color(0.7, 1.8, 2.6, 1.0)
	ring.material_override = m
	ring.position = at + Vector3(0, 0.05, 0)
	ring.scale = Vector3(0.2, 0.05, 0.2)
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(ring)
	var tw := create_tween()
	tw.tween_property(ring, "scale", Vector3(3.5, 0.05, 3.5), 0.45).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(m, "albedo_color:a", 0.0, 0.45)
	tw.tween_callback(ring.queue_free)


func _burst(at: Vector3, color: Color, amount: int, speed: float) -> void:
	var p := GPUParticles3D.new()
	p.amount = maxi(amount, 8)
	p.lifetime = 0.6
	p.one_shot = true
	p.explosiveness = 0.95
	p.position = at
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	pm.emission_sphere_radius = 0.1
	pm.spread = 180.0
	pm.initial_velocity_min = 1.5 * speed
	pm.initial_velocity_max = 4.0 * speed
	pm.damping_min = 4.0
	pm.damping_max = 6.0
	pm.gravity = Vector3(0, -2, 0)
	pm.scale_min = 0.5
	pm.scale_max = 1.2
	var ramp := Gradient.new()
	ramp.set_color(0, Color(1, 1, 1, 1))
	ramp.set_color(1, Color(1, 1, 1, 0))
	var ramp_tex := GradientTexture1D.new()
	ramp_tex.gradient = ramp
	pm.color_ramp = ramp_tex
	p.process_material = pm
	var quad := QuadMesh.new()
	quad.size = Vector2(0.06, 0.06)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.vertex_color_use_as_albedo = true
	m.albedo_color = color
	quad.material = m
	p.draw_pass_1 = quad
	add_child(p)
	p.emitting = true
	get_tree().create_timer(1.5, true, false, true).timeout.connect(p.queue_free)


# ================================================================ เอฟเฟกต์จอ (layer 1 = เหนือ post-fx)
func _build_fx_ui() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 1
	add_child(layer)

	var speed_rect := ColorRect.new()
	speed_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	speed_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sh := Shader.new()
	sh.code = SPEEDLINE_SHADER
	_speed = ShaderMaterial.new()
	_speed.shader = sh
	speed_rect.material = _speed
	layer.add_child(speed_rect)

	_cutin = _make_cutin()
	layer.add_child(_cutin)

	_bar_top = ColorRect.new()
	_bar_top.color = Color.BLACK
	_bar_top.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_bar_top.offset_bottom = 0
	layer.add_child(_bar_top)
	_bar_bottom = ColorRect.new()
	_bar_bottom.color = Color.BLACK
	_bar_bottom.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_bar_bottom.offset_top = 0
	layer.add_child(_bar_bottom)

	_flash = ColorRect.new()
	_flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_flash.color = Color(1, 1, 1, 0)
	layer.add_child(_flash)

	var help := Label.new()
	help.text = "A/D walk   J combo   K finisher"
	help.position = Vector2(12, 8)
	help.add_theme_color_override("font_outline_color", Color.BLACK)
	help.add_theme_constant_override("outline_size", 6)
	layer.add_child(help)


## แถบ cut-in เฉียง + ตัวละครตัวใหญ่ (ใช้ภาพจาก SubViewport เดียวกัน = ท่าเดียวกับในฉาก)
func _make_cutin() -> Node2D:
	var root := Node2D.new()
	root.visible = false
	var y0 := VIEW_H * 0.36
	var band := Polygon2D.new()
	band.polygon = PackedVector2Array([Vector2(-40, y0 + 30), Vector2(VIEW_W + 40, y0 - 30), Vector2(VIEW_W + 40, y0 + 120), Vector2(-40, y0 + 180)])
	band.color = Color(0.06, 0.08, 0.16, 0.92)
	root.add_child(band)
	var stripe := Polygon2D.new()
	stripe.polygon = PackedVector2Array([Vector2(-40, y0 + 172), Vector2(VIEW_W + 40, y0 + 112), Vector2(VIEW_W + 40, y0 + 120), Vector2(-40, y0 + 180)])
	stripe.color = Color(0.35, 0.9, 1.0)
	root.add_child(stripe)
	var portrait := Sprite2D.new()
	portrait.texture = hero.viewport.get_texture()
	portrait.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	portrait.scale = Vector2(2.2, 2.2)
	portrait.position = Vector2(VIEW_W * 0.72, y0 + 10)
	root.add_child(portrait)
	var small := Label.new()
	small.text = "FINISHER"
	small.position = Vector2(80, y0 + 30)
	small.add_theme_font_size_override("font_size", 22)
	small.add_theme_color_override("font_color", Color(0.4, 0.9, 1.0))
	root.add_child(small)
	var big := Label.new()
	big.text = "STARFALL EDGE"
	big.position = Vector2(76, y0 + 56)
	big.add_theme_font_size_override("font_size", 64)
	big.add_theme_color_override("font_outline_color", Color(0.02, 0.02, 0.06))
	big.add_theme_constant_override("outline_size", 12)
	root.add_child(big)
	return root


func _show_cutin() -> void:
	_cutin.visible = true
	_cutin.position.x = -VIEW_W
	var tw := _ui_tween()
	tw.tween_property(_cutin, "position:x", 0.0, 0.16).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	tw.tween_property(_cutin, "position:x", 30.0, 0.42) # ไหลช้า ๆ ระหว่างค้าง
	tw.tween_property(_cutin, "position:x", VIEW_W, 0.14).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)
	tw.tween_callback(func() -> void: _cutin.visible = false)


func _letterbox(on: bool) -> void:
	var h := 70.0 if on else 0.0
	var tw := _ui_tween()
	tw.tween_property(_bar_top, "offset_bottom", h, 0.3).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(_bar_bottom, "offset_top", -h, 0.3).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)


func _flash_screen(alpha: float) -> void:
	_flash.color.a = alpha
	_ui_tween().tween_property(_flash, "color:a", 0.0, 0.3)


func _set_speed(v: float) -> void:
	_speed.set_shader_parameter("amount", v)


# ================================================================ screenshot อัตโนมัติ
func _maybe_screenshot() -> void:
	for arg in OS.get_cmdline_user_args():
		if not arg.begins_with("shot="):
			continue
		var path := arg.substr(5)
		var base := path.get_basename()
		await _frames(40)
		_save(base + "_idle.png")
		_save_rig(base + "_rig_idle.png")
		_auto_dir = Vector3(1, 0, 0)
		await _real(0.35)
		_save_rig(base + "_rig_run.png")
		_save(base + "_run.png")
		_auto_dir = Vector3.ZERO
		await _real(0.6)
		hero.attack()
		await _real(0.2)
		_save(base + "_combo.png")
		await _real(1.0)
		hero.finisher(dummy.position)
		var marks := [[0.3, "_f1_crouch"], [0.78, "_f2_dash"], [1.25, "_f3_cutin"], [2.15, "_f4_slam"]]
		var elapsed := 0.0
		for m in marks:
			await _real(m[0] - elapsed)
			elapsed = m[0]
			_save(base + m[1] + ".png")
			_save_rig(base + m[1] + "_rig.png")
		await _real(2.0)
		_save(base + "_end.png")
		print("dock_lab shots saved: ", base)
		get_tree().quit()


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _real(t: float) -> void:
	await get_tree().create_timer(maxf(t, 0.0), true, false, true).timeout


func _save(path: String) -> void:
	get_viewport().get_texture().get_image().save_png(path)


func _save_rig(path: String) -> void:
	var img := hero.viewport.get_texture().get_image()
	img.convert(Image.FORMAT_RGBA8)
	img.resize(img.get_width() * 3, img.get_height() * 3, Image.INTERPOLATE_NEAREST)
	img.save_png(path)

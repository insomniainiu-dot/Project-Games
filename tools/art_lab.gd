extends Node3D
## Art Lab: ฉากทดสอบ HD-2D สำหรับจูน look ของเกม (ไม่ยุ่งกับระบบเกม)
##   เปิด: Godot --path . res://tools/art_lab.tscn
##   ถ่ายรูปแล้วปิด: Godot --path . res://tools/art_lab.tscn -- shot=<ไฟล์.png>
##
## ปุ่ม:
##   WASD = เดิน   1-4 = อาวุธ tier 1-4   Z/X/C = skill gem ไฟ/น้ำแข็ง/สายฟ้า
##   Tab = ซ่อน/แสดงแผงจูน   ปุ่ม "Print values" = พิมพ์ค่าลง Output ไปใส่ scene_lighting.gd

const WALK_SPEED := 2.6
const AREA := Rect2(-5.5, -1.8, 11.0, 5.0) # ขอบเขตเดิน (x, z)

const TIERS := [
	# [ชื่อ, สีใบมีด, สีเรืองแสง, emission energy, แสงรอบตัว, มีประกาย]
	["T1 Iron", Color(0.55, 0.55, 0.6), Color.BLACK, 0.0, 0.0, false],
	["T2 Steel", Color(0.75, 0.8, 0.9), Color(0.4, 0.7, 1.0), 0.8, 0.0, false],
	["T3 Arcane", Color(0.6, 0.4, 0.9), Color(0.7, 0.35, 1.0), 3.0, 0.8, false],
	["T4 Relic", Color(1.0, 0.85, 0.4), Color(1.0, 0.75, 0.25), 5.0, 1.6, true],
]

const GEMS := {
	KEY_Z: ["Fire", Color(1.0, 0.45, 0.15), Vector3(0, 1.2, 0)],
	KEY_X: ["Ice", Color(0.45, 0.8, 1.0), Vector3(0, -0.6, 0)],
	KEY_C: ["Lightning", Color(0.75, 0.7, 1.0), Vector3(0, 0.3, 0)],
}

var lighting: SceneLighting
var witch: Witch
var env: Environment
var sun: DirectionalLight3D
var post_fx: ShaderMaterial
var cam_attrs: CameraAttributesPractical
var _weapon: Node3D
var _tier_label: Label
var _panel: Control
var _values := {} # ชื่อ -> ค่า slider ล่าสุด (ไว้ print)


func _ready() -> void:
	lighting = SceneLighting.new()
	add_child(lighting)
	lighting.build()
	_grab_lighting_nodes()
	_build_set()
	witch = Witch.new()
	add_child(witch)
	lighting.follow(witch)
	_set_tier(0)
	_build_ui()
	_maybe_screenshot()


func _grab_lighting_nodes() -> void:
	for c in lighting.get_children():
		if c is WorldEnvironment:
			env = (c as WorldEnvironment).environment
		elif c is DirectionalLight3D:
			sun = c
		elif c is CanvasLayer:
			post_fx = (c.get_child(0) as ColorRect).material
	cam_attrs = lighting.camera.attributes


# ================================================================ ฉาก
## ลานหินกลางเมือง: ใช้ helper เดิมของ Scenery (บ้าน, ตะเกียง, ต้นไม้, บ่อน้ำ, ละอองแสง)
func _build_set() -> void:
	var set_pieces := Scenery.new()
	set_pieces._rng = RandomNumberGenerator.new()
	set_pieces._rng.seed = 7
	add_child(set_pieces)

	var cobble := MeshFactory.mat("stone", Color(0.55, 0.52, 0.5))
	cobble.uv1_scale = Vector3(2.5, 2.5, 2.5) # ก้อนหินเล็กลง ดูเป็นถนนหิน ไม่ใช่อิฐก้อนโต
	set_pieces.add_child(MeshFactory.box(Vector3(12, 0.06, 6.5), Vector3(0, 0.0, 0.6), cobble))
	set_pieces._house(Vector3(-3.2, 0, -3.3), 2.4, "WEAPONS & ARMOR")
	set_pieces._house(Vector3(0.0, 0, -3.5), 2.2)
	set_pieces._house(Vector3(3.2, 0, -3.3), 2.4)
	for p in [Vector3(-1.6, 0, -1.9), Vector3(1.6, 0, -1.9), Vector3(-5.6, 0, 2.4), Vector3(5.6, 0, 2.4)]:
		set_pieces._lantern(p)
	set_pieces._tree(Vector3(-6.2, 0, -0.8))
	set_pieces._tree(Vector3(6.4, 0, -1.2))
	set_pieces._well(Vector3(4.0, 0, 1.6))
	for p in [Vector3(-4.6, 0, -1.6), Vector3(-4.1, 0, -1.4), Vector3(1.0, 0, -2.2)]:
		set_pieces.add_child(MeshFactory.cylinder(0.25, 0.55, p + Vector3(0, 0.275, 0), MeshFactory.mat("wood")))
	set_pieces.add_child(MeshFactory.box(Vector3(0.6, 0.45, 0.45), Vector3(-1.0, 0.225, -2.1), MeshFactory.mat("wood", Color(0.8, 0.7, 0.6))))
	for p in [Vector3(-6.5, 0, 3.6), Vector3(-3.5, 0, 4.4), Vector3(2.5, 0, 4.5), Vector3(6.8, 0, 0.8), Vector3(-7.0, 0, 1.0)]:
		set_pieces._bush(p)
	set_pieces._build_motes()


# ================================================================ เดิน + ปุ่ม
func _process(delta: float) -> void:
	var dir := Vector3.ZERO
	if Input.is_key_pressed(KEY_A): dir.x -= 1
	if Input.is_key_pressed(KEY_D): dir.x += 1
	if Input.is_key_pressed(KEY_W): dir.z -= 1
	if Input.is_key_pressed(KEY_S): dir.z += 1
	if dir != Vector3.ZERO:
		if not witch.walking:
			witch.begin_walk()
		dir = dir.normalized()
		witch.face_toward(dir)
		var p := witch.position + dir * WALK_SPEED * delta
		p.x = clampf(p.x, AREA.position.x, AREA.end.x)
		p.z = clampf(p.z, AREA.position.y, AREA.end.y)
		witch.position = p
	elif witch.walking:
		witch.end_walk(false)


func _unhandled_input(event: InputEvent) -> void:
	var k := event as InputEventKey
	if k == null or not k.pressed or k.echo:
		return
	if k.keycode >= KEY_1 and k.keycode <= KEY_4:
		_set_tier(k.keycode - KEY_1)
	elif GEMS.has(k.keycode):
		_cast_gem(GEMS[k.keycode])
	elif k.keycode == KEY_TAB:
		_panel.visible = not _panel.visible


# ================================================================ อาวุธ 4 tier
## tier ต่างกันที่วัสดุ: เหล็กด้าน -> เงาวาว -> เรืองแสง+แสงรอบตัว -> เรืองแสงจัด+ประกาย
func _set_tier(i: int) -> void:
	if _weapon:
		_weapon.queue_free()
	var t: Array = TIERS[i]
	_weapon = Node3D.new()
	_weapon.position = Vector3(0.38, 0.45, 0.08)
	_weapon.rotation_degrees = Vector3(0, 0, -20)
	witch.add_child(_weapon)

	var blade := StandardMaterial3D.new()
	blade.albedo_color = t[1]
	blade.metallic = 0.8
	blade.roughness = 0.35
	if t[3] > 0.0:
		blade.emission_enabled = true
		blade.emission = t[2]
		blade.emission_energy_multiplier = t[3]
	_weapon.add_child(MeshFactory.box(Vector3(0.07, 0.62, 0.025), Vector3(0, 0.36, 0), blade))
	_weapon.add_child(MeshFactory.box(Vector3(0.24, 0.05, 0.05), Vector3(0, 0.05, 0), MeshFactory.mat("wood", Color(0.5, 0.45, 0.4))))
	_weapon.add_child(MeshFactory.box(Vector3(0.05, 0.16, 0.05), Vector3(0, -0.06, 0), MeshFactory.mat("wood")))

	if t[4] > 0.0:
		var aura := OmniLight3D.new()
		aura.light_color = t[2]
		aura.light_energy = t[4]
		aura.omni_range = 1.6
		aura.position = Vector3(0, 0.4, 0.2)
		_weapon.add_child(aura)
	if t[5]:
		_weapon.add_child(_sparkles(t[2]))
	if _tier_label:
		_tier_label.text = "Weapon: %s" % t[0]


func _sparkles(color: Color) -> GPUParticles3D:
	var p := _particles(color * 2.0, 24, 1.2, 0.035)
	p.position = Vector3(0, 0.36, 0)
	var pm: ParticleProcessMaterial = p.process_material
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(0.06, 0.3, 0.03)
	pm.initial_velocity_min = 0.05
	pm.initial_velocity_max = 0.2
	pm.gravity = Vector3(0, 0.3, 0)
	return p


# ================================================================ skill gem
func _cast_gem(gem: Array) -> void:
	var color: Color = gem[1]
	var origin := witch.position + Vector3(0, 0.7, 0.3)
	var burst := _particles(color * 2.2, 90, 0.9, 0.06)
	burst.one_shot = true
	burst.explosiveness = 0.95
	burst.position = origin
	var pm: ParticleProcessMaterial = burst.process_material
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	pm.emission_sphere_radius = 0.15
	pm.spread = 180.0
	pm.initial_velocity_min = 1.2
	pm.initial_velocity_max = 2.8
	pm.gravity = gem[2]
	pm.damping_min = 2.0
	pm.damping_max = 3.5
	add_child(burst)
	burst.emitting = true

	# แสงวาบส่องฉากรอบตัว = จุดเด่นของ HD-2D (สกิลเปลี่ยนสีฉากได้จริง)
	var flash := OmniLight3D.new()
	flash.light_color = color
	flash.light_energy = 5.0
	flash.omni_range = 4.5
	flash.light_volumetric_fog_energy = 3.0
	flash.shadow_enabled = true
	flash.position = origin
	add_child(flash)
	var tw := create_tween()
	tw.tween_property(flash, "light_energy", 0.0, 0.7).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_EXPO)
	tw.tween_interval(0.8)
	tw.tween_callback(func() -> void:
		flash.queue_free()
		burst.queue_free())


## ละอองเรืองแสงแบบเดียวกับ motes ใน Scenery (additive + เกิน 1 = ติด glow)
func _particles(color: Color, amount: int, lifetime: float, size: float) -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.amount = amount
	p.lifetime = lifetime
	p.local_coords = false
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var pm := ParticleProcessMaterial.new()
	var ramp := Gradient.new()
	ramp.set_color(0, Color(1, 1, 1, 1))
	ramp.set_color(1, Color(1, 1, 1, 0))
	var ramp_tex := GradientTexture1D.new()
	ramp_tex.gradient = ramp
	pm.color_ramp = ramp_tex
	pm.scale_min = 0.5
	pm.scale_max = 1.2
	p.process_material = pm
	var quad := QuadMesh.new()
	quad.size = Vector2(size, size)
	var dot := GradientTexture2D.new()
	dot.width = 32
	dot.height = 32
	dot.fill = GradientTexture2D.FILL_RADIAL
	dot.fill_from = Vector2(0.5, 0.5)
	dot.fill_to = Vector2(0.5, 0.0)
	dot.gradient = Gradient.new()
	dot.gradient.set_color(0, Color(1, 1, 1, 1))
	dot.gradient.set_color(1, Color(1, 1, 1, 0))
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.vertex_color_use_as_albedo = true
	m.albedo_texture = dot
	m.albedo_color = color
	quad.material = m
	p.draw_pass_1 = quad
	return p


# ================================================================ แผงจูน
func _build_ui() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 2 # เหนือ post-fx (layer 0) ไม่โดน vignette
	add_child(layer)

	var help := Label.new()
	help.text = "WASD walk   1-4 weapon tier   Z/X/C gem   Tab panel"
	help.position = Vector2(12, 8)
	help.add_theme_color_override("font_outline_color", Color.BLACK)
	help.add_theme_constant_override("outline_size", 6)
	layer.add_child(help)
	_tier_label = help.duplicate()
	_tier_label.position = Vector2(12, 32)
	_tier_label.text = "Weapon: %s" % TIERS[0][0]
	layer.add_child(_tier_label)

	_panel = PanelContainer.new()
	_panel.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_panel.position = Vector2(-300, 8)
	_panel.custom_minimum_size = Vector2(290, 0)
	_panel.modulate = Color(1, 1, 1, 0.92)
	layer.add_child(_panel)
	var box := VBoxContainer.new()
	_panel.add_child(box)

	_slider(box, "Exposure", 0.5, 2.0, env.tonemap_exposure, func(v): env.tonemap_exposure = v)
	_slider(box, "Glow", 0.0, 2.0, env.glow_intensity, func(v): env.glow_intensity = v)
	_slider(box, "Vol. fog", 0.0, 0.08, env.volumetric_fog_density, func(v): env.volumetric_fog_density = v)
	_slider(box, "SSAO", 0.0, 4.0, env.ssao_intensity, func(v): env.ssao_intensity = v)
	_slider(box, "Saturation", 0.5, 1.6, env.adjustment_saturation, func(v): env.adjustment_saturation = v)
	_slider(box, "Contrast", 0.7, 1.4, env.adjustment_contrast, func(v): env.adjustment_contrast = v)
	_slider(box, "Ambient", 0.0, 1.5, env.ambient_light_energy, func(v): env.ambient_light_energy = v)
	_slider(box, "Sun energy", 0.0, 3.0, sun.light_energy, func(v): sun.light_energy = v)
	_slider(box, "Sun pitch", -85.0, -8.0, sun.rotation_degrees.x, func(v): sun.rotation_degrees.x = v)
	_slider(box, "Sun yaw", -180.0, 180.0, sun.rotation_degrees.y, func(v): sun.rotation_degrees.y = v)
	_slider(box, "FOV", 15.0, 60.0, lighting.camera.fov, func(v): lighting.camera.fov = v)
	_slider(box, "DoF amount", 0.0, 0.6, cam_attrs.dof_blur_amount, func(v): cam_attrs.dof_blur_amount = v)
	_slider(box, "DoF near", 1.0, 12.0, cam_attrs.dof_blur_near_distance, func(v): cam_attrs.dof_blur_near_distance = v)
	_slider(box, "DoF far", 4.0, 25.0, cam_attrs.dof_blur_far_distance, func(v): cam_attrs.dof_blur_far_distance = v)
	# get_shader_parameter คืน null ถ้ายังไม่เคย set (ใช้ค่า default ใน shader) เลยใส่ค่าเดียวกับ shader ไว้สำรอง
	var vig = post_fx.get_shader_parameter("vignette")
	var grain = post_fx.get_shader_parameter("grain")
	_slider(box, "Vignette", 0.0, 1.0, 0.55 if vig == null else vig, func(v): post_fx.set_shader_parameter("vignette", v))
	_slider(box, "Grain", 0.0, 0.08, 0.018 if grain == null else grain, func(v): post_fx.set_shader_parameter("grain", v))

	var print_btn := Button.new()
	print_btn.text = "Print values"
	print_btn.focus_mode = Control.FOCUS_NONE
	print_btn.pressed.connect(func() -> void:
		print("---- art_lab values ----")
		for key in _values:
			print("%s = %.3f" % [key, _values[key]]))
	box.add_child(print_btn)


func _slider(parent: Control, label: String, lo: float, hi: float, value: float, apply: Callable) -> void:
	var row := HBoxContainer.new()
	parent.add_child(row)
	var name_label := Label.new()
	name_label.custom_minimum_size = Vector2(90, 0)
	name_label.text = label
	row.add_child(name_label)
	var s := HSlider.new()
	s.min_value = lo
	s.max_value = hi
	s.step = (hi - lo) / 200.0
	s.value = value
	s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	s.focus_mode = Control.FOCUS_NONE # ไม่แย่งปุ่ม WASD
	row.add_child(s)
	var val_label := Label.new()
	val_label.custom_minimum_size = Vector2(52, 0)
	val_label.text = "%.3f" % value
	row.add_child(val_label)
	_values[label] = value
	s.value_changed.connect(func(v: float) -> void:
		apply.call(v)
		val_label.text = "%.3f" % v
		_values[label] = v)


# ================================================================ screenshot อัตโนมัติ
func _maybe_screenshot() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("shot="):
			var path := arg.substr(5)
			_set_tier(3)
			for i in 45:
				await get_tree().process_frame
			get_viewport().get_texture().get_image().save_png(path)
			_cast_gem(GEMS[KEY_X])
			for i in 8:
				await get_tree().process_frame
			var gem_path := path.get_basename() + "_gem.png"
			get_viewport().get_texture().get_image().save_png(gem_path)
			print("art_lab shot: ", path, " + ", gem_path)
			get_tree().quit()

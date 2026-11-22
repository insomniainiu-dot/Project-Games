class_name SceneLighting
extends Node3D
## แสง / กล้อง / หมอก / DOF / post-process ของฉากกระดานแบบ HD-2D + พื้นหญ้า
## (ชื่อคลาสไม่ใช้ WorldEnvironment เพราะชนกับคลาสของ Godot)
##   var lighting := SceneLighting.new(); add_child(lighting); lighting.build()
##   lighting.follow(witch)  # กล้องตามตัวละคร

const CAMERA_OFFSET := Vector3(0, 5.9, 7.2) # กล้องอยู่ห่างจากตัวละครเท่านี้ (ไกลขึ้น + เลนส์แคบ = ดูเป็นโมเดลจิ๋ว)

var camera: Camera3D
var _target: Node3D


func build() -> void:
	_build_environment()
	_build_ground()
	_build_post_fx()


## ให้กล้องตาม node นี้ (กระโดดไปทันที แล้วตามแบบนุ่ม ๆ ใน _process)
func follow(target: Node3D) -> void:
	_target = target
	camera.global_position = target.position + CAMERA_OFFSET


func _process(delta: float) -> void:
	if _target == null:
		return
	var goal := _target.position + CAMERA_OFFSET
	camera.global_position = camera.global_position.lerp(goal, 1.0 - exp(-delta * 4.0))


func _build_environment() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.1, 0.09, 0.11)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.5, 0.55, 0.7)
	env.ambient_light_energy = 0.45
	env.tonemap_mode = Environment.TONE_MAPPER_AGX # สีนุ่มแบบภาพยนตร์ ไฮไลต์ไม่แตก
	env.tonemap_exposure = 1.15
	env.glow_enabled = true # ไฟตะเกียง/หน้าต่างเรืองแสง ฟุ้งเป็นวง
	env.glow_intensity = 0.7
	env.glow_strength = 1.0
	env.glow_bloom = 0.03 # ฟุ้งทั้งภาพนิดเดียว ส่วนใหญ่ฟุ้งเฉพาะไฟที่สว่างจัด
	env.glow_hdr_threshold = 1.1
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SCREEN
	var glow_levels := [0.0, 0.6, 0.8, 0.7, 0.5, 0.0, 0.0]
	for i in glow_levels.size():
		env.set_glow_level(i, glow_levels[i])
	env.ssao_enabled = true # เงาตามซอกมุม
	env.ssao_intensity = 2.2
	env.ssil_enabled = true # แสงสะท้อนสีจากพื้นผิวข้าง ๆ
	env.fog_enabled = true
	env.fog_light_color = Color(0.55, 0.45, 0.36)
	env.fog_density = 0.01
	# หมอกปริมาตร: ทำให้เห็นลำแสงแดดลอดเงา และไฟตะเกียงเป็นวงฟุ้ง
	env.volumetric_fog_enabled = true
	env.volumetric_fog_density = 0.022
	env.volumetric_fog_albedo = Color(0.95, 0.9, 0.82)
	env.volumetric_fog_anisotropy = 0.6
	env.volumetric_fog_length = 40.0
	env.volumetric_fog_ambient_inject = 0.15
	env.adjustment_enabled = true
	env.adjustment_saturation = 1.1
	env.adjustment_contrast = 1.08
	var world_env := WorldEnvironment.new()
	world_env.environment = env
	add_child(world_env)

	# แสงแดดยามเย็น สีอุ่น เงานุ่ม
	var sun := DirectionalLight3D.new()
	sun.light_color = Color(1.0, 0.8, 0.58)
	sun.light_energy = 1.25
	sun.light_angular_distance = 1.2 # เงาขอบนุ่ม (ยิ่งไกลวัตถุยิ่งเบลอ)
	sun.light_volumetric_fog_energy = 1.6
	sun.shadow_enabled = true
	sun.shadow_blur = 1.5
	sun.directional_shadow_max_distance = 30.0
	sun.rotation_degrees = Vector3(-40, -35, 0)
	add_child(sun)

	# กล้องเอียงมองลง + เลนส์แคบ = ดูเหมือนโมเดลจิ๋ว (ตามตัวละครใน _process)
	camera = Camera3D.new()
	camera.fov = 30.0
	# Tilt-shift: โฟกัสคมแค่แถบกลางรอบตัวละคร ฉากหน้า/หลังเบลอแรง
	var focus := CAMERA_OFFSET.length()
	var attrs := CameraAttributesPractical.new()
	attrs.dof_blur_far_enabled = true # ฉากหลังเบลอ
	attrs.dof_blur_far_distance = focus + 0.8
	attrs.dof_blur_far_transition = 2.5
	attrs.dof_blur_near_enabled = true # ฉากหน้าเบลอ
	attrs.dof_blur_near_distance = focus - 1.2
	attrs.dof_blur_near_transition = 1.4
	attrs.dof_blur_amount = 0.24
	camera.attributes = attrs
	add_child(camera)
	camera.look_at_from_position(CAMERA_OFFSET, Vector3(0, 0, 0.2))
	camera.current = true


func _build_ground() -> void:
	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(60, 60)
	ground.mesh = plane
	ground.material_override = MeshFactory.mat("grass")
	add_child(ground)


## Post-process ทับภาพ 3D (อยู่ใต้ UI): ไล่สีอุ่น/เย็น + ขอบภาพมืด + เกรนฟิล์มบาง ๆ
func _build_post_fx() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 0 # UI หลักอยู่ layer 1 ขึ้นไป จึงไม่โดนเอฟเฟกต์
	add_child(layer)
	var rect := ColorRect.new()
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sh := Shader.new()
	sh.code = POST_FX_SHADER
	var mat := ShaderMaterial.new()
	mat.shader = sh
	rect.material = mat
	layer.add_child(rect)


const POST_FX_SHADER := """
shader_type canvas_item;
uniform sampler2D screen_tex : hint_screen_texture, filter_linear;
uniform vec3 shadow_tint = vec3(0.9, 0.95, 1.1);   // เงาอมฟ้า
uniform vec3 light_tint = vec3(1.07, 1.0, 0.88);   // ส่วนสว่างอมส้ม
uniform float vignette = 0.55;
uniform float grain = 0.018;

float hash(vec2 p) { return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453); }

void fragment() {
	vec3 c = texture(screen_tex, SCREEN_UV).rgb;
	float l = dot(c, vec3(0.299, 0.587, 0.114));
	c *= mix(shadow_tint, light_tint, smoothstep(0.15, 0.75, l));
	vec2 d = SCREEN_UV - 0.5;
	d.y *= 1.25; // มืดบน-ล่างมากกว่าซ้าย-ขวานิดนึง
	c *= 1.0 - vignette * smoothstep(0.3, 0.85, length(d));
	c += (hash(SCREEN_UV * 731.0 + fract(TIME) * 37.0) - 0.5) * grain;
	COLOR = vec4(c, 1.0);
}
"""

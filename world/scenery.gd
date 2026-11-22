class_name Scenery
extends Node3D
## ของตกแต่งรอบกระดาน: ปราสาท, บ้าน/ร้านอาวุธ, บ่อน้ำ, ต้นไม้, ตะเกียง, พุ่มไม้, ละอองแสง
## ไม่ยุ่งกับระบบเกมเลย มีหน้าที่สร้างฉากอย่างเดียว
##   var scenery := Scenery.new(); add_child(scenery); scenery.build(board, rng)

var _torches: Array[OmniLight3D] = [] # ไฟที่กะพริบ (คบเพลิงปราสาท + เตาตีเหล็ก)
var _time := 0.0
var _rng: RandomNumberGenerator
var _board: Board


## rng ใช้ต่อจากที่ Board ใช้ไปแล้ว ของตกแต่งจะอยู่ที่เดิมทุกครั้ง
func build(board: Board, rng: RandomNumberGenerator) -> void:
	_board = board
	_rng = rng
	_build_castle()
	_build_props()
	_build_motes()


func _process(delta: float) -> void:
	# ไฟคบเพลิงปราสาทกะพริบ
	_time += delta
	for i in _torches.size():
		_torches[i].light_energy = 1.6 + sin(_time * 9.0 + i * 2.0) * 0.25 + sin(_time * 23.0 + i) * 0.15


# ================================================================ ปราสาท
func _build_castle() -> void:
	var castle := Sprite3D.new()
	castle.texture = load("res://castle_sheet.png")
	castle.hframes = 4
	castle.frame = 0
	var height := 3.4
	castle.pixel_size = height / castle.texture.get_height()
	castle.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	castle.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	castle.shaded = true
	castle.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	var base := Board.tile_pos(Board.CASTLE_TILE)
	castle.position = Vector3(base.x, height / 2.0, base.z - 1.3)
	add_child(castle)

	# คบเพลิงหน้าประตูปราสาท (แสงกะพริบ)
	for side in [-1, 1]:
		var torch := OmniLight3D.new()
		torch.light_color = Color(1.0, 0.6, 0.3)
		torch.light_energy = 1.6
		torch.omni_range = 2.5
		torch.position = Vector3(base.x + side * 0.55, 0.8, base.z - 0.6)
		add_child(torch)
		_torches.append(torch)


# ================================================================ ของตกแต่ง
func _build_props() -> void:
	var blocked: Array[Vector2] = [] # จุดที่มีของแล้ว (พิกัดกริด) กันพุ่มไม้ทับ

	# บ่อน้ำในวงซ้าย
	_well(Board.grid_to_world(Vector2(1.5, 2)))
	blocked.append(Vector2(1.5, 2))

	# ต้นไม้ + ถังไม้ในวงขวา
	_tree(Board.grid_to_world(Vector2(4.6, 1.8)))
	blocked.append(Vector2(4.6, 1.8))
	for g in [Vector2(5.3, 2.8), Vector2(5.0, 3.1)]:
		add_child(MeshFactory.cylinder(0.25, 0.55, Board.grid_to_world(g) + Vector3(0, 0.275, 0), MeshFactory.mat("wood")))
		blocked.append(g)

	# บ้านสองข้างทางขึ้นปราสาท
	_house(Board.grid_to_world(Vector2(0.2, -1.7)), 2.4, "WEAPONS & ARMOR") # ร้านอาวุธ (ช่อง Smithy อยู่หน้าบ้าน)
	_house(Board.grid_to_world(Vector2(5.8, -1.8)), 2.2)
	for g in [Vector2(0.2, -1.7), Vector2(5.8, -1.8)]:
		for dx in [-1.0, 0.0, 1.0]:
			for dy in [-0.6, 0.0, 0.6]:
				blocked.append(g + Vector2(dx, dy))
	for g in [Vector2(1.6, -1.1), Vector2(1.6, -1.6)]: # ทั่ง + เตาหน้าร้านอาวุธ
		blocked.append(g)

	# ตะเกียงตามทางแยก
	var lanterns := [
		Vector2(2.4, -0.6), Vector2(3.6, -0.6), Vector2(-0.6, -0.6), Vector2(6.6, -0.6),
		Vector2(-0.6, 4.6), Vector2(6.6, 4.6), Vector2(2.4, 4.6), Vector2(3.6, 4.6),
		Vector2(-1.6, 1.4), Vector2(7.6, 2.6),
	]
	for g in lanterns:
		_lantern(Board.grid_to_world(g))
		blocked.append(g)

	# พุ่มไม้ดอกสุ่มรอบ ๆ (ไม่ทับช่องเดินและของอื่น)
	var placed := 0
	var tries := 0
	while placed < 40 and tries < 2000:
		tries += 1
		var g := Vector2(_rng.randf_range(-4.0, 10.0), _rng.randf_range(-3.0, 7.5))
		if _board.near_tile(g, 0.85) or _near_any(g, blocked, 0.9):
			continue
		if absf(g.x - 3.0) < 2.0 and g.y < -1.5:
			continue # เว้นหน้าปราสาท
		_bush(Board.grid_to_world(g))
		blocked.append(g)
		placed += 1


func _near_any(g: Vector2, points: Array[Vector2], dist: float) -> bool:
	for p in points:
		if g.distance_to(p) < dist:
			return true
	return false


func _well(pos: Vector3) -> void:
	add_child(MeshFactory.cylinder(0.5, 0.5, pos + Vector3(0, 0.25, 0), MeshFactory.mat("wall")))
	var water := MeshFactory.cylinder(0.39, 0.05, pos + Vector3(0, 0.49, 0), null)
	var water_mat := StandardMaterial3D.new()
	water_mat.albedo_color = Color(0.12, 0.25, 0.32)
	water_mat.roughness = 0.05
	water_mat.metallic = 0.3
	water.material_override = water_mat
	add_child(water)
	for side in [-1, 1]:
		add_child(MeshFactory.box(Vector3(0.08, 0.9, 0.08), pos + Vector3(side * 0.44, 0.9, 0), MeshFactory.mat("wood")))
	var roof := MeshInstance3D.new()
	var prism := PrismMesh.new()
	prism.size = Vector3(1.2, 0.35, 0.7)
	roof.mesh = prism
	roof.material_override = MeshFactory.mat("roof")
	roof.position = pos + Vector3(0, 1.5, 0)
	add_child(roof)


func _tree(pos: Vector3) -> void:
	add_child(MeshFactory.cylinder(0.14, 1.0, pos + Vector3(0, 0.5, 0), MeshFactory.mat("wood")))
	var leaf := StandardMaterial3D.new()
	leaf.albedo_color = Color(0.2, 0.34, 0.17)
	leaf.roughness = 0.9
	for spec in [[Vector3(0, 1.3, 0), 0.6], [Vector3(0.25, 1.7, 0.1), 0.45], [Vector3(-0.25, 1.6, -0.1), 0.45]]:
		var s := MeshInstance3D.new()
		var sphere := SphereMesh.new()
		sphere.radius = spec[1]
		sphere.height = spec[1] * 1.8
		s.mesh = sphere
		s.material_override = leaf
		s.position = pos + spec[0]
		add_child(s)


func _house(pos: Vector3, width: float, shop_name := "") -> void:
	var depth := 1.6
	var height := 1.8
	add_child(MeshFactory.box(Vector3(width, height, depth), pos + Vector3(0, height / 2.0, 0), MeshFactory.mat("wall")))
	var roof := MeshInstance3D.new()
	var prism := PrismMesh.new()
	prism.size = Vector3(width + 0.3, 1.1, depth + 0.3)
	roof.mesh = prism
	roof.material_override = MeshFactory.mat("roof")
	roof.position = pos + Vector3(0, height + 0.55, 0)
	add_child(roof)
	var front_z := pos.z + depth / 2.0 + 0.02
	add_child(MeshFactory.box(Vector3(0.5, 0.9, 0.05), Vector3(pos.x, 0.45, front_z), MeshFactory.mat("wood", Color(0.7, 0.7, 0.7))))
	for side in [-1, 1]:
		add_child(MeshFactory.box(Vector3(0.36, 0.36, 0.05), Vector3(pos.x + side * width * 0.3, 1.15, front_z), MeshFactory.glow_mat(Color(1.0, 0.7, 0.35), 2.5)))
	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.7, 0.4)
	light.light_energy = 1.2
	light.omni_range = 3.0
	light.position = Vector3(pos.x, 1.2, front_z + 0.5)
	add_child(light)
	if shop_name != "":
		_shop_sign(Vector3(pos.x, 1.56, front_z), shop_name)
		# ทั่งตีเหล็ก + เตาไฟหน้าร้าน
		var iron := StandardMaterial3D.new()
		iron.albedo_color = Color(0.22, 0.22, 0.25)
		iron.metallic = 0.7
		iron.roughness = 0.4
		var anvil_x := pos.x + width * 0.5 + 0.35
		add_child(MeshFactory.box(Vector3(0.22, 0.3, 0.22), Vector3(anvil_x, 0.15, front_z - 0.2), MeshFactory.mat("wood", Color(0.6, 0.6, 0.6))))
		add_child(MeshFactory.box(Vector3(0.42, 0.14, 0.2), Vector3(anvil_x, 0.37, front_z - 0.2), iron))
		add_child(MeshFactory.box(Vector3(0.36, 0.22, 0.3), Vector3(anvil_x, 0.11, front_z - 0.75), MeshFactory.glow_mat(Color(1.0, 0.45, 0.15), 3.0)))
		var forge := OmniLight3D.new()
		forge.light_color = Color(1.0, 0.5, 0.2)
		forge.light_energy = 1.5
		forge.omni_range = 2.2
		forge.position = Vector3(anvil_x, 0.5, front_z - 0.5)
		add_child(forge)
		_torches.append(forge) # ให้ไฟกะพริบเหมือนคบเพลิง


## ป้ายร้านติดผนังหน้าบ้าน
func _shop_sign(pos: Vector3, text: String) -> void:
	add_child(MeshFactory.box(Vector3(1.5, 0.34, 0.05), pos + Vector3(0, 0, 0.03), MeshFactory.mat("wood", Color(0.55, 0.42, 0.3))))
	var label := Label3D.new()
	label.text = text
	label.font_size = 26
	label.outline_size = 8
	label.pixel_size = 0.0042
	label.modulate = Color(1.0, 0.86, 0.5)
	label.outline_modulate = Color(0.15, 0.08, 0.03)
	label.position = pos + Vector3(0, 0, 0.065)
	add_child(label)


func _lantern(pos: Vector3) -> void:
	add_child(MeshFactory.box(Vector3(0.1, 1.5, 0.1), pos + Vector3(0, 0.75, 0), MeshFactory.mat("wood")))
	add_child(MeshFactory.box(Vector3(0.24, 0.28, 0.24), pos + Vector3(0, 1.6, 0), MeshFactory.glow_mat(Color(1.0, 0.72, 0.35), 3.0)))
	add_child(MeshFactory.box(Vector3(0.3, 0.06, 0.3), pos + Vector3(0, 1.77, 0), MeshFactory.mat("wood", Color(0.5, 0.5, 0.5))))
	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.72, 0.4)
	light.light_energy = 1.4
	light.omni_range = 3.0
	light.position = pos + Vector3(0, 1.55, 0)
	add_child(light)


func _bush(pos: Vector3) -> void:
	var leaf := StandardMaterial3D.new()
	leaf.albedo_color = Color(0.22, 0.36, 0.18).lerp(Color(0.3, 0.42, 0.2), _rng.randf())
	leaf.roughness = 0.9
	var size := _rng.randf_range(0.3, 0.5)
	var bush := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = size
	sphere.height = size * 1.4
	bush.mesh = sphere
	bush.material_override = leaf
	bush.position = pos + Vector3(0, size * 0.55, 0)
	add_child(bush)
	if _rng.randf() < 0.3:
		return # บางพุ่มไม่มีดอก
	var petal := StandardMaterial3D.new()
	petal.albedo_color = [Color(0.95, 0.65, 0.72), Color(0.98, 0.92, 0.7), Color(0.85, 0.6, 0.9)][_rng.randi() % 3]
	for i in 6:
		var flower := MeshInstance3D.new()
		var f := SphereMesh.new()
		f.radius = 0.06
		f.height = 0.12
		flower.mesh = f
		flower.material_override = petal
		var a := _rng.randf() * TAU
		flower.position = bush.position + Vector3(cos(a) * size * 0.75, _rng.randf_range(0.0, size * 0.5), sin(a) * size * 0.75)
		add_child(flower)


## ฝุ่น/ละอองแสงลอยอ้อยอิ่งทั่วกระดาน (เรืองแสงจับ Glow)
func _build_motes() -> void:
	var p := GPUParticles3D.new()
	p.amount = 160
	p.lifetime = 9.0
	p.preprocess = 9.0 # มีละอองตั้งแต่เปิดเกม
	p.visibility_aabb = AABB(Vector3(-12, -2, -10), Vector3(24, 8, 22))
	p.position = Vector3(0, 1.3, 0.8)
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(9, 1.4, 7)
	pm.direction = Vector3(0.3, 1, 0)
	pm.spread = 60.0
	pm.initial_velocity_min = 0.03
	pm.initial_velocity_max = 0.12
	pm.gravity = Vector3(0, 0.015, 0)
	pm.turbulence_enabled = true # ลอยวนไปมา
	pm.turbulence_noise_strength = 0.6
	pm.turbulence_noise_scale = 3.0
	pm.scale_min = 0.5
	pm.scale_max = 1.3
	var ramp := Gradient.new() # ค่อย ๆ สว่างขึ้นแล้วจางหาย
	ramp.set_color(0, Color(1, 0.85, 0.55, 0))
	ramp.set_color(1, Color(1, 0.85, 0.55, 0))
	ramp.add_point(0.25, Color(1, 0.88, 0.6, 1))
	ramp.add_point(0.75, Color(1, 0.8, 0.5, 0.8))
	var ramp_tex := GradientTexture1D.new()
	ramp_tex.gradient = ramp
	pm.color_ramp = ramp_tex
	p.process_material = pm
	var quad := QuadMesh.new()
	quad.size = Vector2(0.07, 0.07)
	var dot := GradientTexture2D.new() # จุดกลมขอบนุ่ม
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
	m.albedo_color = Color(1.6, 1.3, 0.9) # เกิน 1 = เรืองแสงผ่าน Glow
	quad.material = m
	p.draw_pass_1 = quad
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(p)

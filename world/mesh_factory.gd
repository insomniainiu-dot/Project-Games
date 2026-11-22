class_name MeshFactory
## ตัวช่วยสร้าง mesh / material ที่ใช้ทั่วทั้งฉาก (เรียกแบบ static ได้จากทุกไฟล์)
##   MeshFactory.box(Vector3(1, 1, 1), pos, MeshFactory.mat("stone"))


## วัสดุจากเท็กซ์เจอร์ใน res://textures/<ชื่อ>.png แบบพิกเซลคม
static func mat(texture_name: String, tint := Color.WHITE) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_texture = load("res://textures/%s.png" % texture_name)
	m.albedo_color = tint
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS # พิกเซลคม
	m.uv1_triplanar = true # แปะเท็กซ์เจอร์ 1 รูปต่อ 1 หน่วย ทุกด้านของกล่อง
	m.roughness = 0.9
	return m


## วัสดุเรืองแสง (energy > 1 จะฟุ้งผ่าน Glow)
static func glow_mat(color: Color, energy: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.emission_enabled = true
	m.emission = color
	m.emission_energy_multiplier = energy
	return m


static func box(size: Vector3, pos: Vector3, material: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = size
	mi.mesh = b
	mi.material_override = material
	mi.position = pos
	return mi


static func cylinder(radius: float, height: float, pos: Vector3, material: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var c := CylinderMesh.new()
	c.top_radius = radius
	c.bottom_radius = radius
	c.height = height
	mi.mesh = c
	mi.material_override = material
	mi.position = pos
	return mi

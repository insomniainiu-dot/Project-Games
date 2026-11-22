class_name Board
extends Node3D
## กระดาน: ผังช่อง + ชนิดช่อง + การแปลงพิกัดกริด <-> โลก 3D
##   var board := Board.new(); add_child(board); board.build(rng)
##   board.neighbors(cell)       # ทิศที่เดินไปได้จากช่องนี้
##   Board.tile_pos(cell)        # ตำแหน่งเท้าตัวละครบนช่อง (static)

const STEP := 1.1          # ระยะห่างระหว่างช่อง (หน่วยโลก 3D)
const TILE_SIZE := 1.0
const TILE_TOP := 0.2      # ความสูงผิวบนของช่อง
const GRID_CENTER := Vector2(3, 1.5) # จุดกึ่งกลางกระดาน (พิกัดกริด)
const NO_TILE := Vector2i(9999, 9999)

const UP := Vector2i(0, -1)
const DOWN := Vector2i(0, 1)
const LEFT := Vector2i(-1, 0)
const RIGHT := Vector2i(1, 0)
const DIRS: Array[Vector2i] = [UP, DOWN, LEFT, RIGHT]

# ช่องปราสาท (จุดเริ่มต้น)
const CASTLE_TILE := Vector2i(3, -2)

var tiles: Dictionary = {}       # Vector2i -> MeshInstance3D
var tile_types: Dictionary = {}  # Vector2i -> "battle"/"gold"/...


## แผนผังกระดาน 30 ช่อง (พิกัดกริด x = ขวา, y = ลงมาทางกล้อง)
##
##                    C            <- ปราสาท (3,-2) จุดเริ่ม
##                    |
##          o--o--o--+--o--o--o     + = ทางแยก 4 ทาง
##          |        |        |
##          o        o        o
##          |        |        |
##    o--o--+        o        +--o--o
##          |        |        |
##          o        o        o
##          |        |        |
##          o--o--o--+--o--o--o
##                   |
##                   o
static func layout() -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	# วงรอบนอก 7x5 (20 ช่อง)
	for x in 7:
		cells.append(Vector2i(x, 0))
		cells.append(Vector2i(x, 4))
	for y in range(1, 4):
		cells.append(Vector2i(0, y))
		cells.append(Vector2i(6, y))
	# ถนนกลางแนวตั้ง (3 ช่อง) -> ทำให้เกิดทางแยก 4 ทางบนและล่าง
	for y in range(1, 4):
		cells.append(Vector2i(3, y))
	# ทางขึ้นไปปราสาท (2 ช่อง)
	cells.append(Vector2i(3, -1))
	cells.append(CASTLE_TILE)
	# ทางลงด้านล่าง (1 ช่อง)
	cells.append(Vector2i(3, 5))
	# ทางแยกซ้าย (2 ช่อง) และขวา (2 ช่อง)
	cells.append(Vector2i(-1, 2))
	cells.append(Vector2i(-2, 2))
	cells.append(Vector2i(7, 2))
	cells.append(Vector2i(8, 2))
	return cells # รวม 30 ช่อง


## สร้างช่องทั้งหมด (rng ใช้ย้อมสีช่องนิด ๆ ให้ดูไม่ซ้ำกัน)
func build(rng: RandomNumberGenerator) -> void:
	var k := 0
	for cell in layout():
		# ชนิดช่อง: ช่องพิเศษตาม GameData ที่เหลือวนตามรูปแบบ
		var type: String
		if GameData.SPECIAL_TILES.has(cell):
			type = GameData.SPECIAL_TILES[cell]
		else:
			type = GameData.TILE_PATTERN[k % GameData.TILE_PATTERN.size()]
			k += 1
		tile_types[cell] = type
		var tint := rng.randf_range(0.92, 1.04)
		# ผสมกับสีหินเดิม ให้สีช่องนุ่มลงแต่ยังแยกชนิดออก
		var color: Color = Color(0.9, 0.86, 0.8).lerp(GameData.TILE_TYPES[type].color, 0.6) * tint
		color.a = 1.0
		var tile := MeshFactory.box(Vector3(TILE_SIZE, TILE_TOP, TILE_SIZE), tile_pos(cell) - Vector3(0, TILE_TOP / 2.0, 0), MeshFactory.mat("stone", color))
		add_child(tile)
		tiles[cell] = tile


func type_of(cell: Vector2i) -> String:
	return tile_types.get(cell, "empty")


## ทิศที่เดินไปได้จากช่องนี้ (เฉพาะทิศที่มีช่องอยู่)
func neighbors(cell: Vector2i) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for d in DIRS:
		if tiles.has(cell + d):
			result.append(d)
	return result


## มีช่องกระดานอยู่ใกล้จุด g (พิกัดกริด) ภายในระยะ dist หรือไม่
func near_tile(g: Vector2, dist: float) -> bool:
	for cell in tiles:
		if g.distance_to(Vector2(cell)) < dist:
			return true
	return false


## จุดกึ่งกลางผิวบนของช่อง (ตำแหน่งเท้าตัวละคร)
static func tile_pos(cell: Vector2i) -> Vector3:
	return grid_to_world(Vector2(cell)) + Vector3(0, TILE_TOP, 0)


static func grid_to_world(g: Vector2) -> Vector3:
	return Vector3((g.x - GRID_CENTER.x) * STEP, 0, (g.y - GRID_CENTER.y) * STEP)

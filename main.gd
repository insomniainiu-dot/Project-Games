extends Node2D

const TILE_SIZE := 100
const TILE_GAP := 10
const BOARD_OFFSET := Vector2(300, 150)

# 12 ช่องรอบขอบสี่เหลี่ยม 4x4
var cells: Array[Vector2i] = [
	Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0), Vector2i(3, 0),
	Vector2i(3, 1), Vector2i(3, 2), Vector2i(3, 3), Vector2i(2, 3),
	Vector2i(1, 3), Vector2i(0, 3), Vector2i(0, 2), Vector2i(0, 1)
]

var token: ColorRect
var dice_label: Label
var position_index := 0


func _ready() -> void:
	# สร้างช่องกระดาน
	for cell in cells:
		var tile := ColorRect.new()
		tile.size = Vector2(TILE_SIZE, TILE_SIZE)
		tile.position = _cell_to_pos(cell)
		tile.color = Color(0.25, 0.45, 0.8)
		add_child(tile)

	# สร้างตัวหมาก
	token = ColorRect.new()
	token.size = Vector2(40, 40)
	token.color = Color.RED
	add_child(token)
	_move_token_to(0)

	# ข้อความแสดงผลเต๋า
	dice_label = Label.new()
	dice_label.position = Vector2(20, 20)
	dice_label.text = "Press Space to roll"
	dice_label.add_theme_font_size_override("font_size", 28)
	add_child(dice_label)


func _cell_to_pos(cell: Vector2i) -> Vector2:
	return BOARD_OFFSET + Vector2(cell) * (TILE_SIZE + TILE_GAP)


func _move_token_to(index: int) -> void:
	position_index = index % cells.size()
	token.position = _cell_to_pos(cells[position_index]) + Vector2(30, 30)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_accept"): # Space หรือ Enter
		var roll := randi_range(1, 6)
		dice_label.text = "Rolled: %d" % roll
		_move_token_to(position_index + roll)

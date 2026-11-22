class_name BoardWalker
extends Node
## เดินตัวละครบนกระดานตามจำนวนก้าว ถ้าเจอทางแยกให้ผู้เล่นเลือกทิศ
## ตำแหน่งบนกระดานเก็บใน PlayerStats (tile / came_from) ไม่ได้เก็บที่นี่
##   await walker.walk(player, witch, 7)

var _board: Board
var _ui: MainUI
var _markers: Array[Node3D] = []


func setup(board: Board, ui: MainUI) -> void:
	_board = board
	_ui = ui


func walk(player: PlayerStats, piece: Witch, steps: int) -> void:
	var first_step := true
	for i in steps:
		_ui.set_steps_text("Steps left: %d" % (steps - i))
		var options := _board.neighbors(player.tile)
		# ห้ามเดินย้อนกลับ ยกเว้นก้าวแรก หรือเจอทางตัน
		if not first_step and options.size() > 1:
			options.erase(player.came_from - player.tile)
		var dir: Vector2i
		if options.size() == 1:
			dir = options[0]
		else:
			piece.end_walk(false)
			dir = await _ask_direction(player.tile, options)
		first_step = false
		if not piece.walking:
			piece.begin_walk()
		player.came_from = player.tile
		player.tile += dir
		await piece.step_to(Board.tile_pos(player.tile))
	piece.end_walk()
	_ui.set_steps_text("Steps left: 0")


func _ask_direction(from: Vector2i, options: Array[Vector2i]) -> Vector2i:
	_ui.append_steps_text("  - Choose a way! (Arrow keys / buttons)")
	for d in options:
		_markers.append(_make_marker(from + d))
	var chosen: Vector2i = await _ui.choose_direction(options)
	for m in _markers:
		m.queue_free()
	_markers.clear()
	return chosen


## ลูกศรเรืองแสงลอยอยู่เหนือช่องที่เลือกได้
func _make_marker(cell: Vector2i) -> Node3D:
	var marker := Node3D.new()
	marker.position = Board.tile_pos(cell) + Vector3(0, 0.55, 0)
	_board.add_child(marker)
	var cone := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.2
	mesh.bottom_radius = 0.0
	mesh.height = 0.35
	cone.mesh = mesh
	cone.material_override = MeshFactory.glow_mat(Color(1.0, 0.85, 0.3), 2.5)
	cone.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	marker.add_child(cone)
	var ring := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.36
	torus.outer_radius = 0.44
	ring.mesh = torus
	ring.material_override = MeshFactory.glow_mat(Color(1.0, 0.85, 0.3), 1.5)
	ring.position = Vector3(0, -0.52, 0)
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	marker.add_child(ring)
	var bob := cone.create_tween().set_loops() # ผูกกับ cone จะหยุดเองเมื่อ marker ถูกลบ
	bob.tween_property(cone, "position:y", 0.15, 0.4).set_trans(Tween.TRANS_SINE)
	bob.tween_property(cone, "position:y", 0.0, 0.4).set_trans(Tween.TRANS_SINE)
	return marker

extends Node2D
## Demo: arrow keys / WASD to walk, release to idle (breathing + blinking).

const SPEED := 40.0

@onready var scout: ScoutSprite = $Scout

func _process(delta: float) -> void:
	var v := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	scout.position += v * SPEED * delta
	scout.set_velocity(v)

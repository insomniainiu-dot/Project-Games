class_name ScoutSprite
extends AnimatedSprite2D
## Pixel scout: idle (breathing) with random blinks + 4-direction walk.
## Call set_state(direction, moving) from your movement code.

const DIRS := ["down", "left", "right", "up"]

@export_enum("down", "left", "right", "up") var facing := "down"
@export var moving := false
## Chance that the next idle breath loop (~2.8 s) contains a blink.
@export_range(0.0, 1.0) var blink_chance := 0.45

func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	animation_looped.connect(_on_animation_looped)
	_refresh()
	# desync multiple characters on screen
	frame = randi() % sprite_frames.get_frame_count(animation)

func set_state(direction: String, is_moving: bool) -> void:
	if direction == facing and is_moving == moving:
		return
	facing = direction
	moving = is_moving
	_refresh()

## Convert a movement vector into a facing + moving state.
func set_velocity(v: Vector2) -> void:
	if v.length_squared() < 0.01:
		set_state(facing, false)
	elif absf(v.x) > absf(v.y):
		set_state("right" if v.x > 0.0 else "left", true)
	else:
		set_state("down" if v.y > 0.0 else "up", true)

func _refresh() -> void:
	play(("walk_" if moving else "idle_") + facing)

func _on_animation_looped() -> void:
	if moving:
		return
	var next := "idle_" + facing
	if facing != "up" and randf() < blink_chance:
		next = "idle_blink_" + facing
	if next != animation:
		play(next)

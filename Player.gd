extends KinematicBody2D
class_name Player

var velocity := Vector2.ZERO

onready var camera = $Sprite/Camera2D
export (float) var FRICTION := 500
export (float) var MAX_SPEED := 80
export (float) var ACCELERATION := FRICTION


func setActive(b: bool):
	visible = b
	camera.current = b


func playerInput(input_vector: Vector2, delta: float):
	if input_vector == Vector2.ZERO:
		velocity = velocity.move_toward(Vector2.ZERO, FRICTION * delta)
	else:
		velocity = velocity.move_toward(input_vector * MAX_SPEED, ACCELERATION * delta)

	velocity = move_and_slide(velocity)

extends Node2D

const MAX_ROTATION_SPEED = 3.0
const ACCELERATION = 10.0
const DAMPING = 3.0

var angular_velocity = 0.0

func _physics_process(delta: float) -> void:
    var direction = Input.get_axis("ui_left", "ui_right")
    angular_velocity += direction * ACCELERATION * delta
    angular_velocity = move_toward(angular_velocity, 0.0, DAMPING * delta)
    angular_velocity = clamp(angular_velocity, -MAX_ROTATION_SPEED, MAX_ROTATION_SPEED)
    rotation += angular_velocity * delta

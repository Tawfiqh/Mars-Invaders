extends CharacterBody2D


const SPEED = 200.0

var uuid: String = ""

func _ready():
	uuid = "rocket-" + str(randi())


func _physics_process(delta):
	var direction = Vector2.UP.rotated(rotation)
	var collision = move_and_collide(direction * SPEED * delta)
	if collision:
		var collider = collision.get_collider()
		if collider.has_method("destroy"):
			collider.destroy()
		queue_free()


func _on_visible_on_screen_notifier_2d_screen_exited():
	queue_free()

func serialize_state() -> Dictionary:
	return {
		"rotation": rotation,
		"position": global_position,
		"uuid": uuid,
	}

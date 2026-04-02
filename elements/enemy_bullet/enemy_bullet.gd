extends CharacterBody2D

var speed = 30.0
var direction = Vector2.DOWN

func _physics_process(delta):
	var collision = move_and_collide(direction * delta * speed)
	if collision:
		var collider = collision.get_collider()
		if collider.has_method("take_damage"):
			collider.take_damage()
		queue_free()


func _on_visible_on_screen_notifier_2d_screen_exited():
	queue_free()

extends CharacterBody2D

var speed = 30.0
var direction = Vector2.DOWN

func _physics_process(delta):
	var collision = move_and_collide(direction * delta * speed)
	if collision:
		_apply_damage(collision.get_collider())
		queue_free()


func _on_visible_on_screen_notifier_2d_screen_exited():
	queue_free()


func _apply_damage(collider: Object) -> void:
	if collider == null:
		return

	var node := collider as Node
	while node != null:
		if node.has_method("take_damage"):
			node.take_damage()
			return
		node = node.get_parent()

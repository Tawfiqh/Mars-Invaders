extends CharacterBody2D


const SPEED = 100.0

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
		_despawn()


func _on_visible_on_screen_notifier_2d_screen_exited():
	_despawn()

func _despawn() -> void:
	if is_queued_for_deletion():
		return
	queue_free()

func serialize_state() -> Dictionary:
	return {
		"rotation": rotation,
		"position": position_to_string(position),
		"uuid": uuid,
	}

func position_to_string(current_position: Vector2) -> String:
	return "%s,%s" % [current_position.x, current_position.y]

func get_position_from_string(state_tuple: String) -> Vector2:
	var parsed_position = Vector2(0, 0)
	var position_parts = state_tuple.split(",")
	if position_parts.size() == 2:
		parsed_position.x = float(position_parts[0])
		parsed_position.y = float(position_parts[1])
	# print("DESERIALIZE ROCKET POSITION: %s" % parsed_position)
	return parsed_position

func deserialize_and_update_state(rocket_state: Dictionary) -> void:
	uuid = rocket_state["uuid"]
	rotation = rocket_state["rotation"]
	position = get_position_from_string(rocket_state["position"])

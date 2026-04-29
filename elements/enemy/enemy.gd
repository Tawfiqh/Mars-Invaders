extends CharacterBody2D

const BULLET_SCENE = preload("res://elements/enemy_bullet/enemy_bullet.tscn")
var enemy_id: String = ""

func _ready():
	enemy_id = "enemy-%s-%s" % [str(Time.get_unix_time_from_system()), str(randi())]


func destroy():
	Globals.change_points(1)
	Events.enemy_died.emit()
	queue_free()

func shot():
	var bullet = BULLET_SCENE.instantiate()
	var planet_center = get_parent().global_position
	var outward = (global_position - planet_center).normalized()
	bullet.global_position = global_position + outward * 10.0
	bullet.direction = outward
	bullet.rotation = outward.angle() - PI / 2.0
	add_child(bullet)


func serialize_state() -> Dictionary:
	return {
		"enemy_id": enemy_id,
		"position_x": position.x,
		"position_y": position.y,
	}


func deserialize_and_update_state(state: Dictionary) -> void:
	enemy_id = String(state.get("enemy_id", enemy_id))
	position = Vector2(
		float(state.get("position_x", position.x)),
		float(state.get("position_y", position.y))
	)

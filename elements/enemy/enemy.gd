extends CharacterBody2D

const BULLET_SCENE = preload("res://elements/enemy_bullet/enemy_bullet.tscn")

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

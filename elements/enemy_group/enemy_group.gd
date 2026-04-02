extends Node2D

const ORBIT_SPEED_BOOST := 0.06

@onready var shot_timer := $ShotTimer

var orbit_speed := 0.4

func _ready():
	Events.enemy_died.connect(_on_enemy_died)

func _process(delta: float):
	rotation += orbit_speed * delta

func _on_enemy_died():
	orbit_speed += ORBIT_SPEED_BOOST

func _on_shot_timer_timeout():
	var enemies = get_tree().get_nodes_in_group("enemy")
	if enemies.size() > 0:
		enemies.pick_random().shot()

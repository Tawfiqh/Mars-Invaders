extends Node2D

const ENEMY_SCENE = preload("res://elements/enemy/enemy.tscn")

const ORBIT_SPEED_BOOST := 0.06
const BASE_ENEMY_COUNT := 12
const POINTS_PER_EXTRA_ENEMY := 6
const MAX_ENEMY_COUNT := 36
const ENEMIES_PER_RING := 6
const FIRST_RING_RADIUS := 60.0
const RING_SPACING := 20.0

@onready var shot_timer := $ShotTimer

var orbit_speed := 0.4


func _ready():
	Events.enemy_died.connect(_on_enemy_died)
	_spawn_enemies()


func _spawn_enemies():
	var extra := floori(float(Globals.points) / POINTS_PER_EXTRA_ENEMY)
	var count := clampi(BASE_ENEMY_COUNT + extra, BASE_ENEMY_COUNT, MAX_ENEMY_COUNT)
	var ring_count := ceili(float(count) / ENEMIES_PER_RING)
	var spawned := 0

	for ring in ring_count:
		var radius := FIRST_RING_RADIUS + ring * RING_SPACING
		var enemies_in_ring := mini(ENEMIES_PER_RING, count - spawned)
		var angle_offset := ring * TAU / ENEMIES_PER_RING / 2.0

		for i in enemies_in_ring:
			var angle := angle_offset + TAU * i / enemies_in_ring
			var enemy := ENEMY_SCENE.instantiate()
			enemy.position = Vector2(cos(angle), sin(angle)) * radius
			add_child(enemy)
			spawned += 1


func _process(delta: float):
	rotation += orbit_speed * delta


func _on_enemy_died():
	orbit_speed += ORBIT_SPEED_BOOST


func _on_shot_timer_timeout():
	var enemies := get_tree().get_nodes_in_group("enemy")
	if enemies.size() > 0:
		enemies.pick_random().shot()

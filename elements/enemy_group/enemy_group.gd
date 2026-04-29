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
var current_enemies: Dictionary = {}

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
			current_enemies[enemy.enemy_id] = enemy


func _process(delta: float):
	# rotation += orbit_speed * delta
	pass

func _on_enemy_died():
	orbit_speed += ORBIT_SPEED_BOOST


func _on_shot_timer_timeout():
	var enemies := get_tree().get_nodes_in_group("enemy")
	if enemies.size() > 0:
		enemies.pick_random().shot()


func serialize_state() -> Dictionary:
	var enemies_state: Array[Dictionary] = []
	for enemy_id in current_enemies:
		var enemy = current_enemies[enemy_id]
		# print("Enemy serialize: %s --xxx ==> %s" % [enemy_id, enemy])
		if !is_instance_valid(enemy) or enemy.get_parent() != self: # if it has been deleted
			current_enemies.erase(enemy_id)
			continue
		enemies_state.append(enemy.serialize_state())

	return {
		"rotation": rotation,
		"orbit_speed": orbit_speed,
		"enemies": enemies_state,
	}

func spawn_enemy(enemy_id: String) -> CharacterBody2D:
	var enemy = ENEMY_SCENE.instantiate()
	add_child(enemy)
	enemy.enemy_id = enemy_id
	current_enemies[enemy_id] = enemy
	return enemy

func upsert_enemy(enemy_id: String, enemy_state: Dictionary) -> void:
	 # Get enemy with ID - if the enemy doesn't exist, spawn it
	var local_enemy = current_enemies.get(enemy_id, null)
	if local_enemy == null:
		local_enemy = spawn_enemy(enemy_id) # cant do this inside the get statement as it would always be called
	local_enemy.deserialize_and_update_state(enemy_state)

func deserialize_and_update_state(group_state: Dictionary) -> void:
	rotation = float(group_state.get("rotation", rotation))
	orbit_speed = float(group_state.get("orbit_speed", orbit_speed))
	print("\n\n\nDESERIALIZE AND UPDATE STATE")

	var enemies_state: Array = group_state.get("enemies", [])
	# print("ENEMIES STATE: %s" % enemies_state)
	var incoming_ids: Dictionary = {}
	
	# Iterate incoming enemies
	for enemy_state in enemies_state:
		# Get current incoming enemy ID
		var incoming_id := String(enemy_state.get("enemy_id", ""))
		# Skip if the enemy ID is empty
		if incoming_id == "":
			push_warning("Received enemy state without enemy_id; skipping.")
			continue
		
		# Add the enemy to the map and update
		print("Adding incoming enemy: %s" % incoming_id)
		incoming_ids[incoming_id] = true
		upsert_enemy(incoming_id, enemy_state)


	print("\n")
	for incoming_id in incoming_ids:
		print("Incoming ID: %s" % incoming_id)
	print("\n")
	for enemy_id in current_enemies:
		print("Current enemy: %s" % enemy_id)

	# Get rid of local enemies that are not in the incoming state
	var enemies_to_remove: Array[String] = []
	for enemy_id in current_enemies:
		if not incoming_ids.has(enemy_id):
			enemies_to_remove.append(enemy_id)
			# Dont mutate the dictionary while iterating over it 
			# can cause undefined behavior

	for enemy_id in enemies_to_remove:
		var stale_enemy = current_enemies[enemy_id]
		if is_instance_valid(stale_enemy):
			print("Removing stale enemy: %s" % enemy_id)
			stale_enemy.queue_free()
		current_enemies.erase(enemy_id)

	print("\n\n\n")

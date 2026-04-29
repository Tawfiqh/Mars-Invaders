extends Node2D

const ROCKET_SCENE = preload("res://elements/rocket/rocket.tscn")

const SPEED = 300.0
var color: Color
var rockets: Dictionary = {}
var player_name: String = ""


@onready var spaceShip = $SpaceShip
## When true, this ship is controlled by another machine — no local input or random colour.
var is_remote: bool = false

func _ready():
	if not is_remote:
		player_name = Globals._pick_random_names()
		random_color()

func random_color():
	color = Color.from_hsv(randf(), 1.0, 1.0)
	spaceShip.modulate = color

func set_player_color(newColor: Color):
	color = newColor
	spaceShip.modulate = color

	
func _physics_process(delta: float):
	if is_remote:
		return
	if Input.is_action_just_pressed("ui_accept"):
		shot()

	_manage_rotation(delta)
	#_manage_movementXy(delta) #TBC - this doesn't work great


func _manage_movementXy(delta: float) -> void:
	# var directionX = Input.get_axis("ui_left", "ui_right")
	# velocity.x = directionX * SPEED
	var directionY = Input.get_axis("ui_up", "ui_down")
	spaceShip.velocity.y = directionY * SPEED
	spaceShip.move_and_slide()

func shot():
	var rocket = ROCKET_SCENE.instantiate()
	var offset = Vector2.UP.rotated(rotation) * 30.0
	rocket.global_position = spaceShip.global_position + offset
	rocket.rotation = rotation
	add_child(rocket)
	rockets[rocket.uuid] = rocket

func take_damage():
	Globals.change_lives(-1)


# Number of discrete positions around the circle
const STEPS = 128
const STEP_ANGLE = TAU / STEPS

# Seconds between each step tick (lower = faster)
const TICK_INTERVAL = 0.12
const ACCELERATION = 16.0
const DAMPING = 3.0
const MAX_SPEED = 3.0

var angular_velocity = 0.0
var tick_timer = 0.0
var current_step = 0

func _manage_rotation(delta: float) -> void:
	var direction = Input.get_axis("ui_left", "ui_right")

	angular_velocity += direction * ACCELERATION * delta
	angular_velocity = move_toward(angular_velocity, 0.0, DAMPING * delta)
	angular_velocity = clamp(angular_velocity, -MAX_SPEED, MAX_SPEED)

	tick_timer += abs(angular_velocity) * delta
	if tick_timer >= TICK_INTERVAL:
		tick_timer = fmod(tick_timer, TICK_INTERVAL)
		if angular_velocity > 0.0:
			current_step += 1
		elif angular_velocity < 0.0:
			current_step -= 1
		current_step = posmod(current_step, STEPS)
		rotation = current_step * STEP_ANGLE

# -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
# Serialize for multiplayer
# -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
# Serialize the current state of the player ship for sending to the server / client
func serialize_state() -> Dictionary:
	var rocket_states: Array[Dictionary] = []
	for rocket_id in rockets:
		var rocket = rockets[rocket_id]
		if rocket == null:
			rockets.erase(rocket)
			continue

		rocket_states.append(rocket.serialize_state())

	return {
		"rotation": rotation,
		"color": color.to_html(),
		"name": player_name,
		"rockets": rocket_states
	}

func deserialize_and_update_state(player_state: Dictionary) -> void:
	rotation = player_state["rotation"]
	color = Color(player_state["color"])
	spaceShip.modulate = color

	for rocket_state in player_state["rockets"]:
		var remote_uuid: String = rocket_state.get("uuid", "")
		var existing_rocket = rockets.get(remote_uuid, null)

		if existing_rocket == null: # if it doesn't exist, add it as a child
			var rocket = ROCKET_SCENE.instantiate()
			add_child(rocket)
			rocket.deserialize_and_update_state(rocket_state)
			rockets[remote_uuid] = rocket
		else: # if it exists, update it
			existing_rocket.deserialize_and_update_state(rocket_state)

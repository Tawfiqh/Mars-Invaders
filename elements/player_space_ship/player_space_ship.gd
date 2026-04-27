extends Node2D

const ROCKET_SCENE = preload("res://elements/rocket/rocket.tscn")

const SPEED = 300.0
var color: Color
var rockets: Array[Node2D] = []

## When true, this ship is controlled by another machine — no local input or random colour.
var is_remote: bool = false

func _ready():
	if not is_remote:
		random_color()

func random_color():
	color = Color.from_hsv(randf(), 1.0, 1.0)
	$SpaceShip.modulate = color

func set_player_color(newColor: Color):
	color = newColor
	$SpaceShip.modulate = color

	
func _physics_process(delta: float):
	if is_remote:
		return
	if Input.is_action_just_pressed("ui_accept"):
		shot()

	_manage_pivot(delta)
	#_manage_movementXy(delta) #TBC - this doesn't work great


func _manage_movementXy(delta: float) -> void:
	# var directionX = Input.get_axis("ui_left", "ui_right")
	# velocity.x = directionX * SPEED
	var directionY = Input.get_axis("ui_up", "ui_down")
	$SpaceShip.velocity.y = directionY * SPEED
	$SpaceShip.move_and_slide()

func shot():
	var rocket = ROCKET_SCENE.instantiate()
	var offset = Vector2.UP.rotated(rotation) * 30.0
	rocket.global_position = $SpaceShip.global_position + offset
	rocket.rotation = rotation
	add_child(rocket)
	rockets.append(rocket)

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

func _manage_pivot(delta: float) -> void:
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
	for rocket in rockets:
		if rocket == null:
			rockets.erase(rocket)
			continue
		print("SERIALIZE ROCKET: %s" % rocket.serialize_state())
		rocket_states.append(rocket.serialize_state())

	return {
		"rotation": rotation,
		"color": color.to_html(),
		"rockets": rocket_states
	}

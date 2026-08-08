extends CanvasLayer

@onready var _turn_left: Button = %TurnLeft
@onready var _turn_right: Button = %TurnRight
@onready var _fire: Button = %Fire

var _steer_left := false
var _steer_right := false
var _fire_held := false


func _ready() -> void:
	_turn_left.button_down.connect(func(): _steer_left = true)
	_turn_left.button_up.connect(func(): _steer_left = false)
	_turn_left.mouse_exited.connect(func(): _steer_left = false)
	_turn_right.button_down.connect(func(): _steer_right = true)
	_turn_right.button_up.connect(func(): _steer_right = false)
	_turn_right.mouse_exited.connect(func(): _steer_right = false)
	_fire.button_down.connect(func(): _fire_held = true)
	_fire.button_up.connect(func(): _fire_held = false)
	_fire.mouse_exited.connect(func(): _fire_held = false)


func _process(_delta: float) -> void:
	if not visible:
		Globals.touch_steer_axis = 0.0
		Globals.touch_fire_held = false
		return
	var steer := 0.0
	if _steer_left:
		steer -= 1.0
	if _steer_right:
		steer += 1.0
	Globals.touch_steer_axis = clampf(steer, -1.0, 1.0)
	Globals.touch_fire_held = _fire_held

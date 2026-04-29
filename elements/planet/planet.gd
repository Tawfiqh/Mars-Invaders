extends StaticBody2D

const FRAME_SIZE := Vector2i(100, 100)
const ANIMATION_SPEED := 9.0

const SPRITESHEET_PATHS := [
	"res://elements/planet/Galaxy - 2886578410 - spritesheet.png",
	"res://elements/planet/Ice World - 2886578410 - spritesheet.png",
	"res://elements/planet/Islands - 2886578410 - spritesheet.png",
	"res://elements/planet/Lava World - 2886578410 - spritesheet.png",
	"res://elements/planet/No atmosphere - 2886578410 - spritesheet.png",
	# "res://elements/planet/Star - 3407897484 - spritesheet.png",
	# "res://elements/planet/Star - 3638633701 - spritesheet.png",
	"res://elements/planet/Terran Dry - 4256354238 - spritesheet.png",
	"res://elements/planet/Terran Wet - 2886578410 - spritesheet.png",
]

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
var _spritesheet_path: String = ""


func _ready() -> void:
	set_spritesheet_path(SPRITESHEET_PATHS.pick_random())


func set_spritesheet_path(path: String) -> void:
	_spritesheet_path = path
	var atlas: Texture2D = load(path)
	animated_sprite.sprite_frames = _build_sprite_frames(atlas)
	animated_sprite.play("default")


func _build_sprite_frames(atlas: Texture2D) -> SpriteFrames:
	var frames := SpriteFrames.new()
	frames.set_animation_loop("default", true)
	frames.set_animation_speed("default", ANIMATION_SPEED)

	var cols := int(atlas.get_width() / float(FRAME_SIZE.x))
	var rows := int(atlas.get_height() / float(FRAME_SIZE.y))

	for row in rows:
		for col in cols:
			var frame_texture := AtlasTexture.new()
			frame_texture.atlas = atlas
			frame_texture.region = Rect2(
				col * FRAME_SIZE.x, row * FRAME_SIZE.y,
				FRAME_SIZE.x, FRAME_SIZE.y
			)
			frames.add_frame("default", frame_texture)

	return frames


func serialize_state() -> Dictionary:
	return {
		"spritesheet_path": _spritesheet_path,
		"position_x": global_position.x,
		"position_y": global_position.y,
	}


func deserialize_and_update_state(planet_state: Dictionary) -> void:
	var path := String(planet_state.get("spritesheet_path", ""))
	if path != "" and path != _spritesheet_path:
		set_spritesheet_path(path)
	global_position = Vector2(
		float(planet_state.get("position_x", global_position.x)),
		float(planet_state.get("position_y", global_position.y))
	)

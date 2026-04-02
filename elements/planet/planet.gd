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


func _ready() -> void:
	var atlas: Texture2D = load(SPRITESHEET_PATHS.pick_random())
	animated_sprite.sprite_frames = _build_sprite_frames(atlas)
	animated_sprite.play("default")


func _build_sprite_frames(atlas: Texture2D) -> SpriteFrames:
	var frames := SpriteFrames.new()
	frames.set_animation_loop("default", true)
	frames.set_animation_speed("default", ANIMATION_SPEED)

	var cols := atlas.get_width() / FRAME_SIZE.x
	var rows := atlas.get_height() / FRAME_SIZE.y

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

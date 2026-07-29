extends EnemyBase

const IDLE_SHEET: Texture2D = preload(
	"res://Assets/sprites/soldier-sprite-sheets-pixel-art/Soldier_1/Idle.png"
)
const WALK_SHEET: Texture2D = preload(
	"res://Assets/sprites/soldier-sprite-sheets-pixel-art/Soldier_1/Walk.png"
)
const SHOT_1_SHEET: Texture2D = preload(
	"res://Assets/sprites/soldier-sprite-sheets-pixel-art/Soldier_1/Shot_1.png"
)
const SHOT_2_SHEET: Texture2D = preload(
	"res://Assets/sprites/soldier-sprite-sheets-pixel-art/Soldier_1/Shot_2.png"
)
const HURT_SHEET: Texture2D = preload(
	"res://Assets/sprites/soldier-sprite-sheets-pixel-art/Soldier_1/Hurt.png"
)
const DEATH_SHEET: Texture2D = preload(
	"res://Assets/sprites/soldier-sprite-sheets-pixel-art/Soldier_1/Dead.png"
)
const EXPLOSION_SHEET: Texture2D = preload(
	"res://Assets/sprites/soldier-sprite-sheets-pixel-art/Soldier_1/Explosion.png"
)

const FRAME_SIZE := Vector2i(128, 128)


func _ready() -> void:
	_build_animation_library()
	super._ready()


func _build_animation_library() -> void:
	var soldier_frames := SpriteFrames.new()
	soldier_frames.remove_animation(&"default")
	_add_strip(soldier_frames, &"Idle", IDLE_SHEET, 7, 9.0, true)
	_add_strip(soldier_frames, &"Forward", WALK_SHEET, 7, 12.0, true)
	_add_strip(soldier_frames, &"Fire1", SHOT_1_SHEET, 4, 14.0, false)
	_add_strip(soldier_frames, &"Fire2", SHOT_2_SHEET, 4, 14.0, false)
	_add_strip(soldier_frames, &"Hurt", HURT_SHEET, 3, 14.0, false)
	_add_strip(soldier_frames, &"Death", DEATH_SHEET, 4, 11.0, false)
	sprite.sprite_frames = soldier_frames

	if explosion_sprite == null:
		return

	var explosion_frames := SpriteFrames.new()
	explosion_frames.remove_animation(&"default")
	_add_strip(explosion_frames, &"Explosion", EXPLOSION_SHEET, 9, 18.0, false)
	explosion_sprite.sprite_frames = explosion_frames


func _add_strip(
	frames: SpriteFrames,
	animation_name: StringName,
	sheet: Texture2D,
	frame_count: int,
	fps: float,
	loops: bool
) -> void:
	frames.add_animation(animation_name)
	frames.set_animation_speed(animation_name, fps)
	frames.set_animation_loop(animation_name, loops)

	for frame_index in frame_count:
		var frame := AtlasTexture.new()
		frame.atlas = sheet
		frame.region = Rect2(
			frame_index * FRAME_SIZE.x,
			0,
			FRAME_SIZE.x,
			FRAME_SIZE.y
		)
		frames.add_frame(animation_name, frame)

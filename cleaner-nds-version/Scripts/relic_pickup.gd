extends Area2D
class_name RelicPickup

signal collected(upgrade_name: StringName)

@export var upgrade_name: StringName = &"double_jump"
@export var target_group: StringName = &"player"
@export var pickup_animation: StringName = &"default"
@export var remove_if_already_collected: bool = true

@onready var relic_sprite: Sprite2D = get_node_or_null("Sprite2D")
@onready var pickup_effect: AnimatedSprite2D = get_node_or_null("AnimatedSprite2D")
@onready var collision: CollisionShape2D = get_node_or_null("CollisionShape2D")
@onready var audio: AudioStreamPlayer = get_node_or_null("AudioStreamPlayer")

var _collected: bool = false


func _ready() -> void:
	if PlayerState.has_upgrade(upgrade_name):
		_collected = true
		if remove_if_already_collected:
			queue_free()
		return

	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)

	if pickup_effect != null:
		pickup_effect.stop()
		pickup_effect.set_frame_and_progress(0, 0.0)
		pickup_effect.visible = false


func _on_body_entered(body: Node) -> void:
	if _collected or not body.is_in_group(target_group):
		return

	# PlayerState is the source of truth. Its signal immediately gives the
	# power to the player and refreshes any collection displays.
	if not PlayerState.unlock_upgrade(upgrade_name):
		if PlayerState.has_upgrade(upgrade_name):
			queue_free()
		return

	_collected = true
	collected.emit(upgrade_name)
	_play_collection_effect()


func _play_collection_effect() -> void:
	set_deferred("monitoring", false)
	if collision != null:
		collision.set_deferred("disabled", true)
	if relic_sprite != null:
		relic_sprite.visible = false

	var effect_duration := 0.0

	if audio != null and audio.stream != null:
		audio.play()
		effect_duration = maxf(effect_duration, audio.stream.get_length())

	if pickup_effect != null and pickup_effect.sprite_frames != null:
		pickup_effect.visible = true
		var animation := pickup_animation
		if not pickup_effect.sprite_frames.has_animation(animation):
			var animation_names := pickup_effect.sprite_frames.get_animation_names()
			if not animation_names.is_empty():
				animation = animation_names[0]
		if pickup_effect.sprite_frames.has_animation(animation):
			pickup_effect.play(animation)
			effect_duration = maxf(effect_duration, _get_animation_duration(pickup_effect, animation))

	if effect_duration > 0.0:
		await get_tree().create_timer(effect_duration).timeout

	queue_free()


func _get_animation_duration(sprite: AnimatedSprite2D, animation: StringName) -> float:
	var frames := sprite.sprite_frames
	var speed := frames.get_animation_speed(animation) * absf(sprite.speed_scale)
	if speed <= 0.0:
		return 0.0

	var duration := 0.0
	for frame_index in frames.get_frame_count(animation):
		duration += frames.get_frame_duration(animation, frame_index) / speed
	return duration

extends Area2D
class_name HealthPickup

@export var target_group: StringName = &"player"
@export var one_shot: bool = true
@export var sparkle_anim_name: StringName = &"pickup"

@onready var audio: AudioStreamPlayer = $AudioStreamPlayer
@onready var collision: CollisionShape2D = $CollisionShape2D
@onready var sprite: Sprite2D = $Sprite2D
@onready var sparkle: AnimatedSprite2D = $AnimatedSprite2D

var _collected: bool = false

func _ready() -> void:
	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)

	if sparkle != null:
		sparkle.visible = false

func _on_body_entered(body: Node) -> void:
	if _collected:
		return

	if not body.is_in_group(target_group):
		return

	var health: Health = _find_health(body)
	if health == null:
		return

	_restore_to_max(health)
	_collect()

func _find_health(body: Node) -> Health:
	var health_node := body.get_node_or_null("Health")
	if health_node is Health:
		return health_node as Health

	for child in body.get_children():
		if child is Health:
			return child as Health

	return null

func _restore_to_max(health: Health) -> void:
	health.restore_full()

func _collect() -> void:
	_collected = true

	if collision != null:
		collision.set_deferred("disabled", true)

	if sprite != null:
		sprite.visible = false

	if audio != null and audio.stream != null:
		audio.play()

	if sparkle != null and sparkle.sprite_frames != null:
		sparkle.visible = true

		if sparkle.sprite_frames.has_animation(sparkle_anim_name):
			sparkle.play(sparkle_anim_name)
		else:
			sparkle.play()

		if one_shot:
			await sparkle.animation_finished
			queue_free()
	else:
		if one_shot:
			queue_free()

extends Area2D
class_name SpecialMeterPickup

@export var target_group: StringName = &"player"
@export_range(0.0, 1.0, 0.01) var recharge_ratio: float = 0.25
@export var one_shot: bool = true
@export var sparkle_anim_name: StringName = &"default"

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

	if not body.has_method("add_special_meter"):
		return

	var recharge_amount := _get_recharge_amount(body)
	if recharge_amount <= 0:
		return

	body.call("add_special_meter", recharge_amount)
	_collect()


func _get_recharge_amount(body: Node) -> int:
	var maximum_value: Variant = body.get("special_meter_max")
	if maximum_value == null:
		return 0

	var maximum := int(maximum_value)
	if maximum <= 0:
		return 0

	return maxi(1, roundi(float(maximum) * recharge_ratio))


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

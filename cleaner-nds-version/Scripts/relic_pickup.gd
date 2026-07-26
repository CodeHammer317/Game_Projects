extends Area2D
class_name RelicPickup

signal collected(upgrade_name: StringName)

@export_group("Relic Data")
@export var upgrade_name: StringName = &"double_jump"
@export var relic_title: String = "RAVEN'S WINGS"
@export var relic_classification: String = "MOVEMENT RELIC // NEPHILIM ORIGIN"
@export_multiline var relic_specs: String = """ABILITY // DOUBLE JUMP
TRIGGER // JUMP WHILE AIRBORNE
BOND STATUS // STABLE"""

@export_group("Interaction")
@export var target_group: StringName = &"player"
@export var pickup_animation: StringName = &"default"
@export var remove_if_already_collected: bool = true
@export var close_actions: Array[StringName] = [&"accept", &"attack", &"pause"]
@export var score_value: int = 1000

@export_group("Presentation")
@export var glow_energy: float = 1.15
@export var glow_pulse_amount: float = 0.22
@export var glow_pulse_speed: float = 2.6
@export var beacon_interval: float = 2.4
@export var beacon_flash_energy: float = 3.4
@export var beacon_scale_amount: float = 0.35
@export var marker_fps: float = 18.0
@export var marker_bob_amount: float = 5.0
@export var marker_bob_speed: float = 2.4

@onready var relic_sprite: Sprite2D = get_node_or_null("Sprite2D")
@onready var relic_glow: PointLight2D = get_node_or_null("RelicGlow")
@onready var question_marker: Sprite2D = get_node_or_null("QuestionMarker")
@onready var pickup_effect: AnimatedSprite2D = get_node_or_null("AnimatedSprite2D")
@onready var collision: CollisionShape2D = get_node_or_null("CollisionShape2D")
@onready var audio: AudioStreamPlayer = get_node_or_null("AudioStreamPlayer")
@onready var card_root: Control = get_node_or_null("RelicCardLayer/RelicCardRoot")
@onready var card_icon: TextureRect = get_node_or_null(
	"RelicCardLayer/RelicCardRoot/CenterContainer/CardPanel/CardMargin/CardContent/Body/Icon"
)
@onready var card_classification: Label = get_node_or_null(
	"RelicCardLayer/RelicCardRoot/CenterContainer/CardPanel/CardMargin/CardContent/Classification"
)
@onready var card_title: Label = get_node_or_null(
	"RelicCardLayer/RelicCardRoot/CenterContainer/CardPanel/CardMargin/CardContent/Title"
)
@onready var card_effect: Label = get_node_or_null(
	"RelicCardLayer/RelicCardRoot/CenterContainer/CardPanel/CardMargin/CardContent/Body/Specs/Effect"
)
@onready var card_specs: Label = get_node_or_null(
	"RelicCardLayer/RelicCardRoot/CenterContainer/CardPanel/CardMargin/CardContent/Body/Specs/Details"
)

var _collected: bool = false
var _card_open: bool = false
var _collecting_player: Node = null
var _beacon_elapsed: float = 0.0
var _glow_base_texture_scale: float = 1.0
var _marker_elapsed: float = 0.0
var _marker_base_position: Vector2 = Vector2.ZERO


func _ready() -> void:
	if PlayerState.has_upgrade(upgrade_name):
		_collected = true
		if remove_if_already_collected:
			queue_free()
		return

	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)

	if relic_sprite != null:
		relic_sprite.visible = false
	if relic_glow != null:
		relic_glow.visible = true
		relic_glow.energy = glow_energy
		_glow_base_texture_scale = relic_glow.texture_scale
		# Start with a quick beacon so the relic is noticeable on room entry.
		_beacon_elapsed = maxf(beacon_interval - 0.45, 0.0)
	if question_marker != null:
		question_marker.visible = true
		_marker_base_position = question_marker.position
		_update_question_marker_frame(0)
	if pickup_effect != null:
		pickup_effect.stop()
		pickup_effect.set_frame_and_progress(0, 0.0)
		pickup_effect.visible = false
	if card_root != null:
		card_root.visible = false


func _process(delta: float) -> void:
	if question_marker != null and question_marker.visible:
		_marker_elapsed += delta
		var marker_frame := int(_marker_elapsed * marker_fps) % 30
		_update_question_marker_frame(marker_frame)
		question_marker.position.y = (
			_marker_base_position.y
			+ sin(_marker_elapsed * marker_bob_speed) * marker_bob_amount
		)

	if relic_glow == null or not relic_glow.visible:
		return

	var seconds := Time.get_ticks_msec() / 1000.0
	var ambient_pulse := sin(seconds * glow_pulse_speed) * glow_pulse_amount
	var beacon_strength := 0.0

	if beacon_interval > 0.0:
		_beacon_elapsed = fmod(_beacon_elapsed + delta, beacon_interval)
		# A sharp primary flash followed by a softer echo makes the pickup read
		# like a deliberate beacon instead of another ambient room light.
		beacon_strength += _flash_pulse(_beacon_elapsed, 0.00, 0.18)
		beacon_strength += _flash_pulse(_beacon_elapsed, 0.28, 0.14) * 0.55

	relic_glow.energy = glow_energy + ambient_pulse + beacon_strength * beacon_flash_energy
	relic_glow.texture_scale = _glow_base_texture_scale + beacon_strength * beacon_scale_amount


func _flash_pulse(elapsed: float, start_time: float, duration: float) -> float:
	if duration <= 0.0 or elapsed < start_time or elapsed > start_time + duration:
		return 0.0

	var progress := (elapsed - start_time) / duration
	return sin(progress * PI)


func _update_question_marker_frame(frame_index: int) -> void:
	if question_marker == null:
		return

	var frame_x := frame_index % 10
	var frame_y := frame_index / 10
	question_marker.region_rect = Rect2(frame_x * 48, frame_y * 48, 48, 48)


func _unhandled_input(event: InputEvent) -> void:
	if not _card_open:
		return

	for action in close_actions:
		if event.is_action_pressed(action):
			_close_relic_card()
			get_viewport().set_input_as_handled()
			return


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
	ScoreManager.award_pickup(self, score_value)
	collected.emit(upgrade_name)
	_reveal_relic(body)


func _reveal_relic(player: Node) -> void:
	set_deferred("monitoring", false)
	if collision != null:
		collision.set_deferred("disabled", true)

	_collecting_player = player
	_card_open = true

	if relic_sprite != null:
		relic_sprite.visible = true
		relic_sprite.modulate.a = 0.0
		var reveal_tween := create_tween()
		reveal_tween.tween_property(relic_sprite, "modulate:a", 1.0, 0.35)

	if relic_glow != null:
		relic_glow.energy = glow_energy + glow_pulse_amount * 2.0
	if question_marker != null:
		question_marker.visible = false

	_populate_relic_card()
	if card_root != null:
		card_root.visible = true
		card_root.modulate.a = 0.0
		var card_tween := create_tween()
		card_tween.tween_property(card_root, "modulate:a", 1.0, 0.25)

	if player.has_method("set_control_locked"):
		player.call("set_control_locked", true)

	if audio != null and audio.stream != null:
		audio.play()


func _populate_relic_card() -> void:
	var display_name := PlayerState.get_upgrade_display_name(upgrade_name)
	var description := PlayerState.get_upgrade_description(upgrade_name)

	if card_icon != null and relic_sprite != null:
		card_icon.texture = relic_sprite.texture
	if card_classification != null:
		card_classification.text = relic_classification
	if card_title != null:
		card_title.text = relic_title if not relic_title.is_empty() else display_name.to_upper()
	if card_effect != null:
		card_effect.text = "UNLOCKED // " + display_name.to_upper()
	if card_specs != null:
		card_specs.text = description + "\n\n" + relic_specs


func _close_relic_card() -> void:
	if not _card_open:
		return

	_card_open = false
	if card_root != null:
		card_root.visible = false

	if _collecting_player != null and is_instance_valid(_collecting_player):
		if _collecting_player.has_method("set_control_locked"):
			_collecting_player.call("set_control_locked", false)

	_collecting_player = null
	_play_collection_effect()


func _play_collection_effect() -> void:
	set_deferred("monitoring", false)
	if collision != null:
		collision.set_deferred("disabled", true)
	if relic_sprite != null:
		relic_sprite.visible = false
	if relic_glow != null:
		relic_glow.visible = false
	if question_marker != null:
		question_marker.visible = false

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


func _exit_tree() -> void:
	if _card_open and _collecting_player != null and is_instance_valid(_collecting_player):
		if _collecting_player.has_method("set_control_locked"):
			_collecting_player.call("set_control_locked", false)


func _get_animation_duration(sprite: AnimatedSprite2D, animation: StringName) -> float:
	var frames := sprite.sprite_frames
	var speed := frames.get_animation_speed(animation) * absf(sprite.speed_scale)
	if speed <= 0.0:
		return 0.0

	var duration := 0.0
	for frame_index in frames.get_frame_count(animation):
		duration += frames.get_frame_duration(animation, frame_index) / speed
	return duration

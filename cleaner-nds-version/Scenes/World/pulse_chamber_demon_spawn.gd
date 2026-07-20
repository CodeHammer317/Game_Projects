extends AnimatedSprite2D

@export var demon_path: NodePath = NodePath("../GlitchDemon")
@export var player_path: NodePath = NodePath("../Player")
@export var spawn_delay: float = 4.0
@export_range(0.1, 2.0, 0.05) var pulse_playback_scale: float = 0.4

@onready var demon: Node2D = get_node_or_null(demon_path) as Node2D

var materialization_started: bool = false
var demon_collision_shapes: Array[CollisionShape2D] = []


func _ready() -> void:
	stop()
	visible = false
	speed_scale = pulse_playback_scale
	_prepare_demon()
	frame_changed.connect(_on_pulse_frame_changed)
	animation_finished.connect(_on_pulse_finished)
	_begin_spawn_sequence()


func _begin_spawn_sequence() -> void:
	await _wait_for_player()
	await get_tree().create_timer(spawn_delay).timeout
	visible = true
	frame = 0
	frame_progress = 0.0
	play(&"default")


func _wait_for_player() -> void:
	while get_node_or_null(player_path) == null and get_tree().get_first_node_in_group(&"player") == null:
		await get_tree().process_frame


func _prepare_demon() -> void:
	if demon == null:
		push_warning("Pulse cannot materialize GlitchDemon: demon_path is invalid.")
		return
	demon.visible = false
	demon.modulate.a = 0.0
	demon.process_mode = Node.PROCESS_MODE_DISABLED
	_collect_collision_shapes(demon)
	_set_demon_collisions_disabled(true)


func _collect_collision_shapes(node: Node) -> void:
	for child in node.get_children():
		if child is CollisionShape2D:
			demon_collision_shapes.append(child as CollisionShape2D)
		_collect_collision_shapes(child)


func _set_demon_collisions_disabled(disabled: bool) -> void:
	for shape in demon_collision_shapes:
		shape.set_deferred("disabled", disabled)


func _on_pulse_frame_changed() -> void:
	if materialization_started or not is_playing():
		return
	var frame_count: int = sprite_frames.get_frame_count(animation)
	if frame >= frame_count / 2:
		_materialize_demon(frame_count)


func _materialize_demon(frame_count: int) -> void:
	materialization_started = true
	if demon == null:
		return
	demon.visible = true
	demon.modulate.a = 0.0

	var frames_remaining: int = maxi(frame_count - frame, 1)
	var animation_speed: float = sprite_frames.get_animation_speed(animation) * speed_scale
	var fade_duration: float = frames_remaining / maxf(animation_speed, 0.01)
	var materialize_tween: Tween = create_tween()
	materialize_tween.set_trans(Tween.TRANS_SINE)
	materialize_tween.set_ease(Tween.EASE_OUT)
	materialize_tween.tween_property(demon, "modulate:a", 1.0, fade_duration)
	materialize_tween.tween_callback(_activate_demon)


func _activate_demon() -> void:
	if demon == null:
		return
	demon.modulate.a = 1.0
	demon.process_mode = Node.PROCESS_MODE_INHERIT
	_set_demon_collisions_disabled(false)


func _on_pulse_finished() -> void:
	visible = false

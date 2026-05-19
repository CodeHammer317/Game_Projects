extends Node
class_name CombatFX

var _shake_camera: Camera2D = null
var _shake_time_left: float = 0.0
var _shake_strength: float = 0.0
var _shake_decay: float = 0.0
var _base_offset: Vector2 = Vector2.ZERO

var _hitstop_active: bool = false


func _process(delta: float) -> void:
	_update_camera_shake(delta)


func hitstop(duration: float = 0.05, slow_scale: float = 0.05) -> void:
	if _hitstop_active:
		return

	_hitstop_active = true
	_do_hitstop(duration, slow_scale)


func register_camera(cam: Camera2D) -> void:
	_shake_camera = cam
	if _shake_camera != null:
		_base_offset = _shake_camera.offset


func shake(strength: float = 4.0, duration: float = 0.12, decay: float = 30.0) -> void:
	_shake_strength = max(_shake_strength, strength)
	_shake_time_left = max(_shake_time_left, duration)
	_shake_decay = decay


func _do_hitstop(duration: float, slow_scale: float) -> void:
	_run_hitstop(duration, slow_scale)


func _run_hitstop(duration: float, slow_scale: float) -> void:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		_hitstop_active = false
		return

	var old_scale := Engine.time_scale
	Engine.time_scale = slow_scale

	await tree.create_timer(duration * max(old_scale, 0.001), true, false, true).timeout

	Engine.time_scale = old_scale
	_hitstop_active = false


func _update_camera_shake(delta: float) -> void:
	if _shake_camera == null or not is_instance_valid(_shake_camera):
		return

	if _shake_time_left > 0.0:
		_shake_time_left = max(_shake_time_left - delta, 0.0)

		var offset := Vector2(
			randf_range(-_shake_strength, _shake_strength),
			randf_range(-_shake_strength, _shake_strength)
		)

		offset = offset.round()
		_shake_camera.offset = _base_offset + offset
		_shake_strength = move_toward(_shake_strength, 0.0, _shake_decay * delta)
	else:
		_shake_camera.offset = _base_offset

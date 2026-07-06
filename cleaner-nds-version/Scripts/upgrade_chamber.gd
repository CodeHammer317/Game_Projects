extends Node2D
class_name UpgradeChamber

signal matrix_browse_closed

@export var upgrade_name: StringName = &"double_jump"
@export var move_player_to_stop: bool = true
@export var player_move_speed: float = 120.0
@export var max_move_to_stop_time: float = 3.0
@export var beam_animation: StringName = &"beam"
@export var machine_animation: StringName = &"activate"
@export var fallback_animation_time: float = 1.0
@export_range(1.0, 4.0, 0.05) var animation_duration_multiplier: float = 1.0
@export_range(1, 6, 1) var animation_repeat_count: int = 3
@export var player_scene: PackedScene
@export var player_scale: Vector2 = Vector2(1.5, 1.5)
@export_file("*.tscn") var next_scene: String = "res://Scenes/World/coffee_shop.tscn"
@export var fade_in_duration: float = 0.75
@export var fade_out_duration: float = 0.75
@export var wait_for_matrix_reveal: bool = true
@export_range(0.5, 5.0, 0.1) var matrix_reveal_timeout: float = 2.0

@onready var area: Area2D = $Area2D
@onready var upgrade_matrix: UpgradeMatrixDisplay = $UpgradeMatrixDisplay
@onready var stop_point: Node2D = $StopPoint
@onready var beam_sprite: AnimatedSprite2D = $Beam/AnimatedSprite2D
@onready var machine_sprite: AnimatedSprite2D = $UpgradeMachine/AnimatedSprite2D
@onready var player_spawn: Marker2D = $PlayerSpawn
@onready var camera: SimpleCamera = $Camera2D
@onready var tutorial_ui: CanvasLayer = $TutorialUI
@onready var tutorial_prompt: Label = $TutorialUI/TutorialPrompt
@onready var exit_prompt: Label = $TutorialUI/ExitPrompt
@onready var exit_area: Area2D = $TutorialExit
@onready var transition_layer: CanvasLayer = $TransitionLayer
@onready var transition_overlay: ColorRect = $TransitionLayer/Overlay
@onready var text_panel: Sprite2D = $TextPanel
@onready var acquisition_label: Label = $TextLabel
@onready var matrix_selector: Line2D = $MatrixSelector

var is_active: bool = false
var has_been_used: bool = false
var player: Node2D = null
var _is_leaving: bool = false
var _beam_base_speed_scale: float = 1.0
var _machine_base_speed_scale: float = 1.0
var _matrix_reveal_complete: bool = false
var _matrix_browse_active: bool = false
var _matrix_selection_index: int = 0
var _matrix_items: Array[Dictionary] = []


func _ready() -> void:
	_beam_base_speed_scale = beam_sprite.speed_scale
	_machine_base_speed_scale = machine_sprite.speed_scale
	beam_sprite.stop()
	beam_sprite.set_frame_and_progress(0, 0.0)
	beam_sprite.visible = false
	machine_sprite.stop()
	machine_sprite.set_frame_and_progress(0, 0.0)
	has_been_used = PlayerState.has_upgrade(upgrade_name)
	tutorial_ui.visible = false
	tutorial_prompt.visible = false
	exit_prompt.visible = false
	exit_area.monitoring = false
	text_panel.visible = false
	acquisition_label.visible = false
	matrix_selector.visible = false

	if not _validate_configuration():
		area.set_deferred("monitoring", false)
		return

	if not area.body_entered.is_connected(_on_body_entered):
		area.body_entered.connect(_on_body_entered)
	if not exit_area.body_entered.is_connected(_on_exit_body_entered):
		exit_area.body_entered.connect(_on_exit_body_entered)
	if not upgrade_matrix.upgrade_reveal_finished.is_connected(_on_matrix_reveal_finished):
		upgrade_matrix.upgrade_reveal_finished.connect(_on_matrix_reveal_finished)

	if has_been_used:
		area.set_deferred("monitoring", false)

	_spawn_player()
	await _fade_in()

	if has_been_used:
		_show_upgrade_message(
			PlayerState.get_upgrade_display_name(upgrade_name).to_upper() + " ONLINE"
		)
		_enable_tutorial_exit()


func _on_body_entered(body: Node) -> void:
	if has_been_used:
		return

	if is_active:
		return

	if not body.is_in_group("player"):
		return

	start_upgrade_sequence(body)


func start_upgrade_sequence(player: Node) -> void:
	if not is_node_ready():
		await ready

	if PlayerState.has_upgrade(upgrade_name):
		has_been_used = true
		if area != null:
			area.set_deferred("monitoring", false)
		return

	is_active = true
	has_been_used = true

	if player.has_method("set_control_locked"):
		player.set_control_locked(true)

	if move_player_to_stop:
		await _move_player_to_stop(player)

	if player.has_method("play_idle_animation"):
		player.play_idle_animation()

	await _play_upgrade_animation()

	var should_wait_for_reveal := (
		wait_for_matrix_reveal
		and upgrade_matrix != null
		and upgrade_matrix.will_animate_upgrade(upgrade_name)
	)
	_matrix_reveal_complete = not should_wait_for_reveal

	var upgrade_was_applied := false
	if player.has_method("apply_upgrade"):
		player.apply_upgrade(upgrade_name)
		upgrade_was_applied = PlayerState.has_upgrade(upgrade_name)
	else:
		push_warning("UpgradeChamber: player cannot apply upgrades.")

	if upgrade_was_applied:
		_show_upgrade_message(
			PlayerState.get_upgrade_display_name(upgrade_name).to_upper() + " ACQUIRED"
		)

	if should_wait_for_reveal and upgrade_was_applied:
		await _wait_for_matrix_reveal()

	if upgrade_was_applied:
		await _begin_matrix_browse(upgrade_name)
		await _wait_for_action_release(&"shoot")

	if player.has_method("set_control_locked"):
		player.set_control_locked(false)

	if area != null:
		area.set_deferred("monitoring", false)
	is_active = false
	_enable_tutorial_exit()


func _show_upgrade_message(message: String) -> void:
	acquisition_label.text = message
	text_panel.visible = true
	acquisition_label.visible = true


func _on_matrix_reveal_finished(revealed_upgrade: StringName) -> void:
	if revealed_upgrade == upgrade_name:
		_matrix_reveal_complete = true


func _wait_for_matrix_reveal() -> void:
	var timeout_at := Time.get_ticks_msec() + int(matrix_reveal_timeout * 1000.0)

	while not _matrix_reveal_complete and Time.get_ticks_msec() < timeout_at:
		await get_tree().process_frame

	if not _matrix_reveal_complete:
		push_warning("UpgradeChamber: matrix reveal timed out for: " + str(upgrade_name))


func _wait_for_action_release(action: StringName) -> void:
	while Input.is_action_pressed(action):
		await get_tree().process_frame


func _unhandled_input(event: InputEvent) -> void:
	if not _matrix_browse_active:
		return

	var direction := Vector2.ZERO
	if event.is_action_pressed("menu_left"):
		direction = Vector2.LEFT
	elif event.is_action_pressed("menu_right"):
		direction = Vector2.RIGHT
	elif event.is_action_pressed("menu_up"):
		direction = Vector2.UP
	elif event.is_action_pressed("menu_down"):
		direction = Vector2.DOWN
	elif event.is_action_pressed("accept"):
		_show_selected_matrix_details()
		get_viewport().set_input_as_handled()
		return
	elif event.is_action_pressed("shoot"):
		_end_matrix_browse()
		get_viewport().set_input_as_handled()
		return

	if direction != Vector2.ZERO:
		_move_matrix_selection(direction)
		get_viewport().set_input_as_handled()


func _begin_matrix_browse(initial_upgrade: StringName) -> void:
	_build_matrix_items()
	if _matrix_items.is_empty():
		return

	_matrix_selection_index = _find_upgrade_item(initial_upgrade)
	_matrix_browse_active = true
	matrix_selector.visible = true
	_update_matrix_selector()
	await matrix_browse_closed


func _end_matrix_browse() -> void:
	if not _matrix_browse_active:
		return

	_matrix_browse_active = false
	matrix_selector.visible = false
	_show_upgrade_message(
		PlayerState.get_upgrade_display_name(upgrade_name).to_upper() + " ACQUIRED"
	)
	matrix_browse_closed.emit()


func _build_matrix_items() -> void:
	_matrix_items = [
		_matrix_item(
			$HelperMatrix/MatttSlot/MattSprite,
			"MATTT",
			"Active helper. Calls down a fire column on the nearest enemy.",
			&"helper",
			&"mattt"
		),
		_matrix_item(
			$HelperMatrix/ToadSlot/ToadSprite,
			"TOAD",
			"Full-game operative. Field profile remains classified.",
			&"helper",
			&"toad"
		),
		_matrix_item(
			$HelperMatrix/EdSlot/EdMabrie,
			"ED",
			"Full-game operative. Combat specialty remains classified.",
			&"helper",
			&"ed"
		),
		_upgrade_item(
			&"wall_slide",
			$UpgradeMatrixDisplay/RelicSlots/WallSlideSlot/RelicSprite
		),
		_upgrade_item(
			&"double_jump",
			$UpgradeMatrixDisplay/RelicSlots/DoubleJumpSlot/RelicSprite
		),
		_upgrade_item(
			&"charge_shot",
			$UpgradeMatrixDisplay/RelicSlots/ChargeShotSlot/RelicSprite
		),
		_matrix_item(
			$UpgradeMatrixDisplay/FutureSlots/FutureSlot1,
			"UNKNOWN RELIC",
			"Signal encrypted. Discoverable in the full campaign.",
			&"future",
			&"future_1"
		),
		_matrix_item(
			$UpgradeMatrixDisplay/FutureSlots/FutureSlot2,
			"UNKNOWN RELIC",
			"Signal encrypted. Discoverable in the full campaign.",
			&"future",
			&"future_2"
		),
		_matrix_item(
			$UpgradeMatrixDisplay/FutureSlots/FutureSlot3,
			"UNKNOWN RELIC",
			"Signal encrypted. Discoverable in the full campaign.",
			&"future",
			&"future_3"
		),
	]


func _matrix_item(
	target: CanvasItem,
	title: String,
	description: String,
	kind: StringName,
	item_id: StringName
) -> Dictionary:
	return {
		"target": target,
		"title": title,
		"description": description,
		"kind": kind,
		"id": item_id,
	}


func _upgrade_item(item_upgrade: StringName, target: CanvasItem) -> Dictionary:
	var definition: Dictionary = PlayerState.UPGRADE_DEFINITIONS.get(item_upgrade, {})
	return _matrix_item(
		target,
		PlayerState.get_upgrade_display_name(item_upgrade).to_upper(),
		definition.get("description", "Upgrade data unavailable."),
		&"upgrade",
		item_upgrade
	)


func _find_upgrade_item(item_upgrade: StringName) -> int:
	for index in _matrix_items.size():
		var item := _matrix_items[index]
		if item.get("kind") == &"upgrade" and item.get("id") == item_upgrade:
			return index

	return 0


func _move_matrix_selection(direction: Vector2) -> void:
	var current_position := _get_item_position(_matrix_items[_matrix_selection_index])
	var best_index := _matrix_selection_index
	var best_score := INF

	for index in _matrix_items.size():
		if index == _matrix_selection_index:
			continue

		var offset := _get_item_position(_matrix_items[index]) - current_position
		if offset.length_squared() <= 0.01:
			continue

		var directional_alignment := offset.normalized().dot(direction)
		if directional_alignment < 0.45:
			continue

		var cross_distance := absf(offset.cross(direction))
		var score := offset.length() + cross_distance * 1.5
		if score < best_score:
			best_score = score
			best_index = index

	if best_index != _matrix_selection_index:
		_matrix_selection_index = best_index
		_update_matrix_selector()


func _update_matrix_selector() -> void:
	var item := _matrix_items[_matrix_selection_index]
	matrix_selector.global_position = _get_item_position(item)
	_show_upgrade_message(
		str(item.get("title", "UNKNOWN")) + "\nA: DETAILS   B: EXIT"
	)


func _show_selected_matrix_details() -> void:
	var item := _matrix_items[_matrix_selection_index]
	var status := _get_matrix_item_status(item)
	_show_upgrade_message(
		str(item.get("title", "UNKNOWN"))
		+ " ["
		+ status
		+ "]\n"
		+ str(item.get("description", "No data available."))
	)


func _get_matrix_item_status(item: Dictionary) -> String:
	var kind: StringName = item.get("kind", &"")
	var item_id: StringName = item.get("id", &"")

	if kind == &"upgrade":
		return "ACQUIRED" if PlayerState.has_upgrade(item_id) else "LOCKED"
	if kind == &"helper":
		return "ACTIVE" if PlayerState.has_helper(item_id) else "FULL GAME"

	return "ENCRYPTED"


func _get_item_position(item: Dictionary) -> Vector2:
	var target := item.get("target") as CanvasItem
	if target == null:
		return global_position

	if target is Sprite2D:
		var sprite := target as Sprite2D
		if not sprite.centered and sprite.texture != null:
			return sprite.to_global(Vector2(sprite.texture.get_size()) * 0.5)

	var target_node := target as Node2D
	return target_node.global_position if target_node != null else global_position


func _validate_configuration() -> bool:
	if not PlayerState.UPGRADE_DEFINITIONS.has(upgrade_name):
		push_error("UpgradeChamber: unknown upgrade_name: " + str(upgrade_name))
		return false

	if upgrade_matrix == null:
		push_error("UpgradeChamber: UpgradeMatrixDisplay node is missing.")
		return false

	if not upgrade_matrix.has_upgrade_slot(upgrade_name):
		push_error("UpgradeChamber: matrix has no slot for: " + str(upgrade_name))
		return false

	return true


func _spawn_player() -> void:
	if player_scene == null:
		push_warning("UpgradeChamber: player_scene is not assigned.")
		return

	player = player_scene.instantiate() as Node2D
	if player == null:
		push_warning("UpgradeChamber: failed to instantiate player_scene.")
		return

	add_child(player)
	player.scale = player_scale
	player.global_position = player_spawn.global_position
	if player.has_method("set_combat_enabled"):
		player.call("set_combat_enabled", false)
	camera.target = player


func _enable_tutorial_exit() -> void:
	tutorial_ui.visible = true
	tutorial_prompt.visible = true
	exit_prompt.visible = true
	exit_area.set_deferred("monitoring", true)


func _on_exit_body_entered(body: Node) -> void:
	if _is_leaving or body != player:
		return

	if next_scene.is_empty():
		push_warning("UpgradeChamber: next_scene is not assigned.")
		return

	_is_leaving = true
	exit_area.set_deferred("monitoring", false)

	if player.has_method("set_control_locked"):
		player.call("set_control_locked", true)

	await _fade_out()

	var error := get_tree().change_scene_to_file(next_scene)
	if error != OK:
		push_error("UpgradeChamber: failed to open next scene. Error: %s" % error)
		_is_leaving = false
		_enable_tutorial_exit()


func _fade_in() -> void:
	transition_layer.visible = true
	transition_overlay.visible = true
	transition_overlay.modulate.a = 1.0

	var tween := create_tween()
	tween.tween_property(
		transition_overlay,
		"modulate:a",
		0.0,
		fade_in_duration
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	await tween.finished

	transition_layer.visible = false


func _fade_out() -> void:
	transition_layer.visible = true
	transition_overlay.visible = true
	transition_overlay.modulate.a = 0.0

	var tween := create_tween()
	tween.tween_property(
		transition_overlay,
		"modulate:a",
		1.0,
		fade_out_duration
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	await tween.finished


func _move_player_to_stop(player: Node) -> void:
	if not player is Node2D:
		return

	if stop_point == null:
		return

	var player_2d: Node2D = player
	var move_timer: float = 0.0

	while is_instance_valid(player_2d) and player_2d.global_position.distance_to(stop_point.global_position) > 2.0:
		if move_timer >= max_move_to_stop_time:
			break

		var direction: Vector2 = player_2d.global_position.direction_to(stop_point.global_position)
		var delta := get_process_delta_time()
		if delta <= 0.0:
			delta = 1.0 / 60.0

		move_timer += delta
		player_2d.global_position += direction * player_move_speed * delta
		await get_tree().process_frame

	if is_instance_valid(player_2d):
		player_2d.global_position = stop_point.global_position


func _play_upgrade_animation() -> void:
	var safe_duration_multiplier := maxf(animation_duration_multiplier, 1.0)
	machine_sprite.speed_scale = _machine_base_speed_scale / safe_duration_multiplier
	beam_sprite.speed_scale = _beam_base_speed_scale / safe_duration_multiplier

	beam_sprite.visible = true
	var repeat_count := maxi(animation_repeat_count, 1)

	for cycle in repeat_count:
		var machine_duration := fallback_animation_time * safe_duration_multiplier
		var beam_duration := fallback_animation_time * safe_duration_multiplier

		if machine_sprite.sprite_frames != null:
			if machine_sprite.sprite_frames.has_animation(machine_animation):
				machine_sprite.stop()
				machine_sprite.set_frame_and_progress(0, 0.0)
				machine_sprite.play(machine_animation)
				machine_duration = _get_animation_duration(machine_sprite, machine_animation)

		if beam_sprite.sprite_frames != null:
			if beam_sprite.sprite_frames.has_animation(beam_animation):
				beam_sprite.stop()
				beam_sprite.set_frame_and_progress(0, 0.0)
				beam_sprite.play(beam_animation)
				beam_duration = _get_animation_duration(beam_sprite, beam_animation)

		await get_tree().create_timer(maxf(machine_duration, beam_duration)).timeout

	machine_sprite.stop()
	beam_sprite.stop()
	beam_sprite.visible = false


func _get_animation_duration(sprite: AnimatedSprite2D, animation_name: StringName) -> float:
	if sprite.sprite_frames == null:
		return fallback_animation_time

	if not sprite.sprite_frames.has_animation(animation_name):
		return fallback_animation_time

	var speed := sprite.sprite_frames.get_animation_speed(animation_name) * absf(sprite.speed_scale)
	if speed <= 0.0:
		return fallback_animation_time

	var frame_count := sprite.sprite_frames.get_frame_count(animation_name)
	var total_duration: float = 0.0

	for frame_index in frame_count:
		total_duration += sprite.sprite_frames.get_frame_duration(animation_name, frame_index) / speed

	return maxf(total_duration, 0.05)

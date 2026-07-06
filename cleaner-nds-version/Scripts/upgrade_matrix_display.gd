extends Node2D
class_name UpgradeMatrixDisplay

signal upgrade_reveal_finished(upgrade_name: StringName)

@export var show_empty_slots: bool = true
@export var show_future_slots: bool = true
@export var reveal_collected_on_ready: bool = true
@export var placeholder_modulate: Color = Color(0.12, 0.18, 0.22, 0.65)
@export var future_slots_path: NodePath = ^"FutureSlots"
@export var animate_new_upgrades: bool = true
@export_range(0.1, 1.5, 0.05) var reveal_duration: float = 0.55
@export_range(1.0, 2.0, 0.05) var reveal_pulse_scale: float = 1.25
@export var reveal_flash_color: Color = Color(1.0, 0.92, 0.5, 1.0)

@export var double_jump_slot_path: NodePath = ^"RelicSlots/DoubleJumpSlot"
@export var wall_slide_slot_path: NodePath = ^"RelicSlots/WallSlideSlot"
@export var charge_shot_slot_path: NodePath = ^"RelicSlots/ChargeShotSlot"

var _slot_paths: Dictionary[StringName, NodePath] = {}


func _ready() -> void:
	_slot_paths = {
		&"double_jump": double_jump_slot_path,
		&"wall_slide": wall_slide_slot_path,
		&"charge_shot": charge_shot_slot_path
	}

	if not PlayerState.upgrade_unlocked.is_connected(_on_upgrade_unlocked):
		PlayerState.upgrade_unlocked.connect(_on_upgrade_unlocked)

	refresh()


func refresh() -> void:
	var future_slots := get_node_or_null(future_slots_path) as CanvasItem
	if future_slots != null:
		future_slots.visible = show_future_slots

	for upgrade_name in _slot_paths.keys():
		var is_collected := reveal_collected_on_ready and PlayerState.has_upgrade(upgrade_name)
		_set_slot_state(upgrade_name, is_collected)


func reveal_upgrade(upgrade_name: StringName) -> void:
	_set_slot_state(upgrade_name, true)


func hide_upgrade(upgrade_name: StringName) -> void:
	_set_slot_state(upgrade_name, false)


func _on_upgrade_unlocked(upgrade_name: StringName) -> void:
	if not has_upgrade_slot(upgrade_name):
		return

	reveal_upgrade(upgrade_name)

	if animate_new_upgrades:
		_play_reveal_animation(upgrade_name)
	else:
		upgrade_reveal_finished.emit(upgrade_name)


func has_upgrade_slot(upgrade_name: StringName) -> bool:
	return _slot_paths.has(upgrade_name) and get_node_or_null(_slot_paths[upgrade_name]) != null


func will_animate_upgrade(upgrade_name: StringName) -> bool:
	return animate_new_upgrades and has_upgrade_slot(upgrade_name)


func _set_slot_state(upgrade_name: StringName, is_collected: bool) -> void:
	if not _slot_paths.has(upgrade_name):
		return

	var slot := get_node_or_null(_slot_paths[upgrade_name]) as Node2D
	if slot == null:
		push_warning("Upgrade matrix slot is missing: " + str(_slot_paths[upgrade_name]))
		return

	var relic_sprite := slot.get_node_or_null("RelicSprite") as Sprite2D
	var placeholder_sprite := slot.get_node_or_null("EmptySprite") as Sprite2D

	if relic_sprite == null:
		push_warning("Upgrade matrix relic icon is missing for: " + str(upgrade_name))
		return

	if placeholder_sprite == null:
		push_warning("Upgrade matrix placeholder icon is missing for: " + str(upgrade_name))
		relic_sprite.visible = is_collected
		return

	_sync_placeholder(placeholder_sprite, relic_sprite)
	relic_sprite.visible = is_collected
	placeholder_sprite.visible = show_empty_slots and not is_collected


func _sync_placeholder(placeholder_sprite: Sprite2D, relic_sprite: Sprite2D) -> void:
	placeholder_sprite.texture = relic_sprite.texture
	placeholder_sprite.position = relic_sprite.position
	placeholder_sprite.rotation = relic_sprite.rotation
	placeholder_sprite.scale = relic_sprite.scale
	placeholder_sprite.flip_h = relic_sprite.flip_h
	placeholder_sprite.flip_v = relic_sprite.flip_v
	placeholder_sprite.modulate = placeholder_modulate


func _play_reveal_animation(upgrade_name: StringName) -> void:
	var slot := get_node_or_null(_slot_paths[upgrade_name]) as Node2D
	if slot == null:
		upgrade_reveal_finished.emit(upgrade_name)
		return

	var relic_sprite := slot.get_node_or_null("RelicSprite") as Sprite2D
	if relic_sprite == null:
		upgrade_reveal_finished.emit(upgrade_name)
		return

	var resting_scale := relic_sprite.scale
	relic_sprite.scale = resting_scale * 0.65
	relic_sprite.modulate = reveal_flash_color

	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(
		relic_sprite,
		"scale",
		resting_scale * reveal_pulse_scale,
		reveal_duration * 0.55
	).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(
		relic_sprite,
		"modulate",
		Color.WHITE,
		reveal_duration
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

	await tween.finished

	var settle_tween := create_tween()
	settle_tween.tween_property(
		relic_sprite,
		"scale",
		resting_scale,
		reveal_duration * 0.45
	).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	await settle_tween.finished

	relic_sprite.scale = resting_scale
	relic_sprite.modulate = Color.WHITE
	upgrade_reveal_finished.emit(upgrade_name)

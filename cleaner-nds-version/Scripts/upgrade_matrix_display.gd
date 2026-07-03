extends Node2D
class_name UpgradeMatrixDisplay

@export var show_empty_slots: bool = true
@export var reveal_collected_on_ready: bool = true

@export var double_jump_slot_path: NodePath = ^"RelicSlots/DoubleJumpSlot"
@export var wall_slide_slot_path: NodePath = ^"RelicSlots/WallSlideSlot"
@export var charge_shot_slot_path: NodePath = ^"RelicSlots/ChargeShotSlot"

var _slot_paths: Dictionary = {}


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
	for upgrade_name in _slot_paths.keys():
		var is_collected := reveal_collected_on_ready and PlayerState.has_upgrade(upgrade_name)
		_set_slot_collected(upgrade_name, is_collected)


func reveal_upgrade(upgrade_name: StringName) -> void:
	_set_slot_collected(upgrade_name, true)


func hide_upgrade(upgrade_name: StringName) -> void:
	_set_slot_collected(upgrade_name, false)


func _on_upgrade_unlocked(upgrade_name: StringName) -> void:
	reveal_upgrade(upgrade_name)


func _set_slot_collected(upgrade_name: StringName, is_collected: bool) -> void:
	if not _slot_paths.has(upgrade_name):
		return

	var slot := get_node_or_null(_slot_paths[upgrade_name])
	if slot == null:
		push_warning("Upgrade matrix slot is missing: " + str(_slot_paths[upgrade_name]))
		return

	var relic_sprite := slot.get_node_or_null("RelicSprite") as CanvasItem
	var empty_sprite := slot.get_node_or_null("EmptySprite") as CanvasItem

	if relic_sprite is Sprite2D and empty_sprite is Sprite2D:
		var relic_icon := relic_sprite as Sprite2D
		var empty_icon := empty_sprite as Sprite2D
		if empty_icon.texture == null:
			empty_icon.texture = relic_icon.texture
			empty_icon.position = relic_icon.position
			empty_icon.scale = relic_icon.scale
			empty_icon.modulate = Color(0.12, 0.18, 0.22, 0.65)

	if relic_sprite != null:
		relic_sprite.visible = is_collected

	if empty_sprite != null:
		empty_sprite.visible = show_empty_slots and not is_collected

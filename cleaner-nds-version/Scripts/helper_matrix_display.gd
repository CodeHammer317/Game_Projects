extends Node2D
class_name HelperMatrixDisplay

@export var demo_mode: bool = true
@export var available_modulate: Color = Color.WHITE
@export var locked_modulate: Color = Color(0.18, 0.24, 0.28, 0.48)

@export var mattt_slot_path: NodePath = ^"MatttSlot"
@export var toad_slot_path: NodePath = ^"ToadSlot"
@export var ed_slot_path: NodePath = ^"EdSlot"

var _slot_paths: Dictionary[StringName, NodePath] = {}


func _ready() -> void:
	_slot_paths = {
		&"mattt": mattt_slot_path,
		&"toad": toad_slot_path,
		&"ed": ed_slot_path,
	}

	if not PlayerState.helper_unlocked.is_connected(_on_helper_state_changed):
		PlayerState.helper_unlocked.connect(_on_helper_state_changed)

	refresh()


func refresh() -> void:
	for helper_id in _slot_paths:
		var slot := get_node_or_null(_slot_paths[helper_id]) as CanvasItem
		if slot == null:
			push_warning("Helper matrix slot is missing for: " + str(helper_id))
			continue

		slot.modulate = available_modulate if _is_helper_available(helper_id) else locked_modulate


func _is_helper_available(helper_id: StringName) -> bool:
	if demo_mode and helper_id != PlayerState.DEFAULT_HELPER:
		return false

	return (
		PlayerState.HELPER_DEFINITIONS.has(helper_id)
		and PlayerState.has_helper(helper_id)
	)


func _on_helper_state_changed(_helper_id: StringName) -> void:
	refresh()

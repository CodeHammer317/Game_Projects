# AreaTransition.gd
extends Area2D

@export_file("*.tscn") var next_level_path: String
@export var required_group: StringName = &"player"

var _is_transitioning: bool = false

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	print("AreaTransition ready")

func _on_body_entered(body: Node) -> void:
	if _is_transitioning:
		return

	if not body.is_in_group(required_group):
		return

	if next_level_path.is_empty():
		push_warning("AreaTransition: next_level_path is empty.")
		return

	_is_transitioning = true
	call_deferred("_deferred_change_level")

func _deferred_change_level() -> void:
	get_tree().change_scene_to_file(next_level_path)

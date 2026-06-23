extends Control

const SELECTOR_OFFSET: Vector2 = Vector2(-25, 11)
const BRIEFING_SCENE: String = "res://Scenes/World/study.tscn"

enum MenuOption {
	ONE_PLAYER,
	TWO_PLAYERS,
	EXIT,
}

@onready var menu: Control = $MenuContainer
@onready var selector: Node2D = $MenuContainer/Selector
@onready var fade: ColorRect = $FadeLayer

@onready var sfx_move: AudioStreamPlayer = $SFX_Move
@onready var sfx_confirm: AudioStreamPlayer = $SFX_Confirm
@onready var sfx_unavailable: AudioStreamPlayer = $SFX_Unavailable

var menu_items: Array[Control] = []
var current_index: int = 0
var selector_tween: Tween = null
var is_transitioning: bool = false


func _ready() -> void:
	for child in menu.get_children():
		if child is Control and child != selector:
			menu_items.append(child)

	await get_tree().process_frame
	_update_selector_position()
	fade.modulate.a = 0.0


func _unhandled_input(event: InputEvent) -> void:
	if menu_items.is_empty() or is_transitioning:
		return

	if event.is_action_pressed("menu_down"):
		_navigate(1)
	elif event.is_action_pressed("menu_up"):
		_navigate(-1)
	elif event.is_action_pressed("accept"):
		_confirm_selection()


func _navigate(direction: int) -> void:
	current_index = posmod(current_index + direction, menu_items.size())
	_move_selector()
	sfx_move.play()


func _move_selector() -> void:
	if selector_tween:
		selector_tween.kill()

	selector_tween = create_tween()
	selector_tween.tween_property(
		selector,
		"position",
		menu_items[current_index].position + SELECTOR_OFFSET,
		0.12
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


func _update_selector_position() -> void:
	selector.position = menu_items[current_index].position + SELECTOR_OFFSET


func _confirm_selection() -> void:
	if is_transitioning:
		return

	if current_index == MenuOption.TWO_PLAYERS:
		sfx_unavailable.play()
		return

	is_transitioning = true
	sfx_confirm.play()
	await _fade_out()
	_execute_selection()


func _fade_out() -> void:
	var fade_tween := create_tween()
	fade_tween.tween_property(fade, "modulate:a", 1.0, 0.5)
	await fade_tween.finished


func _execute_selection() -> void:
	match current_index:
		MenuOption.ONE_PLAYER:
			var error := get_tree().change_scene_to_file(BRIEFING_SCENE)
			if error != OK:
				push_error("Failed to open briefing scene. Error: %s" % error)
				_reset_transition()
		MenuOption.EXIT:
			get_tree().quit()
		_:
			push_error("Invalid current_index: %s" % current_index)
			_reset_transition()


func _reset_transition() -> void:
	is_transitioning = false
	fade.modulate.a = 0.0

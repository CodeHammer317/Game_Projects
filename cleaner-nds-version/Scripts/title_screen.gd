extends Control

const SELECTOR_OFFSET: Vector2 = Vector2(-25, 11)
const BRIEFING_SCENE: String = "res://Scenes/World/study.tscn"

enum MenuOption {
	START_DEMO,
	EXIT,
}

@export_group("Timing")
@export var intro_duration: float = 0.45
@export var selector_move_duration: float = 0.12
@export var fade_out_duration: float = 1.25

@onready var logo: TextureRect = $Logo
@onready var demo_label: Label = $DemoLabel
@onready var menu: Control = $MenuContainer
@onready var selector: Node2D = $MenuContainer/Selector
@onready var fade: ColorRect = $FadeLayer

@onready var sfx_move: AudioStreamPlayer = $SFX_Move
@onready var sfx_confirm: AudioStreamPlayer = $SFX_Confirm

var menu_items: Array[Control] = []
var current_index: int = 0
var selector_tween: Tween = null
var selector_pulse_tween: Tween = null
var is_transitioning: bool = true


func _ready() -> void:
	for child in menu.get_children():
		var menu_item := child as Control
		if menu_item == null:
			continue

		var item_index := menu_items.size()
		menu_items.append(menu_item)
		menu_item.mouse_entered.connect(_on_menu_item_mouse_entered.bind(item_index))
		menu_item.gui_input.connect(_on_menu_item_gui_input.bind(item_index))

	await get_tree().process_frame

	if menu_items.is_empty():
		push_error("Title screen has no menu items.")
		return

	_update_selector_position()
	await _play_intro()
	is_transitioning = false
	_start_selector_pulse()


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
		selector_move_duration
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


func _update_selector_position() -> void:
	selector.position = menu_items[current_index].position + SELECTOR_OFFSET


func _confirm_selection() -> void:
	if is_transitioning:
		return

	is_transitioning = true
	_stop_selector_pulse()
	sfx_confirm.play()
	await _fade_out()
	_execute_selection()


func _play_intro() -> void:
	fade.modulate.a = 1.0
	logo.modulate.a = 0.0
	demo_label.modulate.a = 0.0
	menu.modulate.a = 0.0

	var intro_tween := create_tween().set_parallel(true)
	intro_tween.tween_property(fade, "modulate:a", 0.0, intro_duration)
	intro_tween.tween_property(logo, "modulate:a", 1.0, intro_duration)
	intro_tween.tween_property(demo_label, "modulate:a", 1.0, intro_duration)
	intro_tween.tween_property(menu, "modulate:a", 1.0, intro_duration)
	await intro_tween.finished


func _start_selector_pulse() -> void:
	var base_scale := selector.scale
	selector_pulse_tween = create_tween().set_loops()
	selector_pulse_tween.tween_property(
		selector,
		"scale",
		base_scale * 1.08,
		0.45
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	selector_pulse_tween.tween_property(
		selector,
		"scale",
		base_scale,
		0.45
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _stop_selector_pulse() -> void:
	if selector_pulse_tween:
		selector_pulse_tween.kill()
		selector_pulse_tween = null


func _fade_out() -> void:
	var fade_tween := create_tween()
	fade_tween.tween_property(fade, "modulate:a", 1.0, fade_out_duration)
	await fade_tween.finished


func _execute_selection() -> void:
	match current_index:
		MenuOption.START_DEMO:
			# A new run must not inherit relics from an earlier run in the
			# same process; otherwise their pickups remove themselves.
			PlayerState.reset_all()
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
	_start_selector_pulse()


func _on_menu_item_mouse_entered(item_index: int) -> void:
	if is_transitioning or current_index == item_index:
		return

	current_index = item_index
	_move_selector()
	sfx_move.play()


func _on_menu_item_gui_input(event: InputEvent, item_index: int) -> void:
	var mouse_event := event as InputEventMouseButton
	if mouse_event == null:
		return

	if mouse_event.button_index != MOUSE_BUTTON_LEFT or not mouse_event.pressed:
		return

	current_index = item_index
	_move_selector()
	_confirm_selection()
	accept_event()

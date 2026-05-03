extends Control

const SELECTOR_OFFSET: Vector2 = Vector2(-25, 11)

@onready var menu: Control = $MenuContainer
@onready var selector: Node2D = $MenuContainer/Selector
@onready var fade: ColorRect = $FadeLayer

@onready var sfx_move: AudioStreamPlayer = $SFX_Move
@onready var sfx_confirm: AudioStreamPlayer = $SFX_Confirm

var menu_items: Array[Control] = []
var current_index: int = 0
var tween: Tween = null
var is_transitioning: bool = false


func _ready() -> void:
	for child in menu.get_children():
		if child is Control and child != selector:
			menu_items.append(child)

	await get_tree().process_frame
	update_selector_position()
	fade.modulate.a = 0.0


func _unhandled_input(event: InputEvent) -> void:
	if menu_items.is_empty() or is_transitioning:
		return

	if event.is_action_pressed("menu_down"):
		navigate(1)
	elif event.is_action_pressed("menu_up"):
		navigate(-1)
	elif event.is_action_pressed("accept"):
		confirm_selection()


func navigate(direction: int) -> void:
	current_index = posmod(current_index + direction, menu_items.size())
	move_selector()
	sfx_move.play()


func move_selector() -> void:
	if tween:
		tween.kill()

	tween = create_tween()
	tween.tween_property(
		selector,
		"position",
		menu_items[current_index].position + SELECTOR_OFFSET,
		0.12
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


func update_selector_position() -> void:
	selector.position = menu_items[current_index].position + SELECTOR_OFFSET


func confirm_selection() -> void:
	if is_transitioning:
		return

	is_transitioning = true
	sfx_confirm.play()
	fade_out_and_execute()


func fade_out_and_execute() -> void:
	var t := create_tween()
	t.tween_property(fade, "modulate:a", 1.0, 0.5)
	await t.finished
	_on_fade_complete()


func _on_fade_complete() -> void:
	match current_index:
		0:
			get_tree().change_scene_to_file("res://Scenes/World/level_01_briefing_screen.tscn")
		1:
			get_tree().change_scene_to_file("res://Scenes/World/level_01_briefing_screen.tscn")
		2:
			get_tree().quit()
		_:
			push_error("Invalid current_index: %s" % current_index)
			is_transitioning = false

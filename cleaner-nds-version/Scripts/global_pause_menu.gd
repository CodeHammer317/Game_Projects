extends CanvasLayer

const TITLE_SCREEN_PATH: String = "res://Scenes/HUD/title_screen.tscn"

@onready var pause_menu: Control = $PauseMenu
@onready var resume_button: Button = $PauseMenu/CenterContainer/PausePanel/Menu/ResumeButton
@onready var restart_button: Button = $PauseMenu/CenterContainer/PausePanel/Menu/RestartButton
@onready var main_menu_button: Button = $PauseMenu/CenterContainer/PausePanel/Menu/MainMenuButton

var _buttons: Array[Button] = []
var _selected_index: int = 0
var _action_in_progress: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_buttons = [resume_button, restart_button, main_menu_button]

	resume_button.pressed.connect(resume_game)
	restart_button.pressed.connect(restart_current_scene)
	main_menu_button.pressed.connect(return_to_main_menu)

	pause_menu.visible = false
	if get_tree().paused:
		get_tree().paused = false


func _unhandled_input(event: InputEvent) -> void:
	if event.is_echo():
		return

	if event.is_action_pressed("pause"):
		toggle_pause()
		get_viewport().set_input_as_handled()
		return

	if not get_tree().paused or not pause_menu.visible or _action_in_progress:
		return

	if event.is_action_pressed("menu_down"):
		_move_selection(1)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("menu_up"):
		_move_selection(-1)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("accept"):
		_activate_selected_button()
		get_viewport().set_input_as_handled()


func toggle_pause() -> void:
	if _action_in_progress:
		return

	set_game_paused(not get_tree().paused)


func set_game_paused(paused: bool) -> void:
	get_tree().paused = paused
	pause_menu.visible = paused

	if paused:
		_selected_index = 0
		_focus_selected_button()
	else:
		var viewport := get_viewport()
		if viewport != null:
			viewport.gui_release_focus()


func resume_game() -> void:
	if _action_in_progress:
		return

	set_game_paused(false)


func restart_current_scene() -> void:
	if _action_in_progress:
		return

	_action_in_progress = true
	set_game_paused(false)

	var error := get_tree().reload_current_scene()
	if error != OK:
		push_error("PauseMenu: failed to restart the current scene. Error: %s" % error)
		set_game_paused(true)
	_action_in_progress = false


func return_to_main_menu() -> void:
	if _action_in_progress:
		return

	_action_in_progress = true
	set_game_paused(false)

	var error := get_tree().change_scene_to_file(TITLE_SCREEN_PATH)
	if error != OK:
		push_error("PauseMenu: failed to open the title screen. Error: %s" % error)
		set_game_paused(true)
	_action_in_progress = false


func _move_selection(direction: int) -> void:
	if _buttons.is_empty():
		return

	_selected_index = posmod(_selected_index + direction, _buttons.size())
	_focus_selected_button()


func _focus_selected_button() -> void:
	if _buttons.is_empty():
		return

	var selected := _buttons[_selected_index]
	if selected != null and not selected.disabled:
		selected.grab_focus()


func _activate_selected_button() -> void:
	if _buttons.is_empty():
		return

	var focused := get_viewport().gui_get_focus_owner() as Button
	if focused != null and _buttons.has(focused) and not focused.disabled:
		focused.pressed.emit()
		return

	var selected := _buttons[_selected_index]
	if selected != null and not selected.disabled:
		selected.pressed.emit()

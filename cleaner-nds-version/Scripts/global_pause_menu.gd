extends CanvasLayer

const TITLE_SCREEN_PATH: String = "res://Scenes/HUD/title_screen.tscn"
const UI_MOVE_SOUND: AudioStream = preload("res://Assets/Audio/pickup2.ogg")
const UI_CONFIRM_SOUND: AudioStream = preload(
	"res://Assets/Audio/switch-mechanical-switch-gamemaster-audio-lower-tone-2-00-00.mp3"
)

@onready var pause_menu: Control = $PauseMenu
@onready var resume_button: Button = $PauseMenu/CenterContainer/PausePanel/Menu/ResumeButton
@onready var restart_button: Button = $PauseMenu/CenterContainer/PausePanel/Menu/RestartButton
@onready var main_menu_button: Button = $PauseMenu/CenterContainer/PausePanel/Menu/MainMenuButton

var _buttons: Array[Button] = []
var _selected_index: int = 0
var _action_in_progress: bool = false
var _reading_active: bool = false
var _reading_close_callback: Callable = Callable()
var _reading_close_actions: Array[StringName] = []
var _was_paused_before_reading: bool = false


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

	if _reading_active:
		for action in _reading_close_actions:
			if event.is_action_pressed(action):
				var close_callback := _reading_close_callback
				if close_callback.is_valid():
					close_callback.call()
				else:
					end_reading()
				get_viewport().set_input_as_handled()
				return
		return

	if get_tree().get_first_node_in_group("game_over_screen") != null:
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
	CombatFx.play_sfx(UI_CONFIRM_SOUND, -10.0, 0.9 if paused else 1.1, &"UI")

	if paused:
		_selected_index = 0
		_focus_selected_button()
	else:
		var viewport := get_viewport()
		if viewport != null:
			viewport.gui_release_focus()


func begin_reading(
	close_callback: Callable,
	close_actions: Array[StringName]
) -> bool:
	if _reading_active or not close_callback.is_valid():
		return false

	_reading_active = true
	_reading_close_callback = close_callback
	_reading_close_actions = close_actions.duplicate()
	_was_paused_before_reading = get_tree().paused
	get_tree().paused = true
	pause_menu.visible = false
	return true


func end_reading(close_callback: Callable = Callable()) -> void:
	if not _reading_active:
		return
	if close_callback.is_valid() and close_callback != _reading_close_callback:
		return

	_reading_active = false
	_reading_close_callback = Callable()
	_reading_close_actions.clear()
	get_tree().paused = _was_paused_before_reading
	pause_menu.visible = _was_paused_before_reading
	_was_paused_before_reading = false


func is_reading_active() -> bool:
	return _reading_active


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
	CombatFx.play_sfx(UI_MOVE_SOUND, -13.0, 1.1, &"UI")
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

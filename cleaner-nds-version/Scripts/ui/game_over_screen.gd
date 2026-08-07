extends CanvasLayer
class_name GameOverScreen

signal action_selected(action: StringName)

const FRAME_SIZE := Vector2i(416, 128)
const FRAME_COLUMNS: int = 4
const FRAME_COUNT: int = 44
const UI_MOVE_SOUND: AudioStream = preload("res://Assets/Audio/pickup2.ogg")
const UI_CONFIRM_SOUND: AudioStream = preload(
	"res://Assets/Audio/switch-mechanical-switch-gamemaster-audio-lower-tone-2-00-00.mp3"
)

@export var animation_fps: float = 20.0
@export var options_reveal_delay: float = 1.15

@onready var screen_root: Control = $ScreenRoot
@onready var game_over_art: TextureRect = $ScreenRoot/CenterContainer/Content/GameOverArt
@onready var options: VBoxContainer = $ScreenRoot/CenterContainer/Content/Options
@onready var retry_button: Button = $ScreenRoot/CenterContainer/Content/Options/Buttons/RetryButton
@onready var title_button: Button = $ScreenRoot/CenterContainer/Content/Options/Buttons/TitleButton
@onready var game_over_audio: AudioStreamPlayer = $GameOverAudio

var _art_atlas: AtlasTexture = null
var _animation_elapsed: float = 0.0
var _buttons: Array[Button] = []
var _selected_index: int = 0
var _options_ready: bool = false
var _action_in_progress: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group("game_over_screen")
	_buttons = [retry_button, title_button]

	retry_button.pressed.connect(_select_action.bind(&"retry"))
	title_button.pressed.connect(_select_action.bind(&"title"))

	_prepare_art_animation()
	_set_options_enabled(false)
	screen_root.modulate.a = 0.0
	get_tree().paused = true

	if game_over_audio.stream != null:
		game_over_audio.play()

	var intro_tween := create_tween()
	intro_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	intro_tween.tween_property(screen_root, "modulate:a", 1.0, 0.35)

	await get_tree().create_timer(options_reveal_delay, true).timeout
	if not is_inside_tree():
		return

	_options_ready = true
	_set_options_enabled(true)
	var options_tween := create_tween()
	options_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	options_tween.tween_property(options, "modulate:a", 1.0, 0.25)
	_focus_selected_button()


func _process(delta: float) -> void:
	if _art_atlas == null:
		return

	_animation_elapsed += delta
	var frame_index := mini(int(_animation_elapsed * animation_fps), FRAME_COUNT - 1)
	var frame_x := frame_index % FRAME_COLUMNS
	var frame_y := floori(frame_index / float(FRAME_COLUMNS))
	_art_atlas.region = Rect2(
		frame_x * FRAME_SIZE.x,
		frame_y * FRAME_SIZE.y,
		FRAME_SIZE.x,
		FRAME_SIZE.y
	)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_echo():
		return

	# Keep the global pause menu from opening behind this screen.
	if event.is_action_pressed("pause"):
		get_viewport().set_input_as_handled()
		return

	if not _options_ready or _action_in_progress:
		return

	if event.is_action_pressed("menu_right") or event.is_action_pressed("menu_down"):
		_move_selection(1)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("menu_left") or event.is_action_pressed("menu_up"):
		_move_selection(-1)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("accept"):
		_activate_selected_button()
		get_viewport().set_input_as_handled()


func _prepare_art_animation() -> void:
	if game_over_art.texture == null:
		return

	_art_atlas = AtlasTexture.new()
	_art_atlas.atlas = game_over_art.texture
	_art_atlas.region = Rect2(Vector2.ZERO, FRAME_SIZE)
	game_over_art.texture = _art_atlas


func _set_options_enabled(enabled: bool) -> void:
	options.modulate.a = 1.0 if enabled else 0.0
	for button in _buttons:
		button.disabled = not enabled
		button.mouse_filter = Control.MOUSE_FILTER_STOP if enabled else Control.MOUSE_FILTER_IGNORE


func _move_selection(direction: int) -> void:
	if _buttons.is_empty():
		return

	_selected_index = posmod(_selected_index + direction, _buttons.size())
	CombatFx.play_sfx(UI_MOVE_SOUND, -13.0, 0.92, &"UI")
	_focus_selected_button()


func _focus_selected_button() -> void:
	if _buttons.is_empty():
		return

	var selected := _buttons[_selected_index]
	if selected != null and not selected.disabled:
		selected.grab_focus()


func _activate_selected_button() -> void:
	var focused := get_viewport().gui_get_focus_owner() as Button
	if focused != null and _buttons.has(focused) and not focused.disabled:
		focused.pressed.emit()
		return

	if not _buttons.is_empty():
		_buttons[_selected_index].pressed.emit()


func _select_action(action: StringName) -> void:
	if _action_in_progress:
		return

	CombatFx.play_sfx(UI_CONFIRM_SOUND, -8.0, 0.85, &"UI")
	_action_in_progress = true
	for button in _buttons:
		button.disabled = true

	get_tree().paused = false
	action_selected.emit(action)
	queue_free()

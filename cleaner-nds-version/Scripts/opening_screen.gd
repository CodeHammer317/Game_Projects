extends Node2D

@export_group("Opening Timing")
@export_range(1.0, 15.0, 0.25) var panel_duration: float = 8.0
@export_range(0.0, 2.0, 0.05) var fade_duration: float = 0.65
@export_range(1.0, 100.0, 1.0) var characters_per_second: float = 32.0

@export_group("Scene Flow")
@export_file("*.tscn") var next_scene: String = "res://Scenes/World/study.tscn"

@onready var panels: Array[TextureRect] = [
	$CanvasLayer/OpeningImages/OpeningImage1,
	$CanvasLayer/OpeningImages/OpeningImage2,
	$CanvasLayer/OpeningImages/OpeningImage3,
]
@onready var narration: RichTextLabel = $CanvasLayer/NarrationPanel/Narration
@onready var continue_label: Label = $CanvasLayer/ContinueLabel
@onready var fade: ColorRect = $CanvasLayer/Fade
@onready var background_music: AudioStreamPlayer = $BackgroundMusic

var panel_texts: Array[String] = [
	"The Nephilim were never truly gone.\nTheir corruption survived beneath the world.",
	"Now, hidden powers combine forbidden knowledge\nwith modern technology to awaken them.",
	"The Nephilim Death Squad stands against the darkness.\nTonight, a signal is rising beneath the city.",
]

var _panel_index: int = 0
var _panel_timer: float = 0.0
var _typing_tween: Tween
var _transition_tween: Tween
var _is_typing: bool = false
var _is_transitioning: bool = true


func _ready() -> void:
	for panel in panels:
		panel.visible = false
		panel.modulate.a = 0.0

	continue_label.text = "A / Space: continue"
	continue_label.visible = false
	fade.modulate.a = 1.0
	_show_panel(0, true)


func _process(delta: float) -> void:
	if _is_transitioning:
		return

	_panel_timer -= delta
	if _panel_timer <= 0.0:
		_advance_panel()


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("accept") and not event.is_action_pressed("skip"):
		return

	get_viewport().set_input_as_handled()

	if _is_typing:
		_complete_text_reveal()
		return

	if not _is_transitioning:
		_advance_panel()


func _show_panel(index: int, first_panel: bool = false) -> void:
	_panel_index = index
	_panel_timer = panel_duration
	_is_transitioning = true
	continue_label.visible = false

	for panel_index in panels.size():
		panels[panel_index].visible = panel_index == index
		panels[panel_index].modulate.a = 0.0 if panel_index == index else panels[panel_index].modulate.a

	narration.text = panel_texts[index]
	narration.visible_characters = 0

	_kill_tween(_transition_tween)
	_transition_tween = create_tween().set_parallel(true)
	_transition_tween.tween_property(panels[index], "modulate:a", 1.0, fade_duration)
	if first_panel:
		_transition_tween.tween_property(fade, "modulate:a", 0.0, fade_duration)
	_transition_tween.finished.connect(_on_panel_faded_in, CONNECT_ONE_SHOT)


func _on_panel_faded_in() -> void:
	_transition_tween = null
	_is_transitioning = false
	_start_text_reveal()


func _start_text_reveal() -> void:
	_is_typing = true
	_kill_tween(_typing_tween)
	_typing_tween = create_tween()
	var duration := narration.text.length() / characters_per_second
	_typing_tween.tween_property(narration, "visible_characters", narration.text.length(), duration)
	_typing_tween.finished.connect(_on_text_revealed, CONNECT_ONE_SHOT)


func _complete_text_reveal() -> void:
	_kill_tween(_typing_tween)
	_typing_tween = null
	narration.visible_characters = narration.text.length()
	_on_text_revealed()


func _on_text_revealed() -> void:
	_typing_tween = null
	_is_typing = false
	continue_label.visible = true


func _advance_panel() -> void:
	if _is_transitioning:
		return

	_is_transitioning = true
	continue_label.visible = false
	_kill_tween(_typing_tween)
	_is_typing = false

	var current_panel := panels[_panel_index]
	_kill_tween(_transition_tween)
	_transition_tween = create_tween()
	_transition_tween.tween_property(current_panel, "modulate:a", 0.0, fade_duration)

	if _panel_index + 1 < panels.size():
		_transition_tween.finished.connect(
			func() -> void:
				current_panel.visible = false
				_transition_tween = null
				_show_panel(_panel_index + 1),
			CONNECT_ONE_SHOT
		)
	else:
		_transition_tween.set_parallel(true)
		_transition_tween.tween_property(fade, "modulate:a", 1.0, fade_duration)
		_transition_tween.tween_property(background_music, "volume_db", -40.0, fade_duration)
		_transition_tween.finished.connect(_finish_opening, CONNECT_ONE_SHOT)


func _finish_opening() -> void:
	if next_scene.is_empty():
		push_warning("OpeningScreen: next_scene is not assigned.")
		return

	var error := get_tree().change_scene_to_file(next_scene)
	if error != OK:
		push_error("OpeningScreen: failed to open next scene. Error: %s" % error)


func _kill_tween(tween: Tween) -> void:
	if tween != null and tween.is_valid():
		tween.kill()

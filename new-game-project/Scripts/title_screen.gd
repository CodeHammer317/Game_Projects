#Title Screen
extends Control

#---Constants---
const SELECTOR_OFFSET := Vector2(-25,11)

# --- Nodes ---
@onready var menu: Control = $MenuContainer
@onready var selector: Node2D = $MenuContainer/Selector
@onready var fade: ColorRect = $FadeLayer

# --- Audio ---
@onready var sfx_move: AudioStreamPlayer = $SFX_Move
@onready var sfx_confirm: AudioStreamPlayer = $SFX_Confirm

# --- State ---
var menu_items: Array[Control] = []
var current_index: int = 0
var tween: Tween


func _ready() -> void:
	# Collect menu items (StartGame, Options, Exit)
	for child in menu.get_children():
		if child is Control and child.name != "Selector":
			menu_items.append(child)

	# Fade starts invisible
	

	# Wait one frame so UI layout is stable before positioning selector
	await get_tree().process_frame 
	update_selector_position()

	# Create initial tween instance
	#tween = create_tween()
	fade.modulate.a = 0.0

func _unhandled_input(event: InputEvent) -> void:
	# Prevent errors if input fires before menu is ready
	if menu_items.is_empty():
		return

	if event.is_action_pressed("menu_down"):
		navigate(1)

	elif event.is_action_pressed("menu_up"):
		navigate(-1)

	elif event.is_action_pressed("accept"):
		confirm_selection()


# --- Navigation ---
func navigate(direction: int) -> void:
	current_index = (current_index + direction) % menu_items.size()
	move_selector()
	sfx_move.play()


func move_selector() -> void:
	# Kill previous tween safely
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


# --- Selection ---
func confirm_selection() -> void:
	sfx_confirm.play()
	fade_out_and_execute()


func fade_out_and_execute() -> void:
	var t := create_tween()
	t.tween_property(fade, "modulate:a", 1.0,2.5)
	t.finished.connect(_on_fade_complete)


func _on_fade_complete() -> void:
	match current_index:
		0:
			get_tree().change_scene_to_file("res://scenes/Level01BriefingScreen.tscn")
		1:
			get_tree().change_scene_to_file("res://scenes/Level01BriefingScreen.tscn")
		2:
			get_tree().change_scene_to_file("res://scenes/Options.tscn")
		3:
			get_tree().quit()

extends Control

# --- Constants ---
const SELECTOR_OFFSET: Vector2 = Vector2(-25, 11)

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
var tween: Tween = null

# --- References ---
var game_manager = null  # Will assign autoload singleton

func _ready() -> void:
	# Reference the GameManager singleton
	if Engine.has_singleton("GameManager"):
		game_manager = Engine.get_singleton("GameManager")

	# Collect menu items (skip Selector)
	for child in menu.get_children():
		if child is Control and child != selector:
			menu_items.append(child)

	# Wait one frame to ensure UI layout is ready
	await get_tree().process_frame
	update_selector_position()

	# Initialize fade
	fade.modulate.a = 0.0


func _unhandled_input(event: InputEvent) -> void:
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
	t.tween_property(fade, "modulate:a", 1.0, 1.95)
	t.finished.connect(_on_fade_complete)


func _on_fade_complete() -> void:
	# Integrate 1P/2P selection
	if game_manager == null:
		get_tree().change_scene_to_file("res://scenes/title_screen.tscn")
		return

	match current_index:
		0:
			# 1 Player
			game_manager.setup_single_player()
			get_tree().change_scene_to_file("res://scenes/game_scene.tscn")
		1:
			# 2 Player local co-op
			game_manager.setup_local_coop()
			get_tree().change_scene_to_file("res://scenes/game_scene.tscn")
		2:
			# Back to previous menu
			get_tree().change_scene_to_file("res://scenes/title_screen.tscn")

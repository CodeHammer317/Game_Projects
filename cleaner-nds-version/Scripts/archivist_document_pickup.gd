extends Area2D
class_name ArchivistDocumentPickup

signal document_opened(document_id: StringName)
signal document_closed(document_id: StringName)

@export_group("Document Data")
@export var document_id: StringName = &"archivist_file_01"
@export var source_label: String = "ARCHIVIST LOG 7C"
@export var document_title: String = "VESSEL SELECTION"
@export_multiline var transcript: String = "The excavation team is not searching for relics. They are searching for candidates. Demon Protocol compares living subjects against something recovered from the pre-Flood remains. The rejected names are transferred to local holding sites. I cannot find records of their release."

@export_group("Interaction")
@export var available_on_ready: bool = true
@export var interaction_action: StringName = &"attack"
@export var close_actions: Array[StringName] = [&"accept", &"attack", &"pause"]

@export_group("Presentation")
@export var bob_height: float = 3.0
@export var bob_speed: float = 2.2

@onready var document_sprite: Sprite2D = $DocumentSprite
@onready var document_glow: PointLight2D = $DocumentGlow
@onready var interaction_collision: CollisionShape2D = $InteractionCollision
@onready var interaction_prompt: Node2D = $InteractionPrompt
@onready var source_text: Label = $ReaderLayer/ReaderRoot/CenterContainer/ReaderPanel/ReaderMargin/ReaderContent/SourceLabel
@onready var title_text: Label = $ReaderLayer/ReaderRoot/CenterContainer/ReaderPanel/ReaderMargin/ReaderContent/DocumentTitle
@onready var transcript_text: RichTextLabel = $ReaderLayer/ReaderRoot/CenterContainer/ReaderPanel/ReaderMargin/ReaderContent/Transcript
@onready var reader_root: Control = $ReaderLayer/ReaderRoot
@onready var pickup_sound: AudioStreamPlayer = $PickupSound

var _player_in_range: Node = null
var _reader_open: bool = false
var _is_available: bool = false
var _base_sprite_y: float = 0.0


func _ready() -> void:
	interaction_prompt.visible = false
	reader_root.visible = false
	_base_sprite_y = document_sprite.position.y

	if document_id.is_empty():
		push_error("ArchivistDocumentPickup requires a unique document_id.")
		set_available(false)
		return

	if PlayerState.has_document(document_id):
		queue_free()
		return

	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)
	if not body_exited.is_connected(_on_body_exited):
		body_exited.connect(_on_body_exited)

	set_available(available_on_ready)


func _process(_delta: float) -> void:
	if not _is_available or _reader_open:
		return

	var seconds := Time.get_ticks_msec() / 1000.0
	document_sprite.position.y = _base_sprite_y + sin(seconds * bob_speed) * bob_height
	document_glow.energy = 0.72 + sin(seconds * bob_speed * 1.35) * 0.12


func _unhandled_input(event: InputEvent) -> void:
	if _reader_open:
		for action in close_actions:
			if event.is_action_pressed(action):
				_close_reader()
				get_viewport().set_input_as_handled()
				return
		return

	if _player_in_range != null and _is_available and event.is_action_pressed(interaction_action):
		_open_document(_player_in_range)
		get_viewport().set_input_as_handled()


func set_available(value: bool) -> void:
	_is_available = value and not PlayerState.has_document(document_id)
	monitoring = _is_available
	monitorable = _is_available
	interaction_collision.set_deferred("disabled", not _is_available)
	document_sprite.visible = _is_available
	document_glow.visible = _is_available
	interaction_prompt.visible = _is_available and _player_in_range != null


func reveal() -> void:
	set_available(true)


func open_for_player(player: Node) -> void:
	if _is_available and player != null:
		_open_document(player)


func _on_body_entered(body: Node) -> void:
	if not _is_available or not body.is_in_group("player"):
		return

	_player_in_range = body
	interaction_prompt.visible = true


func _on_body_exited(body: Node) -> void:
	if body != _player_in_range or _reader_open:
		return

	_player_in_range = null
	interaction_prompt.visible = false


func _open_document(player: Node) -> void:
	if _reader_open or not PlayerState.collect_document(document_id):
		return

	_reader_open = true
	_player_in_range = player
	monitoring = false
	interaction_collision.set_deferred("disabled", true)
	interaction_prompt.visible = false
	document_sprite.visible = false
	document_glow.visible = false

	source_text.text = source_label
	title_text.text = document_title
	transcript_text.text = transcript
	reader_root.visible = true

	if player.has_method("set_control_locked"):
		player.call("set_control_locked", true)

	if pickup_sound.stream != null:
		pickup_sound.play()

	document_opened.emit(document_id)


func _close_reader() -> void:
	if not _reader_open:
		return

	reader_root.visible = false
	_reader_open = false

	if _player_in_range != null and is_instance_valid(_player_in_range):
		if _player_in_range.has_method("set_control_locked"):
			_player_in_range.call("set_control_locked", false)

	document_closed.emit(document_id)
	queue_free()


func _exit_tree() -> void:
	if _reader_open and _player_in_range != null and is_instance_valid(_player_in_range):
		if _player_in_range.has_method("set_control_locked"):
			_player_in_range.call("set_control_locked", false)

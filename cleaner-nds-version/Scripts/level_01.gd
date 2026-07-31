extends Node2D
class_name OldDistrictLevel

const NEWSPAPER_CLOSE_ACTIONS: Array[StringName] = [&"accept", &"attack", &"pause"]

@export_group("Progression")
@export var final_enemy_group: StringName = &"old_district_final_enemy"
@export_node_path("Area2D") var exit_area_path: NodePath = ^"LevelFlow/AreaTransition"
@export_node_path("StaticBody2D") var exit_gate_path: NodePath = ^"LevelFlow/SubwayGate"

@export_group("Tutorial and Story")
@export_node_path("Area2D") var mattt_tutorial_path: NodePath = ^"Gameplay/Triggers/MatttTutorial"
@export_node_path("Area2D") var banter_trigger_path: NodePath = ^"Gameplay/Triggers/MatttBanter"
@export_node_path("Area2D") var police_audio_zone_path: NodePath = ^"Gameplay/Triggers/PoliceAudioZone"
@export_node_path("Area2D") var newspaper_text_path: NodePath = ^"Gameplay/StoryProps/MissingPoster/NewspaperText"
@export_multiline var newspaper_headline: String = "MISSING RESIDENT LAST SEEN IN OLD DISTRICT"
@export_multiline var newspaper_details: String = '''The resident pictured in today's notice aka "Toad", was last seen near the
													Old District subway. Anyone with information is urged to contact
													 local authorities.'''

@export_group("Presentation")
@export_node_path("Control") var message_panel_path: NodePath = ^"UI/MessageLayer/MessageRoot/MessagePanel"
@export_node_path("Label") var message_header_path: NodePath = ^"UI/MessageLayer/MessageRoot/MessagePanel/Margin/Content/Header"
@export_node_path("Label") var message_body_path: NodePath = ^"UI/MessageLayer/MessageRoot/MessagePanel/Margin/Content/Body"
@export_node_path("AudioStreamPlayer") var music_path: NodePath = ^"WorldFX/AudioStreamPlayer"
@export_node_path("AudioStreamPlayer") var police_siren_path: NodePath = ^"WorldFX/PoliceSiren"

@onready var exit_area: Area2D = get_node_or_null(exit_area_path) as Area2D
@onready var exit_gate: StaticBody2D = get_node_or_null(exit_gate_path) as StaticBody2D
@onready var mattt_tutorial: Area2D = get_node_or_null(mattt_tutorial_path) as Area2D
@onready var banter_trigger: Area2D = get_node_or_null(banter_trigger_path) as Area2D
@onready var police_audio_zone: Area2D = get_node_or_null(police_audio_zone_path) as Area2D
@onready var newspaper_text: Area2D = get_node_or_null(newspaper_text_path) as Area2D
@onready var message_panel: Control = get_node_or_null(message_panel_path) as Control
@onready var message_header: Label = get_node_or_null(message_header_path) as Label
@onready var message_body: Label = get_node_or_null(message_body_path) as Label
@onready var music: AudioStreamPlayer = get_node_or_null(music_path) as AudioStreamPlayer
@onready var police_siren: AudioStreamPlayer = get_node_or_null(police_siren_path) as AudioStreamPlayer

var _final_enemies: Array[Node] = []
var _exit_unlocked: bool = false
var _message_token: int = 0
var _message_source: StringName = &""
var _audio_tween: Tween = null
var _newspaper_reader: Node = null


func _ready() -> void:
	if message_panel != null:
		message_panel.visible = false

	_connect_optional_trigger(mattt_tutorial, _on_mattt_tutorial_entered)
	_connect_optional_trigger(banter_trigger, _on_banter_trigger_entered)
	_connect_optional_trigger(police_audio_zone, _on_police_audio_zone_entered)
	_connect_newspaper_trigger()

	_setup_final_encounter()
	_prepare_audio()


func _process(_delta: float) -> void:
	if exit_gate == null or not exit_gate.visible:
		return

	var pulse := 0.72 + sin(Time.get_ticks_msec() / 170.0) * 0.18
	exit_gate.modulate = Color(1.0, pulse, 0.16, 1.0)


func _connect_optional_trigger(trigger: Area2D, callback: Callable) -> void:
	if trigger != null and not trigger.body_entered.is_connected(callback):
		trigger.body_entered.connect(callback)


func _connect_newspaper_trigger() -> void:
	if newspaper_text == null:
		return
	if not newspaper_text.body_entered.is_connected(_on_newspaper_text_entered):
		newspaper_text.body_entered.connect(_on_newspaper_text_entered)
	if not newspaper_text.body_exited.is_connected(_on_newspaper_text_exited):
		newspaper_text.body_exited.connect(_on_newspaper_text_exited)


func _setup_final_encounter() -> void:
	_final_enemies.clear()
	for enemy in get_tree().get_nodes_in_group(final_enemy_group):
		if enemy == null or not is_instance_valid(enemy):
			continue
		_final_enemies.append(enemy)
		if enemy.has_signal("died") and not enemy.died.is_connected(_on_final_enemy_died):
			enemy.died.connect(_on_final_enemy_died)

	if _final_enemies.is_empty():
		_set_exit_locked(false)
	else:
		_set_exit_locked(true)


func _set_exit_locked(locked: bool) -> void:
	_exit_unlocked = not locked

	if exit_area != null:
		exit_area.set_deferred("monitoring", not locked)
		var exit_collision := exit_area.get_node_or_null("CollisionShape2D") as CollisionShape2D
		if exit_collision != null:
			exit_collision.set_deferred("disabled", locked)

	if exit_gate != null:
		exit_gate.visible = locked
		exit_gate.collision_layer = 1 if locked else 0
		var gate_collision := exit_gate.get_node_or_null("CollisionShape2D") as CollisionShape2D
		if gate_collision != null:
			gate_collision.set_deferred("disabled", not locked)


func _on_final_enemy_died(enemy: Node) -> void:
	_final_enemies.erase(enemy)
	if not _final_enemies.is_empty() or _exit_unlocked:
		return

	_set_exit_locked(false)
	_show_message(
		"MUNICIPAL SYSTEM // CORRUPTED",
		"PORTA SUBTERRANEA APERTA.\nSubway access unlocked.",
		4.5
	)
	_fade_audio(music, -28.0, 1.2)
	_fade_audio(police_siren, -34.0, 1.2)


func _on_mattt_tutorial_entered(body: Node) -> void:
	if not body.is_in_group(&"player"):
		return

	_disable_trigger(mattt_tutorial)
	if body.has_method("set_special_meter"):
		var maximum: Variant = body.get("special_meter_max")
		if maximum is int:
			body.call("set_special_meter", maximum)

	_show_message(
		"MATTT ASSIST ONLINE",
		"Special meter charged.\nPress 1 / CONTROLLER SPECIAL to call fire support.",
		5.0
	)


func _on_banter_trigger_entered(body: Node) -> void:
	if not body.is_in_group(&"player"):
		return

	_disable_trigger(banter_trigger)
	_show_message(
		"MATTT // COMMS",
		"If this really is a gas leak, I want it noted that I heroically volunteered from outside the blast radius.",
		5.5
	)


func _on_police_audio_zone_entered(body: Node) -> void:
	if not body.is_in_group(&"player"):
		return

	_disable_trigger(police_audio_zone)
	if police_siren != null and not police_siren.playing:
		police_siren.play()
	_fade_audio(police_siren, -19.0, 1.5)
	_fade_audio(music, -29.0, 1.5)
	_show_message(
		"NDS // WARNING",
		"Armed quarantine detail ahead. Subway access is still sealed.",
		4.0
	)


func _on_newspaper_text_entered(body: Node) -> void:
	if not body.is_in_group(&"player"):
		return

	var close_callback := Callable(self, "_close_newspaper")
	if not GlobalPauseMenu.begin_reading(close_callback, NEWSPAPER_CLOSE_ACTIONS):
		return

	_newspaper_reader = body
	_show_persistent_message(newspaper_headline, newspaper_details, &"newspaper")


func _on_newspaper_text_exited(body: Node) -> void:
	if body != _newspaper_reader:
		return

	GlobalPauseMenu.end_reading(Callable(self, "_close_newspaper"))
	_newspaper_reader = null
	_hide_message(&"newspaper")


func _close_newspaper() -> void:
	GlobalPauseMenu.end_reading(Callable(self, "_close_newspaper"))
	_newspaper_reader = null
	_hide_message(&"newspaper")


func _exit_tree() -> void:
	GlobalPauseMenu.end_reading(Callable(self, "_close_newspaper"))


func _disable_trigger(trigger: Area2D) -> void:
	if trigger == null:
		return

	trigger.set_deferred("monitoring", false)
	var trigger_collision := trigger.get_node_or_null("CollisionShape2D") as CollisionShape2D
	if trigger_collision != null:
		trigger_collision.set_deferred("disabled", true)


func _show_message(header: String, body: String, duration: float) -> void:
	if message_panel == null or message_header == null or message_body == null:
		return

	_message_token += 1
	var token := _message_token
	_message_source = &"timed"
	message_header.text = header
	message_body.text = body
	message_panel.visible = true
	message_panel.modulate.a = 0.0

	var reveal := create_tween()
	reveal.tween_property(message_panel, "modulate:a", 1.0, 0.18)
	await get_tree().create_timer(duration).timeout

	if token != _message_token or message_panel == null:
		return

	var hide := create_tween()
	hide.tween_property(message_panel, "modulate:a", 0.0, 0.25)
	await hide.finished
	if token == _message_token:
		message_panel.visible = false
		_message_source = &""


func _show_persistent_message(
	header: String,
	body: String,
	source: StringName
) -> void:
	if message_panel == null or message_header == null or message_body == null:
		return

	_message_token += 1
	_message_source = source
	message_header.text = header
	message_body.text = body
	message_panel.visible = true
	message_panel.modulate.a = 0.0

	var reveal := create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	reveal.tween_property(message_panel, "modulate:a", 1.0, 0.18)


func _hide_message(source: StringName) -> void:
	if message_panel == null or _message_source != source:
		return

	_message_token += 1
	_message_source = &""
	var hide := create_tween()
	hide.tween_property(message_panel, "modulate:a", 0.0, 0.18)
	await hide.finished

	if _message_source.is_empty():
		message_panel.visible = false


func _prepare_audio() -> void:
	if police_siren != null:
		police_siren.volume_db = -80.0
		if police_siren.playing:
			police_siren.stop()


func _fade_audio(player: AudioStreamPlayer, target_volume: float, duration: float) -> void:
	if player == null:
		return

	var tween := create_tween()
	tween.tween_property(player, "volume_db", target_volume, duration)

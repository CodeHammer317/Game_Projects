extends Node2D

const TOP_LOBSTA_PORTRAIT: Texture2D = preload("res://Assets/sprites/Study Art/TopLobstaConversationHeadshot.png")
const RAVEN_PORTRAIT: Texture2D = preload("res://Assets/sprites/Study Art/RavenHeadshotConversation.png")
const DIALOGUE_PANEL_HIGH_TOP: float = 0.05
const DIALOGUE_PANEL_HIGH_BOTTOM: float = 0.32
const DIALOGUE_PANEL_LOW_TOP: float = 0.68
const DIALOGUE_PANEL_LOW_BOTTOM: float = 0.95

@export var planting_time: float = 3.5
@export var dialogue_hold_time: float = 2.5
@export var fade_out_time: float = 1.5
@export_file("*.tscn") var next_scene: String = "res://Scenes/World/study.tscn"
@export_range(0.5, 30.0, 0.1) var boss_sound_min_delay: float = 3.0
@export_range(0.5, 30.0, 0.1) var boss_sound_max_delay: float = 7.0

@onready var boss: Node = $GlitchDemon
@onready var demon_spawn: AnimatedSprite2D = $Pulse
@onready var player: Node = $Player
@onready var lightning: AnimatedSprite2D = $Lightning
@onready var room_explosion: AnimatedSprite2D = $RoomExplosion
@onready var pulse_sound: AudioStreamPlayer = $PulseSound
@onready var boss_spawn_sound: AudioStreamPlayer = $BossSpawnSound
@onready var explosion_sound: AudioStreamPlayer = $ExplosionSound
@onready var dialogue_layer: CanvasLayer = $PostBossDialogue
@onready var dialogue_panel: ColorRect = $PostBossDialogue/DialogueRoot/DialoguePanel
@onready var dialogue_text: Label = $PostBossDialogue/DialogueRoot/DialoguePanel/DialogueText
@onready var dialogue_speaker: Label = $PostBossDialogue/DialogueRoot/DialoguePanel/Speaker
@onready var dialogue_portrait: TextureRect = $PostBossDialogue/DialogueRoot/DialoguePanel/Portrait
@onready var fade_layer: CanvasLayer = $FadeLayer
@onready var fade_overlay: ColorRect = $FadeLayer/FadeOverlay
@onready var archivist_document: ArchivistDocumentPickup = $ArchivistDocumentPickup

var _ending_sequence_started: bool = false
var _boss_sound_loop_active: bool = false


func _ready() -> void:
	dialogue_layer.visible = false
	fade_layer.visible = false
	boss_spawn_sound.stop()

	if boss != null and boss.has_signal("died"):
		boss.connect("died", _on_boss_defeated)
	else:
		push_warning("PulseChamber: GlitchDemon death signal is unavailable.")

	if demon_spawn != null and demon_spawn.has_signal("demon_spawned"):
		demon_spawn.connect("demon_spawned", _on_demon_spawned)
	else:
		push_warning("PulseChamber: demon spawn signal is unavailable.")


func _on_demon_spawned() -> void:
	if _boss_sound_loop_active:
		return

	_boss_sound_loop_active = true
	_run_boss_sound_loop()


func _run_boss_sound_loop() -> void:
	while _boss_sound_loop_active and is_instance_valid(boss):
		var minimum_delay := minf(boss_sound_min_delay, boss_sound_max_delay)
		var maximum_delay := maxf(boss_sound_min_delay, boss_sound_max_delay)
		await get_tree().create_timer(randf_range(minimum_delay, maximum_delay)).timeout

		if not _boss_sound_loop_active or not is_instance_valid(boss):
			break

		if "is_dead" in boss and boss.is_dead:
			_stop_boss_sound_loop()
			continue

		if _boss_sound_loop_active and boss_spawn_sound != null and boss_spawn_sound.stream != null:
			boss_spawn_sound.play()


func _stop_boss_sound_loop() -> void:
	_boss_sound_loop_active = false
	if boss_spawn_sound != null:
		boss_spawn_sound.stop()


func _on_boss_defeated(_defeated_boss: Node) -> void:
	_stop_boss_sound_loop()

	if _ending_sequence_started:
		return

	_ending_sequence_started = true
	_set_player_locked(true)
	dialogue_layer.visible = true
	dialogue_text.text = "RAVEN: Demon is down. I'll plant the explosives. Cover me."

	await get_tree().create_timer(dialogue_hold_time).timeout
	dialogue_text.text = "RAVEN: Planting charges..."
	await get_tree().create_timer(planting_time).timeout

	dialogue_text.text = "RAVEN: Charges set. Fire in the hole!"
	await get_tree().create_timer(dialogue_hold_time).timeout

	if explosion_sound != null and explosion_sound.stream != null:
		explosion_sound.play()

	_play_room_explosion()
	_shutdown_lightning()

	await get_tree().create_timer(0.75).timeout
	await _wait_for_archivist_document()

	dialogue_speaker.text = "TOP LOBSTA // COMMS"
	dialogue_portrait.texture = TOP_LOBSTA_PORTRAIT
	dialogue_text.text = "TOP LOBSTA: Azazel. So that's our architect. Great job—now return to base for debriefing."
	await get_tree().create_timer(dialogue_hold_time).timeout

	await _fade_out()
	_go_to_base()


func _wait_for_archivist_document() -> void:
	if PlayerState.has_document(&"archivist_file_03"):
		return

	if archivist_document == null or not is_instance_valid(archivist_document):
		push_warning("PulseChamber: Archivist File 03 is unavailable; continuing ending sequence.")
		return

	_set_dialogue_panel_high(true)
	dialogue_speaker.text = "TOP LOBSTA // COMMS"
	dialogue_portrait.texture = TOP_LOBSTA_PORTRAIT
	dialogue_text.text = "TOP LOBSTA: The blast uncovered an Archivist dead-drop. Read it before we leave."
	await get_tree().create_timer(dialogue_hold_time).timeout

	dialogue_speaker.text = "RAVEN // FIELD"
	dialogue_portrait.texture = RAVEN_PORTRAIT
	dialogue_text.text = "RAVEN: I'll read it."
	archivist_document.reveal()
	_set_player_locked(false)

	await archivist_document.document_opened
	dialogue_layer.visible = false

	await archivist_document.document_closed

	_set_player_locked(true)
	_set_dialogue_panel_high(false)
	dialogue_layer.visible = true


func _set_dialogue_panel_high(use_high_position: bool) -> void:
	if use_high_position:
		dialogue_panel.anchor_top = DIALOGUE_PANEL_HIGH_TOP
		dialogue_panel.anchor_bottom = DIALOGUE_PANEL_HIGH_BOTTOM
	else:
		dialogue_panel.anchor_top = DIALOGUE_PANEL_LOW_TOP
		dialogue_panel.anchor_bottom = DIALOGUE_PANEL_LOW_BOTTOM


func _shutdown_lightning() -> void:
	if lightning != null:
		if lightning.has_method("shutdown"):
			lightning.call("shutdown")
		else:
			lightning.stop()
			lightning.visible = false

	if pulse_sound != null:
		pulse_sound.stop()


func _play_room_explosion() -> void:
	if room_explosion == null:
		return

	room_explosion.visible = true
	room_explosion.frame = 0
	room_explosion.frame_progress = 0.0
	room_explosion.play(&"detonate")
	CombatFx.shake(14.0, 0.55, 28.0)

	if not room_explosion.animation_finished.is_connected(_on_room_explosion_finished):
		room_explosion.animation_finished.connect(_on_room_explosion_finished, CONNECT_ONE_SHOT)


func _on_room_explosion_finished() -> void:
	if room_explosion != null:
		room_explosion.visible = false


func _fade_out() -> void:
	fade_layer.visible = true
	fade_overlay.modulate.a = 0.0

	var tween := create_tween()
	tween.tween_property(fade_overlay, "modulate:a", 1.0, fade_out_time).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	await tween.finished


func _go_to_base() -> void:
	if next_scene.is_empty():
		push_warning("PulseChamber: next_scene is not assigned.")
		return

	PlayerState.begin_demo_finale()
	var error := get_tree().change_scene_to_file(next_scene)
	if error != OK:
		push_error("PulseChamber: failed to return to base. Error: %s" % error)
		fade_layer.visible = false
		dialogue_layer.visible = false
		_set_player_locked(false)


func _set_player_locked(locked: bool) -> void:
	if player == null or not is_instance_valid(player):
		return

	if player.has_method("set_control_locked"):
		player.call("set_control_locked", locked)

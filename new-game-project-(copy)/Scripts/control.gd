#Control.gd
extends Control

@export var chars_per_second: float = 25.0
@export var random_pitch_range: float = 0.1 # Adds variety to the typing
@export var next_scene: String = "res://scenes/level01.tscn"
#@export var auto_advance_time: float = 60.0


@onready var label = $ColorRect/TextLabel
@onready var audio = $AudioStreamPlayer
@onready var skip_label = $SkipLabel

var is_typing: bool = false
#var _timer: float = 0.0 #Used for the auto advance for first scene
var _skipped: bool = false


func _ready():
	skip_label.visible = true
	# Adjust polyphony so sounds don't cut each other off
	audio.max_polyphony = 4 
	
	start_dialogue("NDS // Secure Channel 7  
Clearance: Field Operative

Agent,

Your investigation at the Christian Library triggered multiple alerts across our network.  
The symbols you uncovered match pre‑Flood inscriptions found at three recent incident sites.

At 0430 hours, a civilian reported tremors beneath the Old District.  
Local authorities dismissed it as construction noise.
  
Our sensors say otherwise.

A Nephilim signature — faint, but rising — is pulsing beneath the abandoned subway line  
near the Standard Coffee Shop.

Your objectives are as follows:

1. Enter the Old District undetected.  
2. Locate the source of the seismic activity.  
3. Recover any relics, documents, or biological traces.  
4. Neutralize hostile entities if encountered.  
5. Extract before the area is quarantined by government forces.

Expect resistance.  
Expect misinformation.  
Expect the truth to fight back.

This is your first field deployment, Agent…  
but you’ve seen more than most recruits ever will.

Trust your instincts.  
Trust the signs.
  
And remember:

If the Nephilim are waking,  
we are already behind.
")
func _process(_delta: float) -> void:
	if _skipped:
		return

	'''_timer += delta
	if _timer >= auto_advance_time:
		_go_to_next_scene()'''

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("skip"):
		_skipped = true
		_go_to_next_scene()

func _go_to_next_scene() -> void:
	get_tree().change_scene_to_file(next_scene)

func start_dialogue(new_text: String):
	label.text = new_text
	label.visible_characters = 0
	skip_label.visible = true
	is_typing = true
	
	# 1. Animate the text using a Tween
	var duration = new_text.length() / chars_per_second
	var tween = create_tween()
	tween.tween_property(label, "visible_characters", new_text.length(), duration)
	tween.finished.connect(_on_typing_finished)
	
	# 2. Start the audio "heartbeat"
	play_typing_sounds()

func play_typing_sounds():
	if not is_typing:
		return

	var current_index = label.visible_characters
	
	# Only play sound if we haven't reached the end
	if current_index < label.text.length():
		var current_char = label.text[current_index]
		
		# Only play audio if the character isn't a space or newline
		if current_char != " " and current_char != "\n":
			# Apply a slight random pitch for a more natural feel
			audio.pitch_scale = randf_range(1.0 - random_pitch_range, 1.0 + random_pitch_range)
			audio.play()
		
		# Wait for the next character based on our speed
		get_tree().create_timer(1.0 / chars_per_second).timeout.connect(play_typing_sounds)

func _on_typing_finished():
	is_typing = false
	skip_label.visible = true

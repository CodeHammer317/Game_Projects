extends AnimatedSprite2D

@export var flash_light_path: NodePath = NodePath("../LightningFlashLight")
@export var peak_energy: float = 2.4
@export var response_speed: float = 34.0

@onready var flash_light: PointLight2D = get_node_or_null(flash_light_path) as PointLight2D

const FRAME_ENERGY = [0.08, 0.55, 1.0, 0.72, 0.24, 0.02]

var target_energy: float = 0.0
var _shut_down: bool = false


func _ready() -> void:
	frame_changed.connect(_sync_flash_to_frame)
	play(&"default")
	_sync_flash_to_frame()


func _process(delta: float) -> void:
	if flash_light == null:
		return
	flash_light.energy = move_toward(
		flash_light.energy,
		target_energy,
		response_speed * delta
	)


func shutdown() -> void:
	if _shut_down:
		return

	_shut_down = true
	target_energy = 0.0
	stop()
	visible = false
	set_process(false)

	if flash_light != null:
		flash_light.energy = 0.0


func _sync_flash_to_frame() -> void:
	if _shut_down:
		return
	if flash_light == null:
		return
	var energy_index: int = clampi(frame, 0, FRAME_ENERGY.size() - 1)
	target_energy = FRAME_ENERGY[energy_index] * peak_energy

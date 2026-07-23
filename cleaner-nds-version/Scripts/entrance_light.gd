extends PointLight2D

@export_group("Flicker")
@export var base_energy: float = 0.8
@export var energy_variation: float = 0.18
@export var min_interval: float = 0.04
@export var max_interval: float = 0.14
@export_range(0.0, 1.0) var blackout_chance: float = 0.04
@export var blackout_duration: float = 0.08
@export var smooth_flicker: bool = true

var _target_energy: float
var _time_until_change: float


func _ready() -> void:
	randomize()
	energy = base_energy
	_target_energy = base_energy
	_schedule_next_change()


func _process(delta: float) -> void:
	_time_until_change -= delta

	if _time_until_change <= 0.0:
		_choose_next_energy()
		_schedule_next_change()

	if smooth_flicker:
		energy = move_toward(
			energy,
			_target_energy,
			energy_variation * 20.0 * delta
		)
	else:
		energy = _target_energy


func _choose_next_energy() -> void:
	if randf() < blackout_chance:
		_target_energy = 0.0
		_time_until_change = blackout_duration
		return

	_target_energy = randf_range(
		maxf(0.0, base_energy - energy_variation),
		base_energy + energy_variation
	)


func _schedule_next_change() -> void:
	_time_until_change = randf_range(
		minf(min_interval, max_interval),
		maxf(min_interval, max_interval)
	)

extends Node
class_name Health

signal damaged(info: DamageInfo)
signal died

@export var max_health: int = 3
@export var invulnerable: bool = false
@export var damage_cooldown: float = 0.25

var current_health: int = 0
var _is_dead: bool = false
var _damage_cooldown_timer: float = 0.0


func _ready() -> void:
	current_health = max_health
	print(current_health)

func _process(delta: float) -> void:
	if _damage_cooldown_timer > 0.0:
		_damage_cooldown_timer = max(_damage_cooldown_timer - delta, 0.0)


func apply_damage(info: DamageInfo) -> void:
	if _is_dead:
		return

	if invulnerable:
		return

	if _damage_cooldown_timer > 0.0:
		return

	if info == null:
		return

	current_health -= info.damage
	current_health = max(current_health, 0)
	_damage_cooldown_timer = damage_cooldown
	print(current_health)
	print(name, " took damage: ", info.damage, " hp left: ", current_health)
	damaged.emit(info)

	if current_health <= 0:
		_is_dead = true
		died.emit()


func heal(amount: int) -> void:
	if _is_dead:
		return

	if amount <= 0:
		return

	current_health = min(current_health + amount, max_health)


func is_dead() -> bool:
	return _is_dead


func set_temporary_invulnerable(duration: float) -> void:
	_damage_cooldown_timer = max(_damage_cooldown_timer, duration)
	
func restore_full() -> void:
	_is_dead = false
	current_health = max_health
	damaged.emit(null)

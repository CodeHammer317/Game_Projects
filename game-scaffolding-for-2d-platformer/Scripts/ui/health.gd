extends Node
class_name Health

signal damaged(info: DamageInfo)
signal died
signal health_changed(current: int, maximum: int)

@export var max_health: int = 3
@export var invulnerable: bool = false
@export var damage_cooldown: float = 0.25
@export var use_persistent_player_state: bool = false

var current_health: int = 0
var _is_dead: bool = false
var _damage_cooldown_timer: float = 0.0


func _ready() -> void:
	if use_persistent_player_state:
		PlayerState.max_health = max_health

		# If first time starting game, initialize once.
		if PlayerState.current_health <= 0 and not PlayerState.player_dead:
			PlayerState.current_health = max_health

		current_health = PlayerState.current_health
		_is_dead = PlayerState.player_dead
	else:
		current_health = max_health

	print("Health ready:", get_path(), " -> ", current_health, "/", max_health)
	health_changed.emit(current_health, max_health)


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

	if current_health <= 0:
		_is_dead = true

	_sync_state()

	print(get_path(), " took damage: ", info.damage, " hp left: ", current_health)

	damaged.emit(info)
	health_changed.emit(current_health, max_health)

	if _is_dead:
		died.emit()


func heal(amount: int) -> void:
	if _is_dead:
		return
	if amount <= 0:
		return

	current_health = min(current_health + amount, max_health)
	_sync_state()
	damaged.emit(null)
	health_changed.emit(current_health, max_health)


func restore_full() -> void:
	_is_dead = false
	current_health = max_health
	_sync_state()
	damaged.emit(null)
	health_changed.emit(current_health, max_health)


func _sync_state() -> void:
	if use_persistent_player_state:
		PlayerState.current_health = current_health
		PlayerState.max_health = max_health
		PlayerState.player_dead = _is_dead








'''extends Node
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
	damaged.emit(null)'''

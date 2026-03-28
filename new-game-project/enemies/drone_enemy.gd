extends CharacterBody2D
class_name DroneEnemy

enum State {
	IDLE,
	CHASE,
	ATTACK,
	DEAD
}

@export var move_speed: float = 70.0
@export var vertical_follow_speed: float = 55.0
@export var hover_amplitude: float = 5.0
@export var hover_frequency: float = 2.0
@export var projectile_scene: PackedScene

@onready var death_Explosion: AnimatedSprite2D = $AnimatedSprite2D2
@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var detection_area: Area2D = $DetectionArea
@onready var attack_area: Area2D = $AttackArea
@onready var muzzle: Marker2D = $Muzzle
@onready var fire_cooldown: Timer = $FireCooldown
@onready var hurtbox: Area2D = $Hurtbox
@onready var health = $Health


var state: State = State.IDLE
var target: Node2D = null
var _hover_time: float = 0.0
var _base_y: float = 0.0
var _attack_ready: bool = false

func _ready() -> void:
	_base_y = global_position.y

	fire_cooldown.one_shot = true

	if not detection_area.body_entered.is_connected(_on_detection_body_entered):
		detection_area.body_entered.connect(_on_detection_body_entered)
	if not detection_area.body_exited.is_connected(_on_detection_body_exited):
		detection_area.body_exited.connect(_on_detection_body_exited)

	if not attack_area.body_entered.is_connected(_on_attack_body_entered):
		attack_area.body_entered.connect(_on_attack_body_entered)
	if not attack_area.body_exited.is_connected(_on_attack_body_exited):
		attack_area.body_exited.connect(_on_attack_body_exited)

	if health.has_signal("died") and not health.died.is_connected(_on_died):
		health.died.connect(_on_died)
	if health.has_signal("damaged") and not health.damaged.is_connected(_on_damaged):
		health.damaged.connect(_on_damaged)
	sprite.play("idle")


func _physics_process(delta: float) -> void:
	if state == State.DEAD:
		return

	_hover_time += delta

	match state:
		State.IDLE:
			_process_idle(delta)
		State.CHASE:
			_process_chase(delta)
		State.ATTACK:
			_process_attack(delta)

	move_and_slide()


func _process_idle(delta: float) -> void:
	velocity.x = move_toward(velocity.x, 0.0, 200.0 * delta)
	velocity.y = sin(_hover_time * TAU * hover_frequency) * hover_amplitude

	if sprite.animation != "idle":
		sprite.play("idle")

	if is_instance_valid(target):
		state = State.CHASE


func _process_chase(delta: float) -> void:
	if not is_instance_valid(target):
		target = null
		state = State.IDLE
		return

	var to_target: Vector2 = target.global_position - global_position

	var desired_x = sign(to_target.x) * move_speed
	var desired_y = clamp(to_target.y, -vertical_follow_speed, vertical_follow_speed)

	velocity.x = move_toward(velocity.x, desired_x, 240.0 * delta)
	velocity.y = move_toward(velocity.y, desired_y, 180.0 * delta)

	velocity.y += sin(_hover_time * TAU * hover_frequency) * hover_amplitude * 0.35

	_update_facing()

	if sprite.animation != "move":
		sprite.play("move")

	if _attack_ready:
		state = State.ATTACK


func _process_attack(delta: float) -> void:
	if not is_instance_valid(target):
		target = null
		_attack_ready = false
		state = State.IDLE
		return

	var to_target: Vector2 = target.global_position - global_position

	velocity.x = move_toward(velocity.x, 0.0, 260.0 * delta)
	velocity.y = move_toward(velocity.y, clamp(to_target.y, -25.0, 25.0), 160.0 * delta)
	velocity.y += sin(_hover_time * TAU * hover_frequency) * hover_amplitude * 0.25

	_update_facing()

	if sprite.animation != "attack":
		sprite.play("attack")

	if not _attack_ready:
		state = State.CHASE
		return

	if fire_cooldown.is_stopped():
		_fire_projectile()
		fire_cooldown.start()

	if not _attack_ready:
		state = State.CHASE


func _update_facing() -> void:
	if not is_instance_valid(target):
		return

	sprite.flip_h = target.global_position.x < global_position.x


func _fire_projectile() -> void:
	if projectile_scene == null:
		return
	if not is_instance_valid(target):
		return

	var projectile = projectile_scene.instantiate()
	get_tree().current_scene.add_child(projectile)
	projectile.global_position = muzzle.global_position

	var dir := (target.global_position - muzzle.global_position).normalized()

	if projectile is Projectile:
		projectile.team = 2
		projectile.launch(dir, target, self)
	elif projectile.has_method("launch"):
		projectile.launch(dir, target)
		#muzzle_flash.play("default")

func _on_detection_body_entered(body: Node) -> void:
	if body.is_in_group("player"):
		target = body as Node2D
		if state != State.DEAD:
			state = State.CHASE


func _on_detection_body_exited(body: Node) -> void:
	if body == target:
		target = null
		_attack_ready = false
		if state != State.DEAD:
			state = State.IDLE


func _on_attack_body_entered(body: Node) -> void:
	if body == target:
		_attack_ready = true
		if state != State.DEAD:
			state = State.ATTACK


func _on_attack_body_exited(body: Node) -> void:
	if body == target:
		_attack_ready = false
		if state != State.DEAD and is_instance_valid(target):
			state = State.CHASE


func _on_died() -> void:
	state = State.DEAD
	velocity = Vector2.ZERO

	detection_area.monitoring = false
	attack_area.monitoring = false
	hurtbox.monitoring = false

	set_deferred("collision_layer", 0)
	set_deferred("collision_mask", 0)

	if sprite.sprite_frames.has_animation("death"):
		sprite.play("death")
		await sprite.animation_finished
		death_Explosion.visible = true
		death_Explosion.play("default")
		await death_Explosion.animation_finished
	queue_free()
func _on_damaged(info: DamageInfo) -> void:
	if info.has_tag("electric"):
		pass

	if info.knockback != Vector2.ZERO:
		velocity += info.knockback

	modulate = Color(1.0, 1.0, 1.0, 1.0)
	await get_tree().create_timer(0.06).timeout
	modulate = Color(1.0, 1.0, 1.0)

extends Area2D
class_name HeavyPunchHitbox

@export var damage: int = 2
@export var lifetime: float = 0.12
@export var knockback_force: float = 140.0
@export var team: int = 1
@export var destroy_on_first_hit: bool = false

var instigator: Node = null
var facing: Vector2 = Vector2.RIGHT
var _hit_set: Dictionary = {}
var _expired: bool = false

@onready var timer: Timer = $Timer
@onready var punch_hit: AnimatedSprite2D = $AnimatedSprite2D


func _ready() -> void:
	timer.one_shot = true
	timer.wait_time = lifetime

	if not timer.timeout.is_connected(_on_timer_timeout):
		timer.timeout.connect(_on_timer_timeout)

	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)

	if not area_entered.is_connected(_on_area_entered):
		area_entered.connect(_on_area_entered)

	if punch_hit != null and not punch_hit.animation_finished.is_connected(_on_anim_finished):
		punch_hit.animation_finished.connect(_on_anim_finished)

	timer.start()


func setup(owner_node: Node, dir: Vector2, owner_team: int = 1) -> void:
	instigator = owner_node
	team = owner_team

	if dir == Vector2.ZERO:
		facing = Vector2.RIGHT
	else:
		facing = dir.normalized()


func _on_body_entered(body: Node) -> void:
	_process_hit(body)


func _on_area_entered(area: Area2D) -> void:
	_process_hit(area)


func _process_hit(target_node: Node) -> void:
	if _expired:
		return

	if target_node == null:
		return

	if target_node == instigator:
		return

	var hurtbox := _find_hurtbox(target_node)
	if hurtbox == null:
		return

	if hurtbox == self:
		return

	var target_owner: Node = hurtbox.get_parent()
	if target_owner == null:
		target_owner = hurtbox

	if target_owner == instigator:
		return

	var id := target_owner.get_instance_id()
	if _hit_set.has(id):
		return
	_hit_set[id] = true

	if not hurtbox.has_method("take_damage"):
		return

	var info := DamageInfo.new(
		damage,
		facing * knockback_force,
		instigator if is_instance_valid(instigator) else null,
		["melee", "punch"],
		team
	)

	hurtbox.take_damage(info)

	if destroy_on_first_hit:
		_expire_hitbox()


func _find_hurtbox(node: Node) -> Hurtbox:
	if node is Hurtbox:
		return node as Hurtbox

	for child in node.get_children():
		if child is Hurtbox:
			return child as Hurtbox

	return null


func _on_timer_timeout() -> void:
	_expire_hitbox()


func _expire_hitbox() -> void:
	if _expired:
		return

	_expired = true
	monitoring = false
	monitorable = false

	if punch_hit != null and punch_hit.sprite_frames != null and punch_hit.sprite_frames.has_animation("default"):
		punch_hit.play("default")
	else:
		queue_free()


func _on_anim_finished() -> void:
	if _expired:
		queue_free()

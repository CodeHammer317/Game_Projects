extends CanvasLayer
class_name PlayerHUD

@export var player_path: NodePath
@export var hide_charge_bar_when_idle: bool = true

@onready var health_bar: TextureProgressBar = $HealthBar
@onready var ability_bar: TextureProgressBar = $AbilityBar
@onready var charge_bar: TextureProgressBar = $ChargeBar

var player: Player = null
var health: Health = null


func _ready() -> void:
	_initialize_bars()

	if not get_tree().node_added.is_connected(_on_node_added):
		get_tree().node_added.connect(_on_node_added)

	call_deferred("_find_and_bind_player")


func _exit_tree() -> void:
	if get_tree().node_added.is_connected(_on_node_added):
		get_tree().node_added.disconnect(_on_node_added)

	_disconnect_player()


func _initialize_bars() -> void:
	health_bar.min_value = 0.0
	ability_bar.min_value = 0.0
	charge_bar.min_value = 0.0
	charge_bar.max_value = 1.0
	charge_bar.value = 0.0
	charge_bar.visible = not hide_charge_bar_when_idle


func _find_and_bind_player() -> void:
	var candidate: Node = null

	if not player_path.is_empty():
		candidate = get_node_or_null(player_path)

	if candidate == null:
		candidate = get_tree().get_first_node_in_group("player")

	if candidate is Player:
		set_player(candidate as Player)
	else:
		push_warning("HUD: player not found.")


func set_player(new_player: Player) -> void:
	if player == new_player:
		_update_all_bars()
		return

	_disconnect_player()
	player = new_player

	if player == null:
		return

	if not player.tree_exiting.is_connected(_on_player_tree_exiting):
		player.tree_exiting.connect(_on_player_tree_exiting)

	health = player.get_node_or_null("Health") as Health
	if health == null:
		push_warning("HUD: player has no Health node.")
	else:
		if not health.health_changed.is_connected(_on_health_changed):
			health.health_changed.connect(_on_health_changed)

	if not player.shot_charge_changed.is_connected(_on_shot_charge_changed):
		player.shot_charge_changed.connect(_on_shot_charge_changed)

	if not player.special_meter_changed.is_connected(_on_special_meter_changed):
		player.special_meter_changed.connect(_on_special_meter_changed)

	_update_all_bars()


func _disconnect_player() -> void:
	if health != null and is_instance_valid(health):
		if health.health_changed.is_connected(_on_health_changed):
			health.health_changed.disconnect(_on_health_changed)

	if player != null and is_instance_valid(player):
		if player.tree_exiting.is_connected(_on_player_tree_exiting):
			player.tree_exiting.disconnect(_on_player_tree_exiting)

		if player.shot_charge_changed.is_connected(_on_shot_charge_changed):
			player.shot_charge_changed.disconnect(_on_shot_charge_changed)

		if player.special_meter_changed.is_connected(_on_special_meter_changed):
			player.special_meter_changed.disconnect(_on_special_meter_changed)

	player = null
	health = null


func _update_all_bars() -> void:
	if health != null:
		_on_health_changed(health.current_health, health.max_health)

	if player != null:
		_on_special_meter_changed(player.special_meter, player.special_meter_max)
		_on_shot_charge_changed(player.get_shot_charge_ratio(), false)


func _on_health_changed(current: int, maximum: int) -> void:
	var safe_maximum := maxi(maximum, 1)
	health_bar.max_value = safe_maximum
	health_bar.value = clampi(current, 0, safe_maximum)


func _on_special_meter_changed(current: int, maximum: int) -> void:
	var safe_maximum := maxi(maximum, 1)
	ability_bar.max_value = safe_maximum
	ability_bar.value = clampi(current, 0, safe_maximum)


func _on_shot_charge_changed(ratio: float, charging: bool) -> void:
	charge_bar.value = clampf(ratio, 0.0, 1.0)

	if hide_charge_bar_when_idle:
		charge_bar.visible = charging


func _on_node_added(node: Node) -> void:
	if node is Player:
		_bind_player_when_ready(node as Player)


func _bind_player_when_ready(new_player: Player) -> void:
	if not new_player.is_node_ready():
		await new_player.ready

	if is_instance_valid(new_player):
		set_player(new_player)


func _on_player_tree_exiting() -> void:
	player = null
	health = null
	call_deferred("_find_and_bind_player")

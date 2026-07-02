extends CanvasLayer
class_name PlayerHUD

@export_group("References")
@export var player_path: NodePath
@export var health_bar_path: NodePath = ^"TextureRect/HealthBar"
@export var ability_bar_path: NodePath = ^"TextureRect/AbilityBar"
@export var charge_bar_path: NodePath = ^"TextureRect/ChargeBar"

@export_group("Behavior")
@export var hide_charge_bar_when_idle: bool = true

@onready var health_bar: TextureProgressBar = get_node(health_bar_path) as TextureProgressBar
@onready var ability_bar: TextureProgressBar = get_node(ability_bar_path) as TextureProgressBar
@onready var charge_bar: TextureProgressBar = get_node(charge_bar_path) as TextureProgressBar

var player: Player = null
var health: Health = null


func _ready() -> void:
	_initialize_bars()

	var tree := get_tree()
	if not tree.node_added.is_connected(_on_node_added):
		tree.node_added.connect(_on_node_added)

	call_deferred("_find_and_bind_player")


func _exit_tree() -> void:
	var tree := get_tree()
	if tree != null and tree.node_added.is_connected(_on_node_added):
		tree.node_added.disconnect(_on_node_added)

	_disconnect_player()


func _initialize_bars() -> void:
	health_bar.min_value = 0.0
	ability_bar.min_value = 0.0
	ability_bar.value = 0.0
	charge_bar.min_value = 0.0
	charge_bar.max_value = 1.0
	charge_bar.step = 0.01
	charge_bar.value = 0.0
	charge_bar.visible = not hide_charge_bar_when_idle


func _find_and_bind_player() -> void:
	if not is_inside_tree():
		return

	var candidate := _find_player()
	if candidate != null:
		set_player(candidate)


func _find_player() -> Player:
	if not player_path.is_empty():
		var configured_player := get_node_or_null(player_path) as Player
		if configured_player != null:
			return configured_player

	var grouped_player := get_tree().get_first_node_in_group("player")
	return grouped_player as Player


func set_player(new_player: Player) -> void:
	if player == new_player:
		_update_all_bars()
		return

	_disconnect_player()
	player = new_player

	if player == null or not is_instance_valid(player):
		player = null
		return

	health = player.get_node_or_null("Health") as Health
	if health == null:
		push_warning("HUD: player has no Health node.")

	if not player.tree_exiting.is_connected(_on_player_tree_exiting):
		player.tree_exiting.connect(_on_player_tree_exiting)
	if not player.shot_charge_changed.is_connected(_on_shot_charge_changed):
		player.shot_charge_changed.connect(_on_shot_charge_changed)
	if not player.special_meter_changed.is_connected(_on_special_meter_changed):
		player.special_meter_changed.connect(_on_special_meter_changed)
	if health != null and not health.health_changed.is_connected(_on_health_changed):
		health.health_changed.connect(_on_health_changed)

	_update_all_bars()


func _disconnect_player() -> void:
	if is_instance_valid(health) and health.health_changed.is_connected(_on_health_changed):
		health.health_changed.disconnect(_on_health_changed)

	if is_instance_valid(player):
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
		_on_shot_charge_changed(0.0, player.maximum_charge_time, false)


func _on_health_changed(current: int, maximum: int) -> void:
	_set_bar_value(health_bar, current, maximum)


func _on_special_meter_changed(current: int, maximum: int) -> void:
	_set_bar_value(ability_bar, current, maximum)


func _set_bar_value(bar: TextureProgressBar, current: int, maximum: int) -> void:
	var safe_maximum := maxi(maximum, 1)
	bar.max_value = safe_maximum
	bar.value = clampi(current, 0, safe_maximum)


func _on_shot_charge_changed(
	elapsed_time: float,
	charge_duration: float,
	charging: bool
) -> void:
	var safe_duration := maxf(charge_duration, 0.01)
	charge_bar.max_value = safe_duration
	charge_bar.value = clampf(elapsed_time, 0.0, safe_duration)

	if hide_charge_bar_when_idle:
		charge_bar.visible = charging


func _on_node_added(node: Node) -> void:
	if player == null and node is Player:
		_bind_player_when_ready(node as Player)


func _bind_player_when_ready(new_player: Player) -> void:
	if not new_player.is_node_ready():
		await new_player.ready

	if player == null and is_inside_tree() and is_instance_valid(new_player) and new_player.is_inside_tree():
		set_player(new_player)


func _on_player_tree_exiting() -> void:
	if is_inside_tree():
		call_deferred("_clear_and_rebind_player")


func _clear_and_rebind_player() -> void:
	_disconnect_player()
	if not is_inside_tree():
		return

	await get_tree().process_frame
	_find_and_bind_player()

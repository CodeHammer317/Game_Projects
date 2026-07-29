extends CanvasLayer
class_name PlayerHUD

@export_group("References")
@export var player_path: NodePath
@export var health_bar_path: NodePath = ^"TextureRect/HealthBar"
@export var ability_bar_path: NodePath = ^"TextureRect/AbilityBar"
@export var charge_bar_path: NodePath = ^"TextureRect/ChargeBar"
@export var helper_icon_path: NodePath = ^"TextureRect/HelperIcon"
@export var lives_counter_path: NodePath = ^"TextureRect/LivesCounter"
@export var apple_count_label_path: NodePath = ^"TextureRect/AppleCounter/Count"
@export var score_label_path: NodePath = ^"ScorePanel/ScoreValue"
@export var high_score_label_path: NodePath = ^"ScorePanel/HighScoreValue"

@export_group("Behavior")
@export var hide_charge_bar_when_idle: bool = true
@export var helper_icon_slot_size: Vector2 = Vector2(24.0, 24.0)

@onready var health_bar: TextureProgressBar = get_node(health_bar_path) as TextureProgressBar
@onready var ability_bar: TextureProgressBar = get_node(ability_bar_path) as TextureProgressBar
@onready var charge_bar: TextureProgressBar = get_node(charge_bar_path) as TextureProgressBar
@onready var helper_icon: Sprite2D = _resolve_helper_icon()
@onready var lives_counter: HBoxContainer = get_node_or_null(lives_counter_path) as HBoxContainer
@onready var apple_count_label: Label = get_node_or_null(apple_count_label_path) as Label
@onready var score_label: Label = get_node_or_null(score_label_path) as Label
@onready var high_score_label: Label = get_node_or_null(high_score_label_path) as Label

var player: Player = null
var health: Health = null
var life_icons: Array[TextureRect] = []
var scene_helper_icon: Texture2D = null


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_initialize_bars()
	_initialize_lives_counter()
	if helper_icon != null:
		scene_helper_icon = helper_icon.texture
	_update_helper_icon(PlayerState.selected_helper)
	_update_score(ScoreManager.score)
	_update_high_score(ScoreManager.high_score)

	if not PlayerState.helper_selected.is_connected(_update_helper_icon):
		PlayerState.helper_selected.connect(_update_helper_icon)
	if not PlayerState.lives_changed.is_connected(_update_lives_counter):
		PlayerState.lives_changed.connect(_update_lives_counter)
	if not ScoreManager.score_changed.is_connected(_update_score):
		ScoreManager.score_changed.connect(_update_score)
	if not ScoreManager.high_score_changed.is_connected(_update_high_score):
		ScoreManager.high_score_changed.connect(_update_high_score)

	var tree := get_tree()
	if not tree.node_added.is_connected(_on_node_added):
		tree.node_added.connect(_on_node_added)

	call_deferred("_find_and_bind_player")


func _resolve_helper_icon() -> Sprite2D:
	if not helper_icon_path.is_empty():
		var configured_icon := get_node_or_null(helper_icon_path) as Sprite2D
		if configured_icon != null:
			return configured_icon

	return get_node_or_null("TextureRect/HelperIcon") as Sprite2D


func _exit_tree() -> void:
	if PlayerState.helper_selected.is_connected(_update_helper_icon):
		PlayerState.helper_selected.disconnect(_update_helper_icon)
	if PlayerState.lives_changed.is_connected(_update_lives_counter):
		PlayerState.lives_changed.disconnect(_update_lives_counter)
	if ScoreManager.score_changed.is_connected(_update_score):
		ScoreManager.score_changed.disconnect(_update_score)
	if ScoreManager.high_score_changed.is_connected(_update_high_score):
		ScoreManager.high_score_changed.disconnect(_update_high_score)

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


func _initialize_lives_counter() -> void:
	life_icons.clear()

	if lives_counter == null:
		push_warning("HUD: LivesCounter node is missing.")
		return

	for child in lives_counter.get_children():
		var icon := child as TextureRect
		if icon != null:
			life_icons.append(icon)

	_update_lives_counter(
		PlayerState.get_lives_remaining(),
		PlayerState.lives_maximum
	)


func _update_lives_counter(remaining: int, maximum: int) -> void:
	var available_slots := mini(maximum, life_icons.size())
	var visible_lives := clampi(remaining, 0, available_slots)

	for index in life_icons.size():
		var icon := life_icons[index]
		icon.visible = index < available_slots

		if index < visible_lives:
			icon.modulate = Color.WHITE
		else:
			icon.modulate = Color(0.25, 0.25, 0.25, 0.35)


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
	if not player.apple_ammo_changed.is_connected(_on_apple_ammo_changed):
		player.apple_ammo_changed.connect(_on_apple_ammo_changed)
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
		if player.apple_ammo_changed.is_connected(_on_apple_ammo_changed):
			player.apple_ammo_changed.disconnect(_on_apple_ammo_changed)

	player = null
	health = null


func _update_all_bars() -> void:
	if health != null:
		_on_health_changed(health.current_health, health.max_health)

	if player != null:
		_on_special_meter_changed(player.special_meter, player.special_meter_max)
		_on_apple_ammo_changed(player.apple_ammo, player.max_apple_ammo)
		_on_shot_charge_changed(0.0, player.maximum_charge_time, false)


func _on_health_changed(current: int, maximum: int) -> void:
	_set_bar_value(health_bar, current, maximum)


func _on_special_meter_changed(current: int, maximum: int) -> void:
	_set_bar_value(ability_bar, current, maximum)


func _on_apple_ammo_changed(current: int, _maximum: int) -> void:
	if apple_count_label != null:
		apple_count_label.text = "x%d" % maxi(current, 0)


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


func _update_helper_icon(helper_id: StringName) -> void:
	if helper_icon == null:
		push_warning("HUD: HelperIcon node is missing.")
		return

	var icon: Texture2D = scene_helper_icon
	if icon == null:
		icon = PlayerState.get_helper_hud_icon(helper_id)

	helper_icon.texture = icon
	helper_icon.visible = icon != null

	if icon == null:
		return

	var texture_size := Vector2(icon.get_size())
	if texture_size.x <= 0.0 or texture_size.y <= 0.0:
		return

	var fit_scale := minf(
		helper_icon_slot_size.x / texture_size.x,
		helper_icon_slot_size.y / texture_size.y
	)
	helper_icon.scale = Vector2.ONE * fit_scale


func _update_score(value: int) -> void:
	if score_label != null:
		score_label.text = ScoreManager.format_score(value)


func _update_high_score(value: int) -> void:
	if high_score_label != null:
		high_score_label.text = ScoreManager.format_score(value)


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

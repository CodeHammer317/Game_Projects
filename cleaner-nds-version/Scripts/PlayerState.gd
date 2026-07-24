extends Node

signal upgrade_unlocked(upgrade_name: StringName)
signal helper_unlocked(helper_id: StringName)
signal helper_selected(helper_id: StringName)
signal document_collected(document_id: StringName)

const DEFAULT_HELPER: StringName = &"mattt"
const MATTT_ASSIST_SCENE: PackedScene = preload("res://Scenes/Player/mattt_assist.tscn")
const MATTT_HUD_ICON: Texture2D = preload("res://Assets/NDS Game Files/MatTt Sprites/GhostMatttHead1.png")

const UPGRADE_DEFINITIONS := {
	&"double_jump": {
		"display_name": "Double Jump",
		"description": "Jump once more while airborne."
	},
	&"wall_slide": {
		"display_name": "Wall Slide",
		"description": "Slide down walls and wall jump."
	},
	&"charge_shot": {
		"display_name": "Charge Shot",
		"description": "Hold shoot to charge a stronger projectile."
	}
}

const HELPER_DEFINITIONS := {
	&"mattt": {
		"display_name": "Mattt",
		"description": "Calls down a fire column on the nearest enemy.",
		"assist_scene": MATTT_ASSIST_SCENE,
		"hud_icon": MATTT_HUD_ICON,
	}
}

var max_health: int = 10
var current_health: int = 10
var player_dead: bool = false
var starting_upgrades: Array[StringName] = []
var unlocked_upgrades: Dictionary = {}
var starting_helpers: Array[StringName] = [DEFAULT_HELPER]
var unlocked_helpers: Dictionary = {}
var selected_helper: StringName = DEFAULT_HELPER
var collected_documents: Dictionary = {}
var demo_finale_pending: bool = false


func _ready() -> void:
	reset_upgrades()
	reset_helpers()
	reset_documents()


func reset_all() -> void:
	current_health = max_health
	player_dead = false
	reset_upgrades()
	reset_helpers()
	reset_documents()
	demo_finale_pending = false


func begin_demo_finale() -> void:
	demo_finale_pending = true


func finish_demo_finale() -> void:
	demo_finale_pending = false


func has_document(document_id: StringName) -> bool:
	return collected_documents.get(document_id, false)


func collect_document(document_id: StringName) -> bool:
	if document_id.is_empty():
		push_warning("Cannot collect a document without an ID.")
		return false

	if has_document(document_id):
		return false

	collected_documents[document_id] = true
	document_collected.emit(document_id)
	return true


func reset_documents() -> void:
	collected_documents.clear()


func has_upgrade(upgrade_name: StringName) -> bool:
	return unlocked_upgrades.get(upgrade_name, false)


func unlock_upgrade(upgrade_name: StringName) -> bool:
	if not UPGRADE_DEFINITIONS.has(upgrade_name):
		push_warning("Unknown upgrade: " + str(upgrade_name))
		return false

	if has_upgrade(upgrade_name):
		return false

	unlocked_upgrades[upgrade_name] = true
	upgrade_unlocked.emit(upgrade_name)
	return true


func reset_upgrades() -> void:
	unlocked_upgrades.clear()

	for upgrade_name in starting_upgrades:
		if UPGRADE_DEFINITIONS.has(upgrade_name):
			unlocked_upgrades[upgrade_name] = true


func get_upgrade_display_name(upgrade_name: StringName) -> String:
	if not UPGRADE_DEFINITIONS.has(upgrade_name):
		return str(upgrade_name).capitalize()

	return UPGRADE_DEFINITIONS[upgrade_name].get("display_name", str(upgrade_name).capitalize())


func has_helper(helper_id: StringName) -> bool:
	return unlocked_helpers.get(helper_id, false)


func unlock_helper(helper_id: StringName) -> bool:
	if not HELPER_DEFINITIONS.has(helper_id):
		push_warning("Unknown helper: " + str(helper_id))
		return false

	if has_helper(helper_id):
		return false

	unlocked_helpers[helper_id] = true
	helper_unlocked.emit(helper_id)
	return true


func select_helper(helper_id: StringName) -> bool:
	if not has_helper(helper_id):
		push_warning("Cannot select locked helper: " + str(helper_id))
		return false

	if selected_helper == helper_id:
		return true

	selected_helper = helper_id
	helper_selected.emit(selected_helper)
	return true


func reset_helpers() -> void:
	unlocked_helpers.clear()

	for helper_id in starting_helpers:
		if HELPER_DEFINITIONS.has(helper_id):
			unlocked_helpers[helper_id] = true

	if has_helper(DEFAULT_HELPER):
		selected_helper = DEFAULT_HELPER
	elif not unlocked_helpers.is_empty():
		selected_helper = unlocked_helpers.keys()[0]
	else:
		selected_helper = &""

	helper_selected.emit(selected_helper)


func get_selected_helper_definition() -> Dictionary:
	return HELPER_DEFINITIONS.get(selected_helper, {})


func get_selected_helper_assist_scene() -> PackedScene:
	return get_selected_helper_definition().get("assist_scene") as PackedScene


func get_selected_helper_hud_icon() -> Texture2D:
	return get_helper_hud_icon(selected_helper)


func get_helper_hud_icon(helper_id: StringName) -> Texture2D:
	var definition: Dictionary = HELPER_DEFINITIONS.get(helper_id, {})
	return definition.get("hud_icon") as Texture2D


func get_helper_display_name(helper_id: StringName) -> String:
	if not HELPER_DEFINITIONS.has(helper_id):
		return str(helper_id).capitalize()

	return HELPER_DEFINITIONS[helper_id].get("display_name", str(helper_id).capitalize())

# PlayerStats.gd
extends Resource
class_name PlayerStats

@export var max_speed : float = 150.0
@export var accel_ground : float = 1400.0
@export var accel_air : float = 900.0
@export var friction_ground : float = 1600.0
@export var air_control : float = 0.65

@export var gravity : float = 987.0
@export var jump_velocity : float = -330.0
@export var coyote_time : float = 0.12
@export var jump_buffer : float = 0.14
@export var variable_jump_cut : float = 0.55

@export var dash_speed : float = 450.0
@export var dash_time : float = 0.045
@export var dash_cooldown : float = 0.35

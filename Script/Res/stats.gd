extends Resource
class_name stats

@export_category("Stats")
@export var base_defense : float = 20
@export var max_health : float = 100
@export var max_stamina : float = 100
@export var stamina_regen : float = 5
@export var stamina_exhausted_regen : float = 15
@export var stamina_drain : float = 25

@export_category("Movement")
@export var sprint_speed : float = 15
@export var walk_speed : float = 7
@export var roll_speed : float = 10
@export var roll_rot_speed : float = 7

@export_category("Modifiers")
@export var mod_speed : float = 0

func reset_mods() -> void:
	mod_speed = 0

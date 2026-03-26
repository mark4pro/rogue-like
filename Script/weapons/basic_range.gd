extends RigidBody2D

@export_category("This Object")
@export var col : RigidBody2D = null
@export var sprite : Sprite2D = null

@export_category("Data")
@export var weapSys : WeaponSys = null

func _ready() -> void:
	if weapSys and col and weapSys.parentNode:
		col.set_collision_layer_value(1, false)
		col.set_collision_mask_value(1, true)
		
		if weapSys.parentNode.is_in_group("Player"):
			col.set_collision_layer_value(4, true)
			col.set_collision_mask_value(3, true)
		else:
			col.set_collision_layer_value(5, true)
			col.set_collision_mask_value(2, true)

extends Node2D

@export_category("This Object")
@export var col : Area2D = null
@export var sprite : Sprite2D = null

@export_category("Data")
@export var weapSys : WeaponSys = null

var gpuPart : GPUParticles2D = null

var hitTargets : Array = []

var thisScale : float = 0

func _ready() -> void:
	if weapSys and col and weapSys.parentNode:
		col.set_collision_layer_value(1, false)
		col.set_collision_mask_value(1, false)
		
		if weapSys.parentNode.is_in_group("Player"):
			col.set_collision_layer_value(4, true)
			col.set_collision_mask_value(3, true)
		else:
			col.set_collision_layer_value(5, true)
			col.set_collision_mask_value(2, true)
		col.connect("area_entered", _on_col_area_entered)
	
	thisScale = scale.x
	gpuPart = get_node_or_null("Sprite2D/GPUParticles2D")

func _process(_delta: float) -> void:
	if weapSys and weapSys.parentNode:
		for c in sprite.get_children():
			if c is PointLight2D:
				c.range_z_max = z_index + get_parent().z_index
		
		if col:
			if weapSys.isAttacking:
				col.monitoring = true
				
				var bodies = col.get_overlapping_bodies()
				
				for b in bodies:
					if b.has_method("take_damage") and not hitTargets.has(b):
						b.take_damage(weapSys.weapon.genDamage())
						hitTargets.append(b)
			else:
				col.monitoring = false
				hitTargets = []
		
		if gpuPart:
			if weapSys.isAttacking:
				gpuPart.amount_ratio = 1
			else:
				gpuPart.amount_ratio = 0.1

func _on_col_area_entered(area: Area2D) -> void:
	var parent = area.get_parent()
	
	if parent.has_method("take_damage"):
		parent.take_damage(weapSys.weapon.genDamage())

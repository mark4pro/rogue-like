extends Node2D

@export var baseSword : Node2D = null
@export var gpuPart : GPUParticles2D = null

func _process(delta: float) -> void:
	if baseSword.weapSys and baseSword.weapSys.parentNode:
		for c in baseSword.sprite.get_children():
			if c is PointLight2D:
				c.range_z_max = baseSword.z_index + baseSword.get_parent().z_index
		
		if gpuPart:
			if baseSword.weapSys.isAttacking:
				gpuPart.amount_ratio = 1
			else:
				gpuPart.amount_ratio = 0.1

extends Node2D

@export var baseSword : Node2D = null
@export var gpuPart : GPUParticles2D = null
@export var lights : Array[PointLight2D] = []

func extUpdate() -> void:
	if baseSword.weapSys and baseSword.weapSys.parentNode:
		for c in lights:
			c.range_z_max = baseSword.z_index + baseSword.get_parent().z_index
		
		if gpuPart:
			if baseSword.weapSys.isAttacking:
				gpuPart.amount_ratio = 1
			else:
				gpuPart.amount_ratio = 0.1

func _ready() -> void:
	extUpdate()

func _process(delta: float) -> void:
	extUpdate()

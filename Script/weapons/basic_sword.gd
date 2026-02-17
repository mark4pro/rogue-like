extends Node2D

@onready var col : Area2D = $Sprite2D/Col

@export var entity : RigidBody2D = null
@export var animPlayer : AnimationPlayer = null
@export var sprite : AnimatedSprite2D = null

var gpuPart : GPUParticles2D = null

var weapon : WeaponItem = null

var hitTargets : Array = []

func _ready() -> void:
	col.set_collision_layer_value(1, false)
	col.set_collision_mask_value(1, false)
	
	if entity.is_in_group("Player"):
		col.set_collision_layer_value(4, true)
		col.set_collision_mask_value(3, true)
	else:
		col.set_collision_layer_value(5, true)
		col.set_collision_mask_value(2, true)
	
	gpuPart = get_node_or_null("Sprite2D/GPUParticles2D")

func _process(_delta: float) -> void:
	if sprite.get_parent().scale.x == -1:
		scale.x = -1
	else:
		scale.x = 1
	
	if animPlayer.is_playing():
		col.monitoring = true
		
		var bodies = col.get_overlapping_bodies()
		
		for b in bodies:
			if b.has_method("take_damage") and not hitTargets.has(b):
				b.take_damage(weapon.genDamage())
				hitTargets.append(b)
	else:
		col.monitoring = false
		hitTargets = []
	
	if gpuPart:
		if animPlayer.is_playing():
			gpuPart.amount_ratio = 1
		else:
			gpuPart.amount_ratio = 0.1

func _on_col_area_entered(area: Area2D) -> void:
	var parent = area.get_parent()
	
	if parent.has_method("take_damage"):
		parent.take_damage(weapon.genDamage())

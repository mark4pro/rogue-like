extends RigidBody2D

@export var damage : float = 0.5

func _process(delta: float) -> void:
	var bodies = get_colliding_bodies()
	for b in bodies:
		if b.has_method("take_damage"): b.take_damage(damage)

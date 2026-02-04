extends Node2D

@export var damage : float = 5

var touching : bool = false

func _process(delta: float) -> void:
	var bodies = $Area2D.get_overlapping_bodies()
	for b in bodies:
		if b.has_method("take_damage"): b.take_damage(damage)

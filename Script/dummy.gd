extends Node2D

func take_damage(data: Dictionary):
	if not get_tree().paused:
		Global.damNumbers($Area2D/CollisionPolygon2D, data)

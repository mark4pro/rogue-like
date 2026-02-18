extends Node2D

func take_damage(data: Dictionary):
	Global.damageAnim($Sprite2D, data.value)
	Global.damNumbers($Area2D/CollisionPolygon2D, data)

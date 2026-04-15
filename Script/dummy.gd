extends Node2D

@onready var sprite : Sprite2D = %Sprite2D
@onready var coll : CollisionPolygon2D = %CollisionPolygon2D

var ogScale : Vector2 = Vector2.ONE

func _ready() -> void:
	ogScale = sprite.scale

func take_damage(data: Dictionary, attacker: Node):
	Global.damageAnim(sprite, data.value, ogScale)
	Global.damNumbers(coll, data)

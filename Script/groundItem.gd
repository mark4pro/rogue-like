extends Node2D

@export var item : BaseItem

@onready var item_sprite : Sprite2D = $Icon

func _ready() -> void:
	if rotation == 0:
		rotation_degrees = randf_range(0, 360)
	scale.x = item.groundScale
	scale.y = item.groundScale
	item_sprite.texture = item.itemIcon
	if not item.rolled: item.rollStats()

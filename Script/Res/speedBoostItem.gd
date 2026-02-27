extends BaseItem
class_name SpeedItem

@export var speed : float = 5

func use() -> void:
	Global.player.speedMod += speed
	quantitiy -= 1

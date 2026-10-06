extends BaseItem
class_name SpeedItem

@export var speed : float = 5

func use() -> void:
	if not Global.player: return
	# The player's speedTimer winds mod_speed back down by 5 every 5 seconds
	Global.player.pStats.mod_speed += speed
	quantity -= 1

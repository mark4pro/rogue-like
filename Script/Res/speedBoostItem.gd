extends BaseItem
class_name SpeedItem

func use() -> void:
	Global.player.speedBoostDecrement += 5

	

extends BaseItem
class_name SpeedItem

func use() -> void:
	Global.player.speedMod += 5
	quantitiy -= 1

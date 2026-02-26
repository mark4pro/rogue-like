extends BaseItem
class_name SpeedItem


func use() -> void:
	Global.player.walk_speed += 10
	Global.player.sprint_speed += 10
	quantitiy -= 1

extends BaseItem
class_name SprintItem

func use() -> void:
	Global.player.stamina_regen += 20
	
	quantitiy -= 1

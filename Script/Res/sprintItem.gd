extends BaseItem
class_name SprintItem

@export var stamina : float = 20

func use() -> void:
	Global.player.stamina_regen += stamina
	quantitiy -= 1

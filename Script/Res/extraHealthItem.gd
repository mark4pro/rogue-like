extends BaseItem
class_name ExtraHealthItem
@export var healthAmount : float = 100

func use() -> void:
	Global.player.health += 80
	quantitiy -= 1

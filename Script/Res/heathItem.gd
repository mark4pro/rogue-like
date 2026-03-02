extends BaseItem
class_name HealthItem

@export var healthAmount : float = 100

func use() -> void:
	Global.player.health += healthAmount
	quantity -= 1

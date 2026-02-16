extends BaseItem
class_name WeaponItem

#@export var healthAmount : float = 100

#func use() -> void:
	#Global.player.health += healthAmount
	#quantitiy -= 1

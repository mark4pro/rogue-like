extends BaseItem
class_name SprintItem

## Extra stamina regen per second while it lasts
@export var stamina : float = 20
@export var duration : float = 5

func use() -> void:
	var p : Node = Global.player
	if not p or not p.has_method("addRegen"): return
	# Temporary boost (the old version targeted a property the player doesn't have)
	if not p.addRegen(RegenPotionItem.regen_stat.STAMINA, stamina * duration, duration): return
	quantity -= 1

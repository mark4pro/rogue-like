extends Node2D

var damage : float = 100

#data has value which is the damage and isCrit which is if the attack was a critical hit
#make it say "crit: " before the damage number then change color if it's a crit
func take_damage(data: Dictionary):
	if not get_tree().paused:
		var label = Global.damNum.instantiate()
		label.text = str(roundi(data.value))
		
		# Position it at the enemy's location
		label.position = global_position
		get_tree().current_scene.add_child(label)

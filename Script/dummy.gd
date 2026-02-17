extends Node2D

var damage : String = "100"

var show_damage = preload("res://Assets/prefabs/damage_label.tscn/")


func _on_area_2d_body_entered(body: Node2D) -> void:
	var damage = 100
	damage = 100
	var label = show_damage.instantiate()
	label.text = str(damage)
	# Position it at the enemy's location
	label.position = global_position
	get_tree().current_scene.add_child(label)
	

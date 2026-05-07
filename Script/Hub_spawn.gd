extends Node2D

@export var spawn : Marker2D
@export var flipPlayer : bool = true

func _process(_delta: float) -> void:
	if not Global.player and spawn:
		Global.saveGame()
		var newPlayer : RigidBody2D = Global.playerRes.instantiate()
		newPlayer.global_position = spawn.global_position
		get_tree().current_scene.add_child(newPlayer)
		newPlayer.rot_point.scale.x = -1 if flipPlayer else 1
		
		if not Global.hub_groundItems.is_empty():
			Global.genGroundItems()

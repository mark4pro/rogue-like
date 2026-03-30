extends Node2D

func _process(_delta: float) -> void:
	if not Global.player:
		Global.saveGame()
		var newPlayer : RigidBody2D = Global.playerRes.instantiate()
		newPlayer.global_position = $Spawn.global_position
		get_tree().current_scene.add_child(newPlayer)

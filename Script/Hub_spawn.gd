extends Node2D

func _process(delta: float) -> void:
	if not Global.player:
		var newPlayer : RigidBody2D = Global.playerRes.instantiate()
		newPlayer.position = $Spawn.position
		get_tree().current_scene.add_child(newPlayer)

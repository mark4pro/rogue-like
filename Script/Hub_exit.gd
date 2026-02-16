extends Node2D

var touching : bool = false

func _process(_delta: float) -> void:
	if touching and Input.is_action_just_pressed("interact") and not get_tree().paused:
		Global.sceneIndex = 1

func _on_area_2d_body_entered(body: Node2D) -> void:
	if body.is_in_group("Player"):
		Global.sendMessage("Press E to start your journey!", 5.0)
		touching = true

func _on_area_2d_body_exited(_body: Node2D) -> void:
	touching = false

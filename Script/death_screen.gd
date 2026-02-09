extends Control

func _on_back_to_hub_button_down() -> void:
	Global.resetRunDays()
	Global.sceneIndex = 0

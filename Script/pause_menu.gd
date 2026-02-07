extends Control

@onready var pauseCanvasLayer : CanvasLayer = $".." 

func _ready() -> void:
	pass

func _process(delta: float) -> void:
	pass

func _on_resume_button_down() -> void:
	get_tree().paused = !get_tree().paused
	pauseCanvasLayer.visible = !pauseCanvasLayer.visible

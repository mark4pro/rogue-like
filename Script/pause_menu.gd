extends Control

@onready var pauseCanvasLayer : CanvasLayer = $".." 
@onready var bg : ColorRect = $ColorRect
@onready var exitBttn : Button = $ColorRect/exitGame

var bgChildren : Array[Node] = []

func getChildCount() -> int:
	var count = 0
	
	for c in bgChildren:
		if c.visible: count += 1
	
	return count

func _process(_delta: float) -> void:
	bgChildren = bg.get_children()
	
	var bgCount : int = getChildCount()
	
	if Global.sceneIndex == 0:
		$ColorRect/backToHub.visible = false
		
		var dif : int = bgChildren.size() - bgCount
		var thisIndex : int = bgChildren.find(exitBttn) - dif
		
		exitBttn.position.y = (thisIndex * 100) + (thisIndex * 10) + 10
		
		var halfBGSize : Vector2 = bg.size / 2
		var newSize : float = (bgCount * 100) + (bgCount * 10) + 10
		
		bg.custom_minimum_size.y = newSize
		bg.size.y = newSize
		bg.position = Vector2(960 - halfBGSize.x, 540 - halfBGSize.y)

func _on_resume_button_down() -> void:
	get_tree().paused = !get_tree().paused
	pauseCanvasLayer.visible = !pauseCanvasLayer.visible

func _on_back_to_hub_button_down() -> void:
	Global.resetRunDays()
	get_tree().paused = false
	Global.sceneIndex = 0

func _on_exit_game_button_down() -> void:
	Global.saveGame()
	get_tree().quit()

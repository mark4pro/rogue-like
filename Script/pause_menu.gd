extends Control

@onready var pauseCanvasLayer : CanvasLayer = $".." 
@onready var bg : ColorRect = $ColorRect
@onready var exitBttn : Button = $ColorRect/exitGame
@onready var resumeBttn : Button = $ColorRect/Resume

var bgChildren : Array[Node] = []
var optionsBttn : Button = null
var menuBttn : Button = null
var optionsMenu : OptionsMenu = null

func getChildCount() -> int:
	var count = 0
	
	for c in bgChildren:
		if c.visible: count += 1
	
	return count

func _ready() -> void:
	# Options button made at runtime from Resume, so the pause menu scene doesn't need editing.
	# duplicate(0) = no signals, otherwise it would also resume the game.
	optionsBttn = resumeBttn.duplicate(0)
	optionsBttn.name = "options"
	optionsBttn.text = "Options"
	bg.add_child(optionsBttn)
	bg.move_child(optionsBttn, resumeBttn.get_index() + 1)
	optionsBttn.button_down.connect(_on_options_button_down)
	
	# Main Menu: saves (mid-run it ends the run like Back to Hub) and goes to the title screen
	menuBttn = resumeBttn.duplicate(0)
	menuBttn.name = "mainMenu"
	menuBttn.text = "Main Menu"
	bg.add_child(menuBttn)
	bg.move_child(menuBttn, exitBttn.get_index())
	menuBttn.button_down.connect(_on_main_menu_button_down)

func _on_main_menu_button_down() -> void:
	pauseCanvasLayer.visible = false
	Global.returnToMenu()

func _process(_delta: float) -> void:
	$ColorRect/backToHub.visible = Global.sceneIndex != 0
	
	# Stack the visible buttons and size/centre the background to fit (hub and runs)
	bgChildren = bg.get_children()
	var bgCount : int = getChildCount()
	var i : int = 0
	for c in bgChildren:
		if not c.visible:
			continue
		c.position.y = (i * 100) + (i * 10) + 10
		i += 1
	
	var newSize : float = (bgCount * 100) + (bgCount * 10) + 10
	bg.custom_minimum_size.y = newSize
	bg.size.y = newSize
	var halfBGSize : Vector2 = bg.size / 2
	bg.position = Vector2(960 - halfBGSize.x, 540 - halfBGSize.y)
	
	# Keyboard / controller: something in the menu needs focus to navigate it
	if pauseCanvasLayer.visible and bg.visible and get_viewport().gui_get_focus_owner() == null:
		resumeBttn.grab_focus()
	
	# If the pause menu got closed some other way, don't leave the options menu behind
	if not pauseCanvasLayer.visible and optionsMenu and is_instance_valid(optionsMenu):
		optionsMenu.close()

func _on_options_button_down() -> void:
	if optionsMenu and is_instance_valid(optionsMenu):
		return
	optionsMenu = OptionsMenu.new()
	optionsMenu.closed.connect(_on_options_closed)
	add_child(optionsMenu)
	bg.visible = false

func _on_options_closed() -> void:
	optionsMenu = null
	bg.visible = true

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

extends Node

var playerRes : PackedScene = preload("res://Assets/prefabs/player.tscn")
var groundItem : PackedScene = preload("res://Assets/prefabs/groundItem.tscn")
var inventoryItem : PackedScene = preload("res://Assets/prefabs/inventoryItem.tscn")
var contextMenu : PackedScene = preload("res://Assets/prefabs/context_menu.tscn")
var massageUI : PackedScene = preload("res://Assets/prefabs/message.tscn")

var Inventory : Array[BaseItem] = []
var MaxInventory : int = 32

var messageTimer : Timer = null
var messageBox : VBoxContainer = null
var maxMessages : int = 6

var messages : Array[Node] = []
var messageCount : int = 0

var player : RigidBody2D = null
var inventoryUI : Control = null

@export var addMs : bool = false

@export var sceneIndex = 0
@export var scenes : Dictionary = {
	0: preload("res://Assets/scenes/hub.tres"),
	1: preload("res://Assets/scenes/testWorld.tres")
}

func _ready() -> void:
	#For testing
	Inventory.append(load("res://Assets/items/health_1.tres"))
	add_item(load("res://Assets/items/health_1.tres"))

func hasSpace(item: BaseItem) -> bool:
	if not item:
		return Inventory.size() < MaxInventory
	else:
		var index = Inventory.find_custom(func(i): return i.id == item.id)
		if not index == -1:
			return true
		else:
			return Inventory.size() < MaxInventory

func add_item(item: BaseItem):
	var index = Inventory.find_custom(func(i): return i.id == item.id)
	if not index == -1:
		Inventory[index].quantitiy += item.quantitiy
	else:
		Inventory.append(item)

func remove_items_by_id(id: int, amount: int):
	var index = Inventory.find_custom(func(i): return i.id == id)
	if not index == -1:
		Inventory[index].quantitiy -= amount

func sendMessage(ms: String, time: float = 2.0, c: Color = Color.WHITE):
	if messageBox:
		if messageCount + 1 > maxMessages: messageBox.get_children()[0].queue_free()
		
		var newMessage : ColorRect = massageUI.instantiate()
		newMessage.ms = ms
		newMessage.c = c
		newMessage.time = time
		messageBox.add_child(newMessage)

func _process(delta: float) -> void:
	var playerChk = get_tree().get_nodes_in_group("Player")
	if not playerChk.is_empty(): player = playerChk[0]
	
	if player:
		if not messageBox:
			messageBox = player.get_node("UI/MessageBox")
		
		if not messageTimer:
			messageTimer = player.get_node("UI/MessageTimer")
		
		if messageBox:
			messageBox.position.y = 1080 - (maxMessages * 50)
			messageBox.size.y = (maxMessages * 50)
			
			messages = messageBox.get_children()
			messageCount = messages.size()
			
			if messageTimer:
				if messageCount > 0 and messageTimer.is_stopped() and not get_tree().paused: messageTimer.start()
				if messageCount == 0: messageTimer.stop()
				if messageCount > 0: 
					if messageTimer.wait_time != messages[0].time:
						messageTimer.wait_time = messages[0].time
						messageTimer.start()
					messages[0].pBar.value = (messageTimer.time_left / messageTimer.wait_time) * 100
			
			for i in messageCount:
				var c = messages[i]
				var inverted_index = messageCount - 1 - i
				
				c.pBar.visible = i == 0
				
				var t = (float(inverted_index) / float(maxMessages - 1))
				c.modulate.a = clampf(1.0 - t, 0.1, 0.9)
	
	#Scene manager
	sceneIndex = clamp(sceneIndex, 0, scenes.keys().size() - 1)
	if get_tree().current_scene.name != scenes[sceneIndex].rootNode:
		get_tree().change_scene_to_file(scenes[sceneIndex].path)
	
	#Clear items with no quanitity
	for i in Inventory:
		if i.quantitiy <= 0: Inventory.erase(i)
	
	#For testing
	if addMs and OS.has_feature("editor"):
		sendMessage("TESTING", 2.0, Color(randf_range(0, 1), randf_range(0, 1), randf_range(0, 1)))
		addMs = false

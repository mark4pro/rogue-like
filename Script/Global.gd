extends Node

var playerRes : PackedScene = preload("res://Assets/prefabs/player.tscn")
var groundItem : PackedScene = preload("res://Assets/prefabs/groundItem.tscn")
var inventoryItem : PackedScene = preload("res://Assets/prefabs/inventoryItem.tscn")
var contextMenu : PackedScene = preload("res://Assets/prefabs/context_menu.tscn")
var massageUI : PackedScene = preload("res://Assets/prefabs/message.tscn")

@export_category("Inventory")
@export var Inventory : Array[BaseItem] = []
@export var MaxInventory : int = 32

@export_category("Player stats")
@export var armor : float = 0

var messageTimer : Timer = null
var messageBox : VBoxContainer = null
@export_category("Messages")
@export var maxMessages : int = 6

var messages : Array[Node] = []
@export var messageCount : int = 0

var player : RigidBody2D = null
var inventoryUI : Control = null

@export_category("Testing")
@export var debugVision : bool = true
@export var addMs : bool = false

@export_category("Scenes")
@export var sceneIndex = 0
@export var scenes : Dictionary = {
	0: preload("res://Assets/scenes/hub.tres"),
	1: preload("res://Assets/scenes/testWorld.tres")
}

@export_category("Day/Night System")
@export var dayLengthSeconds : float = 120.0
@export_range(0.0, 1.0, 0.001) var timeOfDay : float = 0.0
@export var totalDays : int = 0 #Total amount of days past
@export var runDays : int = 0 #Amount of days past during run
@export_category("Colors")
@export var nightColor : Color = Color(0.08, 0.08, 0.15)
@export var dayColor : Color = Color(1, 1, 1)
@export var bloodMoonColor : Color = Color(0.429, 0.0, 0.013)
@export_category("Blood Moon")
@export var bloodMoons : bool = true
@export var bloodMoonChance : float = 0.1
@export var isBloodMoon : bool = false

const MIDNIGHT : float = 0.0
const SUNRISE : float = 0.25
const NOON : float = 0.5
const SUNSET : float = 0.75

var rollBloodMoon : bool = true

var ambientLight : CanvasModulate = null
var ambientColor : Color = Color.WHITE

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

func add_item(item: BaseItem) -> void:
	var index = Inventory.find_custom(func(i): return i.id == item.id)
	if not index == -1:
		Inventory[index].quantitiy += item.quantitiy
	else:
		Inventory.append(item)

func remove_items_by_id(id: int, amount: int) -> void:
	var index = Inventory.find_custom(func(i): return i.id == id)
	if not index == -1:
		Inventory[index].quantitiy -= amount

func getKeyFromAction(action: String) -> String:
	return InputMap.action_get_events(action)[0].as_text().split(" ")[0]

func sendMessage(ms: String, time: float = 2.0, c: Color = Color.WHITE, bg: Color = Color("4a4a4a")) -> void:
	if messageBox:
		if messageCount + 1 > maxMessages: messageBox.get_children()[0].queue_free()
		
		var newMessage : ColorRect = massageUI.instantiate()
		newMessage.ms = ms
		newMessage.c = c
		newMessage.bg = bg
		newMessage.time = time
		messageBox.add_child(newMessage)

func resetRunDays() -> void:
	isBloodMoon = false
	totalDays += runDays + 1
	runDays = 0
	timeOfDay = SUNRISE

func getRandom(list: Array):
	var total_weight : float = 0
	for entry in list:
		total_weight += max(entry.weight, 0)
	
	var roll : float = randf() * total_weight
	var cumulative : float = 0
	
	for entry in list:
		cumulative += entry.weight
		if roll <= cumulative:
			return entry.data
	
	if list.is_empty(): return null
	
	return list.back().data

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
	
	#Time of day and light calc
	timeOfDay += delta / dayLengthSeconds
	timeOfDay = clamp(timeOfDay, 0.0, 1.0)
	if timeOfDay >= 1.0:
		if sceneIndex == 0:
			totalDays += 1
		else:
			runDays += 1
		timeOfDay = 0.0
	
	#Blood moon
	if sceneIndex != 0:
		if bloodMoons and timeOfDay >= SUNSET and rollBloodMoon:
			isBloodMoon = randf() < bloodMoonChance
			if isBloodMoon: sendMessage("Something feels off...", 5.0, Color(0.506, 0.0, 0.0), Color(0.26, 0.2, 0.2))
			rollBloodMoon = false
	if timeOfDay >= SUNRISE and timeOfDay < SUNSET:
		isBloodMoon = false
		rollBloodMoon = true
	
	#Update lighting
	var t : float = clampf(cos((timeOfDay - 0.5) * TAU) * 0.5 + 0.5, 0.0, 1.0)
	
	ambientColor = nightColor.lerp(dayColor, t)
	
	var bloodMoon_t : float = 0.0
	
	if isBloodMoon:
		bloodMoon_t = 1.0
		
		if timeOfDay >= SUNSET:
			bloodMoon_t = clampf((timeOfDay - SUNSET) / (1.0 - SUNSET), 0.0, 1.0)
		
		if timeOfDay < SUNRISE:
			bloodMoon_t = clampf(1.0 - (timeOfDay / SUNRISE), 0.0, 1.0)
	
	ambientColor = ambientColor.lerp(bloodMoonColor, bloodMoon_t * 1.0)
	
	var moonlight : float = lerp(0.3, 0.0, t)
	ambientColor += Color(moonlight, moonlight, moonlight)

	
	if get_tree().current_scene:
		#Set ambient or add a new one
		if not ambientLight:
			var ambientChk : CanvasModulate = get_tree().current_scene.get_node_or_null("Ambient")
			if ambientChk: ambientLight = ambientChk
			else:
				var newAmbient : CanvasModulate = CanvasModulate.new()
				newAmbient.name = "Ambient"
				newAmbient.color = ambientColor
				get_tree().current_scene.add_child(newAmbient)
		
		if ambientLight: ambientLight.color = ambientColor
	
	#For testing
	if addMs and OS.has_feature("editor"):
		sendMessage("TESTING", 2.0, Color(randf_range(0, 1), randf_range(0, 1), randf_range(0, 1)))
		addMs = false

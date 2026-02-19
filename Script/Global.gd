extends Node

var playerRes : PackedScene = preload("res://Assets/prefabs/player.tscn")
var inventoryItem : PackedScene = preload("res://Assets/prefabs/inventoryItem.tscn")
var contextMenu : PackedScene = preload("res://Assets/prefabs/context_menu.tscn")
var massageUI : PackedScene = preload("res://Assets/prefabs/message.tscn")
var loading : PackedScene = preload("res://Assets/prefabs/loading.tscn")
var damNum : PackedScene = preload("res://Assets/prefabs/damage_label.tscn")
var compareUI : PackedScene = preload("res://Assets/prefabs/compare.tscn")

@export_category("Player")
@export var inventory : Inventory = preload("res://Player_Data/playerInventory.tres")
@export var weapon : WeaponItem = null
#@export var armor : ArmorItem = null
@export var armor : float = 0

var messageTimer : Timer = null
var messageBox : VBoxContainer = null
@export_category("Messages")
@export var maxMessages : int = 6

var messages : Array[Node] = []
@export var messageCount : int = 0

var player : RigidBody2D = null
var inventoryUI : Control = null
var currentScene : Node = null

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
@export var lastRunDays : int = 0
@export var longestRun : int = 0
@export_category("Colors")
@export var nightColor : Color = Color(0.08, 0.08, 0.15)
@export var dayColor : Color = Color(1, 1, 1)
@export var bloodMoonColor : Color = Color(0.429, 0.0, 0.013)
@export_category("Blood Moon")
@export var bloodMoons : bool = true
@export var bloodMoonChance : float = 0.1
@export var isBloodMoon : bool = false

@export_category("RNG")
@export var rng : int = randi()
@export var meta : float = totalDays * 0.6
@export var performance : float = 1

@export_category("Damage Numbers")
@export var damNumberEnable : bool = true
@export var damNumberSizeRange : Vector2i = Vector2i(8, 12)
@export var damNumberSizeRangeCrit : Vector2i = Vector2i(10, 14)
@export var damNumberNormColor : Color = Color.WHITE
@export var damNumberCritColor : Color = Color.DARK_RED
@export_category("Damage Animation")
@export var damAnimRotEnable : bool = true

const MIDNIGHT : float = 0.0
const SUNRISE : float = 0.25
const NOON : float = 0.5
const SUNSET : float = 0.75

var rollBloodMoon : bool = true

var ambientLight : CanvasModulate = null
var ambientColor : Color = Color.WHITE

func _ready() -> void:
	#For testing
	inventory.add_item(load("res://Assets/items/health_1.tres"))
	inventory.add_item(load("res://Assets/items/health_1.tres"))
	inventory.add_item(load("res://Assets/items/over_grown.tres"))
	inventory.add_item(load("res://Assets/items/over_grown.tres"))

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
	lastRunDays = runDays
	if runDays > longestRun: longestRun = runDays
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

func formatFloat(num: float, per: int = 2):
	if num == int(num): return int(num)
	else:
		var step = 1.0 / pow(10.0, per)
		return snapped(num, step)

func getRandomPosFromColShap(colShape) -> Vector2:
	var randomPos : Vector2 = colShape.global_position
	
	if colShape is CollisionShape2D:
		var shape : Shape2D = colShape.shape
		
		if shape is RectangleShape2D:
			var extents = shape.size * 0.5
			var local_pos = Vector2(
				randf_range(-extents.x, extents.x),
				randf_range(-extents.y, extents.y)
			)
			randomPos = colShape.to_global(local_pos)
		elif shape is CircleShape2D:
			var r = shape.radius
			var angle = randf() * TAU
			var dist = sqrt(randf()) * r
			var local_pos = Vector2(cos(angle), sin(angle)) * dist
			randomPos = colShape.to_global(local_pos)
	elif colShape is CollisionPolygon2D:
		var points = colShape.polygon
		if not points.size() == 0:
			var index = randi() % points.size()
			var next_index = (index + 1) % points.size()
			var t = randf()
			var local_pos = points[index].lerp(points[next_index], t)
			randomPos = colShape.to_global(local_pos)
	
	return randomPos

#data has value which is the damage and isCrit which is if the attack was a critical hit
#Supports rect and circle collision shapes and collision polys
func damNumbers(colShape, data: Dictionary) -> void:
	if damNumberEnable:
		var newLabel : Label = damNum.instantiate()
		newLabel.text = str(roundi(data.value))
		
		if data.isCrit:
			newLabel.add_theme_font_size_override("font_size", randi_range(damNumberSizeRangeCrit.x, damNumberSizeRangeCrit.y))
			newLabel.add_theme_color_override("font_color", damNumberCritColor)
		else:
			newLabel.add_theme_font_size_override("font_size", randi_range(damNumberSizeRange.x, damNumberSizeRange.y))
			newLabel.add_theme_color_override("font_color", damNumberNormColor)
		
		var randomPos : Vector2 = getRandomPosFromColShap(colShape)
		
		newLabel.position = randomPos
		Global.currentScene.add_child(newLabel)

func damageAnim(node: Node2D, damage: float = 10) -> void:
	var intensity = clamp(sqrt(damage) * 0.02, 0.05, 0.4)
	
	var squash = 1.0 - intensity
	var stretch = 1.0 + intensity
	
	var tween = create_tween()
	tween.set_trans(Tween.TRANS_BACK)
	tween.set_ease(Tween.EASE_OUT)
	
	tween.tween_property(node, "scale", Vector2(stretch, squash), 0.08)
	tween.tween_property(node, "scale", Vector2(1.05, 0.95), 0.06)
	tween.tween_property(node, "scale", Vector2.ONE, 0.06)
	
	if damAnimRotEnable:
		var rot = randf_range(-intensity, intensity)
		
		tween.tween_property(node, "rotation", rot, 0.05)
		tween.tween_property(node, "rotation", 0.0, 0.1)

func _process(delta: float) -> void:
	Global.inventory.update()
	
	meta = totalDays * 0.6
	if longestRun > 0:
		performance = float(lastRunDays) / float(longestRun)
	
	if not currentScene:
		currentScene = get_tree().current_scene
	
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
				
				var m_t = (float(inverted_index) / float(maxMessages - 1))
				c.modulate.a = clampf(1.0 - m_t, 0.1, 0.9)
	
	var thisLoading = get_tree().root.get_node_or_null("loading")
	
	#Scene manager
	sceneIndex = clamp(sceneIndex, 0, scenes.keys().size() - 1)
	if get_tree().current_scene.name != scenes[sceneIndex].rootNode:
		if not thisLoading:
			var newLoading : CanvasLayer = loading.instantiate()
			newLoading.name = "loading"
			get_tree().root.add_child(newLoading)
		
		get_tree().change_scene_to_file(scenes[sceneIndex].path)
	
	if thisLoading:
		match sceneIndex:
			0:
				if player:
					thisLoading.queue_free()
			_:
				if Global.currentScene and Global.currentScene.get_node_or_null("World"):
					thisLoading.queue_free()
	
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
	var tod_t : float = clampf(cos((timeOfDay - 0.5) * TAU) * 0.5 + 0.5, 0.0, 1.0)
	
	ambientColor = nightColor.lerp(dayColor, tod_t)
	
	var bloodMoon_t : float = 0.0
	
	if isBloodMoon:
		bloodMoon_t = 1.0
		
		if timeOfDay >= SUNSET:
			bloodMoon_t = clampf((timeOfDay - SUNSET) / (1.0 - SUNSET), 0.0, 1.0)
		
		if timeOfDay < SUNRISE:
			bloodMoon_t = clampf(1.0 - (timeOfDay / SUNRISE), 0.0, 1.0)
	
	ambientColor = ambientColor.lerp(bloodMoonColor, bloodMoon_t * 1.0)
	
	var moonlight : float = lerp(0.3, 0.0, tod_t)
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

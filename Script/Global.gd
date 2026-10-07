extends Node

var playerRes : PackedScene = preload("uid://bjts4lj4357yt")
var inventoryItem : PackedScene = preload("uid://tlobv0bfa6bo")
var contextMenu : PackedScene = preload("uid://cl2m3dpyfhdty")
var massageUI : PackedScene = preload("uid://ckm4t02r3wbh6")
var loading : PackedScene = preload("uid://bdxva4d6mjjnc")
var damNum : PackedScene = preload("uid://ccn6wcxen3txi")
var compareUI : PackedScene = preload("uid://bdiwb0lraqgm1")

@export_category("Player")
@export var inventory : Inventory = Inventory.new()
@export var weapon : WeaponItem = null
@export var armor : ArmorItem = null
@export var money : int = 0
@export var pickupRange : float = 50
@export var playerStats : stats = _newStats()

@export_category("Hot Bar")
@export var hotbar_weapons : Array[BaseItem] = []
@export var hotbar_items : Array[BaseItem] = []

@export_category("Ext Data")
@export var shopInventory : Array[BaseItem] = []
@export var hub_groundItems : Array[GroundItem] = []

var messageTimer : Timer = null
var messageBox : VBoxContainer = null
@export_category("Messages")
@export var maxMessages : int = 6

var messages : Array[Node] = []
@export var messageCount : int = 0

var player : RigidBody2D = null
var inventoryUI : Control = null
## True while the main menu is up (main_menu.gd): the scene manager, day clock and world
## pre-generation wait. Continue sets it false and the hub loads.
var inMenu : bool = false
var currentScene : Node = null

@export_category("Vision cones")
@export var debugVision : bool = true
@export var normVisionDebugColor : Color = Color(0.64, 0.0, 0.0, 0.118)
@export var inVisionDebugColor : Color = Color(0.149, 0.64, 0.0, 0.118)
@export var chaseVisionDebugColor : Color = Color(0.64, 0.619, 0.0, 0.118)
@export var outVisionDebugColor : Color = Color(0.0, 0.576, 0.64, 0.118)
@export_category("Toggles")
@export var addMs : bool = false

@export_category("Scenes")
@export var sceneIndex = 0
@export var scenes : Dictionary = {
	0: preload("uid://cd4ijegw25bc"),
	1: preload("uid://efkev7tpq38h")
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

@export var lootList : LootList = preload("uid://bc340l20tpoev")

const MAX_KNOCKBACK : float = 1000
const KNOCKBACK_DECAY : float = 0.001

const MIDNIGHT : float = 0.0
const SUNRISE : float = 0.25
const NOON : float = 0.5
const SUNSET : float = 0.75

var rollBloodMoon : bool = true

# Added to the rarity roll of any item that rolls its stats while this is set
# (enemies set it for a moment while dropping blood moon loot)
var lootRarityBonus : float = 0.0

# Everything added to an item's rarity roll: temporary bonuses (blood moon drops) + the player's Luck
func rarityRollBonus() -> float:
	return lootRarityBonus + (playerStats.rarityBonus() if playerStats else 0.0)

var ambientLight : CanvasModulate = null
var ambientColor : Color = Color.WHITE

const savePath : String = "user://saves/"
const MENU_SCENE : String = "uid://dhnmtdvag6gj5"

#region Save slots

const SLOT_COUNT : int = 3
const LEGACY_SAVE : String = "save_data.tres" # pre-slot save, moved into slot 1
const SLOTS_CFG : String = "slots.cfg"        # remembers the last played slot
var saveSlot : int = 1
## Seconds played on the current save. Counts while in the hub or a run (not the main menu,
## not while paused) and is stored with the save.
var playTime : float = 0.0
## Task counters and claimed task ids for this save (see Tasks)
var taskProgress : Dictionary = {}
var tasksClaimed : Array[String] = []

# "2h 05m", "14m", "<1m"
static func formatPlayTime(seconds: float) -> String:
	var mins : int = int(seconds / 60.0)
	if mins < 1: return "<1m"
	var h : int = mins / 60
	if h == 0: return "%dm" % mins
	return "%dh %02dm" % [h, mins % 60]

func slotPath(slot: int) -> String:
	return savePath + "slot_%d.tres" % slot

func slotExists(slot: int) -> bool:
	return FileAccess.file_exists(slotPath(slot))

func anySlotExists() -> bool:
	for s in range(1, SLOT_COUNT + 1):
		if slotExists(s): return true
	return false

# Summary for the slot picker ({} = empty slot)
func slotInfo(slot: int) -> Dictionary:
	if not slotExists(slot): return {}
	var d : SaveData = ResourceLoader.load(slotPath(slot), "", ResourceLoader.CACHE_MODE_IGNORE) as SaveData
	if not d: return {"corrupt": true}
	return {
		"level": d.playerStats.level if d.playerStats else 1,
		"money": d.money,
		"days": d.totalDays,
		"longest": d.longestRun,
		"time": d.playTime,
		"modified": FileAccess.get_modified_time(slotPath(slot)),
	}

func deleteSlot(slot: int) -> void:
	if slotExists(slot):
		DirAccess.remove_absolute(slotPath(slot))

func lastSlot() -> int:
	var cfg : ConfigFile = ConfigFile.new()
	if cfg.load(savePath + SLOTS_CFG) == OK:
		return clampi(int(cfg.get_value("slots", "last", 1)), 1, SLOT_COUNT)
	return 1

func _rememberSlot(slot: int) -> void:
	if not DirAccess.dir_exists_absolute(savePath):
		DirAccess.make_dir_recursive_absolute(savePath)
	var cfg : ConfigFile = ConfigFile.new()
	cfg.set_value("slots", "last", slot)
	cfg.save(savePath + SLOTS_CFG)

# The old single save becomes slot 1
func _migrateLegacySave() -> void:
	if FileAccess.file_exists(savePath + LEGACY_SAVE) and not slotExists(1):
		DirAccess.rename_absolute(savePath + LEGACY_SAVE, slotPath(1))

# Starting kit: the player picks a weapon type on New Game, gets a random common weapon of
# that type plus some Snail Meds, both put in the first hotbar slots
const STARTER_WEAPONS : Dictionary = {
	"melee": ["uid://b3a0hq8gaedfp", "uid://ctrrswfhhu73y"],
	"ranged": ["uid://bocuq5n3soyig", "uid://c0xwr07dbdodf", "uid://bntwej254djn2"],
	"laser": ["uid://bsrswcnoltxaf"],
}
const STARTER_MEDS : String = "uid://dwu6vcmregnk8"
const STARTER_MED_COUNT : int = 3

func giveStarterKit(kind: String) -> void:
	var pool : Array = STARTER_WEAPONS.get(kind, STARTER_WEAPONS["melee"])
	var w : WeaponItem = (load(pool[randi() % pool.size()]) as WeaponItem).duplicate(true)
	w.rollCommon() # always a plain Common, never mutated
	
	inventory.add_item(w) # adds a copy
	var myWeapon : BaseItem = inventory.data.back()
	var meds : BaseItem = load(STARTER_MEDS).duplicate()
	meds.quantity = STARTER_MED_COUNT
	inventory.add_item(meds)
	var medsIdx : int = inventory.data.find_custom(func(i): return i.name == meds.name)
	
	weapon = myWeapon
	hotbar_weapons[0] = myWeapon
	if medsIdx != -1: hotbar_items[0] = inventory.data[medsIdx]

# Fresh-character state (what a brand new save starts with)
func resetState(starterKind: String = "melee") -> void:
	inventory = Inventory.new()
	weapon = null
	armor = null
	money = 0
	playerStats = _newStats()
	hotbar_weapons = []
	hotbar_items = []
	hotbar_weapons.resize(3)
	hotbar_items.resize(3)
	shopInventory = []
	hub_groundItems = []
	timeOfDay = SUNRISE
	totalDays = 0
	runDays = 0
	lastRunDays = 0
	longestRun = 0
	playTime = 0.0
	taskProgress = {}
	tasksClaimed = []
	isBloodMoon = false
	rollBloodMoon = true
	sceneIndex = 0
	lootList.getValid()
	giveStarterKit(starterKind)

func startNewGame(slot: int, starterKind: String = "melee") -> void:
	deleteSlot(slot)
	resetState(starterKind)
	saveSlot = slot
	_rememberSlot(slot)
	saveGame()

func loadSlot(slot: int) -> bool:
	if not slotExists(slot): return false
	saveSlot = slot
	_rememberSlot(slot)
	sceneIndex = 0
	runDays = 0
	loadGame()
	return true

# Pause menu -> main menu. Mid-run this ends the run like Back to Hub, then saves.
func returnToMenu() -> void:
	get_tree().paused = false
	if sceneIndex != 0:
		resetRunDays()
		sceneIndex = 0
	saveGame()
	inMenu = true
	player = null
	messageBox = null
	messageTimer = null
	currentScene = null
	ambientLight = null
	var l : Node = get_tree().root.get_node_or_null("loading")
	if l: l.queue_free()
	get_tree().change_scene_to_file(MENU_SCENE)

#endregion

static func _newStats() -> stats:
	var s : stats = stats.new()
	s.version = stats.CURRENT_VERSION
	return s

func _inHub() -> bool:
	var cs : Node = get_tree().current_scene
	return cs != null and cs.name == scenes[0].rootNode

func saveGame() -> void:
	if sceneIndex == 0:
		playerStats.reset_mods()
		
		if not DirAccess.dir_exists_absolute(savePath):
			DirAccess.make_dir_recursive_absolute(savePath)
		
		var save_data : SaveData = SaveData.new()
		
		#Player
		save_data.weapon = weapon
		save_data.armor = armor
		save_data.money = money
		save_data.playerStats = playerStats
		
		#Inventory
		save_data.inventory = inventory
		save_data.hotbar_weapons = hotbar_weapons
		save_data.hotbar_items = hotbar_items
		
		#Time
		save_data.timeOfDay = timeOfDay
		save_data.totalDays = totalDays
		save_data.lastRunDays = lastRunDays
		save_data.longestRun = longestRun
		save_data.playTime = playTime
		save_data.taskProgress = taskProgress
		save_data.tasksClaimed = tasksClaimed
		
		#Ext data
		save_data.shopInventory = shopInventory
		# Ground items: whatever's still waiting to spawn + (only when actually in the hub) what's
		# lying around. Built on a copy so saving twice never doubles them up.
		var pending : Array[GroundItem] = hub_groundItems
		hub_groundItems = pending.duplicate()
		if _inHub(): storeGroundItemData()
		save_data.groundItems = hub_groundItems
		hub_groundItems = pending
		
		#Debug variables
		save_data.bloodMoons = bloodMoons
		save_data.damNumberEnable = damNumberEnable
		save_data.damAnimRotEnable = damAnimRotEnable
		save_data.debugVision = debugVision
		
		var err = ResourceSaver.save(save_data, slotPath(saveSlot))
		if err == OK: _rememberSlot(saveSlot)
		
		if err == OK:
			sendMessage("SAVED GAME", 3, Color.YELLOW)
			print("Saved successfully")
		else:
			sendMessage("SAVE FAILED", 10, Color.RED)
			print("Save failed:", err)

func loadGame():
	if slotExists(saveSlot):
		# Ignore the cache: the last load/save of this slot may still be cached and share objects
		var save_data : SaveData = ResourceLoader.load(slotPath(saveSlot), "", ResourceLoader.CACHE_MODE_IGNORE)
		
		##Reroll newly added stats
		#for i in inventory.data:
			#i.rolled = false
		
		#Player
		weapon = save_data.weapon
		armor = save_data.armor
		money = save_data.money
		playerStats = save_data.playerStats
		# Base stat values changed since this save was made: take the new defaults
		# but carry the earned progression over
		if not playerStats or playerStats.version < stats.CURRENT_VERSION:
			var fresh : stats = _newStats()
			if playerStats:
				for p in ["level", "xp", "unspent_points", "attributes", "beeness_unlocked", "proficiency"]:
					if p in playerStats and playerStats.get(p) != null: fresh.set(p, playerStats.get(p))
			playerStats = fresh
		
		#Inventory
		inventory = save_data.inventory
		hotbar_weapons = save_data.hotbar_weapons
		hotbar_items = save_data.hotbar_items
		
		#Time
		timeOfDay = save_data.timeOfDay
		totalDays = save_data.totalDays
		lastRunDays = save_data.lastRunDays
		longestRun = save_data.longestRun
		playTime = save_data.playTime
		taskProgress = save_data.taskProgress.duplicate()
		tasksClaimed = save_data.tasksClaimed.duplicate()
		
		#Ext data
		shopInventory = save_data.shopInventory
		hub_groundItems = save_data.groundItems
		
		#Debug variables
		bloodMoons = save_data.bloodMoons
		damNumberEnable = save_data.damNumberEnable
		damAnimRotEnable = save_data.damAnimRotEnable
		debugVision = save_data.debugVision
		hotbar_weapons.resize(3)
		hotbar_items.resize(3)
	else:
		print("No save in slot ", saveSlot)
		# Started straight into a scene (F6 / testing) with no save: make one
		if not inMenu: saveGame()

func _ready() -> void:
	_migrateLegacySave()
	saveSlot = lastSlot()
	# Boot state = the last played slot (the menu shows its shell), or a fresh character
	if slotExists(saveSlot): loadGame()
	else:
		resetState()
		_saveIfNotMenu.call_deferred() # the main scene isn't in the tree yet
	lootList.getValid()
	
	hotbar_weapons.resize(3)
	hotbar_items.resize(3)

# Launched straight into a game scene (F6) with no save yet: make one so the hub etc. work
func _saveIfNotMenu() -> void:
	if not inMenu and not slotExists(saveSlot):
		saveGame()

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
	lootList.getValid()

#TODO store totalChance somewhere so it can be used with getRandom
func precalcWeights(list: Array) -> void:
	var totalChance : float = 0
	
	for entry in list:
		totalChance += max(entry.chance, 0)
	
	for entry in list:
		entry.calcWeight(totalChance)

func getRandom(list: Array, skipWeightCalc: bool = true):
	if list.is_empty(): return null
	
	var totalChance : float = 0
	
	if not skipWeightCalc:
		for entry in list:
			totalChance += max(entry.chance, 0)
		
		if totalChance == 0:
			return list[randi() % list.size()].data
	
	var roll : float = randf_range(0, 100)
	var cumulative : float = 0.0
	
	for entry in list:
		if not skipWeightCalc: entry.calcWeight(totalChance)
		cumulative += entry.weight
		if roll <= cumulative:
			return entry.data
	
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
			var extents : Vector2 = shape.size * 0.5
			var local_pos : Vector2 = Vector2(
				randf_range(-extents.x, extents.x),
				randf_range(-extents.y, extents.y)
			)
			randomPos = colShape.to_global(local_pos)
		elif shape is CircleShape2D:
			var r : float = shape.radius
			var angle : float = randf() * TAU
			var dist : float = sqrt(randf()) * r
			var local_pos : Vector2 = Vector2(cos(angle), sin(angle)) * dist
			randomPos = colShape.to_global(local_pos)
	elif colShape is CollisionPolygon2D:
		var points : PackedVector2Array = colShape.polygon
		if not points.size() == 0:
			var index : int = randi() % points.size()
			var next_index : int = (index + 1) % points.size()
			var local_pos : Vector2 = points[index].lerp(points[next_index], randf())
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
		# Elemental / status damage is coloured by its element
		if data.has("color"):
			newLabel.add_theme_color_override("font_color", data.color)
		
		var randomPos : Vector2 = getRandomPosFromColShap(colShape)
		
		newLabel.position = randomPos
		Global.currentScene.add_child(newLabel)

func damageAnim(node: Node2D, damage: float = 10, og_size : Vector2 = Vector2.ONE) -> void:
	var intensity = clamp(sqrt(damage) * 0.02, 0.05, 0.4)
	
	var squash = max(og_size.y - intensity, 0.01)
	var stretch = og_size.x + intensity
	
	var tween = create_tween()
	tween.set_trans(Tween.TRANS_BACK)
	tween.set_ease(Tween.EASE_OUT)
	
	tween.tween_property(node, "scale", Vector2(stretch, squash), 0.08)
	tween.tween_property(node, "scale", Vector2(og_size.x + 0.05, max(og_size.x - 0.05, 0.01)), 0.06)
	tween.tween_property(node, "scale", og_size, 0.06)
	
	if damAnimRotEnable:
		var rot = randf_range(-intensity, intensity)
		
		tween.tween_property(node, "rotation", rot, 0.05)
		tween.tween_property(node, "rotation", 0.0, 0.1)

func getGroundItems() -> Array[Node]:
	return get_tree().get_nodes_in_group("items")

func storeGroundItemData() -> void:
	var itemNodes : Array[Node] = get_tree().get_nodes_in_group("items")
	
	for i in itemNodes:
		# Dropped items carry `item`, placed things (e.g. torches) carry `weapSys.weapon`
		var thisItem : BaseItem = null
		if "item" in i and i.item:
			thisItem = i.item
		elif "weapSys" in i and i.weapSys and i.weapSys.weapon:
			thisItem = i.weapSys.weapon
		if not thisItem:
			continue
		
		var newGroundItem : GroundItem = GroundItem.new()
		newGroundItem.item = thisItem
		newGroundItem.pos = i.global_position
		newGroundItem.rot = i.rotation
		newGroundItem.placed = thisItem.placedScene != null and i.scene_file_path == thisItem.placedScene.resource_path
		
		hub_groundItems.append(newGroundItem)

func genGroundItems() -> void:
	for i in hub_groundItems:
		if not i.item:
			continue
		
		# Placed things come back placed (a lit torch, not a torch icon on the floor)
		if i.placed and i.item.placedScene:
			i.item.spawnPlaced(i.pos, i.rot)
			continue
		
		var newGroundItem : Node2D = load("uid://b5eq6i6you4bx").instantiate()
		newGroundItem.name = i.item.name
		newGroundItem.position = i.pos
		newGroundItem.rotation = i.rot
		newGroundItem.item = i.item
		
		currentScene.add_child(newGroundItem)
	
	hub_groundItems = []

func _process(delta: float) -> void:
	Global.inventory.update()
	
	meta = totalDays * 0.6
	if longestRun > 0:
		performance = float(lastRunDays) / float(longestRun)
	
	if not currentScene:
		currentScene = get_tree().current_scene
	
	if not player:
		var playerChk : Array[Node] = get_tree().get_nodes_in_group("Player")
		if not playerChk.is_empty(): player = playerChk[0]
	
	#Message system
	if player:
		if not messageBox:
			messageBox = player.messageBox
		
		if not messageTimer:
			messageTimer = player.messageTimer
		
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
				var c : ColorRect = messages[i]
				var inverted_index : int = messageCount - 1 - i
				
				c.pBar.visible = i == 0
				
				var m_t : float = (float(inverted_index) / float(maxMessages - 1))
				c.modulate.a = clampf(1.0 - m_t, 0.1, 0.9)
	
	# Main menu: nothing below runs (no scene switching, no clock, no lighting changes)
	if inMenu:
		return
	
	# Play time for this save (main menu returned above)
	if not get_tree().paused: playTime += delta
	
	var thisLoading : CanvasLayer = get_tree().root.get_node_or_null("loading")
	
	#Scene manager
	sceneIndex = clamp(sceneIndex, 0, scenes.keys().size() - 1)
	if get_tree().current_scene.name != scenes[sceneIndex].rootNode:
		if not thisLoading:
			var newLoading : CanvasLayer = loading.instantiate()
			newLoading.name = "loading"
			get_tree().root.add_child(newLoading)
		
		get_tree().change_scene_to_file(scenes[sceneIndex].path)
		currentScene = null # re-picked once the new scene is in
	
	if thisLoading:
		match sceneIndex:
			0:
				if player:
					thisLoading.queue_free()
			_:
				if Global.currentScene and Worldgen.loaded:
					thisLoading.queue_free()
	
	#Reset things for save system
	if sceneIndex != 0:
		shopInventory = []
	
	#Time of day and light calc
	timeOfDay += delta / dayLengthSeconds
	timeOfDay = clamp(timeOfDay, 0.0, 1.0)
	if timeOfDay >= 1.0:
		if sceneIndex == 0:
			totalDays += 1
		else:
			runDays += 1
		lootList.getValid()
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
	
	#Hot Bar
	if hotbar_weapons.size() == 3:
		if Input.is_action_just_pressed("hotbar_1") and hotbar_weapons[0]:
			weapon = hotbar_weapons[0]
		if Input.is_action_just_pressed("hotbar_2") and hotbar_weapons[1]:
			weapon = hotbar_weapons[1]
		if Input.is_action_just_pressed("hotbar_3") and hotbar_weapons[2]:
			weapon = hotbar_weapons[2]
	if hotbar_items.size() == 3:
		if Input.is_action_just_pressed("hotbar_4") and hotbar_items[0]:
			if hotbar_items[0] is WeaponItem:
				weapon = hotbar_items[0]
			else:
				hotbar_items[0].use()
		if Input.is_action_just_pressed("hotbar_5") and hotbar_items[1]:
			if hotbar_items[1] is WeaponItem:
				weapon = hotbar_items[1]
			else:
				hotbar_items[1].use()
		if Input.is_action_just_pressed("hotbar_6") and hotbar_items[2]:
			if hotbar_items[2] is WeaponItem:
				weapon = hotbar_items[2]
			else:
				hotbar_items[2].use()
	
	#For testing
	if addMs and OS.has_feature("editor"):
		sendMessage("TESTING", 2.0, Color(randf_range(0, 1), randf_range(0, 1), randf_range(0, 1)))
		addMs = false

extends Node

var groundItem : PackedScene = preload("res://Assets/prefabs/groundItem.tscn")
var inventoryItem : PackedScene = preload("res://Assets/prefabs/inventoryItem.tscn")
var contextMenu : PackedScene = preload("res://Assets/prefabs/context_menu.tscn")

var Inventory : Array[BaseItem] = []
var MaxInventory : int = 30

var player : RigidBody2D = null
var inventoryUI : Control = null

@export var use : bool = false

func _ready() -> void:
	#For testing
	Inventory.append(load("res://Assets/items/health_1.tres"))

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

func _process(delta: float) -> void:
	#Clear items with no quanitity
	for i in Inventory:
		if i.quantitiy <= 0: Inventory.erase(i)
	
	#For testing
	if Inventory.size() > 0 and use and OS.has_feature("editor"):
		Inventory[0].use()
		use = false

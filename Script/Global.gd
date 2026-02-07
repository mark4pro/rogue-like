extends Node

var Inventory : Array[BaseItem] = []

var player : RigidBody2D = null

@export var use : bool = false

signal Inventory_update

func _ready() -> void:
	Inventory.append(load("res://Assets/items/health_1.tres"))

func add_item(item : BaseItem):
	var index = Inventory.find_custom(func(i): return i.id == item.id)
	if not index == -1:
		Inventory[index].quantitiy += item.quantitiy
	else:
		Inventory.append(item)
	Inventory_update.emit()

func remove_item():
	Inventory_update.emit()

func increase_inventory_size():
	Inventory_update.emit()

func _process(delta: float) -> void:
	for i in Inventory:
		if i.quantitiy <= 0: Inventory.erase(i)
	
	if Inventory.size() > 0 and use and OS.has_feature("editor"):
		Inventory[0].use()
		use = false

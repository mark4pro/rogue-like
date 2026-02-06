extends Node

var Inventory = []

signal Inventory_update

var player_node: Node = null



func _ready():
	#amount of inventory slots
	Inventory.resize(30)
	
	
func add_item(item):
	for i in range(Inventory.size()):
		if Inventory[1] != null and Inventory[1]["type"] == item["type"] and Inventory[1]["effect"] == item["effect"]:
			Inventory[1]["quantitiy"] += item["quantity"]
			Inventory_update.emit()
			return true
		elif Inventory[1] == null:
			Inventory[1] = item
			Inventory_update.emit()
			return true
		return false
			
func remove_item():
	Inventory_update.emit()

func increase_inventory_size():
	Inventory_update.emit()

func set_player_reference(player):
	player_node = player

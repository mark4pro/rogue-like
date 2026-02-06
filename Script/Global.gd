extends Node

var Inventory = []

signal Inventory_update

var player_node: Node = null

func _ready():
	#amount of inventory slots
	Inventory.resize(30)

func add_item(item):
	for i in Inventory:
		if i != null and i["type"] == item["type"] and i["effect"] == item["effect"]:
			i["quantitiy"] += item["quantity"]
		elif i == null:
			i = item
	Inventory_update.emit()

func remove_item():
	Inventory_update.emit()

func increase_inventory_size():
	Inventory_update.emit()

func set_player_reference(player):
	player_node = player

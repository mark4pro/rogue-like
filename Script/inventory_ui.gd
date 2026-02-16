extends Control

@onready var grid_container = $ColorRect/GridContainer

func _ready() -> void:
	gen_inventory()

func clear_grid():
	for c in grid_container.get_children(): c.queue_free()

func gen_inventory():
	clear_grid()
	var empty : int = Global.MaxInventory - Global.Inventory.size()
	for i in Global.Inventory:
		var newInventoryItem : Control = Global.inventoryItem.instantiate()
		newInventoryItem.item = i
		grid_container.add_child(newInventoryItem)
	for e in range(empty):
		var newInventoryItem : Control = Global.inventoryItem.instantiate()
		newInventoryItem.item = null
		grid_container.add_child(newInventoryItem)

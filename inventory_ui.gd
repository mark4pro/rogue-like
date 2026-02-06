extends Control

@onready var grid_container = $GridContainer
# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	Global.Inventory_update.connect(_on_inventory_updated)
	_on_inventory_updated()



func _on_inventory_updated():
	clear_grid_container()
	
func clear_grid_container():
	while grid_container.get_child_count() > 0:
		var child = grid_container.get_child(0)
		grid_container.remove_child(child)
		child.queue_free()
	

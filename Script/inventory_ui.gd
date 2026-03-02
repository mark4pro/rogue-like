extends Control

@onready var grid_container = $ColorRect/GridContainer

@export var menuSize : Vector2 = Vector2(1920, 1080)

@export var oldSize : Vector2 = Vector2.ZERO
@export var cellSize : Vector2 = Vector2.ZERO

var latch : bool = false
var loaded : bool = false

func _ready() -> void:
	gen_inventory()

func gen_inventory_deferred():
	call_deferred("gen_inventory")

func gen_inventory():
	Global.inventory.update()
	for c in grid_container.get_children(): c.queue_free()
	cellSize = grid_container.size / Global.inventory.grid
	var empty : int = Global.inventory.maxSlots - Global.inventory.data.size()
	for i in Global.inventory.data:
		var newInventoryItem : Control = Global.inventoryItem.instantiate()
		newInventoryItem.custom_minimum_size = cellSize
		newInventoryItem.item = i if i.quantity > 0 else null
		grid_container.add_child(newInventoryItem)
	for e in range(empty):
		var newInventoryItem : Control = Global.inventoryItem.instantiate()
		newInventoryItem.custom_minimum_size = cellSize
		newInventoryItem.item = null
		grid_container.add_child(newInventoryItem)
	loaded = true

func _process(_delta: float) -> void:
	if not $"..".visible: oldSize = Vector2.ZERO
	
	if loaded:
		var menuMinSize : Vector2 = Vector2((64 * Global.inventory.grid.x) + (grid_container.get_theme_constant("h_separation") * Global.inventory.grid.x) + 120, \
			(64 * Global.inventory.grid.y) + (grid_container.get_theme_constant("v_separation") * Global.inventory.grid.y) + 120)
		
		if menuSize.x < menuMinSize.x: menuSize.x = menuMinSize.x
		if menuSize.y < menuMinSize.y: menuSize.y = menuMinSize.y
		
		$ColorRect.size = menuSize
		$ColorRect/Label.size.x = menuSize.x
		
		var gridSize : Vector2 = menuSize - Vector2(120, 120)
		var gridPosX : float = (menuSize.x - grid_container.size.x) / 2
		var gridPosY : float = $ColorRect/Label.size.y
		grid_container.position = Vector2(gridPosX, gridPosY)
		grid_container.size = gridSize
		
		cellSize = gridSize / Global.inventory.grid
		
		if not menuSize == oldSize:
			for i in grid_container.get_children():
				i.custom_minimum_size = cellSize
			
			oldSize = Vector2(menuSize)
	else:
		gen_inventory()

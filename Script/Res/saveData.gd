extends Resource
class_name SaveData

@export var save_version : int = 1

@export_category("Player Data")
@export var inventory : Inventory = Inventory.new()#Array[BaseItem] = []
#@export var inventory_grid : Vector2 = 
@export var weapon : WeaponItem = null
@export var money : int = 0

@export_category("Time/Day Data")
@export_range(0.0, 1.0, 0.001) var timeOfDay : float = 0.0
@export var totalDays : int = 0
@export var lastRunDays : int = 0
@export var longestRun : int = 0

@export_category("Setting Data")
@export var bloodMoons : bool = true
@export var damNumberEnable : bool = true
@export var damAnimRotEnable : bool = true
@export var debugVision : bool = true

extends Resource
class_name SaveData

@export var save_version : int = 1

@export_category("Player Data")
@export var inventory : Inventory = Inventory.new()
@export var weapon : WeaponItem = null
@export var armor : ArmorItem = null
@export var money : int = 0
@export var playerStats : stats = stats.new()

@export_category("Hot Bar")
@export var hotbar_weapons : Array[BaseItem] = []
@export var hotbar_items : Array[BaseItem] = []

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

@export var groundItems : Array[GroundItem] = []
@export var shopInventory : Array[BaseItem] = []

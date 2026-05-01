extends CanvasLayer

@onready var itemHBox : HBoxContainer = %ItemDisplayH
@onready var buyBttn : Button = %Buy
@onready var sellBttn : Button = %Sell
@onready var optionDrop : OptionButton = %OptionButton 

@export var itemDisplay : Panel = null

@export_category("Settings")
@export var amountOfGlobal : int = 3
@export var amountOfShop : int = 10

@export_category("Lists")
@export var shopLootList : LootList
#@export var list : Array[BaseItem] = []
@export var shopInventory : Inventory = Inventory.new()
@export var sortedList : Array[BaseItem] = []

var shopkeeper : Node2D = null

var oldSel : int = -1
var mode : int = 0 #0- Buy, 1- Sell
var regen : bool = false

func _ready() -> void:
	if shopkeeper.list.is_empty():
		for i in range(amountOfGlobal):
			var newItem : BaseItem = Global.lootList.getRandom(true)
			if newItem.stackable:
				newItem.quantity += randi_range(1, 20)
			shopInventory.add_item(newItem)
		for i in range(amountOfShop):
			var newItem : BaseItem = shopLootList.getRandom(true)
			if newItem.stackable:
				newItem.quantity += randi_range(1, 20)
			shopInventory.add_item(newItem)
		shopkeeper.list = shopInventory.data
	else:
		shopInventory.data = shopkeeper.list
	
	itemDisplay.visible = false

func _process(delta: float) -> void:
	buyBttn.disabled = mode == 0
	sellBttn.disabled = mode == 1
	
	if oldSel != optionDrop.selected:
		regen = true
		oldSel = optionDrop.selected
	
	if regen:
		#Clear hbox
		for c in itemHBox.get_children():
			if c.visible: c.queue_free()
		
		#Sort the list if needed
		match optionDrop.selected:
			#Weapons
			1:
				pass
			#Armor
			2:
				pass
			#Items
			3:
				pass
		
		if optionDrop.selected == 0:
			#Use list
			if mode == 0:
				for i in shopInventory.data:
					var newItemDisplay = itemDisplay.duplicate()
					newItemDisplay.mode = mode
					newItemDisplay.item = i
					newItemDisplay.visible = true
					
					itemHBox.add_child(newItemDisplay)
			else:
				for i in Global.inventory.data:
					var newItemDisplay = itemDisplay.duplicate()
					newItemDisplay.mode = mode
					newItemDisplay.item = i
					newItemDisplay.visible = true
					
					itemHBox.add_child(newItemDisplay)
		else:
			#Use sorted list
			pass
		
		regen = false

func _on_button_pressed() -> void:
	shopkeeper.isShopClosed = true
	queue_free()

func _on_buy_pressed() -> void:
	mode = 0
	regen = true

func _on_sell_pressed() -> void:
	mode = 1
	regen = true

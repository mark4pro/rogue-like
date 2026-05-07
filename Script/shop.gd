extends CanvasLayer

@onready var itemHBox : HBoxContainer = %ItemDisplayH
@onready var buyBttn : Button = %Buy
@onready var sellBttn : Button = %Sell
@onready var optionDrop : OptionButton = %OptionButton
@onready var itemsPanel : PanelContainer = %ItemDisplay

@onready var quantityPanel : PanelContainer = %Quantity
@onready var quantityTxt : RichTextLabel = %quantity
@onready var quantitySlider : HSlider = %HSlider
@onready var quantityConfirm : Button = %confirm

@export var itemDisplay : Panel = null

@export_category("Settings")
@export var amountOfGlobal : int = 3
@export var amountOfShop : int = 10

@export_category("Lists")
@export var shopLootList : LootList
@export var shopInventory : Inventory = Inventory.new()
@export var sortedList : Array[BaseItem] = []

var shopkeeper : Node2D = null

var oldSel : int = -1
var mode : int = 0 #0- Buy, 1- Sell
var regen : bool = false

var touching : bool = false
var selected : BaseItem = null

func _ready() -> void:
	if Global.shopInventory.is_empty():
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
		Global.shopInventory = shopInventory.data
	else:
		shopInventory.data = Global.shopInventory
	
	itemDisplay.visible = false
	quantityPanel.visible = false

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
		
		if mode == 0:
			for i in shopInventory.get_sorted(optionDrop.selected):
				var newItemDisplay = itemDisplay.duplicate()
				newItemDisplay.item = i
				newItemDisplay.visible = true
				
				itemHBox.add_child(newItemDisplay)
		else:
			for i in Global.inventory.get_sorted(optionDrop.selected):
				var newItemDisplay = itemDisplay.duplicate()
				newItemDisplay.item = i
				newItemDisplay.visible = true
				
				itemHBox.add_child(newItemDisplay)
		
		regen = false
	
	var mousePos : Vector2 = get_viewport().get_mouse_position()
	
	touching = mousePos.x >= itemsPanel.global_position.x and mousePos.x <= itemsPanel.global_position.x + itemsPanel.size.x \
		and mousePos.y >= itemsPanel.global_position.y and mousePos.y <= itemsPanel.global_position.y + itemsPanel.size.y
	
	if not touching:
		var comp : Control = get_node_or_null("Compare")
		if comp: comp.queue_free()
	
	quantityPanel.visible = selected != null
	
	if selected:
		var thisCost : int = selected.cost if mode == 0 else selected.shopPrice
		var total : int = thisCost * quantitySlider.value
		
		quantitySlider.max_value = selected.quantity
		quantityTxt.text = str(int(quantitySlider.value)) + "/" + str(selected.quantity) + " | $" + str(total)
		
		if mode == 0:
			quantityConfirm.disabled = Global.money < total
		else:
			quantityConfirm.disabled = false

func _on_button_pressed() -> void:
	shopkeeper.isShopClosed = true
	queue_free()

func _on_buy_pressed() -> void:
	mode = 0
	regen = true

func _on_sell_pressed() -> void:
	mode = 1
	regen = true

func _on_confirm_pressed() -> void:
	if mode == 0:
		selected.buy(quantitySlider.value)
		selected = null
	else:
		selected.sell(quantitySlider.value)
		selected = null

func _on_close_quantity_pressed() -> void:
	selected = null
	quantityPanel.visible = false

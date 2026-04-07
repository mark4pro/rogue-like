extends CanvasLayer

@export_category("Settings")
@export var amountOfGlobal : int = 3
@export var amountOfShop : int = 10

@export_category("Lists")
@export var shopLootList : LootList
@export var list : Array[BaseItem] = []

var shopkeeper : Node2D = null

func _ready() -> void:
	if shopkeeper.list.is_empty():
		for i in range(amountOfGlobal):
			var newItem : BaseItem = Global.lootList.getRandom()
			if newItem.stackable:
				newItem.quantity += randi_range(1, 20)
				var thisIndex : int = list.find(newItem)
				if thisIndex != -1:
					list[thisIndex].quantity += newItem.quantity
					continue
			list.append(newItem)
		for i in range(amountOfShop):
			var newItem : BaseItem = shopLootList.getRandom()
			if newItem.stackable:
				newItem.quantity += randi_range(1, 20)
				var thisIndex : int = list.find(newItem)
				if thisIndex != -1:
					list[thisIndex].quantity += newItem.quantity
					continue
			list.append(newItem)
		shopkeeper.list = list
	else:
		list = shopkeeper.list
	
	for i in list:
			print(i.name)

func _process(delta: float) -> void:
	pass

func _on_button_pressed() -> void:
	shopkeeper.isShopClosed = true
	queue_free()
	print("test")

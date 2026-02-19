extends Resource
class_name Inventory

@export_category("Inventory")
@export var data : Array[BaseItem] = []
@export var grid : Vector2 = Vector2(8, 4)

var maxSlots : int = 32

func hasSpace(item: BaseItem) -> bool:
	if not item:
		return data.size() < maxSlots
	else:
		if item.stackable:
			var index = data.find_custom(func(i): return i.id == item.id)
			
			if not index == -1:
				return true
			else:
				return data.size() < maxSlots
		else:
			return data.size() < maxSlots

func add_item(item: BaseItem) -> void:
	if item.stackable:
		var index = data.find_custom(func(i): return i.id == item.id)
		
		if not index == -1:
			data[index].quantitiy += item.quantitiy
		else:
			var newItem : BaseItem = item.duplicate(true)
			if not newItem.rolled: newItem.rollStats()
			data.append(newItem)
	else:
		var newItem : BaseItem = item.duplicate(true)
		if not newItem.rolled: newItem.rollStats()
		data.append(newItem)

func remove_items(item: BaseItem, amount: int = 1) -> void:
	var index = data.find_custom(func(i): return i == item)
	if not index == -1:
		amount = clampi(amount, 1, data[index].quantitiy)
		data[index].quantitiy -= amount

func remove_items_by_id(id: int = 0, amount: int = 1) -> void:
	var index = data.find_custom(func(i): return i.id == id)
	if not index == -1:
		amount = clampi(amount, 1, data[index].quantitiy)
		data[index].quantitiy -= amount

func update() -> void:
	maxSlots = grid.x * grid.y
	
	#Clear items with no quanitity
	for i in data:
		if i.quantitiy <= 0: data.erase(i)

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
			var index = data.find_custom(func(i): return i.name == item.name)
			
			if not index == -1:
				return true
			else:
				return data.size() < maxSlots
		else:
			return data.size() < maxSlots

func add_item(item: BaseItem) -> void:
	if item.stackable:
		var index = data.find_custom(func(i): return i.name == item.name)
		
		if not index == -1:
			data[index].quantity += item.quantity
		else:
			print(item.name)
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
		amount = clampi(amount, 1, data[index].quantity)
		data[index].quantity -= amount

func remove_items_by_name(name: String = "", amount: int = 1) -> void:
	var index = data.find_custom(func(i): return i.name == name)
	if not index == -1:
		amount = clampi(amount, 1, data[index].quantity)
		data[index].quantity -= amount

func update() -> void:
	maxSlots = roundi(grid.x) * roundi(grid.y)
	
	#Clear items with no quanitity
	for i in data:
		if not i.rolled: i.rollStats()
		if i.quantity <= 0: 
			if Global.weapon == i: Global.weapon = null
			data.erase(i)

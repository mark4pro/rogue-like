extends Resource
class_name LootList

@export var list : Array[ItemWeighted] = []

var valid : Array[ItemWeighted] = []

func getValid() -> void:
	valid = []
	
	var currentDay : int = Global.runDays if Global.sceneIndex != 0 else Global.totalDays
	
	for entry in list:
		var afterStart : bool = entry.day <= currentDay
		var beforeEnd : bool = entry.lastDay == -1 or entry.lastDay >= currentDay
		
		if afterStart and beforeEnd:
			valid.append(entry)
	
	Global.precalcWeights(list)

func getRandom() -> BaseItem:
	if valid.is_empty(): getValid()
	return Global.getRandom(valid)

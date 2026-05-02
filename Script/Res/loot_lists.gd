extends Resource
class_name LootList

@export var list : Array[Weighted] = []

var valid : Array[Weighted] = []

func getValid() -> void:
	valid = []
	
	var currentDay : int = Global.runDays if Global.sceneIndex != 0 else Global.totalDays
	
	for entry in list:
		var afterStart : bool = entry.day <= currentDay
		var beforeEnd : bool = entry.lastDay == -1 or entry.lastDay >= currentDay
		
		if afterStart and beforeEnd:
			valid.append(entry)
	
	Global.precalcWeights(list)

func getRandom(dup: bool = false):
	if valid.is_empty(): getValid()
	
	var thisItem = Global.getRandom(valid)
	if dup: thisItem = thisItem.duplicate()
	
	return thisItem

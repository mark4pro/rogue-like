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
	
	Global.precalcWeights(valid)

func getRandom(dup: bool = false):
	if valid.is_empty(): getValid()
	
	var thisItem : Variant = Global.getRandom(valid)
	if dup and thisItem: thisItem = thisItem.duplicate() # (an entry can be empty)
	
	return thisItem

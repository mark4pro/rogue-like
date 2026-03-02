extends Resource
class_name Weighted

@export var chance : float = 1.0
@export var weight : float = 1.0
@export var day : int = 0
@export var lastDay : int = -1 #-1 disables this

func calcWeight(total: float) -> void:
	weight = chance / total * 100

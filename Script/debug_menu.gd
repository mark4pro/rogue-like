extends CanvasLayer

@onready var spawnMenu : Control = $SpawnMenu

var path : String = "res://Assets/items"
var items : Array[BaseItem] = []

func getItems() -> void:
	items = []
	
	var dir : DirAccess = DirAccess.open(path)
	
	if not dir:
		print("Failed to open directory: " + path)
		return
	
	dir.list_dir_begin()
	var fileName : String = dir.get_next()
	
	while fileName != "":
		if not dir.current_is_dir():
			items.append(load(path + "/" + fileName))
		fileName = dir.get_next()
	
	dir.list_dir_end()

func _ready() -> void:
	getItems()

func _process(delta: float) -> void:
	pass

extends CanvasLayer

var itemUI : PackedScene = preload("res://Assets/prefabs/ui/item_spawn.tscn")

@onready var spawnMenu : Control = $SpawnMenu
@onready var listContainer : VBoxContainer = $SpawnMenu/BG/ScrollContainer/VBoxContainer

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

func genList() -> void:
	for i in listContainer: i.queue_free()
	
	for g in items:
		var newItemUI : ColorRect = itemUI.instantiate()
		

func _ready() -> void:
	getItems()

func _process(delta: float) -> void:
	pass

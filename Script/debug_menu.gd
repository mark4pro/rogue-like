extends CanvasLayer

@export var catUI : PackedScene
@export var itemUI : PackedScene

@onready var spawnMenu : Control = %SpawnMenu
@onready var listContainer : VBoxContainer = %VBoxContainer

var path : String = "res://Assets/"
var items : Array[BaseItem] = []

func getItems(extPath : String = "items") -> void:
	var dir : DirAccess = DirAccess.open(path + extPath)
	
	if not dir:
		print("Failed to open directory: " + path + extPath)
		return
	
	#Catagory marker
	var newCatUI : ColorRect = catUI.instantiate()
	var catTxt : String = extPath
	catTxt[0] = catTxt[0].to_upper()
	newCatUI.get_node("title").text = catTxt
	listContainer.add_child(newCatUI)
	
	dir.list_dir_begin()
	var fileName : String = dir.get_next()
	
	while fileName != "":
		if not dir.current_is_dir():
			items.append(load(path + extPath + "/" + fileName))
			
			var newItemUI : ColorRect = itemUI.instantiate()
			newItemUI.item = items[-1]
			listContainer.add_child(newItemUI)
		fileName = dir.get_next()
	
	dir.list_dir_end()

func _ready() -> void:
	items = []
	
	for i in listContainer.get_children(): 
		i.queue_free()
	
	getItems("items")
	getItems("armor")
	getItems("weapons")

func _process(delta: float) -> void:
	if Global.player.is_dead: queue_free()

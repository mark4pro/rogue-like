extends Node2D

@onready var ground : TileMapLayer = %Ground
@onready var props : TileMapLayer = %Props
@onready var walls : TileMapLayer = %Walls
@onready var trees : Node2D = %Trees
@onready var debug : TileMapLayer = %Debug
@onready var coll : CollisionPolygon2D = %CollisionPolygon2D

func _ready() -> void:
	debug.visible = false

func clearLayers() -> void:
	ground.clear()
	props.clear()
	walls.clear()
	debug.clear()
	
	for c in trees.get_children():
		c.queue_free()

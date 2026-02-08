extends Node

@onready var treeRes : PackedScene = preload("res://Assets/prefabs/tree.tscn")
@onready var worldData : World = preload("res://worldGen/Worlds/default.tres").duplicate(true)

@export var thisSeed : int = -1 # -1 use random seed
@export var chunkSize : Vector2i = Vector2i(10, 10)
@export var chunkTiles : int = 30
@export var tileSize : int = 32

var seed : int = randi()

var hasWorldNode : Node2D = null

var player : RigidBody2D = null

enum TileType {
	EMPTY,
	FLOOR,
	WALL,
	GRASS,
	PLANT,
	TREE,
	WATER
}

enum Biome {
	DUNGEON,
	CAVE,
	FOREST,
	MIXED
}

var biomeMap = [] # biome_map[chunk_y][chunk_x]
var world = [] # world[y][x] = TileType
var layers = {}

var worldNode : Node2D = null
var isTestEnv : Node2D = null
var freeCam : Camera2D = null

func genLayers(parent: Node2D) -> Dictionary:
	var newLayers = {}

	var ground : TileMapLayer = TileMapLayer.new()
	ground.name = "Ground"
	ground.z_index = 0
	parent.add_child(ground)
	newLayers.ground = ground

	var props : TileMapLayer = TileMapLayer.new()
	props.name = "Props"
	props.z_index = 1
	parent.add_child(props)
	newLayers.props = props
	
	var trees : Node2D = Node2D.new()
	trees.name = "Trees"
	trees.z_index = 4
	parent.add_child(trees)
	newLayers.trees = trees
	
	var walls : TileMapLayer = TileMapLayer.new()
	walls.name = "Walls"
	walls.z_index = 3
	parent.add_child(walls)
	newLayers.walls = walls
	
	return newLayers

func initArrays() -> void:
	biomeMap.clear()
	for y in range(chunkSize.y):
		biomeMap.append([])
		for x in range(chunkSize.x):
			biomeMap[y].append(Biome.FOREST)

	var world_w = chunkSize.x * chunkTiles
	var world_h = chunkSize.y * chunkTiles

	world.clear()
	for y in range(world_h):
		world.append([])
		for x in range(world_w):
			world[y].append(TileType.EMPTY)

func genDungeon() -> void:
	pass

func genCave() -> void:
	pass

func mixGen() -> void:
	pass

#gens the actual map in the tileMapLayer
func mapGen() -> void:
	var ground : TileMapLayer = layers.ground
	var props : TileMapLayer = layers.props
	var trees : Node2D = layers.trees
	var walls : TileMapLayer = layers.walls 
	
	var tileSet = load("res://Assets/tilesets/forest_test.tres")
	
	ground.tile_set = tileSet
	props.tile_set = tileSet
	walls.tile_set = tileSet
	
	ground.tile_set.tile_size = Vector2i(tileSize, tileSize)
	props.tile_set.tile_size = Vector2i(tileSize, tileSize)
	walls.tile_set.tile_size = Vector2i(tileSize, tileSize)
	
	ground.clear()
	props.clear()
	walls.clear()
	
	for y in range(world.size()):
		for x in range(world[y].size()):
			match world[y][x]:
				TileType.GRASS:
					ground.set_cell(Vector2i(x, y), 0, Vector2i(0, 0))
					
				TileType.PLANT:
					ground.set_cell(Vector2i(x, y), 0, Vector2i(1, 0))
				
				TileType.TREE:
					ground.set_cell(Vector2i(x, y), 0, Vector2i(0, 0))
					
					var newTree : Sprite2D = treeRes.instantiate()
					trees.add_child(newTree)
					newTree.name = "Tree1"
					newTree.rotation_degrees = randf_range(0, 360)
					newTree.position = ground.map_to_local(Vector2i(x, y)) + Vector2(randf_range(-16, 16), randf_range(-16, 16))
				
				TileType.FLOOR:
					ground.set_cell(Vector2i(x, y), 0, Vector2i(0, 3))
				
				TileType.WALL:
					walls.set_cell(Vector2i(x, y), 0, Vector2i(0, 2))

func regen() -> void:
	seed = randi()
	seed(seed)
	if not thisSeed == -1: seed = thisSeed
	if hasWorldNode: get_tree().current_scene.get_node("World").free()

func _process(delta: float) -> void:
	if Global.player: Global.player.get_node("Camera2D").make_current()
	
	freeCam = get_tree().current_scene.get_node_or_null("FreeCam")
	hasWorldNode = get_tree().current_scene.get_node_or_null("World")
	
	#Enable/Disable free cam
	if not Global.player and freeCam:
		freeCam.make_current()
	
	#Create world node
	if not hasWorldNode and Global.scenes[Global.sceneIndex].worldGen:
		var newWorldNode : Node2D = Node2D.new()
		get_tree().current_scene.add_child(newWorldNode)
		worldNode = newWorldNode
		newWorldNode.name = "World"
		layers = genLayers(newWorldNode)
		#Generate map
		initArrays()
		worldData.biomeGenerator.gen()
		for s in worldData.generators:
			s.gen()
		mapGen()
	
	#Engine only
	#regen map
	if OS.has_feature("editor") and freeCam:
		if Input.is_action_just_pressed("regen_map") and not Global.player:
			regen()
		if Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT) and not Global.player:
			var newPlayer : RigidBody2D = Global.playerRes.instantiate()
			newPlayer.position = freeCam.get_global_mouse_position()
			worldNode.add_child(newPlayer)
		if Input.is_action_just_pressed("free_cam") and not Global.player == null:
			Global.player.queue_free()

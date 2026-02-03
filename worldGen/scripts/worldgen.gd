extends Node

@onready var playerRes : PackedScene = preload("res://Assets/prefabs/player.tscn")

var chunkSize : Vector2i = Vector2i(10, 10)
var tileSize : int = 32
var thisSeed : int = -1 # -1 use random seed

var hasWorldNode : bool = false
var loaded : bool = false

var player : RigidBody2D = null

var noise = FastNoiseLite.new()

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

	return newLayers

func initArrays() -> void:
	biomeMap.clear()
	for y in range(chunkSize.y):
		biomeMap.append([])
		for x in range(chunkSize.x):
			biomeMap[y].append(Biome.FOREST)

	var world_w = chunkSize.x * 10
	var world_h = chunkSize.y * 10

	world.clear()
	for y in range(world_h):
		world.append([])
		for x in range(world_w):
			world[y].append(TileType.EMPTY)

func genBiome() -> void:
	for cy in range(chunkSize.y):
		for cx in range(chunkSize.x):
			var n = noise.get_noise_2d(cx, cy)
			if n < -0.3:
				biomeMap[cy][cx] = Biome.CAVE
			elif n < 0.2:
				biomeMap[cy][cx] = Biome.FOREST
			else:
				biomeMap[cy][cx] = Biome.DUNGEON

func genDungeon() -> void:
	pass

func genCave() -> void:
	pass

func genForest() -> void:
	for cy in range(chunkSize.y):
		for cx in range(chunkSize.x):
			if biomeMap[cy][cx] != Biome.FOREST:
				continue
				
			for y in range(10):
				for x in range(10):
					var wx = cx * 10 + x
					var wy = cy * 10 + y
					
					world[wy][wx] = TileType.GRASS
					
					var n = noise.get_noise_2d(wx, wy)
					if (n > 0.28 and n < 0.3):
						world[wy][wx] = TileType.PLANT
					if (n > 0.5):
						world[wy][wx] = TileType.TREE

func mixGen() -> void:
	pass

#gens the actual map in the tileMapLayer
func mapGen() -> void:
	var ground : TileMapLayer = layers.ground
	var props  : TileMapLayer = layers.props
	
	var tileSet = load("res://Assets/tilesets/forest_test.tres")
	
	ground.tile_set = tileSet
	props.tile_set = tileSet
	
	ground.tile_set.tile_size = Vector2i(tileSize, tileSize)
	props.tile_set.tile_size = Vector2i(tileSize, tileSize)
	
	ground.clear()
	props.clear()
	
	for y in range(world.size()):
		for x in range(world[y].size()):
			match world[y][x]:
				TileType.GRASS:
					ground.set_cell(Vector2i(x, y), 0, Vector2i(0, 0))
					
				TileType.PLANT:
					ground.set_cell(Vector2i(x, y), 0, Vector2i(1, 0))
				
				TileType.TREE:
					ground.set_cell(Vector2i(x, y), 0, Vector2i(0, 0))
					var treeScene = load("res://Assets/prefabs/tree.tscn")
					var newTree : Sprite2D = treeScene.instantiate()
					worldNode.add_child(newTree)
					newTree.rotation_degrees = randf_range(0, 360)
					newTree.offset = Vector2(randf_range(-16, 16), randf_range(-16, 16))
					newTree.position = ground.map_to_local(Vector2i(x, y))
					#props.set_cell(Vector2i(x, y), 0, Vector2i(4, 2))

func regen() -> void:
	var seed : int = randi()
	seed(seed)
	if not thisSeed == -1: seed = thisSeed
	noise.seed = seed
	noise.frequency = randf_range(0.03, 0.5)#0.03
	if isTestEnv:
		if isTestEnv: isTestEnv.get_node("World").free()
		hasWorldNode = false
		loaded = false

func _ready() -> void:
	var seed : int = randi()
	seed(seed)
	if not thisSeed == -1: seed = thisSeed
	noise.seed = seed
	noise.frequency = randf_range(0.03, 0.5)

func _process(delta: float) -> void:
	var chkPlayer = get_tree().get_nodes_in_group("Player")
	if not chkPlayer.is_empty():
		player = chkPlayer[0]
		player.get_node("Camera2D").enabled = true
	else: player = null
	isTestEnv = get_tree().root.get_node_or_null("TestGen")
	if isTestEnv:
		#Enable/Disable free cam
		if not chkPlayer.is_empty():
			isTestEnv.get_node("FreeCam").enabled = false
		else:
			isTestEnv.get_node("FreeCam").enabled = true
		
		#regen map
		if Input.is_action_just_pressed("regen_map"):
			regen()
		
		#Create world node
		if not hasWorldNode:
			var newWorldNode : Node2D = Node2D.new()
			isTestEnv.add_child(newWorldNode)
			worldNode = newWorldNode
			newWorldNode.name = "World"
			layers = genLayers(newWorldNode)
			hasWorldNode = true
		
		#Generate map
		if not loaded:
			initArrays()
			genBiome()
			genForest()
			mapGen()
			loaded = true
	
	#Engine only
	if OS.has_feature("editor"):
		if Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT) and not player:
			var newPlayer : RigidBody2D = playerRes.instantiate()
			newPlayer.position = get_viewport().get_mouse_position()
			worldNode.add_child(newPlayer)
		if Input.is_action_just_pressed("free_cam") and not player == null:
			player.queue_free()

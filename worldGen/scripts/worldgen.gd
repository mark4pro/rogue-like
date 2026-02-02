extends Node

var chunkSize : Vector2i = Vector2i(10, 10)
var tileSize : int = 32
var thisSeed : int = -1 # -1 use random seed

var hasWorldNode : bool = false
var loaded : bool = false

var noise = FastNoiseLite.new()

enum TileType {
	EMPTY,
	FLOOR,
	WALL,
	GRASS,
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
					if n > 0.35:
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
					
				TileType.TREE:
					ground.set_cell(Vector2i(x, y), 0, Vector2i(0, 0))
					props.set_cell(Vector2i(x, y), 0, Vector2i(1, 0))


func _ready() -> void:
	var seed : int = randi()
	seed(seed)
	if not thisSeed == -1: seed = thisSeed
	noise.seed = seed
	noise.frequency = 0.03

func _process(delta: float) -> void:
	var isTestEnv : Node2D = get_tree().root.get_node_or_null("TestGen")
	if isTestEnv:
		if not hasWorldNode:
			var newWorldNode : Node2D = Node2D.new()
			newWorldNode.name = "World"
			isTestEnv.add_child(newWorldNode)
			layers = genLayers(newWorldNode)
			hasWorldNode = true
		if not loaded:
			initArrays()
			genBiome()
			genForest()
			print(world[0][0])
			mapGen()
			loaded = true

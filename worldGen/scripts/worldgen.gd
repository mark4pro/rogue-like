extends Node

var chunkSize : Vector2i = Vector2i(10, 10)
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

func initArrays() -> void:
	biomeMap.clear()
	for y in chunkSize.y:
		biomeMap.append([])
		for x in chunkSize.x:
			biomeMap[y].append(Biome.FOREST)
	
	var world_w = chunkSize.x * 10
	var world_h = chunkSize.y * 10

	world.clear()
	for y in world_h:
		world.append([])
		for x in world_w:
			world[y].append(TileType.EMPTY)


func genBiome() -> void:
	for cy in chunkSize.x:
		for cx in chunkSize.y:
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
	pass
	#if noise.get_noise_2d(x, y) > 0.4:
		#world[y][x] = TREE

func mixGen() -> void:
	pass

#gens the actual map in the tileMapLayer
func mapGen() -> void:
	pass

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
			var newWorldNode : TileMap = TileMap.new()
			newWorldNode.name = "World"
			isTestEnv.add_child(newWorldNode)
			hasWorldNode = true
		if not loaded:
			initArrays()
			genBiome()
			loaded = true

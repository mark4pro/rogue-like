extends Node

@onready var treeRes : PackedScene = preload("res://Assets/prefabs/objects/tree.tscn")
@onready var worldData : World = preload("res://worldGen/Worlds/default.tres").duplicate(true)

@export var thisSeed : int = -1 # -1 use random seed
@export var worldSize : Vector2i = Vector2i(300, 300)
@export var tileSize : int = 32

var currentSeed : int = randi()

var hasWorldNode : Node2D = null

var player : RigidBody2D = null

var preGen : bool = false
var loaded : bool = false

var world = [] # world[y][x] = WorldTile
var layers = {}
var sepBiomes : Dictionary = {}
var regions : Dictionary = {}

var worldNode : Node2D = null
var isTestEnv : Node2D = null
var freeCam : Camera2D = null

var biome_debug : bool = false

var dirs : Array[Vector2i] = [
	Vector2i.LEFT,
	Vector2i.RIGHT,
	Vector2i.UP,
	Vector2i.DOWN
]

var ground_remap : Dictionary = {
	0: Vector2(0, 0), #Grass
	1: Vector2(0, 3), #Cave floor
}

var wall_remap : Dictionary = {
	0: Vector2(1, 3), #Cave wall
}

var debug_remap : Dictionary = {
	0: Vector2(0, 0), #Forest
	1: Vector2(1, 0), #Cave
}

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
	
	var debug : TileMapLayer = TileMapLayer.new()
	debug.name = "Debug"
	debug.z_index = 10
	debug.modulate.a = 0.5
	debug.visible = false
	parent.add_child(debug)
	newLayers.debug = debug
	
	return newLayers

func genArrays() -> void:
	var biome_noise := FastNoiseLite.new()
	biome_noise.seed = currentSeed
	
	var moisture_noise := FastNoiseLite.new()
	moisture_noise.seed = currentSeed
	
	var cave_noise := FastNoiseLite.new()
	cave_noise.seed = currentSeed
	cave_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	cave_noise.fractal_octaves = 3
	cave_noise.frequency = 0.01
	
	var halfTileSize : float = tileSize * 0.5
	
	world.clear()
	sepBiomes.clear()
	regions.clear()
	
	for y in range(worldSize.y):
		world.append([])
		for x in range(worldSize.x):
			var newWorldTile : WorldTile = WorldTile.new()
			
			newWorldTile.tilePos = Vector2i(x, y)
			newWorldTile.globalPos = Global.currentScene.to_global(Vector2(newWorldTile.tilePos) * tileSize + Vector2(halfTileSize, halfTileSize))
			
			newWorldTile.biome = biome_noise.get_noise_2d(x, y)
			newWorldTile.moisture = moisture_noise.get_noise_2d(x, y)
			newWorldTile.cave = cave_noise.get_noise_2d(x, y)
			
			var forest_strength = clamp(newWorldTile.moisture + newWorldTile.biome, 0.0, 1.0)
			
			if newWorldTile.cave > 0.3:
				newWorldTile.is_cave = true
				newWorldTile.biome_type = 1
				
				newWorldTile.ground_type = 1
				
				if newWorldTile.cave < 0.5:
					newWorldTile.wall_type = 0
				
				if not sepBiomes.find_key("cave"):
					sepBiomes.cave = []
				sepBiomes.cave.append(newWorldTile)
			else:
				if not sepBiomes.find_key("forest"):
					sepBiomes.forest = []
				sepBiomes.forest.append(newWorldTile)
			
			world[y].append(newWorldTile)

func is_cave_wall(tile: WorldTile) -> bool:
	return tile.wall_type == 0 and tile.biome_type == 1

func is_cave_floor(tile: WorldTile) -> bool:
	return tile.wall_type == -1 and tile.biome_type == 1

func is_forest(tile: WorldTile) -> bool:
	return tile.biome_type == 0

func flood_region(start: Vector2, temp: Dictionary, type: int) -> Region:
	var newRegion : Region = Region.new()
	
	match type:
		0:
			newRegion.type = Region.regionType.FOREST
		1:
			newRegion.type = Region.regionType.CAVE
	
	var queue : Array[Vector2i] = [start]
	temp[start] = true
	
	var total_global : Vector2 = Vector2.ZERO
	var total_tile : Vector2i = Vector2i.ZERO
	var count : int = 0
	
	while not queue.is_empty():
		var pos : Vector2i = queue.pop_front()
		
		var tile : WorldTile = world[pos.y][pos.x]
		
		if not newRegion.tile_lookup.has(pos):
			newRegion.tiles.append(tile)
			
			total_global += tile.globalPos
			total_tile += pos
			count += 1
			
			newRegion.tile_lookup[pos] = tile
		
		var is_edge : bool = false
		
		for dir in dirs:
			var next : Vector2i = pos + dir
			
			#Bounds check
			if next.x < 0 or next.y < 0 \
			or next.y >= world.size() \
			or next.x >= world[next.y].size():
				is_edge = true
				continue
			
			var next_tile = world[next.y][next.x]
			
			match type:
				0:
					if is_forest(next_tile):
						if not temp.has(next):
							temp[next] = true
							queue.append(next)
					else:
						is_edge = true
				1:
					if next_tile.is_cave:
						if not temp.has(next):
							temp[next] = true
							queue.append(next)
					else:
						is_edge = true
		
		if is_edge and not newRegion.edgeTile_lookup.has(pos):
			tile.is_edge = true
			newRegion.edgeTiles.append(tile)
			newRegion.edgeTile_lookup[pos] = tile
	
	newRegion.avgPos_global = total_global / count
	newRegion.avgPos_tile = total_tile / count
	
	return newRegion

func flood_subregion(start: Vector2i, temp: Dictionary, parent: Region) -> SubRegion:
	var sub := SubRegion.new()
	
	var queue : Array[Vector2i] = [start]
	temp[start] = true
	
	var total_global : Vector2 = Vector2.ZERO
	var total_tile : Vector2i = Vector2i.ZERO
	var count : int = 0
	
	while not queue.is_empty():
		var pos = queue.pop_front()
		
		var tile : WorldTile = world[pos.y][pos.x]
		
		if not sub.tile_lookup.has(pos):
			sub.tiles.append(tile)
			
			total_global += tile.globalPos
			total_tile += pos
			count += 1
			
			sub.tile_lookup[pos] = tile
		
		var is_edge : bool = false
		
		for dir in dirs:
			var next = pos + dir
			
			#Bounds and outside region check
			if next.x < 0 or next.y < 0 \
			or next.y >= world.size() \
			or next.x >= world[next.y].size() \
			or not parent.tile_lookup.has(next):
				is_edge = true
				continue
			
			var next_tile = world[next.y][next.x]
			
			match parent.type:
				Region.regionType.FOREST:
					pass
				Region.regionType.CAVE:
					if is_cave_floor(next_tile):
						if not temp.has(next):
							temp[next] = true
							queue.append(next)
					else:
						is_edge = true
		
		if is_edge and not sub.edgeTile_lookup.has(pos):
			tile.is_edge = true
			sub.edgeTiles.append(tile)
			sub.edgeTile_lookup[pos] = tile
	
	sub.avgPos_global = total_global / count
	sub.avgPos_tile = total_tile / count
	
	return sub

func gen_cave_regions() -> void:
	var temp : Dictionary = {}
	
	for y in range(world.size()):
		for x in range(world[y].size()):
			var pos : Vector2i = Vector2i(x, y)
			
			if temp.has(pos) or not world[y][x].is_cave:
				continue
			
			var thisRegion : Region = flood_region(pos, temp, 1)
			if not regions.has("cave"): regions.cave = []
			regions.cave.append(thisRegion)

func gen_cave_subRegions() -> void:
	if not regions.has("cave"):
		return
	
	for r in regions.cave:
		var temp : Dictionary = {}
		
		for tile in r.tiles:
			var pos : Vector2i = tile.tilePos
			
			if temp.has(pos) or not is_cave_floor(tile):
				continue
			
			var thisSub : SubRegion = flood_subregion(pos, temp, r)
			
			if thisSub.tiles.size() > 0:
				r.subRegions.append(thisSub)

func gen_forest_regions() -> void:
	var temp : Dictionary = {}
	
	for y in range(world.size()):
		for x in range(world[y].size()):
			var pos : Vector2i = Vector2i(x, y)
			
			if temp.has(pos) or not is_forest(world[y][x]):
				continue
			
			var thisRegion : Region = flood_region(pos, temp, 0)
			if not regions.has("forest"): regions.forest = []
			regions.forest.append(thisRegion)

#gens the actual map in the tileMapLayer
func genTileMap() -> void:
	var ground : TileMapLayer = layers.ground
	var props : TileMapLayer = layers.props
	var trees : Node2D = layers.trees
	var walls : TileMapLayer = layers.walls
	var debug : TileMapLayer = layers.debug
	
	var tileSet : TileSet = load("res://Assets/tilesets/forest_test.tres")
	
	ground.tile_set = tileSet
	props.tile_set = tileSet
	walls.tile_set = tileSet
	debug.tile_set = tileSet
	
	ground.tile_set.tile_size = Vector2i(tileSize, tileSize)
	props.tile_set.tile_size = Vector2i(tileSize, tileSize)
	walls.tile_set.tile_size = Vector2i(tileSize, tileSize)
	debug.tile_set.tile_size = Vector2i(tileSize, tileSize)
	
	ground.clear()
	props.clear()
	walls.clear()
	debug.clear()
	
	for y in range(world.size()):
		for x in range(world[y].size()):
			var thisTile : WorldTile = world[y][x]
			
			ground.set_cell(Vector2i(x, y), 0, ground_remap[thisTile.ground_type])
			
			if thisTile.wall_type != -1:
				walls.set_cell(Vector2i(x, y), 0, wall_remap[thisTile.wall_type])
			
			debug.set_cell(Vector2i(x, y), 1, debug_remap[thisTile.biome_type])
			
				#TileType.GRASS:
					#ground.set_cell(Vector2i(x, y), 0, Vector2i(0, 0))
					#
				#TileType.PLANT:
					#ground.set_cell(Vector2i(x, y), 0, Vector2i(1, 0))
				#
				#TileType.TREE:
					#ground.set_cell(Vector2i(x, y), 0, Vector2i(0, 0))
					
					#var newTree : Sprite2D = treeRes.instantiate()
					#trees.add_child(newTree)
					#newTree.name = "Tree1"
					#newTree.rotation_degrees = randf_range(0, 360)
					#newTree.position = ground.map_to_local(Vector2i(x, y)) + Vector2(randf_range(-16, 16), randf_range(-16, 16))
				
				#TileType.FLOOR:
					#ground.set_cell(Vector2i(x, y), 0, Vector2i(0, 3))
				#
				#TileType.WALL:
					#walls.set_cell(Vector2i(x, y), 0, Vector2i(1, 3))
	
	#Gen world bounds
	var used_rect := ground.get_used_rect()
	var tile_size := ground.tile_set.tile_size
	
	var size_in_pixels = used_rect.size * tile_size
	size_in_pixels = Vector2(size_in_pixels)
	size_in_pixels *= ground.scale
	
	var newStaticBody : StaticBody2D = StaticBody2D.new()
	newStaticBody.name = "Bounds"
	newStaticBody.add_to_group("Bounds")
	
	var newCollisionPoly : CollisionPolygon2D = CollisionPolygon2D.new()
	newCollisionPoly.name = "CollisionPolygon2D"
	
	var points := PackedVector2Array()
	
	points.append(Vector2.ZERO)
	points.append(Vector2(size_in_pixels.x, 0))
	points.append(Vector2(size_in_pixels.x, size_in_pixels.y))
	points.append(Vector2(0, size_in_pixels.y))
	
	newCollisionPoly.polygon = points
	newCollisionPoly.build_mode = CollisionPolygon2D.BUILD_SEGMENTS
	
	Global.currentScene.get_node("World").add_child(newStaticBody)
	Global.currentScene.get_node("World/Bounds").add_child(newCollisionPoly)

func genWorld() -> void:
	#Generate map
	genArrays()
	gen_cave_regions()
	gen_cave_subRegions()
	gen_forest_regions()

func regen() -> void:
	currentSeed = randi()
	if not thisSeed == -1: currentSeed = thisSeed
	seed(currentSeed)
	if hasWorldNode: Global.currentScene.get_node("World").free()
	world.clear()
	EnemySpawner.clearEnemies()

func _process(_delta: float) -> void:
	if Global.player:
		var playerCamera : Camera2D = Global.player.get_node_or_null("Camera2D")
		if playerCamera and playerCamera.is_inside_tree(): playerCamera.make_current()
	
	if Global.sceneIndex == 0 and not preGen:
		genWorld()
		preGen = true
	
	if Global.currentScene:
		freeCam = Global.currentScene.get_node_or_null("FreeCam")
		hasWorldNode = Global.currentScene.get_node_or_null("World")
		
		#Enable/Disable free cam
		if not Global.player and freeCam and freeCam.is_inside_tree(): freeCam.make_current()
		
		#Create world node
		if not hasWorldNode and Global.scenes[Global.sceneIndex].worldGen:
			if Global.currentScene: Global.currentScene.y_sort_enabled = true
			var newWorldNode : Node2D = Node2D.new()
			Global.currentScene.add_child(newWorldNode)
			worldNode = newWorldNode
			newWorldNode.name = "World"
			layers = genLayers(newWorldNode)
			if world.is_empty(): genWorld()
			genTileMap()
			preGen = false
		
		#Engine only
		#regen map
		if OS.has_feature("editor") and freeCam:
			if not Global.player:
				if Input.is_action_just_pressed("regen_map"):
					regen()
				
				if Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
					var newPlayer : RigidBody2D = Global.playerRes.instantiate()
					newPlayer.position = freeCam.get_global_mouse_position()
					Global.currentScene.add_child(newPlayer)
				
				if Input.is_action_just_pressed("debug_biome"):
					layers.debug.visible = not layers.debug.visible
			else:
				if Input.is_action_just_pressed("free_cam"):
					Global.player.queue_free()

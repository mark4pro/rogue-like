extends Node

@onready var treeRes : PackedScene = preload("uid://biahn66yel13i")
#@onready var worldData : World = preload("uid://bjciwkufbj1c").duplicate(true)

@export var thisSeed : int = -1 # -1 use random seed
@export var tileSize : Vector2i = Vector2i(32, 32)
@export var worldSize : Vector2i = Vector2i(300, 300)

var currentSeed : int = randi()

#State
var preGen : bool = false
var loaded : bool = false

#Noise
var biome_noise : FastNoiseLite = FastNoiseLite.new()
var moisture_noise : FastNoiseLite = FastNoiseLite.new()
var cave_noise : FastNoiseLite = FastNoiseLite.new()

#World data
var world = [] # world[y][x] = WorldTile
var sepBiomes : Dictionary = {}
var regions : Dictionary = {}

var worldNode : Node2D = null
var freeCam : Camera2D = null #Make it spawn this in if you press f6 and the player is loaded

var biome_debug : bool = false

var dirs : Array[Vector2i] = [
	Vector2i.LEFT,
	Vector2i.RIGHT,
	Vector2i.UP,
	Vector2i.DOWN
]

var ground_remap : Dictionary = {
	0: Vector2i(0, 0), #Grass
	1: Vector2i(0, 3), #Cave floor
}

var wall_remap : Dictionary = {
	0: Vector2i(1, 3), #Cave wall
}

var debug_remap : Dictionary = {
	0: {
		"norm": Vector2i(0, 0), #Forest
		"edge": Vector2i(0, 1)  #Forest edge
	},
	1: {
		"norm": Vector2i(1, 0), #Cave
		"edge": Vector2i(1, 1), #Cave edge
		"wall_norm": Vector2i(1, 2), #Cave wall
		"wall_edge": Vector2i(1, 3)  #Cave wall edge
	}
}

func genArrays() -> void:
	biome_noise.seed = currentSeed
	moisture_noise.seed = currentSeed
	cave_noise.seed = currentSeed
	cave_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	cave_noise.fractal_octaves = 3
	cave_noise.frequency = 0.01
	
	var halfTileSize : Vector2i = tileSize * 0.5
	
	world.clear()
	sepBiomes.clear()
	regions.clear()
	
	for y in range(worldSize.y):
		world.append([])
		for x in range(worldSize.x):
			var newWorldTile : WorldTile = WorldTile.new()
			
			newWorldTile.tilePos = Vector2i(x, y)
			newWorldTile.globalPos = Global.currentScene.to_global(Vector2(newWorldTile.tilePos * tileSize + halfTileSize))
			
			newWorldTile.biome = biome_noise.get_noise_2d(x, y)
			newWorldTile.moisture = moisture_noise.get_noise_2d(x, y)
			newWorldTile.cave = cave_noise.get_noise_2d(x, y)
			
			var _forest_strength = clamp(newWorldTile.moisture + newWorldTile.biome, 0.0, 1.0)
			
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
	
	newRegion.avgPos_global = total_global / float(count)
	newRegion.avgPos_tile = Vector2i(Vector2(total_tile) / float(count))
	
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
	
	sub.avgPos_global = total_global / float(count)
	sub.avgPos_tile = Vector2i(Vector2(total_tile) / float(count))
	
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
	var ground : TileMapLayer = worldNode.ground
	var _props : TileMapLayer = worldNode.props
	var _trees : Node2D = worldNode.trees
	var walls : TileMapLayer = worldNode.walls
	var debug : TileMapLayer = worldNode.debug
	
	for y in range(worldSize.x):
		for x in range(worldSize.y):
			var thisTile : WorldTile = world[y][x]
			
			#Set ground
			ground.set_cell(Vector2i(x, y), 0, ground_remap[thisTile.ground_type])
			
			#Set walls if there is any
			if thisTile.wall_type != -1:
				walls.set_cell(Vector2i(x, y), 0, wall_remap[thisTile.wall_type])
			
			#Set debug for non edge ground
			debug.set_cell(Vector2i(x, y), 1, debug_remap[thisTile.biome_type].norm)
			
			#Set debug for non edge walls if any
			if thisTile.is_cave and thisTile.wall_type != -1:
				debug.set_cell(Vector2i(x, y), 1, debug_remap[thisTile.biome_type].wall_norm)
			
			if thisTile.is_edge:
				#Sets edge ground
				debug.set_cell(Vector2i(x, y), 1, debug_remap[thisTile.biome_type].edge)
				
				#Sets edge walls if any
				if thisTile.is_cave and thisTile.wall_type != -1:
					debug.set_cell(Vector2i(x, y), 1, debug_remap[thisTile.biome_type].wall_edge)
			
			#var newTree : Sprite2D = treeRes.instantiate()
			#trees.add_child(newTree)
			#newTree.name = "Tree1"
			#newTree.rotation_degrees = randf_range(0, 360)
			#newTree.position = ground.map_to_local(Vector2i(x, y)) + Vector2(randf_range(-16, 16), randf_range(-16, 16))
	
	#Set world bounds
	var used_rect_size : Vector2i = ground.get_used_rect().size
	
	var size_in_pixels : Vector2 = Vector2(used_rect_size * tileSize)
	size_in_pixels *= ground.scale
	
	var points : PackedVector2Array = PackedVector2Array()
	
	points.append(Vector2.ZERO)
	points.append(Vector2(size_in_pixels.x, 0))
	points.append(size_in_pixels)
	points.append(Vector2(0, size_in_pixels.y))
	
	worldNode.coll.polygon = points

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
	world.clear()
	EnemySpawner.clearEnemies()
	loaded = false

func _process(_delta: float) -> void:
	if Global.player:
		var playerCamera : Camera2D = Global.player.camera
		if playerCamera and playerCamera.is_inside_tree(): playerCamera.make_current()
	
	if Global.sceneIndex == 0 and not preGen:
		if worldNode:
			worldNode.queue_free()
			worldNode = null
		genWorld()
		loaded = false
		preGen = true
	
	if Global.currentScene:
		freeCam = Global.currentScene.get_node_or_null("FreeCam")
		
		#Enable/Disable free cam
		if not Global.player and freeCam and freeCam.is_inside_tree(): freeCam.make_current()
		
		#Create world node
		if not loaded and Global.scenes[Global.sceneIndex].worldGen:
			var worldChk : Node2D = Global.currentScene.get_node_or_null("World")
			
			#Create world node
			if not worldChk:
				Global.currentScene.y_sort_enabled = true
				var newWorldNode : Node2D = load("uid://didgtbe1q6t4k").instantiate()
				Global.currentScene.add_child(newWorldNode)
				worldNode = newWorldNode
			
			if worldNode:
				worldNode.clearLayers()
				if world.is_empty(): genWorld()
				genTileMap()
				preGen = false
				loaded = true
		
		#Engine only
		if OS.has_feature("editor") and freeCam:
			if not Global.player:
				if Input.is_action_just_pressed("regen_map"):
					regen()
				
				if Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
					var newPlayer : RigidBody2D = Global.playerRes.instantiate()
					newPlayer.position = freeCam.get_global_mouse_position()
					Global.currentScene.add_child(newPlayer)
				
				if Input.is_action_just_pressed("debug_biome"):
					worldNode.debug.visible = not worldNode.debug.visible
			else:
				if Input.is_action_just_pressed("free_cam"):
					Global.player.queue_free()

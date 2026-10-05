extends Node

@onready var treeRes : PackedScene = preload("uid://biahn66yel13i")
#@onready var worldData : World = preload("uid://bjciwkufbj1c").duplicate(true)

const NO_PARENT : Vector2i = Vector2i(-1, -1)

@export var thisSeed : int = -1 # -1 use random seed
@export var tileSize : Vector2i = Vector2i(32, 32)
@export var worldSize : Vector2i = Vector2i(300, 300)

@export_group("Caves")
@export_range(0.0, 1.0) var cave_threshold : float = 0.3        # noise above this = cave
@export_range(0.0, 1.0) var cave_floor_threshold : float = 0.5  # noise above this = open floor (between = wall)
@export var min_pocket_size : int = 6                           # floor pockets smaller than this get filled with rock
@export_range(0.0, 1.0) var link_chance : float = 0.45          # chance two neighbouring pockets get joined
@export_range(0.0, 1.0) var loop_chance : float = 0.1           # chance of an extra link between pockets already joined
@export_range(0.0, 1.0) var extra_exit_chance : float = 0.25    # chance a pocket gets its own exit even if its group has one
@export var max_link_distance : int = 20                        # max rock tiles a pocket-to-pocket tunnel may cut through
@export var max_exit_search : int = 60                          # max rock tiles an exit tunnel may cut through
@export var tunnel_radius_min : int = 1
@export var tunnel_radius_max : int = 2
@export var opening_clear_radius : int = 3                      # no trees this close to a cave mouth

@export_group("Trees")
@export var tree_noise_frequency : float = 0.035
@export_range(-1.0, 1.0) var clearing_threshold : float = -0.2  # noise below this = clearing (no trees)
@export_range(-1.0, 1.0) var clump_threshold : float = 0.15     # noise above this = dense clump
@export_range(0.0, 1.0) var clump_density : float = 0.8
@export_range(0.0, 1.0) var sparse_density : float = 0.08
@export var tree_jitter : float = 12.0

var currentSeed : int = randi()
var rng : RandomNumberGenerator = RandomNumberGenerator.new()

#State
var preGen : bool = false
var loaded : bool = false

#Noise
var biome_noise : FastNoiseLite = FastNoiseLite.new()
var moisture_noise : FastNoiseLite = FastNoiseLite.new()
var cave_noise : FastNoiseLite = FastNoiseLite.new()
var tree_noise : FastNoiseLite = FastNoiseLite.new()

#World data
var world = [] # world[y][x] = WorldTile
var sepBiomes : Dictionary = {}
var regions : Dictionary = {}
var cave_openings : Array[Vector2i] = [] # forest tile just outside each cave mouth
var no_tree_zone : Dictionary = {}       # Vector2i -> true

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

func _ready() -> void:
	if thisSeed != -1: currentSeed = thisSeed
	seed(currentSeed)

#region Helpers

func in_bounds(p: Vector2i) -> bool:
	return p.x >= 0 and p.y >= 0 and p.x < worldSize.x and p.y < worldSize.y

func get_tile(p: Vector2i) -> WorldTile:
	return world[p.y][p.x]

func is_cave_wall(tile: WorldTile) -> bool:
	return tile.wall_type == 0 and tile.biome_type == 1

func is_cave_floor(tile: WorldTile) -> bool:
	return tile.wall_type == -1 and tile.biome_type == 1

func is_forest(tile: WorldTile) -> bool:
	return tile.biome_type == 0

# Seeded shuffle so BFS paths wander instead of always making the same L-shape
func shuffled_dirs() -> Array[Vector2i]:
	var d : Array[Vector2i] = dirs.duplicate()
	for i in range(d.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp := d[i]
		d[i] = d[j]
		d[j] = tmp
	return d

func _trace(from: Vector2i, parent: Dictionary) -> Array[Vector2i]:
	var path : Array[Vector2i] = []
	var cur : Vector2i = from
	while parent[cur] != NO_PARENT:
		path.append(cur)
		cur = parent[cur]
	return path

func _uf_find(uf: Array[int], i: int) -> int:
	while uf[i] != i:
		uf[i] = uf[uf[i]]
		i = uf[i]
	return i

func _groups(uf: Array[int]) -> Dictionary:
	var groups := {}
	for i in uf.size():
		var root := _uf_find(uf, i)
		if not groups.has(root): groups[root] = []
		groups[root].append(i)
	return groups

#endregion

#region Base generation

func setup_noise() -> void:
	rng.seed = currentSeed
	
	# Different seeds per layer, otherwise biome and moisture are identical
	biome_noise.seed = currentSeed
	moisture_noise.seed = currentSeed + 1
	cave_noise.seed = currentSeed + 2
	tree_noise.seed = currentSeed + 3
	
	cave_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	cave_noise.fractal_octaves = 3
	cave_noise.frequency = 0.01
	
	tree_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	tree_noise.fractal_octaves = 3
	tree_noise.frequency = tree_noise_frequency

func genArrays() -> void:
	setup_noise()
	
	var halfTileSize : Vector2 = Vector2(tileSize) * 0.5
	
	world.clear()
	sepBiomes = {"cave": [], "forest": []}
	regions.clear()
	
	for y in worldSize.y:
		world.append([])
		for x in worldSize.x:
			var tile : WorldTile = WorldTile.new()
			
			tile.tilePos = Vector2i(x, y)
			tile.globalPos = Global.currentScene.to_global(Vector2(tile.tilePos * tileSize) + halfTileSize)
			
			tile.biome = biome_noise.get_noise_2d(x, y)
			tile.moisture = moisture_noise.get_noise_2d(x, y)
			tile.cave = cave_noise.get_noise_2d(x, y)
			
			if tile.cave > cave_threshold:
				tile.is_cave = true
				tile.biome_type = 1
				tile.ground_type = 1
				
				if tile.cave < cave_floor_threshold:
					tile.wall_type = 0
				
				sepBiomes.cave.append(tile)
			else:
				sepBiomes.forest.append(tile)
			
			tile.is_walkable = tile.wall_type == -1
			
			world[y].append(tile)

#endregion

#region Regions

# Shared BFS flood fill. `target` is a Region or SubRegion.
# `accepts` decides whether a neighbouring position belongs to the same area.
func _flood(start: Vector2i, temp: Dictionary, target, accepts: Callable) -> void:
	var queue : Array[Vector2i] = [start]
	temp[start] = true
	
	var total_global : Vector2 = Vector2.ZERO
	var total_tile : Vector2i = Vector2i.ZERO
	
	var head : int = 0 # index instead of pop_front(), which is O(n)
	while head < queue.size():
		var pos : Vector2i = queue[head]
		head += 1
		
		var tile : WorldTile = get_tile(pos)
		target.tiles.append(tile)
		target.tile_lookup[pos] = tile
		total_global += tile.globalPos
		total_tile += pos
		
		var is_edge : bool = false
		for dir in dirs:
			var next : Vector2i = pos + dir
			if not in_bounds(next) or not accepts.call(next):
				is_edge = true
				continue
			if not temp.has(next):
				temp[next] = true
				queue.append(next)
		
		if is_edge:
			tile.is_edge = true
			target.edgeTiles.append(tile)
			target.edgeTile_lookup[pos] = tile
	
	var count : int = queue.size()
	target.avgPos_global = total_global / float(count)
	target.avgPos_tile = Vector2i(Vector2(total_tile) / float(count))

func flood_region(start: Vector2i, temp: Dictionary, type: Region.regionType) -> Region:
	var r : Region = Region.new()
	r.type = type
	
	if type == Region.regionType.CAVE:
		_flood(start, temp, r, func(p: Vector2i) -> bool: return get_tile(p).is_cave)
	else:
		_flood(start, temp, r, func(p: Vector2i) -> bool: return is_forest(get_tile(p)))
	
	return r

func gen_regions() -> void:
	regions = {"cave": [], "forest": []}
	var temp : Dictionary = {}
	
	for y in worldSize.y:
		for x in worldSize.x:
			var pos : Vector2i = Vector2i(x, y)
			if temp.has(pos):
				continue
			
			var tile : WorldTile = get_tile(pos)
			if tile.is_cave:
				regions.cave.append(flood_region(pos, temp, Region.regionType.CAVE))
			elif is_forest(tile):
				regions.forest.append(flood_region(pos, temp, Region.regionType.FOREST))

func gen_cave_subRegions() -> void:
	for r in regions.cave:
		r.subRegions.clear()
		var temp : Dictionary = {}
		
		for tile in r.tiles:
			if temp.has(tile.tilePos) or not is_cave_floor(tile):
				continue
			
			var sub : SubRegion = SubRegion.new()
			_flood(tile.tilePos, temp, sub, func(p: Vector2i) -> bool: return is_cave_floor(get_tile(p)))
			r.subRegions.append(sub)

# Carving changes which pockets touch, so redo regions/sub-regions/edge flags afterwards
func rebuild_regions() -> void:
	for row in world:
		for tile in row:
			tile.is_edge = false
	gen_regions()
	gen_cave_subRegions()

#endregion

#region Cave connections

func connect_caves() -> void:
	cave_openings.clear()
	no_tree_zone.clear()
	
	for r in regions.cave:
		_connect_region(r)

func _connect_region(r: Region) -> void:
	# Drop tiny pockets: not worth a tunnel, just fill them in
	var subs : Array = []
	for sub in r.subRegions:
		if sub.tiles.size() < min_pocket_size:
			for t in sub.tiles:
				t.wall_type = 0
				t.is_walkable = false
		else:
			subs.append(sub)
	
	if subs.is_empty():
		return # solid rock blob, nothing needs to get out
	
	# pos -> pocket index
	var owner : Dictionary = {}
	for i in subs.size():
		for t in subs[i].tiles:
			owner[t.tilePos] = i
	
	# One BFS per pocket finds its nearest exit and its nearest neighbouring pockets
	var results : Array = []
	var candidates : Dictionary = {} # Vector2i(a, b) -> path through rock
	for i in subs.size():
		var res : Dictionary = _search_from_pocket(subs[i], i, owner)
		results.append(res)
		for j in res.links:
			var key : Vector2i = Vector2i(mini(i, j), maxi(i, j))
			var path : Array = res.links[j]
			if not candidates.has(key) or path.size() < candidates[key].size():
				candidates[key] = path
	
	var keys : Array = candidates.keys()
	keys.sort_custom(func(a, b): return candidates[a].size() < candidates[b].size())
	
	var uf : Array[int] = []
	for i in subs.size():
		uf.append(i)
	
	# Randomly join neighbouring pockets, shortest tunnels first
	for key in keys:
		var ra : int = _uf_find(uf, key.x)
		var rb : int = _uf_find(uf, key.y)
		var chance : float = link_chance if ra != rb else loop_chance
		if rng.randf() < chance:
			_carve_path(candidates[key])
			if ra != rb:
				uf[ra] = rb
	
	# A group that can't reach the surface gets welded to its nearest neighbour group
	var changed : bool = true
	while changed:
		changed = false
		var groups : Dictionary = _groups(uf)
		for root in groups:
			if _group_has_exit(groups[root], results):
				continue
			for key in keys:
				var ra : int = _uf_find(uf, key.x)
				var rb : int = _uf_find(uf, key.y)
				if ra == rb or (ra != root and rb != root):
					continue
				_carve_path(candidates[key])
				uf[ra] = rb
				changed = true
				break
			if changed:
				break
	
	# Every group gets at least one exit (the shortest one), maybe more
	for members in _groups(uf).values():
		var best : int = -1
		for i in members:
			if results[i].has_exit and (best == -1 or results[i].exit.size() < results[best].exit.size()):
				best = i
		
		if best == -1:
			_force_exit(subs[members[0]]) # last resort, ignores distance limits
			continue
		
		_open_exit(results[best].exit, results[best].mouth)
		
		for i in members:
			if i != best and results[i].has_exit and rng.randf() < extra_exit_chance:
				_open_exit(results[i].exit, results[i].mouth)

func _group_has_exit(members: Array, results: Array) -> bool:
	for i in members:
		if results[i].has_exit:
			return true
	return false

# Multi-source BFS from a pocket's edge, travelling only through rock.
# Returns the nearest forest tile (exit) and the nearest tile of each other pocket it can reach.
func _search_from_pocket(sub: SubRegion, index: int, owner: Dictionary) -> Dictionary:
	var parent : Dictionary = {}
	var depth : Dictionary = {}
	var queue : Array[Vector2i] = []
	
	for t in sub.edgeTiles:
		parent[t.tilePos] = NO_PARENT
		depth[t.tilePos] = 0
		queue.append(t.tilePos)
	
	var result : Dictionary = {"has_exit": false, "exit": [], "mouth": Vector2i.ZERO, "links": {}}
	var limit : int = maxi(max_exit_search, max_link_distance)
	
	var head : int = 0
	while head < queue.size():
		var pos : Vector2i = queue[head]
		head += 1
		var d : int = depth[pos]
		
		for dir in shuffled_dirs():
			var next : Vector2i = pos + dir
			if not in_bounds(next) or depth.has(next):
				continue
			
			var tile : WorldTile = get_tile(next)
			if is_forest(tile):
				if not result.has_exit and d <= max_exit_search:
					result.has_exit = true
					result.exit = _trace(pos, parent)
					result.mouth = next
			elif is_cave_floor(tile):
				var other : int = owner.get(next, index)
				if other != index and d <= max_link_distance and not result.links.has(other):
					result.links[other] = _trace(pos, parent)
			elif d < limit:
				depth[next] = d + 1
				parent[next] = pos
				queue.append(next)
	
	return result

# Fallback: BFS through any cave tile until we hit forest
func _force_exit(sub: SubRegion) -> void:
	var parent : Dictionary = {}
	var queue : Array[Vector2i] = []
	for t in sub.tiles:
		parent[t.tilePos] = NO_PARENT
		queue.append(t.tilePos)
	
	var head : int = 0
	while head < queue.size():
		var pos : Vector2i = queue[head]
		head += 1
		for dir in shuffled_dirs():
			var next : Vector2i = pos + dir
			if not in_bounds(next) or parent.has(next):
				continue
			if is_forest(get_tile(next)):
				_open_exit(_trace(pos, parent), next)
				return
			parent[next] = pos
			queue.append(next)

func _open_exit(path: Array, mouth: Vector2i) -> void:
	_carve_path(path)
	cave_openings.append(mouth)
	
	for dy in range(-opening_clear_radius, opening_clear_radius + 1):
		for dx in range(-opening_clear_radius, opening_clear_radius + 1):
			no_tree_zone[mouth + Vector2i(dx, dy)] = true

func _carve_path(path: Array) -> void:
	var radius : int = rng.randi_range(tunnel_radius_min, tunnel_radius_max)
	for p in path:
		# Let the width drift so tunnels don't look extruded
		if rng.randf() < 0.15:
			radius = clampi(radius + rng.randi_range(-1, 1), tunnel_radius_min, tunnel_radius_max)
		_carve_disc(p, radius)

func _carve_disc(center: Vector2i, radius: int) -> void:
	for dy in range(-radius, radius + 1):
		for dx in range(-radius, radius + 1):
			if dx * dx + dy * dy > radius * radius + radius:
				continue
			var p : Vector2i = center + Vector2i(dx, dy)
			if not in_bounds(p):
				continue
			var t : WorldTile = get_tile(p)
			if is_cave_wall(t):
				t.wall_type = -1
				t.is_walkable = true
				t.is_connection = true

#endregion

#region Trees

func gen_trees() -> void:
	for y in worldSize.y:
		for x in worldSize.x:
			var tile : WorldTile = world[y][x]
			tile.has_tree = false
			
			# Keep trees off the cave rim and out of cave mouths
			if not is_forest(tile) or tile.is_edge or no_tree_zone.has(tile.tilePos):
				continue
			
			var n : float = tree_noise.get_noise_2d(x, y)
			var chance : float = 0.0
			if n > clearing_threshold:
				var t : float = smoothstep(clearing_threshold, clump_threshold, n)
				chance = lerpf(sparse_density, clump_density, t)
			
			if rng.randf() < chance:
				tile.has_tree = true
				tile.tree_offset = Vector2(rng.randf_range(-tree_jitter, tree_jitter), rng.randf_range(-tree_jitter, tree_jitter))
				tile.tree_rotation = rng.randf_range(0.0, TAU)

#endregion

#gens the actual map in the tileMapLayer
func genTileMap() -> void:
	var ground : TileMapLayer = worldNode.ground
	var _props : TileMapLayer = worldNode.props
	var trees : Node2D = worldNode.trees
	var walls : TileMapLayer = worldNode.walls
	var debug : TileMapLayer = worldNode.debug
	
	for child in trees.get_children():
		child.queue_free()
	
	for y in worldSize.y:
		for x in worldSize.x:
			var cell : Vector2i = Vector2i(x, y)
			var thisTile : WorldTile = world[y][x]
			
			#Set ground
			ground.set_cell(cell, 0, ground_remap[thisTile.ground_type])
			
			#Set walls if there is any
			if thisTile.wall_type != -1:
				walls.set_cell(cell, 0, wall_remap[thisTile.wall_type])
			
			#Set debug for non edge ground
			debug.set_cell(cell, 1, debug_remap[thisTile.biome_type].norm)
			
			#Set debug for non edge walls if any
			if thisTile.is_cave and thisTile.wall_type != -1:
				debug.set_cell(cell, 1, debug_remap[thisTile.biome_type].wall_norm)
			
			if thisTile.is_edge:
				#Sets edge ground
				debug.set_cell(cell, 1, debug_remap[thisTile.biome_type].edge)
				
				#Sets edge walls if any
				if thisTile.is_cave and thisTile.wall_type != -1:
					debug.set_cell(cell, 1, debug_remap[thisTile.biome_type].wall_edge)
			
			if thisTile.has_tree:
				var newTree : Node2D = treeRes.instantiate()
				# Go through global space so it lines up even if ground is scaled
				var world_pos : Vector2 = ground.to_global(ground.map_to_local(cell) + thisTile.tree_offset)
				newTree.position = trees.to_local(world_pos)
				newTree.rotation = thisTile.tree_rotation
				trees.add_child(newTree)
	
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
	genArrays()
	gen_regions()
	gen_cave_subRegions()
	connect_caves()
	rebuild_regions()
	gen_trees()

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

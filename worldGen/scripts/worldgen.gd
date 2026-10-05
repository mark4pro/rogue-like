extends Node

@onready var treeRes : PackedScene = preload("uid://biahn66yel13i")
#@onready var worldData : World = preload("uid://bjciwkufbj1c").duplicate(true)

const NO_PARENT : Vector2i = Vector2i(-1, -1)
const CUTOUT_GROUP : StringName = &"tree_cutout" # add the player + enemies to this group
const MAX_CUTOUTS : int = 32                      # width of the cutout data texture, raise freely
const CUTOUT_CANVAS_GROUP : StringName = &"tree_cutout_canvas" # hand-placed CanvasGroups (e.g. the hub) using tree_cutout_group.gdshader

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

@export_group("Forest connections")
@export var min_forest_size : int = 12 # sealed-in forest patches smaller than this become rock instead of getting a tunnel

@export_group("Trees")
@export var tree_noise_frequency : float = 0.035
@export_range(-1.0, 1.0) var clearing_threshold : float = -0.2  # noise below this = clearing (no trees)
@export_range(-1.0, 1.0) var clump_threshold : float = 0.15     # noise above this = dense clump
@export_range(0.0, 1.0) var clump_density : float = 0.8
@export_range(0.0, 1.0) var sparse_density : float = 0.08
@export var tree_jitter : float = 12.0
@export var tree_chunk_size : int = 32 # tiles per MultiMesh chunk, lets off-screen chunks get culled

@export_group("Tree cutouts")
@export var tree_cutout_shader : Shader = preload("uid://cpd32ul7pn8w2")
@export var cutout_radius : float = 48.0
@export var cutout_softness : float = 24.0
@export_range(0.0, 1.0) var cutout_alpha : float = 0.25

@export_group("Cave lighting")
@export var cave_dark_color : Color = Color(0.14, 0.13, 0.17) # how bright cave tiles get (forest keeps the normal day/night light)
@export var cave_dark_blur : int = 1                           # tiles of soft fade at cave edges/mouths (0 = hard edge)
@export var torch_item : WeaponItem = preload("res://Assets/weapons/torch.tres")
@export var wall_torch_spacing : int = 9                       # min tiles between wall torches
@export_range(0.0, 1.0) var wall_torch_chance : float = 0.35   # chance a wall spot that fits the spacing gets a torch
@export var room_torch_min_size : int = 80                     # pockets with at least this many floor tiles get a centre torch
@export var room_torch_clearance : int = 5                     # min tiles between a room torch and any other torch
@export var torch_wall_inset : float = 0.45                    # how far towards the wall a wall torch sits (0 = tile centre, 0.5 = wall edge)

@export_group("Ground blending")
@export var blend_ground : bool = true                 # blend floor types with a shader instead of transition tiles
@export var ground_blend_shader : Shader = preload("res://Assets/shaders/ground_blend.gdshader")
@export_range(0.0, 1.5) var ground_blend_strength : float = 0.6 # 0 = straight tile edges, higher = more ragged border
@export var ground_blend_feature_px : float = 24.0     # rough size of the border wobbles in pixels

@export_group("Player spawn")
@export var spawn_clear_radius : int = 2    # no trees within this many tiles of the spawn (a small clearing)
@export var spawn_cave_distance : int = 10  # min tiles from any cave tile
@export var spawn_border_margin : int = 12  # min tiles from the map edge
@export var spawn_tries : int = 600         # random picks before relaxing the rules

var currentSeed : int = randi()
var rng : RandomNumberGenerator = RandomNumberGenerator.new()

#State
var preGen : bool = false
var loaded : bool = false
var gen_id : int = 0 # bumps every genWorld(), lets other systems know their cached world data is stale

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
var torch_spots : Array[Dictionary] = [] # {"cell": Vector2i, "wall": Vector2i} (wall = ZERO for a free-standing room torch)

var cave_dark_light : PointLight2D = null # subtractive light shaped like the caves (see _build_cave_darkness)

var spawn_cell : Vector2i = Vector2i(-1, -1) # picked in genWorld() from the seed
var spawn_on_load : bool = false             # set when a run's world node is created, cleared once the player is placed

#Tree rendering (built once from treeRes)
var tree_mesh : ArrayMesh = null
var tree_texture : Texture2D = null
var tree_scale : Vector2 = Vector2.ONE
var tree_modulate : Color = Color.WHITE
var tree_material : Material = null
var cutout_material : ShaderMaterial = null
var cutout_image : Image = null
var cutout_texture : ImageTexture = null

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

# Global position -> tile coords. Uses the ground layer when it exists so scale/offset are respected.
func cell_at(global_pos: Vector2) -> Vector2i:
	if worldNode and is_instance_valid(worldNode):
		var ground : TileMapLayer = worldNode.ground
		return ground.local_to_map(ground.to_local(global_pos))
	return Vector2i((global_pos / Vector2(tileSize)).floor())

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
			if temp.has(tile.tilePos) or not _is_room_floor(tile):
				continue
			
			var sub : SubRegion = SubRegion.new()
			_flood(tile.tilePos, temp, sub, func(p: Vector2i) -> bool: return _is_room_floor(get_tile(p)))
			r.subRegions.append(sub)

# Pocket floor, not tunnel. Tunnels are corridors between pockets, not part of them.
func _is_room_floor(tile: WorldTile) -> bool:
	return is_cave_floor(tile) and not tile.is_connection

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
	_clear_trees_around(mouth)

func _clear_trees_around(center: Vector2i) -> void:
	for dy in range(-opening_clear_radius, opening_clear_radius + 1):
		for dx in range(-opening_clear_radius, opening_clear_radius + 1):
			no_tree_zone[center + Vector2i(dx, dy)] = true

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

#region Forest connections

# Makes every forest region reachable from the biggest one.
# Paths are free through forest and cave floor and only cost something through rock,
# so a region that can already be reached by walking through a cave gets no new tunnel.
func connect_forests() -> void:
	var forests : Array = regions.forest.duplicate()
	if forests.size() <= 1:
		return
	forests.sort_custom(func(a, b): return a.tiles.size() > b.tiles.size())
	
	# Pass 1: tiny patches sealed in solid rock aren't worth a tunnel, turn them into rock.
	# (Done before any carving so a later tunnel can't route through a patch that then gets filled.)
	var to_connect : Array = []
	for i in range(1, forests.size()):
		var r = forests[i]
		if r.tiles.size() < min_forest_size and _is_sealed_in_rock(r):
			_fill_with_rock(r)
		else:
			to_connect.append(r)
	
	# Pass 2: tunnel each remaining region to anything already connected to the main forest
	var connected : Dictionary = {}
	for t in forests[0].tiles:
		connected[t.tilePos] = true
	
	for r in to_connect:
		var path : Array[Vector2i] = _cheapest_path_to(r, connected)
		if path.is_empty():
			continue
		
		_carve_path(path)
		_clear_trees_around(path.front()) # mouth on the connected side
		_clear_trees_around(path.back())  # mouth on this region's side
		
		for t in r.tiles:
			connected[t.tilePos] = true
		for p in path:
			connected[p] = true

func _is_sealed_in_rock(r) -> bool:
	for t in r.edgeTiles:
		for dir in dirs:
			var n : Vector2i = t.tilePos + dir
			if in_bounds(n) and is_cave_floor(get_tile(n)):
				return false # opens onto a cave, filling it could block a passage
	return true

func _fill_with_rock(r) -> void:
	for t in r.tiles:
		t.is_cave = true
		t.biome_type = 1
		t.ground_type = 1
		t.wall_type = 0
		t.is_walkable = false

# 0-1 BFS from every tile of `r`: rock costs 1, everything else costs 0.
# Returns the path (excluding r's own tiles) to the cheapest tile in `targets`.
func _cheapest_path_to(r, targets: Dictionary) -> Array[Vector2i]:
	const INF : int = 1 << 30
	var parent : Dictionary = {}
	var dist : Dictionary = {}
	var cur : Array[Vector2i] = []
	var nxt : Array[Vector2i] = []
	
	for t in r.tiles:
		parent[t.tilePos] = NO_PARENT
		dist[t.tilePos] = 0
		cur.append(t.tilePos)
	
	var level : int = 0
	while not cur.is_empty():
		var head : int = 0
		while head < cur.size():
			var pos : Vector2i = cur[head]
			head += 1
			if dist[pos] != level:
				continue # found a cheaper route to this tile later, skip the stale entry
			if targets.has(pos):
				return _trace(pos, parent)
			
			for dir in shuffled_dirs():
				var next : Vector2i = pos + dir
				if not in_bounds(next):
					continue
				var step : int = 1 if is_cave_wall(get_tile(next)) else 0
				var nd : int = level + step
				if nd < int(dist.get(next, INF)):
					dist[next] = nd
					parent[next] = pos
					if step == 0:
						cur.append(next)
					else:
						nxt.append(next)
		
		cur = nxt
		nxt = []
		level += 1
	
	return []

#endregion

#region Region connection data

# Fills connections_* / connected_subregion_ids / has_exit / reaches_outside
# from the final map. Each corridor (a connected run of tunnel tiles) is flooded once,
# and we record every pocket and forest region it touches.
#
# Every connections_tile entry is a tile that belongs to the region/pocket it's stored on,
# at the middle of the doorway:
#   SubRegion            -> pocket floor where a corridor enters it
#   Region (cave)        -> corridor tile at a cave mouth
#   Region (forest)      -> forest tile just outside a cave mouth
func gen_region_connections() -> void:
	var forest_owner : Dictionary = {} # Vector2i -> index into regions.forest
	for fi in regions.forest.size():
		for t in regions.forest[fi].tiles:
			forest_owner[t.tilePos] = fi
	
	var seen : Dictionary = {}
	
	for r in regions.cave:
		var sub_owner : Dictionary = {} # Vector2i -> index into r.subRegions
		for si in r.subRegions.size():
			for t in r.subRegions[si].tiles:
				sub_owner[t.tilePos] = si
		
		for start in r.tiles:
			if seen.has(start.tilePos) or not start.is_connection:
				continue
			
			var c : Dictionary = _flood_corridor(start.tilePos, seen, sub_owner, forest_owner)
			var touched : Array = c.subs.keys()
			var leads_out : bool = not c.forest.is_empty()
			
			# Pockets on this corridor
			for si in touched:
				var sub : SubRegion = r.subRegions[si]
				_add_connection(sub, _doorway(c.subs[si]))
				for sj in touched:
					if sj != si and not sub.connected_subregion_ids.has(sj):
						sub.connected_subregion_ids.append(sj)
				if leads_out:
					sub.has_exit = true
			
			# Cave mouths: one doorway per forest region this corridor opens onto
			for fi in c.forest:
				_add_connection(regions.forest[fi], _doorway(c.forest[fi]))
				_add_connection(r, _doorway(c.mouths[fi]))
		
		# A pocket can walk out if any pocket it's linked to (directly or not) has an exit
		for si in r.subRegions.size():
			r.subRegions[si].reaches_outside = _pocket_reaches_outside(r, si)

func _flood_corridor(start: Vector2i, seen: Dictionary, sub_owner: Dictionary, forest_owner: Dictionary) -> Dictionary:
	var result : Dictionary = {
		"subs": {},   # pocket index -> pocket tiles touching the corridor
		"forest": {}, # forest region index -> forest tiles touching the corridor
		"mouths": {}  # forest region index -> corridor tiles touching that forest
	}
	
	var queue : Array[Vector2i] = [start]
	seen[start] = true
	var head : int = 0
	
	while head < queue.size():
		var pos : Vector2i = queue[head]
		head += 1
		
		for dir in dirs:
			var n : Vector2i = pos + dir
			if not in_bounds(n):
				continue
			
			var tile : WorldTile = get_tile(n)
			if tile.is_connection:
				if not seen.has(n):
					seen[n] = true
					queue.append(n)
			elif sub_owner.has(n):
				var si : int = sub_owner[n]
				if not result.subs.has(si): result.subs[si] = []
				result.subs[si].append(n)
			elif forest_owner.has(n):
				var fi : int = forest_owner[n]
				if not result.forest.has(fi):
					result.forest[fi] = []
					result.mouths[fi] = []
				result.forest[fi].append(n)
				result.mouths[fi].append(pos)
	
	return result

# Middle of a doorway: the contact tile closest to the average of all contact tiles
func _doorway(contacts: Array) -> Vector2i:
	var avg : Vector2 = Vector2.ZERO
	for p in contacts:
		avg += Vector2(p)
	avg /= float(contacts.size())
	
	var best : Vector2i = contacts[0]
	var best_d : float = INF
	for p in contacts:
		var d : float = Vector2(p).distance_squared_to(avg)
		if d < best_d:
			best_d = d
			best = p
	return best

func _add_connection(target, tile_pos: Vector2i) -> void:
	target.connections_tile.append(tile_pos)
	target.connections_global.append(get_tile(tile_pos).globalPos)

func _pocket_reaches_outside(r: Region, start: int) -> bool:
	var visited : Dictionary = {start: true}
	var queue : Array[int] = [start]
	var head : int = 0
	while head < queue.size():
		var sub : SubRegion = r.subRegions[queue[head]]
		head += 1
		if sub.has_exit:
			return true
		for j in sub.connected_subregion_ids:
			if not visited.has(j):
				visited[j] = true
				queue.append(j)
	return false

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

# Reads the Sprite2D out of treeRes once and turns it into a quad mesh,
# so the tree scene stays the place you edit the tree's look.
func _load_tree_visual() -> void:
	if tree_mesh:
		return
	
	var inst : Node = treeRes.instantiate()
	var sprite : Sprite2D = inst as Sprite2D
	if not sprite:
		var found : Array[Node] = inst.find_children("*", "Sprite2D", true, false)
		if not found.is_empty():
			sprite = found[0]
	assert(sprite and sprite.texture, "treeRes needs a Sprite2D with a texture")
	
	tree_texture = sprite.texture
	tree_scale = sprite.scale
	tree_modulate = sprite.modulate * sprite.self_modulate
	
	# Carry over the drop shadow shader (on the sprite, or on the scene root if the sprite uses its parent's)
	tree_material = sprite.material
	if not tree_material and inst is CanvasItem:
		tree_material = inst.material
	
	# Own copy so the flag below doesn't leak into the tree scene's material
	if tree_material:
		tree_material = tree_material.duplicate()
		if tree_material is ShaderMaterial:
			tree_material.set_shader_parameter("use_instance_data", true)
	
	# Local rect already accounts for centered/offset/region/frames
	var rect : Rect2 = sprite.get_rect()
	
	# Work out which part of the texture the sprite shows
	var tex_size : Vector2 = tree_texture.get_size()
	var src : Rect2 = sprite.region_rect if sprite.region_enabled else Rect2(Vector2.ZERO, tex_size)
	var frame_size : Vector2 = src.size / Vector2(sprite.hframes, sprite.vframes)
	var frame_pos : Vector2 = src.position + frame_size * Vector2(sprite.frame_coords)
	var uv0 : Vector2 = frame_pos / tex_size
	var uv1 : Vector2 = (frame_pos + frame_size) / tex_size
	if sprite.flip_h:
		var t : float = uv0.x; uv0.x = uv1.x; uv1.x = t
	if sprite.flip_v:
		var t : float = uv0.y; uv0.y = uv1.y; uv1.y = t
	
	var arrays : Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = PackedVector2Array([
		rect.position,
		Vector2(rect.end.x, rect.position.y),
		rect.end,
		Vector2(rect.position.x, rect.end.y)
	])
	arrays[Mesh.ARRAY_TEX_UV] = PackedVector2Array([
		uv0,
		Vector2(uv1.x, uv0.y),
		uv1,
		Vector2(uv0.x, uv1.y)
	])
	arrays[Mesh.ARRAY_INDEX] = PackedInt32Array([0, 1, 2, 0, 2, 3])
	
	tree_mesh = ArrayMesh.new()
	tree_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	
	inst.free()

# chunks: Vector2i chunk coord -> Array[Transform2D] (in trees-node space)
func _build_tree_multimeshes(trees: Node2D, chunks: Dictionary) -> void:
	_load_tree_visual()
	
	# Everything goes inside one CanvasGroup so cutouts are cut from the finished forest,
	# not from each tree (overlapping trees would otherwise stack back up to opaque)
	var group : CanvasGroup = CanvasGroup.new()
	group.name = "TreeGroup"
	if tree_cutout_shader:
		if not cutout_material:
			cutout_material = ShaderMaterial.new()
			cutout_material.shader = tree_cutout_shader
		group.material = cutout_material
	else:
		push_warning("tree_cutout_shader not assigned, trees won't cut out")
	trees.add_child(group)
	
	for chunk in chunks:
		var entries : Array = chunks[chunk] # [Transform2D, Color custom]
		
		var mm : MultiMesh = MultiMesh.new()
		# Both of these must be set before instance_count
		mm.transform_format = MultiMesh.TRANSFORM_2D
		mm.use_custom_data = true
		mm.mesh = tree_mesh
		mm.instance_count = entries.size()
		for i in entries.size():
			mm.set_instance_transform_2d(i, entries[i][0])
			mm.set_instance_custom_data(i, entries[i][1])
		
		var mmi : MultiMeshInstance2D = MultiMeshInstance2D.new()
		mmi.name = "Trees_%d_%d" % [chunk.x, chunk.y]
		mmi.multimesh = mm
		mmi.texture = tree_texture
		mmi.self_modulate = tree_modulate
		mmi.material = tree_material # shadow shader, shared across chunks
		group.add_child(mmi)

#endregion

#region Cave torches

# Picks torch spots: one in the middle of every big pocket, then wall torches along cave walls.
# Only data here; _spawn_torches() turns them into pickup-able placed torches.
func gen_torches() -> void:
	torch_spots.clear()
	var grid : Dictionary = {} # spatial hash: Vector2i bucket -> Array[Vector2i], for spacing checks
	var bucket : int = maxi(wall_torch_spacing, room_torch_clearance)
	
	# Room centres first so wall torches keep their distance from them
	for r in regions.cave:
		for sub in r.subRegions:
			if sub.tiles.size() < room_torch_min_size:
				continue
			# Interior tile closest to the pocket's average (the average itself can be in a wall for odd shapes)
			var best : WorldTile = null
			var best_d : float = INF
			for t in sub.tiles:
				if t.is_edge:
					continue
				var d : float = Vector2(t.tilePos).distance_squared_to(Vector2(sub.avgPos_tile))
				if d < best_d:
					best_d = d
					best = t
			if best and _torch_fits(best.tilePos, room_torch_clearance, grid, bucket):
				_add_torch(best.tilePos, Vector2i.ZERO, grid, bucket)
	
	# Wall torches: cave floor next to cave wall, shuffled so spacing doesn't follow scan order
	var candidates : Array[Vector2i] = []
	for r in regions.cave:
		for t in r.tiles:
			if is_cave_floor(t) and not _wall_dirs(t.tilePos).is_empty():
				candidates.append(t.tilePos)
	for i in range(candidates.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp := candidates[i]
		candidates[i] = candidates[j]
		candidates[j] = tmp
	
	for c in candidates:
		if rng.randf() >= wall_torch_chance:
			continue
		if not _torch_fits(c, wall_torch_spacing, grid, bucket):
			continue
		var walls : Array[Vector2i] = _wall_dirs(c)
		_add_torch(c, walls[rng.randi_range(0, walls.size() - 1)], grid, bucket)

# Cardinal directions from `cell` that hit a cave wall
func _wall_dirs(cell: Vector2i) -> Array[Vector2i]:
	var out : Array[Vector2i] = []
	for dir in dirs:
		var n : Vector2i = cell + dir
		if in_bounds(n) and is_cave_wall(get_tile(n)):
			out.append(dir)
	return out

func _torch_fits(cell: Vector2i, spacing: int, grid: Dictionary, bucket: int) -> bool:
	var b : Vector2i = Vector2i((Vector2(cell) / float(bucket)).floor())
	var sq : int = spacing * spacing
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			for other in grid.get(b + Vector2i(dx, dy), []):
				if (other - cell).length_squared() < sq:
					return false
	return true

func _add_torch(cell: Vector2i, wall: Vector2i, grid: Dictionary, bucket: int) -> void:
	torch_spots.append({"cell": cell, "wall": wall})
	var b : Vector2i = Vector2i((Vector2(cell) / float(bucket)).floor())
	if not grid.has(b): grid[b] = []
	grid[b].append(cell)

# Builds each torch the same way BaseItem.place() does, so the pickup menu sees it as a placed torch
func _spawn_torches() -> void:
	var torches : Node2D = worldNode.get_node_or_null("Torches")
	if torches:
		torches.free() # free now so the new node can take the name
	torches = Node2D.new()
	torches.name = "Torches"
	worldNode.add_child(torches)
	
	if not torch_item or not torch_item.placedScene:
		push_warning("torch_item has no placedScene, no cave torches spawned")
		return
	
	var ground : TileMapLayer = worldNode.ground
	var tile_local : Vector2 = Vector2(tileSize)
	
	for i in torch_spots.size():
		var spot : Dictionary = torch_spots[i]
		var wall : Vector2i = spot.wall
		var local : Vector2 = ground.map_to_local(spot.cell) + Vector2(wall) * tile_local * torch_wall_inset
		
		var t : Node2D = torch_item.placedScene.instantiate()
		t.name = "CaveTorch_%d" % i
		t.position = torches.to_local(ground.to_global(local))
		if wall != Vector2i.ZERO:
			t.rotation = Vector2(-wall).angle() + PI * 0.5 # flame points away from the wall
		t.z_index = 4 # above the wall layer (3)
		t.add_to_group("items")
		
		var item : BaseItem = torch_item.duplicate()
		item.quantity = 1
		if "item" in t:
			t.item = item
		if "weapSys" in t:
			var ws : WeaponSys = WeaponSys.new()
			ws.weapon = item
			t.weapSys = ws
		
		torches.add_child(t)

# Cave-only darkness: one big SUBTRACT light whose texture is a per-tile mask of the caves
# (1 texel = 1 tile). It darkens everything standing on cave tiles (ground, walls, enemies,
# items, the player) and leaves the forest alone. Torch lights are ADD lights, so they still
# light caves up. The CanvasModulate keeps doing day/night for the whole map as before.
func _build_cave_darkness() -> void:
	var old : Node = worldNode.get_node_or_null("CaveDarkness")
	if old:
		old.free()
	
	var img : Image = Image.create_empty(worldSize.x, worldSize.y, false, Image.FORMAT_RGBA8)
	for y in worldSize.y:
		for x in worldSize.x:
			if world[y][x].is_cave:
				img.set_pixel(x, y, Color(1, 1, 1, 1))
			else:
				img.set_pixel(x, y, Color(0, 0, 0, 0))
	
	# Soft edges: a few box-blur passes spread the mask ~1 tile per pass into cave mouths/edges
	for pass_i in cave_dark_blur:
		var src : Image = img.duplicate()
		for y in worldSize.y:
			for x in worldSize.x:
				var sum : float = 0.0
				var n : int = 0
				for dy in range(-1, 2):
					for dx in range(-1, 2):
						var sx : int = x + dx
						var sy : int = y + dy
						if sx >= 0 and sy >= 0 and sx < worldSize.x and sy < worldSize.y:
							sum += src.get_pixel(sx, sy).a
							n += 1
				var a : float = sum / float(n)
				img.set_pixel(x, y, Color(a, a, a, a))
	
	# Light textures are sampled without filtering (they live in the light atlas), so upscale the
	# mask with bilinear interpolation; otherwise the fade shows up as tile-sized steps
	const MASK_RES : int = 4 # texels per tile
	img.resize(worldSize.x * MASK_RES, worldSize.y * MASK_RES, Image.INTERPOLATE_BILINEAR)
	
	var ground : TileMapLayer = worldNode.ground
	var light : PointLight2D = PointLight2D.new()
	light.name = "CaveDarkness"
	light.texture = ImageTexture.create_from_image(img)
	light.blend_mode = Light2D.BLEND_MODE_SUB
	light.shadow_enabled = false
	light.texture_scale = float(tileSize.x) * ground.global_scale.x / float(MASK_RES)
	light.range_z_min = RenderingServer.CANVAS_ITEM_Z_MIN
	light.range_z_max = RenderingServer.CANVAS_ITEM_Z_MAX
	worldNode.add_child(light)
	# Texture is centred on the light, so sit it in the middle of the map
	light.global_position = ground.to_global(Vector2(worldSize * tileSize) * 0.5)
	cave_dark_light = light
	_update_cave_darkness()

# Lit result in a cave = albedo * (ambient - sub) + torches, so subtracting (ambient - cave_dark_color)
# lands caves on cave_dark_color whatever the time of day (and never brightens them at night).
func _update_cave_darkness() -> void:
	if not cave_dark_light or not is_instance_valid(cave_dark_light):
		return
	var a : Color = Global.ambientColor
	cave_dark_light.color = Color(
		maxf(a.r - cave_dark_color.r, 0.0),
		maxf(a.g - cave_dark_color.g, 0.0),
		maxf(a.b - cave_dark_color.b, 0.0)
	)
	cave_dark_light.energy = 1.0

#endregion

#region Ground blending

# Puts ground_blend.gdshader on the Ground layer: a 1-texel-per-tile mask says which floor
# type each tile is (one colour channel per type, up to 4) and the shader draws a noisy,
# pixel-snapped border between them, so no hand-made transition tiles are needed.
func _apply_ground_blend() -> void:
	var ground : TileMapLayer = worldNode.ground
	if not blend_ground or not ground_blend_shader:
		ground.material = null
		return
	
	var type_count : int = mini(ground_remap.size(), 4)
	var img : Image = Image.create_empty(worldSize.x, worldSize.y, false, Image.FORMAT_RGBA8)
	for y in worldSize.y:
		for x in worldSize.x:
			var c : Color = Color(0, 0, 0, 0)
			var gt : int = world[y][x].ground_type
			if gt >= 0 and gt < 4:
				c[gt] = 1.0
			img.set_pixel(x, y, c)
	
	var tiles : PackedVector2Array = PackedVector2Array()
	for i in 4:
		tiles.append(Vector2(ground_remap.get(i, Vector2i.ZERO)))
	
	var atlas : TileSetAtlasSource = ground.tile_set.get_source(0) as TileSetAtlasSource
	
	var noise : FastNoiseLite = FastNoiseLite.new()
	noise.seed = currentSeed + 4
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	noise.fractal_octaves = 1 # one smooth octave: wavy border without stray single pixels
	noise.frequency = 1.0 / maxf(ground_blend_feature_px, 1.0)
	var noise_tex : NoiseTexture2D = NoiseTexture2D.new()
	noise_tex.width = 256
	noise_tex.height = 256
	noise_tex.seamless = true
	noise_tex.noise = noise
	
	var mat : ShaderMaterial = ShaderMaterial.new()
	mat.shader = ground_blend_shader
	mat.set_shader_parameter("ground_mask", ImageTexture.create_from_image(img))
	mat.set_shader_parameter("mask_size", Vector2(worldSize))
	mat.set_shader_parameter("tile_px", Vector2(tileSize))
	mat.set_shader_parameter("atlas_padding", 1.0 if atlas.use_texture_padding else 0.0)
	mat.set_shader_parameter("type_tiles", tiles)
	mat.set_shader_parameter("type_count", type_count)
	mat.set_shader_parameter("ground_origin", ground.global_position)
	mat.set_shader_parameter("ground_scale", ground.global_scale)
	mat.set_shader_parameter("edge_noise", noise_tex)
	mat.set_shader_parameter("noise_tex_px", 256.0)
	mat.set_shader_parameter("noise_strength", ground_blend_strength)
	ground.material = mat

#endregion

#region Player spawn

# Picks the run's start tile from the seeded rng (same seed = same spot).
# Wants: main forest region, no trees within spawn_clear_radius, at least spawn_cave_distance
# from caves, away from the map edge. Relaxes those rules step by step if nothing fits.
func gen_spawn() -> void:
	spawn_cell = Vector2i(-1, -1)
	if regions.forest.is_empty():
		spawn_cell = worldSize / 2
		return
	
	# Biggest forest region: everything else is guaranteed to connect to it (connect_forests)
	var main : Region = regions.forest[0]
	for r in regions.forest:
		if r.tiles.size() > main.tiles.size():
			main = r
	
	var rules : Array = [
		[spawn_clear_radius, spawn_cave_distance, spawn_border_margin],
		[1, spawn_cave_distance / 2, spawn_border_margin / 2],
		[0, 0, 0],
	]
	for rule in rules:
		for i in spawn_tries:
			var t : WorldTile = main.tiles[rng.randi_range(0, main.tiles.size() - 1)]
			if _spawn_ok(t, rule[0], rule[1], rule[2]):
				spawn_cell = t.tilePos
				return
	
	spawn_cell = main.avgPos_tile # last resort

func _spawn_ok(t: WorldTile, clear_r: int, cave_d: int, margin: int) -> bool:
	var p : Vector2i = t.tilePos
	if t.has_tree or not t.is_walkable or no_tree_zone.has(p):
		return false
	if p.x < margin or p.y < margin or p.x >= worldSize.x - margin or p.y >= worldSize.y - margin:
		return false
	var r : int = maxi(clear_r, cave_d)
	for dy in range(-r, r + 1):
		for dx in range(-r, r + 1):
			var n : Vector2i = p + Vector2i(dx, dy)
			if not in_bounds(n):
				continue
			var nt : WorldTile = get_tile(n)
			if nt.is_cave and absi(dx) <= cave_d and absi(dy) <= cave_d:
				return false
			if nt.has_tree and absi(dx) <= clear_r and absi(dy) <= clear_r:
				return false
	return true

# Global position of the spawn tile (needs the world node, so only valid after genTileMap)
func get_spawn_position() -> Vector2:
	var ground : TileMapLayer = worldNode.ground
	return ground.to_global(ground.map_to_local(spawn_cell))

# Places the player at the spawn tile. Only runs once per run load (spawn_on_load), never after
# an F6 despawn or a free-cam regen, so the debug free cam / right-click spawn work as before.
func _spawn_player_on_load() -> void:
	spawn_on_load = false
	if not get_tree().get_nodes_in_group("Player").is_empty():
		return # someone's already here
	var newPlayer : RigidBody2D = Global.playerRes.instantiate()
	newPlayer.position = Global.currentScene.to_local(get_spawn_position())
	Global.currentScene.add_child(newPlayer)

#endregion

var _cutout_warned : Dictionary = {}

# Where the hole goes for a node in the cutout group.
# 1. If the node has get_cutout_position(), that wins (use it when the moving body is a child).
# 2. Otherwise its global_position if it's a Node2D.
# 3. Otherwise warn once per scene type, so you can see what's being skipped.
func _cutout_position(n: Node):
	if n.has_method("get_cutout_position"):
		return n.get_cutout_position()
	if n is Node2D:
		return n.global_position
	
	var key : String = n.scene_file_path if n.scene_file_path != "" else n.get_class()
	if not _cutout_warned.has(key):
		_cutout_warned[key] = true
		push_warning("Tree cutout: '%s' (%s) isn't a Node2D, skipping. Add get_cutout_position() or put the group on its body." % [n.name, key])
	return null

# Sends the positions of everything in CUTOUT_GROUP to the tree shader.
# If there are more than MAX_CUTOUTS, the ones closest to the camera win.
func update_tree_cutouts() -> void:
	# The generated forest's material, plus any hand-placed CanvasGroup in CUTOUT_CANVAS_GROUP
	var mats : Array[ShaderMaterial] = []
	if cutout_material and loaded:
		mats.append(cutout_material)
	for n in get_tree().get_nodes_in_group(CUTOUT_CANVAS_GROUP):
		if n is CanvasItem and n.material is ShaderMaterial and not mats.has(n.material):
			mats.append(n.material)
	if mats.is_empty():
		return
	
	if not cutout_texture:
		cutout_image = Image.create_empty(MAX_CUTOUTS, 1, false, Image.FORMAT_RGF) # 32-bit floats, no 0-1 clamping
		cutout_texture = ImageTexture.create_from_image(cutout_image)
	
	# Collect positions (player first, then everything else in the group)
	var points : Array[Vector2] = []
	if Global.player and is_instance_valid(Global.player) and Global.player.is_inside_tree():
		points.append(_cutout_position(Global.player))
	
	var others : Array[Vector2] = []
	for n in get_tree().get_nodes_in_group(CUTOUT_GROUP):
		if n == Global.player or not n.is_inside_tree():
			continue
		var p = _cutout_position(n)
		if p != null:
			others.append(p)
	
	if points.size() + others.size() > MAX_CUTOUTS:
		var cam : Camera2D = get_viewport().get_camera_2d()
		if cam:
			var center : Vector2 = cam.get_screen_center_position()
			others.sort_custom(func(a, b): return a.distance_squared_to(center) < b.distance_squared_to(center))
	points.append_array(others)
	
	var count : int = mini(points.size(), MAX_CUTOUTS)
	for i in count:
		cutout_image.set_pixel(i, 0, Color(points[i].x, points[i].y, 0.0))
	
	cutout_texture.update(cutout_image)
	for mat in mats:
		# Re-assign every frame in case the material was swapped/reloaded
		mat.set_shader_parameter("cutout_data", cutout_texture)
		mat.set_shader_parameter("cutout_count", count)
		mat.set_shader_parameter("cutout_radius", cutout_radius)
		mat.set_shader_parameter("cutout_softness", cutout_softness)
		mat.set_shader_parameter("cutout_alpha", cutout_alpha)

#gens the actual map in the tileMapLayer
func genTileMap() -> void:
	var ground : TileMapLayer = worldNode.ground
	var _props : TileMapLayer = worldNode.props
	var trees : Node2D = worldNode.trees
	var walls : TileMapLayer = worldNode.walls
	var debug : TileMapLayer = worldNode.debug
	
	for child in trees.get_children():
		child.queue_free()
	
	_load_tree_visual() # needs to happen before the loop, it sets tree_scale
	var tree_chunks : Dictionary = {}
	
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
				# Go through global space so it lines up even if ground is scaled
				var world_pos : Vector2 = ground.to_global(ground.map_to_local(cell) + thisTile.tree_offset)
				var xform : Transform2D = Transform2D(thisTile.tree_rotation, tree_scale, 0.0, trees.to_local(world_pos))
				
				# Baked for the shader: world position, rotation, scale
				var custom : Color = Color(world_pos.x, world_pos.y, thisTile.tree_rotation, tree_scale.x)
				
				var chunk : Vector2i = cell / tree_chunk_size
				if not tree_chunks.has(chunk):
					tree_chunks[chunk] = []
				tree_chunks[chunk].append([xform, custom])
	
	_build_tree_multimeshes(trees, tree_chunks)
	_spawn_torches()
	_build_cave_darkness()
	_apply_ground_blend()
	
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
	gen_id += 1
	genArrays()
	gen_regions()
	gen_cave_subRegions()
	connect_caves()
	rebuild_regions()
	connect_forests()
	rebuild_regions()
	gen_region_connections() # must come after the last rebuild, which replaces every Region/SubRegion
	gen_trees()
	gen_torches()
	gen_spawn()

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
				spawn_on_load = true # fresh world for a run: place the player once it's built
			
			if worldNode:
				worldNode.clearLayers()
				if world.is_empty(): genWorld()
				genTileMap()
				preGen = false
				loaded = true
				if spawn_on_load: _spawn_player_on_load()
		
		update_tree_cutouts() # runs in every scene, not just generated ones (the hub has its own trees)
		_update_cave_darkness() # follows day/night
		
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

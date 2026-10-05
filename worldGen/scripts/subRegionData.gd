class_name SubRegion

var tiles : Array[WorldTile] = []
var edgeTiles : Array[WorldTile] = []

var buildings : Array[Node] = []

var avgPos_tile : Vector2i = Vector2i.ZERO #Hopefully the center tile position (or close)
var avgPos_global : Vector2 = Vector2.ZERO #Hopefully the center global position (or close)

# Indices into the parent Region's subRegions (ints, not objects: two SubRegions holding
# each other would be a RefCounted cycle and leak on every regen)
var connected_subregion_ids : Array[int] = []

# One entry per corridor touching this pocket: the pocket floor tile in the middle of the doorway
var connections_tile : Array[Vector2i] = []
var connections_global : Array[Vector2] = []

var has_exit : bool = false        # a corridor from this pocket opens straight onto forest
var reaches_outside : bool = false # can walk out, possibly through other pockets (always true after gen)

var tile_lookup : Dictionary = {}
var edgeTile_lookup : Dictionary = {}

func get_closest_tile_to(pos: Vector2) -> WorldTile:
	var result : Dictionary = {"dist":INF, "data":null}
	
	for i in tiles:
		var dist : float = i.globalPos.distance_squared_to(pos)
		
		if dist <= result.dist:
			result.dist = dist
			result.data = i
	
	return result.data

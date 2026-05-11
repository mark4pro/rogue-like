class_name SubRegion

var tiles : Array[WorldTile] = []
var edgeTiles : Array[WorldTile] = []

var buildings : Array[Node] = []

var avgPos_tile : Vector2i = Vector2i.ZERO #Hopefully the center tile position (or close)
var avgPos_global : Vector2 = Vector2.ZERO #Hopefully the center global position (or close)

var tile_lookup : Dictionary = {}
var edgeTile_lookup : Dictionary = {}

func get_closest_tile_to(pos: Vector2) -> WorldTile:
	var result : Dictionary = {"dist":INF, "data":null}
	
	for i in tiles:
		var dist : float = i.globalPos.distance_to(pos)
		
		if dist <= result.dist:
			result.dist = dist
			result.data = i
	
	return result.data

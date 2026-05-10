class_name SubRegion

var regionTiles : Array[WorldTile] = []

var buildings : Array[Node] = []

var avgPos_tile : Vector2i = Vector2i.ZERO #Hopefully the center tile position (or close)
var avgPos_global : Vector2 = Vector2.ZERO #Hopefully the center global position (or close)

func get_closest_tile_to(pos: Vector2) -> WorldTile:
	var result : Dictionary = {}
	
	for i in regionTiles:
		if i.tilePos:
			pass
	
	return result.data

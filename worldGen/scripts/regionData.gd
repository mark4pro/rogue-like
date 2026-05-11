class_name Region

enum regionType {
	FOREST,
	CAVE
}

var type : regionType = regionType.CAVE

var tiles : Array[WorldTile] = []
var edgeTiles : Array[WorldTile] = []
var subRegions : Array[SubRegion] = []

var avgPos_tile : Vector2i = Vector2i.ZERO #Hopefully the center tile position (or close)
var avgPos_global : Vector2 = Vector2.ZERO #Hopefully the center global position (or close)

var connections_tile : Array[Vector2i] = []
var connections_global : Array[Vector2] = []

var tile_lookup : Dictionary = {}
var edgeTile_lookup : Dictionary = {}

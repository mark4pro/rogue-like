class_name WorldTile

var tilePos : Vector2i = Vector2i.ZERO

#Types
var ground_type : int = 0
var wall_type : int = -1
var biome_type : int = 0
var building : Node = null

#Lists nodes of spawned props connected to this tile (easier to remove things for spawning buildings)
var props : Array[Node] = []

#Weights
var biome : float = 0.0
var moisture : float = 0.0
var elevation : float = 0.0
var cave : float = 0.0

#Flags
var ai_transparent : bool = false
var is_walkable : bool = false
var is_cave : bool = false
var is_breakable : bool = false

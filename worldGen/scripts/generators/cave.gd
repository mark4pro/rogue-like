extends WorldGenerator
class_name CaveGenerator

@export var iterations : int = 6
@export var frequency : Vector2 = Vector2(0.03, 0.5)

var chunkTiles : int = 10
var noise = FastNoiseLite.new()

func gen() -> void:
	noise.seed = Worldgen.seed
	noise.frequency = randf_range(frequency.x, frequency.y)
	
	for cy in range(Worldgen.chunkSize.y):
		for cx in range(Worldgen.chunkSize.x):
			if Worldgen.biomeMap[cy][cx] != Worldgen.Biome.CAVE:
				continue

			# --- initial random fill ---
			for y in range(chunkTiles):
				for x in range(chunkTiles):
					var wx = cx * chunkTiles + x
					var wy = cy * chunkTiles + y

					if randf() < 0.45:
						Worldgen.world[wy][wx] = Worldgen.TileType.WALL
					else:
						Worldgen.world[wy][wx] = Worldgen.TileType.FLOOR

			# --- cellular automata smoothing ---
			for i in range(iterations):
				smooth_cave_chunk(cx, cy)

func smooth_cave_chunk(cx: int, cy: int) -> void:
	var temp := []

	# copy chunk into temp
	for y in range(chunkTiles):
		temp.append([])
		for x in range(chunkTiles):
			var wx = cx * chunkTiles + x
			var wy = cy * chunkTiles + y
			temp[y].append(Worldgen.world[wy][wx])

	# apply rules
	for y in range(chunkTiles):
		for x in range(chunkTiles):
			var wall_count := 0

			for ny in range(-1, 2):
				for nx in range(-1, 2):
					if nx == 0 and ny == 0:
						continue

					var px = x + nx
					var py = y + ny

					if px < 0 or py < 0 or px >= chunkTiles or py >= chunkTiles:
						wall_count += 1
					elif temp[py][px] == Worldgen.TileType.WALL:
						wall_count += 1

			var wx = cx * chunkTiles + x
			var wy = cy * chunkTiles + y

			if wall_count > 4:
				Worldgen.world[wy][wx] = Worldgen.TileType.WALL
			else:
				Worldgen.world[wy][wx] = Worldgen.TileType.FLOOR

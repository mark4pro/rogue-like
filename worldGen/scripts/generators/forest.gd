extends WorldGenerator
class_name ForestGenerator

@export var frequency : Vector2 = Vector2(0.03, 0.5)

var noise = FastNoiseLite.new()

func gen() -> void:
	noise.seed = Worldgen.seed
	noise.frequency = randf_range(frequency.x, frequency.y)
	
	for cy in range(Worldgen.chunkSize.y):
		for cx in range(Worldgen.chunkSize.x):
			if Worldgen.biomeMap[cy][cx] != Worldgen.Biome.FOREST:
				continue
				
			for y in range(Worldgen.chunkTiles):
				for x in range(Worldgen.chunkTiles):
					var wx = cx * Worldgen.chunkTiles + x
					var wy = cy * Worldgen.chunkTiles + y
					
					Worldgen.world[wy][wx] = Worldgen.TileType.GRASS
					
					var n = noise.get_noise_2d(wx, wy)
					if (n > 0.28 and n < 0.3):
						Worldgen.world[wy][wx] = Worldgen.TileType.PLANT
					if (n > 0.5):
						Worldgen.world[wy][wx] = Worldgen.TileType.TREE

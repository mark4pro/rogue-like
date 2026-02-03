extends WorldGenerator
class_name ForestGenerator

var noise = FastNoiseLite.new()

func gen() -> void:
	noise.seed = Worldgen.seed
	noise.frequency = randf_range(0.03, 0.5)
	
	for cy in range(Worldgen.chunkSize.y):
		for cx in range(Worldgen.chunkSize.x):
			if Worldgen.biomeMap[cy][cx] != Worldgen.Biome.FOREST:
				continue
				
			for y in range(10):
				for x in range(10):
					var wx = cx * 10 + x
					var wy = cy * 10 + y
					
					Worldgen.world[wy][wx] = Worldgen.TileType.GRASS
					
					var n = noise.get_noise_2d(wx, wy)
					if (n > 0.28 and n < 0.3):
						Worldgen.world[wy][wx] = Worldgen.TileType.PLANT
					if (n > 0.5):
						Worldgen.world[wy][wx] = Worldgen.TileType.TREE

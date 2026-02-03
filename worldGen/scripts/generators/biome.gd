extends WorldGenerator
class_name BiomeGenerator

var noise = FastNoiseLite.new()

func gen() -> void:
	noise.seed = Worldgen.seed
	noise.frequency = randf_range(0.03, 0.5)
	
	for cy in range(Worldgen.chunkSize.y):
		for cx in range(Worldgen.chunkSize.x):
			var n = noise.get_noise_2d(cx, cy)
			if n < -0.3:
				Worldgen.biomeMap[cy][cx] = Worldgen.Biome.CAVE
			elif n < 0.2:
				Worldgen.biomeMap[cy][cx] = Worldgen.Biome.FOREST
			else:
				Worldgen.biomeMap[cy][cx] = Worldgen.Biome.DUNGEON

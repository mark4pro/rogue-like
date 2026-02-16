extends WorldGenerator
class_name BiomeGenerator

@export var frequency : Vector2 = Vector2(0.03, 0.5)

@export var cave_val : float = -0.3
#@export var forest_val : float = 0.2
#@export var dungeon_val : float = -0.3

var noise = FastNoiseLite.new()

func gen() -> void:
	noise.seed = Worldgen.currentSeed
	noise.frequency = randf_range(frequency.x, frequency.y)
	
	for cy in range(Worldgen.chunkSize.y):
		for cx in range(Worldgen.chunkSize.x):
			var n = noise.get_noise_2d(cx, cy)
			if n < cave_val:
				Worldgen.biomeMap[cy][cx] = Worldgen.Biome.CAVE
			else:
				Worldgen.biomeMap[cy][cx] = Worldgen.Biome.FOREST

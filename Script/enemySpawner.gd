extends Node

const HABITAT_FOREST : int = 1
const HABITAT_CAVE : int = 2

@onready var enemyList : LootList = preload("uid://nsj3x6vtwf1e")

@export var targetFPS : int = 60
@export var updateSlots : int = 10
@export var maxEnemies : int = 20
@export var enemyCount : int = 0
@export var spawnTime : float = 0.5

@export_group("Spawn placement")
@export var spawn_band : int = 12            # how many tiles past the screen edge enemies can appear
@export var offscreen_margin : float = 64.0  # extra px around the screen that still counts as "visible"
@export var front_bias : float = 3.0         # extra weight for tiles ahead of the player (0 = no preference)
@export var mouth_bias : float = 3.0         # weight multiplier near cave mouths (1 = no preference)
@export var mouth_radius : int = 4           # tiles around a cave mouth that get mouth_bias
@export var spawn_in_corridors : bool = false

@export_group("Enemy levels")
# Each enemy gets a level when it spawns (replaces the old flat difficulty multipliers):
#   level = 1 + total_days * level_per_total_day + run_days * level_per_run_day (+ blood moon bonus)
# total_days = days finished before this run started (Global.totalDays), run_days = Global.runDays.
# The level buys attribute points (same table as the player) spread by the enemy's archetype
# weights, plus a small built-in boost per level so high-level enemies are tough whatever their build.
@export var level_per_total_day : float = 0.2
@export var level_per_run_day : float = 1.0
@export var level_variance : int = 1             # random +-, so a pack isn't all one level
@export var health_per_level : float = 0.08      # +8% max health per level above 1
@export var damage_per_level : float = 0.05      # +5% damage per level above 1
@export var defense_per_level : float = 0.5      # flat defense per level above 1
@export_subgroup("Blood moon")
@export var blood_moon_bonus_levels : int = 5    # blood moon enemies are this many levels higher
@export var blood_moon_spawn_rate_mult : float = 2.0  # spawns this many times as often
@export var blood_moon_max_enemies_mult : float = 1.5 # and allows this many times as many at once
@export_subgroup("Blood moon loot")
# Applies to enemies killed while a blood moon is up
@export var blood_moon_money_mult : float = 2.0        # money dropped
@export var blood_moon_loot_chance_mult : float = 2.0  # chance of dropping items at all
@export var blood_moon_extra_loot : int = 1            # extra items per drop
@export var blood_moon_equip_drop_mult : float = 2.0   # chance of dropping the enemy's own weapon
@export_range(0.0, 1.0) var blood_moon_rarity_bonus : float = 0.25 # added to the rarity roll (6 tiers, so 0.25 = +1.5 tiers)

@export_group("Elites")
# Rare tougher versions of normal enemies from a set run day on: a coloured glow, more health and
# damage, much better drops, and one affix (fast / splitting / shielded). Tuning for each affix is
# in enemy.gd (Elite region).
@export var elite_first_run_day : int = 2              # no elites on run days before this
@export_range(0.0, 1.0) var elite_chance : float = 0.04          # chance per spawn on that day
@export_range(0.0, 1.0) var elite_chance_per_day : float = 0.015 # added each run day after it
@export_range(0.0, 1.0) var elite_chance_max : float = 0.15
@export var elite_blood_moon_mult : float = 2.0        # blood moons spawn this many times as many
@export var elite_health_mult : float = 2.5
@export var elite_damage_mult : float = 1.35

@export_group("Cave spawning")
@export_range(0.0, 1.0) var cave_spawn_weight : float = 0.3 # weight of a cave tile vs a forest tile (1 = equal)
@export var cave_tiles_per_enemy : int = 80                 # pocket capacity = pocket tiles / this (at least 1)

var enemyNode : Node2D = null

var time : float = 0.0
var oldDay : int = -1
var spawned_total : int = 0

# World caches, rebuilt once per generated world (see _refresh_world_cache)
var _cache_gen : int = -1
var _mouth_zone : Dictionary = {}       # Vector2i -> true
var _pocket_of : Dictionary = {}        # Vector2i -> pocket index (cave room floor only)
var _pocket_capacity : Array[int] = []  # pocket index -> max enemies

func getCameraRect() -> Rect2:
	var camera : Camera2D = get_viewport().get_camera_2d()
	if not camera:
		return Rect2()
	var half_size : Vector2 = (camera.get_viewport_rect().size * 0.5) / camera.zoom
	# Screen center, not global_position: accounts for smoothing, drag margins and limits
	return Rect2(camera.get_screen_center_position() - half_size, half_size * 2.0)

func isWalkable(pos: Vector2) -> bool:
	var cell : Vector2i = Worldgen.cell_at(pos)
	return Worldgen.in_bounds(cell) and Worldgen.get_tile(cell).is_walkable

func habitat_of(tile: WorldTile) -> int:
	if not tile.is_walkable:
		return 0
	if Worldgen.is_forest(tile):
		return HABITAT_FOREST
	if tile.is_connection and not spawn_in_corridors:
		return 0
	return HABITAT_CAVE

#region Wandering

# Random reachable point for AI wandering.
# Walks from `from` through walkable tiles and picks a random tile between min_steps and
# max_steps away by walking distance, so the nav agent always gets a target it can reach.
# keep_habitat: only walk/pick within the same biome as `from` (cave enemies stay in caves,
# forest enemies don't wander into caves).
# Returns `from` if nothing fits, so the agent just idles until its next retarget.
func getWanderPoint(from: Vector2, min_steps: int = 8, max_steps: int = 30, keep_habitat: bool = true) -> Vector2:
	if not Worldgen.loaded or Worldgen.world.is_empty():
		return from
	
	var start : Vector2i = Worldgen.cell_at(from)
	if not Worldgen.in_bounds(start):
		return from
	var start_forest : bool = Worldgen.is_forest(Worldgen.get_tile(start))
	
	var dist : Dictionary = {start: 0}
	var queue : Array[Vector2i] = [start]
	var head : int = 0
	var picked : WorldTile = null
	var seen_candidates : int = 0
	
	while head < queue.size():
		var c : Vector2i = queue[head]
		head += 1
		var d : int = dist[c]
		
		if d >= min_steps:
			# Reservoir sampling: uniform pick without storing every candidate
			seen_candidates += 1
			if randi() % seen_candidates == 0:
				picked = Worldgen.get_tile(c)
		
		if d >= max_steps:
			continue
		
		for dir in Worldgen.dirs:
			var n : Vector2i = c + dir
			if dist.has(n) or not Worldgen.in_bounds(n):
				continue
			var t : WorldTile = Worldgen.get_tile(n)
			if not t.is_walkable:
				continue
			if keep_habitat and Worldgen.is_forest(t) != start_forest:
				continue
			dist[n] = d + 1
			queue.append(n)
	
	return picked.globalPos if picked else from

#endregion

#region Spawn placement

# Picks a spawn spot and an enemy that's allowed to live there.
# Returns {"pos": Vector2 (global), "scene": PackedScene}, or {} if nothing fits this tick.
#
# Walks outward from the player's tile through walkable tiles only (BFS), so every candidate
# is reachable on foot and close by walking distance, not just in a straight line.
# That replaces the old raycast: a spot behind a cave wall is far in steps, so it never qualifies.
func findSpawn() -> Dictionary:
	if not Worldgen.loaded or Worldgen.world.is_empty() or not Global.player:
		return {}
	
	var allowed : int = _available_habitats()
	if allowed == 0:
		return {} # no enemies valid today
	
	_refresh_world_cache()
	var pocket_counts : Dictionary = _count_enemies_per_pocket()
	
	var cam_rect : Rect2 = getCameraRect().grow(offscreen_margin)
	var tile_px : float = float(Worldgen.tileSize.x)
	var half : Vector2 = cam_rect.size * 0.5
	# Walking distance is never shorter than straight-line distance, so nothing closer than
	# the nearest screen edge can be off-screen. The camera check below handles the rest.
	var min_steps : int = int(minf(half.x, half.y) / tile_px)
	var max_steps : int = int(half.length() / tile_px) + spawn_band
	
	var player_pos : Vector2 = Global.player.global_position
	var player_cell : Vector2i = Worldgen.cell_at(player_pos)
	if not Worldgen.in_bounds(player_cell):
		return {}
	
	var player_dir : Vector2 = Vector2.ZERO
	if "dir" in Global.player:
		player_dir = Global.player.dir
	
	var tiles : Array[WorldTile] = []
	var weights : PackedFloat32Array = PackedFloat32Array()
	var total : float = 0.0
	
	var dist : Dictionary = {player_cell: 0}
	var queue : Array[Vector2i] = [player_cell]
	var head : int = 0
	
	while head < queue.size():
		var c : Vector2i = queue[head]
		head += 1
		var d : int = dist[c]
		
		if d >= min_steps:
			var t : WorldTile = Worldgen.get_tile(c)
			var hab : int = habitat_of(t)
			if hab & allowed and not cam_rect.has_point(t.globalPos) and not _pocket_full(c, pocket_counts):
				var w : float = 1.0
				if hab == HABITAT_CAVE:
					w *= cave_spawn_weight
				if player_dir != Vector2.ZERO and (t.globalPos - player_pos).dot(player_dir) > 0.0:
					w += front_bias
				if _mouth_zone.has(c):
					w *= mouth_bias
				tiles.append(t)
				weights.append(w)
				total += w
		
		if d >= max_steps:
			continue
		
		for dir in Worldgen.dirs:
			var n : Vector2i = c + dir
			if dist.has(n) or not Worldgen.in_bounds(n):
				continue
			if not Worldgen.get_tile(n).is_walkable:
				continue
			dist[n] = d + 1
			queue.append(n)
	
	if total <= 0.0:
		return {}
	
	# Weighted pick of a tile
	var r : float = randf() * total
	var idx : int = 0
	while idx < weights.size() - 1:
		r -= weights[idx]
		if r <= 0.0:
			break
		idx += 1
	
	var tile : WorldTile = tiles[idx]
	var scene : PackedScene = _pick_enemy(habitat_of(tile))
	if not scene:
		return {}
	
	return {"pos": tile.globalPos, "scene": scene}

# Bitmask of habitats that have at least one valid enemy right now
func _available_habitats() -> int:
	if enemyList.valid.is_empty():
		enemyList.getValid()
	var mask : int = 0
	for e in enemyList.valid:
		if e is EnemyWeighted and e.data:
			mask |= e.habitat
	return mask

# Weighted by `chance` over just the enemies allowed in this habitat.
# (Doesn't use the precalculated `weight`, since that was normalised over the whole list.)
func _pick_enemy(habitat: int) -> PackedScene:
	var options : Array[EnemyWeighted] = []
	var total : float = 0.0
	for e in enemyList.valid:
		if e is EnemyWeighted and e.data and e.habitat & habitat:
			options.append(e)
			total += e.chance
	
	if options.is_empty() or total <= 0.0:
		return null
	
	var r : float = randf() * total
	for e in options:
		r -= e.chance
		if r <= 0.0:
			return e.data
	return options.back().data

# Rebuilt once per generated world:
# - mouth zone: forest tiles near cave mouths (forest side only, so caves don't get the boost)
# - pocket lookup + capacity, so small caves can't fill up
func _refresh_world_cache() -> void:
	if _cache_gen == Worldgen.gen_id:
		return
	_cache_gen = Worldgen.gen_id
	_mouth_zone.clear()
	_pocket_of.clear()
	_pocket_capacity.clear()
	
	for r in Worldgen.regions.get("forest", []):
		for p in r.connections_tile:
			for dy in range(-mouth_radius, mouth_radius + 1):
				for dx in range(-mouth_radius, mouth_radius + 1):
					var n : Vector2i = p + Vector2i(dx, dy)
					if Worldgen.in_bounds(n) and Worldgen.is_forest(Worldgen.get_tile(n)):
						_mouth_zone[n] = true
	
	for r in Worldgen.regions.get("cave", []):
		for sub in r.subRegions:
			var idx : int = _pocket_capacity.size()
			_pocket_capacity.append(maxi(1, sub.tiles.size() / maxi(1, cave_tiles_per_enemy)))
			for t in sub.tiles:
				_pocket_of[t.tilePos] = idx

# pocket index -> enemies currently standing in it
func _count_enemies_per_pocket() -> Dictionary:
	var counts : Dictionary = {}
	if not enemyNode:
		return counts
	for e in enemyNode.get_children():
		if not e is Node2D:
			continue
		var idx = _pocket_of.get(Worldgen.cell_at(e.global_position))
		if idx != null:
			counts[idx] = counts.get(idx, 0) + 1
	return counts

func _pocket_full(cell: Vector2i, counts: Dictionary) -> bool:
	var idx = _pocket_of.get(cell)
	if idx == null:
		return false # forest (or corridor): no cap
	return counts.get(idx, 0) >= _pocket_capacity[idx]

#endregion

#region Difficulty

# Level for an enemy spawning right now
func enemyLevel() -> int:
	var lvl : int = 1 + int(Global.totalDays * level_per_total_day + Global.runDays * level_per_run_day)
	if Global.isBloodMoon: lvl += blood_moon_bonus_levels
	lvl += randi_range(-level_variance, level_variance)
	return clampi(lvl, 1, stats.LEVEL_CAP)

# Call before add_child so the enemy starts at full (scaled) health
func applyLevel(e: Node) -> void:
	if e.has_method("setLevel"):
		e.setLevel(enemyLevel())
	if Global.isBloodMoon:
		e.set_meta("blood_moon", true)
	if e.has_method("makeElite") and randf() < eliteChance():
		e.makeElite(e.ELITE_AFFIXES.pick_random())

# Chance that an enemy spawning right now is an elite
func eliteChance() -> float:
	if Global.sceneIndex == 0 or Global.runDays < elite_first_run_day: return 0.0
	var c : float = minf(elite_chance + elite_chance_per_day * (Global.runDays - elite_first_run_day), elite_chance_max)
	if Global.isBloodMoon: c *= elite_blood_moon_mult
	return minf(c, 1.0)

# Blood moons spawn faster and allow more enemies at once
func currentSpawnTime() -> float:
	return spawnTime / blood_moon_spawn_rate_mult if Global.isBloodMoon else spawnTime

func currentMaxEnemies() -> int:
	return roundi(maxEnemies * blood_moon_max_enemies_mult) if Global.isBloodMoon else maxEnemies

# Loot modifiers for an enemy dying right now (blood moon kills drop better loot)
func lootMods() -> Dictionary:
	if not Global.isBloodMoon:
		return {"money": 1.0, "loot_chance": 1.0, "extra": 0, "equip": 1.0, "rarity": 0.0}
	return {
		"money": blood_moon_money_mult,
		"loot_chance": blood_moon_loot_chance_mult,
		"extra": blood_moon_extra_loot,
		"equip": blood_moon_equip_drop_mult,
		"rarity": blood_moon_rarity_bonus,
	}

#endregion

func clearEnemies() -> void:
	if enemyNode: enemyNode.queue_free()

func _process(delta: float) -> void:
	if Global.sceneIndex != 0 and Global.currentScene and Global.player:
		enemyNode = Global.currentScene.get_node_or_null("Enemies")
		
		if enemyNode:
			if enemyNode.z_index != 3: enemyNode.z_index = 3
			enemyCount = enemyNode.get_child_count()
			updateSlots = max(10, ceili(max(1, enemyCount) / (float(targetFPS) / 100)))
			if oldDay == Global.runDays:
				if enemyCount < currentMaxEnemies():
					time += delta
					
					if time >= currentSpawnTime():
						time = 0.0
						
						var spawn : Dictionary = findSpawn()
						if not spawn.is_empty(): # no valid spot this tick, try again next time
							var newEnemy : Node2D = spawn.scene.instantiate()
							newEnemy.name = "Enemy_%d" % spawned_total
							newEnemy.position = enemyNode.to_local(spawn.pos)
							applyLevel(newEnemy) # before add_child so health starts full at the scaled max
							enemyNode.add_child(newEnemy)
							spawned_total += 1
				else:
					time = 0.0
			else:
				oldDay = Global.runDays
				enemyList.getValid()
		else:
			var newNode : Node2D = Node2D.new()
			newNode.y_sort_enabled = true
			newNode.z_index = 3 # same layer as the player so they y-sort together (and stand above the grass)
			newNode.name = "Enemies"
			Global.currentScene.add_child(newNode)

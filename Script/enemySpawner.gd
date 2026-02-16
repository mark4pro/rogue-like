extends Node

@export var enemies : Array[EnemyWeighted] = []

@export var targetFPS : int = 60
@export var updateSlots : int = 10
@export var maxEnemies : int = 20
@export var enemyCount : int = 0
@export var spawnTime : float = 0.5

var time = 0
var oldDay = -1
var validEnemies : Array[EnemyWeighted] = []

func _ready() -> void:
	enemies.append(preload("res://Assets/enemies/spider_1.tres"))

func getCameraRect() -> Rect2:
	var camera : Camera2D = Global.player.camera
	var viewport_size = camera.get_viewport_rect().size
	var half_size = (viewport_size * 0.5) / camera.zoom
	return Rect2(camera.global_position - half_size, half_size * 2.0)

func isWalkable(pos: Vector2) -> bool:
	var walls : TileMapLayer = get_tree().current_scene.get_node("World/Walls")
	var ground : TileMapLayer = get_tree().current_scene.get_node("World/Ground")
	var cell = walls.local_to_map(walls.to_local(pos))
	var wallTileData = walls.get_cell_tile_data(cell)
	var groundTileData = ground.get_cell_tile_data(cell)
	if groundTileData == null:
		return false
	if wallTileData == null:
		return true
	return not wallTileData.get_collision_polygons_count(0) > 0

func getSpawn(center: Vector2, radius: float, chkCamera: bool = false, inFrontOfPlayer: bool = false, maxAtt: int = 50) -> Vector2:
	var cam_rect = getCameraRect()
	
	var playerDir : Vector2 = Vector2.ZERO
	if inFrontOfPlayer and Global.player:
		playerDir = Global.player.dir
	
	for i in maxAtt:
		var angle = 0
		var dist = randf_range(960, 960 + radius)
		var pos : Vector2 = Vector2.ZERO
		
		if inFrontOfPlayer and Global.player and playerDir != Vector2.ZERO:
			var halfPI : float = PI / 2
			angle = randf_range(-halfPI, halfPI)  # ±90 degrees around player_dir
			pos = center + playerDir.rotated(angle) * dist
		else:
			angle = randf() * TAU
			pos = center + Vector2.RIGHT.rotated(angle) * dist
		
		if cam_rect.has_point(pos) and chkCamera:
			continue
		if not isWalkable(pos):
			continue
		
		return pos
	return Vector2.ZERO

func _process(delta: float) -> void:
	var currentScene : Node2D = get_tree().current_scene
	if not Global.sceneIndex == 0 and currentScene and Global.player:
		var enemyNodeChk : Node2D = currentScene.get_node_or_null("Enemies")
		
		if enemyNodeChk:
			enemyCount = enemyNodeChk.get_child_count()
			updateSlots = max(10, ceili(max(1, enemyCount) / (float(targetFPS) / 100)))
			if oldDay == Global.runDays:
				if enemyCount < maxEnemies:
					time += delta
					
					if time >= spawnTime:
						time = 0
						
						var enemy : PackedScene = Global.getRandom(validEnemies)
						
						if enemy:
							var newEnemy = enemy.instantiate()
							newEnemy.name = "Enemy_" + str(enemyCount + 1)
							newEnemy.position = getSpawn(Global.player.position, 0, true, true)
							
							enemyNodeChk.add_child(newEnemy)
				else:
					time = 0
			else:
				oldDay = Global.runDays
				
				validEnemies = []
				
				for entry in enemies:
					if Global.runDays <= entry.day:
						validEnemies.append(entry)
		else:
			var newNode : Node2D = Node2D.new()
			newNode.y_sort_enabled = true
			newNode.name = "Enemies"
			currentScene.add_child(newNode)

extends Node2D

@export var enemy_scene = [preload("res://Assets/prefabs/enemy.tscn")]
@export var max_enemies : int = 10
var current_enemies : int = 0

func _on_timer_timeout():
	if current_enemies < max_enemies and Global.sceneIndex > 0:
		var enemy = enemy_scene.pick_random().instantiate()
	
		var spawn_x = randf_range(0, get_viewport_rect().size.x)
		var spawn_y = -50
		
		enemy.position = Vector2(spawn_x, spawn_y)
		current_enemies += 1
		add_child(enemy)

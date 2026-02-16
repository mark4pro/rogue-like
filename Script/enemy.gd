extends RigidBody2D

@onready var nav : NavigationAgent2D = $NavigationAgent2D

@export var maxHealth : float = 100
@export var health : float = 100
@export var damage : float = 0.5
@export var speed : float = 7
@export var stopDist : float = 65

var id : int
var target : Vector2 = Vector2.ZERO
var pathing : bool = false

var dir : Vector2 = Vector2.ZERO

func take_damage(amount: float):
	if not get_tree().paused:
		health -= amount

func _ready() -> void:
	nav.target_desired_distance = stopDist
	id = randi() % EnemySpawner.updateSlots

func _process(delta: float) -> void:
	if Global.player:
		if linear_velocity.x < 0:
			$sprite2D.flip_h = true
			$CollisionShape2D.position.x = -1
			$Shadow.position.x = 4
		if linear_velocity.x > 0:
			$sprite2D.flip_h = false
			$CollisionShape2D.position.x = 1
			$Shadow.position.x = -4
		
		if Engine.get_physics_frames() % EnemySpawner.updateSlots == id:
			nav.target_position = Global.player.position
			nav.set_velocity(Vector2.ZERO)
		
		pathing = not nav.is_navigation_finished()
		
		if pathing:
			target = nav.get_next_path_position()
			dir = (target - position).normalized()
			
			nav.set_velocity(dir * speed * 1000 * delta)
		else:
			nav.set_velocity(Vector2.ZERO)

func _on_navigation_agent_2d_velocity_computed(safe_velocity: Vector2) -> void:
	linear_velocity = safe_velocity

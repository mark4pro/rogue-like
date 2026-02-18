extends RigidBody2D

@onready var nav : NavigationAgent2D = $NavigationAgent2D
@onready var cone : Node2D = $sprite2D/Cone

@export_category("Base Stats")
@export var maxHealth : float = 100
@export var health : float = 100
@export var damage : float = 0.5
@export_category("Movement")
@export var speed : float = 7
@export var stopDist : float = 65
@export var wonderUpdate : float = 2
@export_category("Vision")
@export var visionRange : float = 100
@export var visionAngle : float = 90
@export var timeUntilChase : float = 1
@export var timeUntilChaseEnd : float = 3

enum state {
	WONDER,
	CHASE
}

var currentState : state = state.WONDER

var normVisionDebugColor : Color = Color(0.64, 0.0, 0.0, 0.118)
var inVisionDebugColor : Color = Color(0.149, 0.64, 0.0, 0.118)
var chaseVisionDebugColor : Color = Color(0.64, 0.619, 0.0, 0.118)
var outVisionDebugColor : Color = Color(0.0, 0.576, 0.64, 0.118)

var id : int
var target : Vector2 = Vector2.ZERO
var pathing : bool = false
var retarget : bool = true
var gotoLastKnownPos : bool = false

var eyeDir : Vector2 = Vector2.ZERO
var eyePos : Vector2 = Vector2.ZERO

var wonderTime : float = 0
var inSiteTime : float = 0
var endChaseTime : float = 0

var dir : Vector2 = Vector2.ZERO

func take_damage(data: Dictionary):
	if not get_tree().paused:
		health -= data.value
		
		var label = Global.damNum.instantiate()
		label.text = str(roundi(data.value))
		
		var radius = randf_range(20, 15)
		var angle = randf_range(0, 5 * PI)
	
		var spawn_pos = Vector2(
		cos(angle) * radius,
		sin(angle) * radius
		)
		
		label.position = global_position + spawn_pos
		get_tree().current_scene.add_child(label)

func canSeePlayer() -> bool:
	if not Global.player: return false
	
	if eyeDir == Vector2.ZERO: return false
	
	var dirToPlayer = Global.player.position - eyePos
	
	if dirToPlayer.length() > visionRange: return false
	
	var angleToPlayer = rad_to_deg(eyeDir.angle_to(dirToPlayer))
	
	if abs(angleToPlayer) > visionAngle / 2: return false
	
	var space : PhysicsDirectSpaceState2D = get_world_2d().direct_space_state
	var query : PhysicsRayQueryParameters2D = PhysicsRayQueryParameters2D.create(eyePos, Global.player.position)
	query.exclude = [self]
	
	var result = space.intersect_ray(query)
	
	if result and result.collider != Global.player: return false
	return true

func _ready() -> void:
	nav.target_desired_distance = stopDist
	id = randi() % EnemySpawner.updateSlots

func _process(delta: float) -> void:
	eyePos = $Marker2D.global_position
	eyeDir = (target - eyePos).normalized()
	
	health = clamp(health, 0, maxHealth)
	$UI/healthBar.value = (health / maxHealth) * 100
	
	if health <= 0: queue_free()
	
	cone.pos = eyePos
	cone.dir = eyeDir
	cone.vAngle = visionAngle
	cone.vRange = visionRange
	
	if not Global.player:
		currentState = state.WONDER
	
	if Global.player and position.distance_to(Global.player.position) > 1000:
		queue_free()
	
	if linear_velocity.x < 0:
		$sprite2D.flip_h = true
		$CollisionShape2D.position.x = -1
		$Shadow.position.x = 4
		$Marker2D.position.x = -13
	if linear_velocity.x > 0:
		$sprite2D.flip_h = false
		$CollisionShape2D.position.x = 1
		$Shadow.position.x = -4
		$Marker2D.position.x = 13
	
	if Global.debugVision: cone.queue_redraw()
	
	match currentState:
		state.WONDER:
			endChaseTime = 0
			
			wonderTime += delta
			retarget = wonderTime >= wonderUpdate
			
			if canSeePlayer():
				inSiteTime += delta
				
				if inSiteTime >= timeUntilChase:
					currentState = state.CHASE
				
				if not gotoLastKnownPos:
					gotoLastKnownPos = true
					nav.target_position = Global.player.position
					nav.set_velocity(Vector2.ZERO)
				
				cone.visionDebugColor = inVisionDebugColor
			else:
				inSiteTime = 0
				cone.visionDebugColor = normVisionDebugColor
				if gotoLastKnownPos and not pathing:
					gotoLastKnownPos = false
		state.CHASE:
			retarget = true
			wonderTime = 0
			inSiteTime = 0
			gotoLastKnownPos = false
			
			if not canSeePlayer():
				endChaseTime += delta
				
				if endChaseTime >= timeUntilChaseEnd:
					currentState = state.WONDER
				
				cone.visionDebugColor = outVisionDebugColor
			else:
				endChaseTime = 0
				cone.visionDebugColor = chaseVisionDebugColor
	
	if Engine.get_physics_frames() % EnemySpawner.updateSlots == id and retarget:
		match currentState:
			state.WONDER:
				wonderTime = 0
				if not gotoLastKnownPos:
					nav.target_position = EnemySpawner.getSpawn(position, 30)
			state.CHASE:
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

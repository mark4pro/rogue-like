extends BaseAI
class_name DefaultAI

enum state {
	WONDER,
	CHASE
}

var id : int
var weapSys : WeaponSys = null
@export var currentState : state = state.WONDER
var gotoLastKnownPos : bool = false
var wonderTime : float = 0
var inSiteTime : float = 0
var endChaseTime : float = 0
var dir : Vector2 = Vector2.ZERO

var foundTarget = null
var targetNode = null

func engage(attacker: Node = null) -> void:
	currentState = state.CHASE
	targetNode = attacker

func disengage(attacker: Node = null) -> void:
	if targetNode == attacker or not attacker: currentState = state.WONDER

func update(delta: float) -> void:
	#init values
	if id == 0:
		navAgent.target_desired_distance = stopDist
		id = randi() % EnemySpawner.updateSlots
	
	var canUpdate : bool = Engine.get_physics_frames() % EnemySpawner.updateSlots == id
	var pathing : bool = not navAgent.is_navigation_finished()
	eyeDir = (target - eyePos).normalized()
	visionCone()
	
	foundTarget = canSeeTarget()
	
	if currentState == state.WONDER:
		#Reset chase vars
		endChaseTime = 0
		
		wonderTime += delta
		var retarget : bool = wonderTime >= wonderUpdate
		
		if not gotoLastKnownPos and retarget and canUpdate: # and not pathing
			wonderTime = 0
			navAgent.target_position = EnemySpawner.getSpawn(body.global_position, 30)
			navAgent.set_velocity(Vector2.ZERO)
		
		if not foundTarget:
			inSiteTime = 0
			if cone: cone.visionDebugColor = Global.normVisionDebugColor
			if gotoLastKnownPos and not pathing:
				gotoLastKnownPos = false
		else:
			inSiteTime += delta
			
			if inSiteTime >= timeUntilChase:
				currentState = state.CHASE
				targetNode = foundTarget
			
			if not gotoLastKnownPos and canUpdate:
				wonderTime = 0
				gotoLastKnownPos = true
				
				navAgent.target_position = foundTarget.global_position
				navAgent.set_velocity(Vector2.ZERO)
				
				if cone: cone.visionDebugColor = Global.inVisionDebugColor
	
	if currentState == state.CHASE:
		#Reset wonder vars
		wonderTime = 0
		inSiteTime = 0
		gotoLastKnownPos = false
		
		if canUpdate and targetNode: navAgent.target_position = targetNode.global_position
		
		if not foundTarget:
			endChaseTime += delta
			
			if endChaseTime >= timeUntilChaseEnd:
				currentState = state.WONDER
				targetNode = null
			
			if cone: cone.visionDebugColor = Global.outVisionDebugColor
		else:
			endChaseTime = 0
			
			if not foundTarget == targetNode:
				targetNode = foundTarget
				
			if cone: cone.visionDebugColor = Global.chaseVisionDebugColor
	
	if pathing:
		target = navAgent.get_next_path_position()
		dir = (target - body.global_position).normalized()
		
		navAgent.set_velocity(dir * speed * 1000 * delta)
	else:
		navAgent.set_velocity(Vector2.ZERO)
		#Weapon system attack
		if currentState == state.CHASE and targetNode and \
		body.global_position.distance_to(targetNode.global_position) <= stopDist and \
		not body.get_tree().paused and weapSys and not weapSys.isAttacking:
				weapSys.attack()

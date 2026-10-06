extends BaseAI
class_name DefaultAI

enum state {
	WONDER,
	CHASE
}

var id : int
var initialized : bool = false
var weapSys : WeaponSys = null
@export var currentState : state = state.WONDER
var gotoLastKnownPos : bool = false
@export var investigateDist : float = 8 # how close to get to the last known position (stopDist is too far, the agent counted as arrived almost instantly)
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
	if not initialized:
		navAgent.target_desired_distance = stopDist
		id = randi() % EnemySpawner.updateSlots
		initialized = true
	
	var canUpdate : bool = Engine.get_physics_frames() % EnemySpawner.updateSlots == id % EnemySpawner.updateSlots
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
			navAgent.target_desired_distance = stopDist
			navAgent.target_position = EnemySpawner.getWanderPoint(body.global_position)
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
			
			# Keep refreshing while the target is in view, so losing sight sends it to where
			# the target was LAST seen, not where it was first spotted
			if canUpdate:
				wonderTime = 0
				gotoLastKnownPos = true
				
				navAgent.target_desired_distance = investigateDist
				navAgent.target_position = foundTarget.global_position
				navAgent.set_velocity(Vector2.ZERO)
				
				if cone: cone.visionDebugColor = Global.inVisionDebugColor
	
	if currentState == state.CHASE:
		#Reset wonder vars
		wonderTime = 0
		inSiteTime = 0
		gotoLastKnownPos = false
		
		# Chasing stops at attack range again
		if navAgent.target_desired_distance != stopDist: navAgent.target_desired_distance = stopDist
		
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
		not body.get_tree().paused and weapSys and not weapSys.isAttacking and weapSys.canAfford() and \
		not ("hitstun" in body and body.hitstun > 0):
				weapSys.attack() # out of stamina/mana the enemy holds off until its pool recovers

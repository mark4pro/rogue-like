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
## Wandering: walk to a point, then idle wonderUpdate to wonderUpdate x this seconds before the next.
## The pause is random per stop (wonderUpdate 2 -> 2 to 5 s), so a group doesn't move in sync.
@export var wanderPauseMax : float = 2.5
## Give up on a wander point that's taking this long (blocked, stuck on something)
@export var wanderGiveUp : float = 12.0
## How close counts as reached for a wander point (stopDist is the attack range, far too loose)
@export var wanderArriveDist : float = 12.0
var _wanderIdle : float = 0.0
var _wanderWait : float = -1.0
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
		if _wanderWait < 0.0: _wanderWait = randf_range(0.0, wonderUpdate * wanderPauseMax) # first stop: staggered
		# Walking: keep going to the point (only give up if it takes far too long).
		# Arrived: stand around for a bit, then pick the next point.
		if pathing: _wanderIdle = 0.0
		else: _wanderIdle += delta
		var retarget : bool = (not pathing and _wanderIdle >= _wanderWait) or (pathing and wonderTime >= wanderGiveUp)
		
		if not gotoLastKnownPos and retarget and canUpdate:
			wonderTime = 0
			_wanderIdle = 0.0
			_wanderWait = randf_range(wonderUpdate, wonderUpdate * wanderPauseMax)
			navAgent.target_desired_distance = wanderArriveDist
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
		
		# Was `speed * 1000 * delta`: a velocity scaled by the frame time, so enemies walked slower
		# the higher the frame rate (2.4x slower at 144 fps). Same speed as before at 60 fps.
		navAgent.set_velocity(dir * speed * 1000.0 / 60.0)
	else:
		navAgent.set_velocity(Vector2.ZERO)
		#Weapon system attack
		if currentState == state.CHASE and targetNode and \
		body.global_position.distance_to(targetNode.global_position) <= stopDist and \
		not body.get_tree().paused and weapSys and not weapSys.isAttacking and weapSys.canAfford() and \
		not ("hitstun" in body and body.hitstun > 0) and _clearShot():
				weapSys.attack() # out of stamina/mana the enemy holds off until its pool recovers

# Projectile / laser enemies used to fire into walls when the player was in range on the other side
# (wasting mana and giving the player a free show). Melee swings don't need it.
func _clearShot() -> bool:
	if not weapSys.weapon or weapSys.weapon.animationType == WeaponItem.animType.SWING: return true
	if not (targetNode is Node2D): return true
	var q : PhysicsRayQueryParameters2D = PhysicsRayQueryParameters2D.create(body.global_position, targetNode.global_position, 1)
	q.exclude = [body.get_rid()]
	return body.get_world_2d().direct_space_state.intersect_ray(q).is_empty()

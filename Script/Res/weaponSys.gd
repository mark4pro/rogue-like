extends Resource
class_name WeaponSys

@export var parentNode = null
@export var weapon : WeaponItem = null
@export var posOffset : Vector2 = Vector2.ZERO
@export var rotOffset : float = 0
@export var spawnPos : Array = []

@export var time : float = 0
@export var isAttacking : bool = false

var oldWeapon : WeaponItem = null

var t : float = 0
var attackDir : int = 1
var flip : bool = false

var spawned : Array[Node] = []
var excludeList : Array[RID] = []

var amount : int = 0

var lastTime : float = 0
var firingActive : bool = false
var perT : float = 0

var flipSword : bool = false
var swingAim : float = 0.0 # swing direction, held while a swing is underway
const SWING_AIM_FOLLOW : float = 14.0 # how quickly the resting weapon turns to follow the mouse
var _swingWasAttacking : bool = false
const SWING_AIM_BLEND : float = 0.3 # share of a swing spent turning to the new direction
var _aimFrom : float = 0.0
var _aimTo : float = 0.0
var _swingStartT : float = 0.0

# Scales damage dealt through this weapon system (EnemySpawner sets it from difficulty; the player stays at 1)
var damageMult : float = 1.0
# Scales swing speed and ranged fire rate (the player sets it from playerStats.attack_speed)
var attackSpeedMult : float = 1.0

# The wielder's stats (the player sets it; enemies leave it null): attribute scaling, crit
# bonuses, pool cost reductions, laser range and tick rate
var wielderStats : stats = null

# Only the player earns and uses weapon proficiency (enemies share the stats code but not this)
var trackProficiency : bool = false

func profType() -> String:
	return stats.profType(weapon)

func profStats() -> stats:
	return wielderStats if trackProficiency else null

# Proficiency EXP per hit: 1 for a sword swing or a single shot; multi-shot weapons split it so a
# full volley is worth about two hits; beams tick often so each tick is worth less
func profHitXp() -> float:
	match weapon.animationType:
		WeaponItem.animType.AIM_LASER: return 0.3
		WeaponItem.animType.RANGE: return 2.0 / (1.0 + weapon.rangeSpawnAmount)
	return 1.0

# Use this instead of weapon.genDamage() so per-wielder multipliers apply.
# Called once per hit on a target, so it's also where proficiency is earned.
func genDamage() -> Dictionary:
	var data : Dictionary = weapon.genDamage(wielderStats)
	data.value *= damageMult
	var ps : stats = profStats()
	if ps:
		var t : String = profType()
		data.value *= ps.profDamageMult(t)
		var newLevel : int = ps.addProficiency(t, profHitXp())
		if newLevel > 0:
			Global.sendMessage("%s proficiency %d!" % [stats.PROFICIENCY_NAMES.get(t, t), newLevel], 3.0, Color(0.55, 0.8, 1.0))
	
	# A weakened wielder (Shadow) hits softer
	if parentNode and is_instance_valid(parentNode) and "statusFx" in parentNode and parentNode.statusFx:
		data.value *= parentNode.statusFx.damageDealtMult()
	
	# Split into physical + elemental parts (resolved against the target's resistances in
	# StatusEffects.resolveHit). Magic makes the elemental part hit harder.
	var els : Dictionary = weapon.getElements()
	var share : float = 0.0
	for e in els: share += float(els[e])
	share = clampf(share, 0.0, 1.0)
	var potency : float = wielderStats.elementalPotency() if wielderStats else 1.0
	data.kind = weapon.damageKind()
	data.physical = data.value * (1.0 - share)
	data.elements = {}
	for e in els: data.elements[e] = data.value * float(els[e]) / maxf(share, 1.0) * potency
	data.attackerStats = wielderStats
	return data

# Speed bonus from proficiency for the current weapon type (1.0 for enemies)
func profSpeed() -> float:
	var ps : stats = profStats()
	return ps.profSpeedMult(profType()) if ps and weapon else 1.0

# Pool cost after the wielder's reductions (Stamina for melee/thrown, Magic for projectiles, Focus for beams)
func poolCost() -> float:
	if not weapon: return 0.0
	var cost : float = weapon.getPoolCost()
	var ps : stats = profStats()
	if ps: cost *= ps.profCostMult(profType())
	if not wielderStats: return cost
	if weapon.getPool() == WeaponItem.poolType.STAMINA: return cost * wielderStats.meleeStaminaCostMult()
	if weapon.animationType == WeaponItem.animType.AIM_LASER: return cost * wielderStats.beamManaCostMult()
	return cost * wielderStats.projectileManaCostMult()

func laserRange() -> float:
	return weapon.laserRange * (wielderStats.laserRangeMult() if wielderStats else 1.0)

func laserTickSpeed() -> float:
	return weapon.laserAttackSpeed * (wielderStats.laserTickMult() if wielderStats else 1.0)

func ellipseArc(center: Vector2, radius: Vector2, angleRange: Vector2, steps: int) -> PackedVector2Array:
	var points : PackedVector2Array = []
	
	for i in range(steps + 1):
		var t_e : float = float(i) / float(steps)
		var angle : float = lerp(deg_to_rad(angleRange.y), deg_to_rad(angleRange.x), t_e)
		
		var point : Vector2 = Vector2(cos(angle) * radius.x, sin(angle) * radius.y)
		
		var pos : Vector2 = center + point
		points.append(pos)
	
	return points

func raycastTo(start: Vector2, dir: Vector2, dist: float, r: float) -> Dictionary:
	var space : PhysicsDirectSpaceState2D = parentNode.get_world_2d().direct_space_state
	
	var trueDist : float = min(dist, r)
	var to : Vector2 = start + dir * trueDist
	
	var query : PhysicsRayQueryParameters2D = PhysicsRayQueryParameters2D.create(start, to)
	query.exclude = excludeList
	query.collide_with_areas = true
	query.collide_with_bodies = true
	
	return space.intersect_ray(query)

# --- Pool costs -------------------------------------------------------------
# Melee and thrown weapons spend the wielder's stamina, projectiles and lasers spend mana.
# The wielder implements spendPool(pool, amount, force) -> bool, hasPool(pool, amount) -> bool
# and optionally poolFizzle(pool). Wielders without them (e.g. placed items) attack for free.

const EXHAUSTED_SWING_MULT : float = 0.5

var slowSwing : bool = false
var volleyPaid : bool = false

func hasPoolOwner() -> bool:
	return parentNode != null and is_instance_valid(parentNode) and parentNode.has_method("spendPool")

func payPool(amount: float, force: bool = false) -> bool:
	if not weapon or not hasPoolOwner() or amount <= 0: return true
	return parentNode.spendPool(weapon.getPool(), amount, force)

# Used by the AI so enemies wait for their pool to recover instead of spamming fizzles
func canAfford() -> bool:
	if not weapon or not hasPoolOwner() or not parentNode.has_method("hasPool"): return true
	var need : float = poolCost()
	if weapon.animationType == weapon.animType.AIM_LASER: need *= 0.25 # a quarter second of beam
	return parentNode.hasPool(weapon.getPool(), need)

func fizzle() -> void:
	if weapon and hasPoolOwner() and parentNode.has_method("poolFizzle"):
		parentNode.poolFizzle(weapon.getPool())

# Lasers and ranged weapons keep firing while the button is held. Only the player holds a button;
# enemies re-trigger attack() every frame they want to keep firing.
func holdingFire() -> bool:
	return parentNode == Global.player and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)

func attack() -> void:
	if not isAttacking and parentNode and weapon:
		if weapon.animationType == weapon.animType.SWING:
			# Melee always swings; short on stamina it drains what's left and swings slowly
			slowSwing = not payPool(poolCost(), true)
		isAttacking = true

func reset() -> void:
	isAttacking = false
	time = 0

func update(delta: float, target: Vector2) -> void:
	if parentNode:
		var weaponNode : Node2D = parentNode.get_node_or_null("Weapon")
		
		if not isAttacking: flip = target.x < parentNode.global_position.x
		
		if not weapon and (weaponNode or spawned.size() > 0):
			if weaponNode: weaponNode.queue_free()
			else:
				for i in spawned:
					if i: i.queue_free()
				spawned = []
			reset()
			oldWeapon = null
		
		if oldWeapon != weapon:
			for i in spawned: 
				if i: i.queue_free()
			spawned = []
			if weaponNode: weaponNode.queue_free()
			reset()
			oldWeapon = weapon
		
		if weapon:
			match weapon.animationType:
				weapon.animType.SWING:
					# Aim is locked for the whole swing, so moving the mouse mid-swing (very noticeable
					# with slow swings) doesn't drag the arc around. Between swings it follows the mouse.
					# After a swing it eases back onto the mouse instead of snapping (no jerk).
					# Each new swing aims at the mouse as it starts, so holding the attack button
					# (back-to-back swings, no gap to ease in) still re-aims every swing.
					# The turn to the new direction is blended over the first part of the swing
					# (SWING_AIM_BLEND of it), so the sword never teleports between swings.
					var wanted : float = (target - (parentNode.global_position + posOffset)).angle()
					if not isAttacking:
						swingAim = lerp_angle(swingAim, wanted, 1.0 - exp(-SWING_AIM_FOLLOW * delta))
					else:
						if not _swingWasAttacking:
							_aimFrom = swingAim
							_aimTo = wanted
							_swingStartT = t
						var s : float = clampf(absf(t - _swingStartT) / SWING_AIM_BLEND, 0.0, 1.0)
						swingAim = lerp_angle(_aimFrom, _aimTo, smoothstep(0.0, 1.0, s))
					_swingWasAttacking = isAttacking
					var rot : float = swingAim + rotOffset
					var angRange : Vector2 = Vector2.UP.rotated(rot) + weapon.swingAngleRange
					var points : PackedVector2Array = ellipseArc(parentNode.global_position, weapon.swingRadius, angRange, weapon.swingSteps)
					
					var index : int = int(t * (points.size() - 1))
					index = clampi(index, 0, points.size() - 1)
					
					var newPos : Vector2 = parentNode.to_local(points[index])
					var restRot : float = lerp(weapon.swingRestAngle, -(weapon.swingRestAngle - 180), t)
					
					if not weaponNode:
						var newWeapon : Node2D = weapon.weaponScene.instantiate()
						newWeapon.name = "Weapon"
						
						newWeapon.position = newPos.rotated(rot) + posOffset
						newWeapon.rotation_degrees = rad_to_deg(rot) + restRot
						newWeapon.z_as_relative = true
						newWeapon.z_index = weapon.swingZRange.x if t < 0.5 else weapon.swingZRange.y
						if "weapSys" in newWeapon: newWeapon.weapSys = self
						Mutation.applyTree(newWeapon, weapon)
						parentNode.add_child(newWeapon)
					else:
						if isAttacking:
							var step : float = delta / weapon.swingDuration
							var exhaustMult : float = EXHAUSTED_SWING_MULT if slowSwing else 1.0
							t += (step * attackDir) * weapon.swingSpeedMulti * exhaustMult * attackSpeedMult * profSpeed()
						
						# Flip without resetting the size (the torch scene is scaled to 0.4)
						if t > 0.5:
							weaponNode.scale.x = -absf(weaponNode.scale.x)
						if t < 0.5:
							weaponNode.scale.x = absf(weaponNode.scale.x)
						
						if t >= 1.0:
							t = 1.0
							weaponNode.reset()
							isAttacking = false
							_swingWasAttacking = false # the next swing re-aims, even straight after
							attackDir = -1
						elif t <= 0.0:
							t = 0.0
							weaponNode.reset()
							isAttacking = false
							_swingWasAttacking = false
							attackDir = 1
						
						weaponNode.position = newPos.rotated(rot) + posOffset
						weaponNode.rotation_degrees = rad_to_deg(rot) + restRot
						weaponNode.z_index = weapon.swingZRange.x if t < 0.5 else weapon.swingZRange.y
				weapon.animType.AIM_LASER:
					if not spawned.size() == spawnPos.size():
						# Ray queries exclude by RID, not by node
						excludeList.clear()
						if parentNode is CollisionObject2D: excludeList.append(parentNode.get_rid())
						for i in parentNode.get_tree().get_nodes_in_group("Exclude_From_Lasers"):
							if i is CollisionObject2D: excludeList.append(i.get_rid())
						
						for i in spawnPos:
							var newWeapon : Node2D = weapon.weaponScene.instantiate()
							newWeapon.name = "Weapon " + str(spawnPos.find(i))
							newWeapon.global_position = i.global_position
							newWeapon.z_as_relative = true
							newWeapon.z_index = i.z_index
							if "weapSys" in newWeapon: newWeapon.weapSys = self
							Mutation.applyTree(newWeapon, weapon)
							parentNode.add_child(newWeapon)
							spawned.append(newWeapon)
					else:
						for index in range(spawned.size()):
							var i : Node = spawned[index]
							
							i.global_position = spawnPos[index].global_position
							
							var _dir : Vector2 = target - spawnPos[index].global_position
							var dir : Vector2 = _dir.normalized()
							var dist : float = _dir.length()
							
							var ray : Dictionary = raycastTo(spawnPos[index].global_position, dir, dist, laserRange())
							
							var finalDist : float = laserRange()
							
							if ray:
								var hitDist : float = spawnPos[index].global_position.distance_to(ray.position)
								finalDist = min(hitDist, dist)
								
								var thisTarget : Node = ray.collider
								if ray.collider is Area2D: thisTarget = ray.collider.get_parent()
								
								#Call the damage function
								if thisTarget.has_method("take_damage") and i.has_method("damage") and t > 0:
									i.damage(thisTarget)
								
								# Sparks where the fully extended beam actually ends on something
								if t >= 0.95 and hitDist <= dist and i.has_method("spark"):
									i.spark(ray.position, ray.normal)
							else:
								finalDist = min(dist, laserRange())
							
							var thisPos : Vector2 = dir * finalDist
							
							i.set_point_position(1, t * thisPos)
						
						#checks if you are rolling
						var canAttack : bool = true
						if "roll_state" in parentNode and parentNode.roll_state != 0: canAttack = false
						
						# Beam drains mana every frame it's held; out of mana it retracts
						if isAttacking and canAttack and not payPool(poolCost() * delta):
							canAttack = false
							fizzle()
						
						if isAttacking and canAttack:
							t = min(t + (weapon.laserActivateSpeed * profSpeed() * delta), 1)
						else:
							var thisDeactivateSpeed : float = weapon.laserDeactivateSpeed
							
							#this line makes the laser retract faster so it's gone before you roll
							if not canAttack: thisDeactivateSpeed *= 2
							
							t = max(t - (thisDeactivateSpeed * delta), 0)
						if not holdingFire():
							isAttacking = false
				weapon.animType.RANGE:
					firingActive = t == 1
					
					# Pay for the whole volley as it starts (mana, or stamina for thrown weapons)
					if firingActive and amount == 0 and not volleyPaid:
						if payPool(poolCost()):
							volleyPaid = true
						else:
							fizzle()
							firingActive = false
							t = 0
					
					if firingActive:
						var avgPos : Vector2 = spawnPos.reduce(func(a, b): return a.global_position + b.global_position) / spawnPos.size()
						var dir : Vector2 = (target - avgPos).normalized()
						
						if weapon.rangePerSpawnDelay == 0:
							for i in range(weapon.rangeSpawnAmount):
								if weapon.quantity > 0:
									spawnBullet(i, avgPos, dir, delta)
								if weapon.throwable: weapon.quantity -= 1
							amount = weapon.rangeSpawnAmount
						else:
							if perT == 1 or amount == 0:
								if weapon.quantity > 0:
									spawnBullet(amount, avgPos, dir, delta)
									if weapon.throwable: weapon.quantity -= 1
								amount = min(amount + 1, weapon.rangeSpawnAmount)
								perT = 0
							perT = min(perT + (weapon.rangePerSpawnDelay * delta), 1)
						
						if amount == weapon.rangeSpawnAmount:
							amount = 0
							t = 0
							volleyPaid = false
					
					#checks if you are rolling
					var canAttack : bool = true
					if "roll_state" in parentNode and parentNode.roll_state != 0: canAttack = false
					
					if isAttacking and canAttack:
						t = min(t + (weapon.rangeFireSpeed * attackSpeedMult * profSpeed() * delta), 1)
						if lastTime == 1:
							t = 1
							lastTime = 0
					else:
						t = 0
						amount = 0
						perT = 0
						volleyPaid = false
						lastTime = min(lastTime + (weapon.rangeFireSpeed * attackSpeedMult * profSpeed() * delta), 1)
					
					if not holdingFire():
						isAttacking = false

func spawnBullet(index: int, pos: Vector2, dir: Vector2, delta: float) -> void:
	var newBullet : Node = weapon.weaponScene.instantiate()
	
	# angle offset for spread
	var angleOffset : float = 0
	if weapon.rangeSpawnAmount > 1:
		angleOffset = lerp(-weapon.rangeSpreadAngle * 0.5, weapon.rangeSpreadAngle * 0.5, float(index) / (weapon.rangeSpawnAmount - 1))
	
	newBullet.global_position = pos
	newBullet.rotation = dir.angle() + deg_to_rad(angleOffset)
	newBullet.z_as_relative = false
	newBullet.z_index = parentNode.z_index + weapon.rangeZOffset
	if "weapSys" in newBullet:
		newBullet.weapSys = self
	
	if newBullet is RigidBody2D:
		#newBullet.apply_impulse(dir.rotated(deg_to_rad(angleOffset)) * (1000 * weapon.rangeSpeed * delta))
		newBullet.linear_velocity = dir.rotated(deg_to_rad(angleOffset)) * (1000 * weapon.rangeSpeed * delta)
	
	Mutation.applyTree(newBullet, weapon)
	Global.currentScene.add_child(newBullet)

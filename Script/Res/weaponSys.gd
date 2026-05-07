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

func ellipseArc(center: Vector2, radius: Vector2, angleRange: Vector2, steps: int) -> Array[Vector2]:
	var points : Array[Vector2] = []
	
	for i in range(steps + 1):
		var t : float = float(i) / steps
		var angle : float = lerp(deg_to_rad(angleRange.y), deg_to_rad(angleRange.x), t)
		
		var point : Vector2 = Vector2(cos(angle) * radius.x, sin(angle) * radius.y)
		
		var pos : Vector2 = center + point
		points.append(pos)
	
	return points

func raycastTo(start: Vector2, dir: Vector2, dist: float, range: float) -> Dictionary:
	var space : PhysicsDirectSpaceState2D = parentNode.get_world_2d().direct_space_state
	
	var trueDist : float = min(dist, range)
	var to : Vector2 = start + dir * trueDist
	
	var query : PhysicsRayQueryParameters2D = PhysicsRayQueryParameters2D.create(start, to)
	query.exclude = excludeList
	query.collide_with_areas = true
	query.collide_with_bodies = true
	
	return space.intersect_ray(query)

func attack() -> void:
	if not isAttacking and parentNode and weapon:
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
					var rot : float = (target - (parentNode.global_position + posOffset)).angle() + rotOffset
					var angRange : Vector2 = Vector2.UP.rotated(rot) + weapon.swingAngleRange
					var points : Array[Vector2] = ellipseArc(parentNode.global_position, weapon.swingRadius, angRange, weapon.swingSteps)
					
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
						parentNode.add_child(newWeapon)
					else:
						if isAttacking:
							var step : float = delta / weapon.swingDuration
							t += (step * attackDir) * weapon.swingSpeedMulti
						
						if t > 0.5:
							weaponNode.scale.x = -1
						if t < 0.5:
							weaponNode.scale.x = 1
						
						if t >= 1.0:
							t = 1.0
							weaponNode.reset()
							isAttacking = false
							attackDir = -1
						elif t <= 0.0:
							t = 0.0
							weaponNode.reset()
							isAttacking = false
							attackDir = 1
						
						weaponNode.position = newPos.rotated(rot) + posOffset
						weaponNode.rotation_degrees = rad_to_deg(rot) + restRot
						weaponNode.z_index = weapon.swingZRange.x if t < 0.5 else weapon.swingZRange.y
				weapon.animType.AIM_LASER:
					if not spawned.size() == spawnPos.size():
						excludeList.append(parentNode)
						for i in parentNode.get_tree().get_nodes_in_group("Exclude_From_Lasers"):
							excludeList.append(i)
						
						for i in spawnPos:
							var newWeapon : Node2D = weapon.weaponScene.instantiate()
							newWeapon.name = "Weapon " + str(spawnPos.find(i))
							newWeapon.global_position = i.global_position
							newWeapon.z_as_relative = true
							newWeapon.z_index = i.z_index
							if "weapSys" in newWeapon: newWeapon.weapSys = self
							parentNode.add_child(newWeapon)
							spawned.append(newWeapon)
					else:
						for index in range(spawned.size()):
							var i = spawned[index]
							
							i.global_position = spawnPos[index].global_position
							
							var _dir : Vector2 = target - spawnPos[index].global_position
							var dir : Vector2 = _dir.normalized()
							var dist : float = _dir.length()
							
							var ray : Dictionary = raycastTo(spawnPos[index].global_position, dir, dist, weapon.laserRange)
							
							var finalDist : float = weapon.laserRange
							
							if ray:
								var hitDist : float = spawnPos[index].global_position.distance_to(ray.position)
								finalDist = min(hitDist, dist)
								
								var thisTarget : Node = ray.collider
								if ray.collider is Area2D: thisTarget = ray.collider.get_parent()
								
								#Call the damage function
								if thisTarget.has_method("take_damage") and i.has_method("damage") and t > 0:
									i.damage(thisTarget)
							else:
								finalDist = min(dist, weapon.laserRange)
							
							var thisPos : Vector2 = dir * finalDist
							
							i.points[1] = t * thisPos
						
						#checks if you are rolling
						var canAttack : bool = true
						if "roll_state" in parentNode and parentNode.roll_state != 0: canAttack = false
						
						if isAttacking and canAttack:
							t = min(t + (weapon.laserActivateSpeed * delta), 1)
						else:
							var thisDeactivateSpeed : float = weapon.laserDeactivateSpeed
							
							#this line makes the laser retract faster so it's gone before you roll
							if not canAttack: thisDeactivateSpeed *= 2
							
							t = max(t - (thisDeactivateSpeed * delta), 0)
						if not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
							isAttacking = false
				weapon.animType.RANGE:
					firingActive = t == 1
					
					if firingActive:
						var avgPos = spawnPos.reduce(func(a, b): return a.global_position + b.global_position) / spawnPos.size()
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
					
					#checks if you are rolling
					var canAttack : bool = true
					if "roll_state" in parentNode and parentNode.roll_state != 0: canAttack = false
					
					if isAttacking and canAttack:
						t = min(t + (weapon.rangeFireSpeed * delta), 1)
						if lastTime == 1:
							t = 1
							lastTime = 0
					else:
						t = 0
						amount = 0
						perT = 0
						lastTime = min(lastTime + (weapon.rangeFireSpeed * delta), 1)
					
					if not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
						isAttacking = false

func spawnBullet(index: int, pos: Vector2, dir: Vector2, delta: float) -> void:
	var newBullet = weapon.weaponScene.instantiate()
	
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
	
	Global.currentScene.add_child(newBullet)

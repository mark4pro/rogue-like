extends Resource
class_name WeaponSys

@export var parentNode = null
@export var weapon : WeaponItem = null
@export var posOffset : Vector2 = Vector2.ZERO
@export var rotOffset : float = 0
@export var spawnPos : Array[Vector2] = []

@export var time : float = 0
@export var isAttacking : bool = false

var oldWeapon : WeaponItem = null

var t : float = 0
var attackDir : int = 1
var flip : bool = false
var lockedFlip : bool = false

var spawned : Array[Node] = []

func ellipseArc(center: Vector2, radius: Vector2, angleRange: Vector2, steps: int) -> Array[Vector2]:
	var points : Array[Vector2] = []
	
	for i in range(steps + 1):
		var t : float = float(i) / steps
		var angle : float = lerp(deg_to_rad(angleRange.y), deg_to_rad(angleRange.x), t)
		
		var point : Vector2 = Vector2(cos(angle) * radius.x, sin(angle) * radius.y)
		
		var pos : Vector2 = center + point
		points.append(pos)
	
	return points

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
					var angRange : Vector2 = Vector2.UP.rotated(rot) + weapon.angleRange
					var points : Array[Vector2] = ellipseArc(parentNode.global_position, weapon.radius, angRange, weapon.steps)
					
					if not weaponNode:
						var newWeapon : Node2D = weapon.weaponScene.instantiate()
						newWeapon.name = "Weapon"
						
						var newPos : Vector2 = parentNode.to_local(points[-1])
						newWeapon.position = newPos
						
						newWeapon.rotation_degrees = weapon.restAngle
						newWeapon.z_as_relative = true
						newWeapon.z_index = weapon.zRange.x
						if "weapSys" in newWeapon: newWeapon.weapSys = self
						parentNode.add_child(newWeapon)
					else:
						if isAttacking:
							var step : float = delta / weapon.duration
							t += (step * attackDir) * weapon.speedMulti
						
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
						
						var index : int = int(t * (points.size() - 1))
						index = clampi(index, 0, points.size() - 1)
						
						var newPos : Vector2 = parentNode.to_local(points[index])
						weaponNode.position = newPos.rotated(rot) + posOffset
						
						var restRot : float = lerp(weapon.restAngle, -(weapon.restAngle - 180), t)
						weaponNode.rotation_degrees = rad_to_deg(rot) + restRot
						
						weaponNode.z_index = weapon.zRange.x if t < 0.5 else weapon.zRange.y
				weapon.animType.AIM_LASER:
					if not spawned.size() == spawnPos.size():
						for i in spawnPos:
							var newWeapon : Node2D = weapon.weaponScene.instantiate()
							newWeapon.name = "Weapon " + str(spawnPos.find(i))
							newWeapon.global_position = i
							#newWeapon.z_as_relative = true
							#newWeapon.z_index = weapon.zRange.x
							if "weapSys" in newWeapon: newWeapon.weapSys = self
							parentNode.add_child(newWeapon)
							spawned.append(newWeapon)
					else:
						for i in spawned:
							var index : int = spawned.find(i)
							
							i.global_position = spawnPos[index]
							
							var _dir : Vector2 = target - spawnPos[index]
							var dir : Vector2 = _dir.normalized()
							var dist : float = _dir.length()
							
							var clampedDist : float = min(dist, weapon.range)
							var thisPos : Vector2 = dir * clampedDist
							
							i.points[1] = t * thisPos
						
						#checks if you are rolling
						var canAttack : bool = true
						if "roll_state" in parentNode and parentNode.roll_state != 0: canAttack = false
						
						if isAttacking and canAttack:
							t = min(t + (weapon.activateSpeed * delta), 1)
						else:
							var thisDeactivateSpeed : float = weapon.deactivateSpeed
							
							#this line makes the laser retract faster so it's gone before you roll
							if not canAttack: thisDeactivateSpeed *= 2
							
							t = max(t - (thisDeactivateSpeed * delta), 0)
						if not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
							isAttacking = false

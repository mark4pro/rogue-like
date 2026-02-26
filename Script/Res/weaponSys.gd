extends Resource
class_name WeaponSys

@export var parentNode = null
@export var weapon : WeaponItem = null

@export var time : float = 0
@export var isAttacking : bool = false

var oldWeapon : WeaponItem = null

var thisScale : float = 1

var t : float = 0
var attackDir : int = 1
var flip : bool = false
var lockedFlip : bool = false

func ellipseArc(center: Vector2, radius: Vector2, angleRange: Vector2, steps: int) -> Array[Vector2]:
	var points : Array[Vector2] = []
	
	for i in range(steps + 1):
		var t : float = float(i) / steps
		var angle : float = lerp(deg_to_rad(angleRange.y), deg_to_rad(angleRange.x), t)
		
		var point : Vector2 = Vector2(cos(angle) * radius.x, sin(angle) * radius.y)
		
		var pos : Vector2 = center + point#.rotated(rot)
		points.append(pos)
	
	return points

func attack() -> void:
	if not isAttacking and parentNode and weapon:
		isAttacking = true

func reset() -> void:
	isAttacking = false
	time = 0

func update(delta: float, target: Vector2) -> void:
	if parentNode and weapon:
		var weaponNode : Node2D = parentNode.get_node_or_null("Weapon")
		
		if not isAttacking: flip = target.x < parentNode.global_position.x
		
		var rot : float = (target - parentNode.global_position).angle()
		
		var angRange : Vector2 = weapon.angleRange
		if flip: angRange = Vector2(weapon.angleRange.y, weapon.angleRange.x)
		
		var points : Array[Vector2] = ellipseArc(parentNode.position, weapon.radius, angRange, weapon.steps)
		
		if not weapon and weaponNode:
			weaponNode.queue_free()
			reset()
			oldWeapon = null
		
		if oldWeapon != weapon:
			if weaponNode: weaponNode.queue_free()
			reset()
			oldWeapon = weapon
		
		if not weaponNode:
			var newWeapon : Node2D = weapon.weaponScene.instantiate()
			newWeapon.name = "Weapon"
			
			var newPos : Vector2 = parentNode.to_local(points[-1])
			if flip: newPos.x *= -1
			
			newWeapon.position = newPos
			newWeapon.rotation_degrees = weapon.restAngle
			newWeapon.z_as_relative = true
			newWeapon.z_index = weapon.zRange.x
			if "weapSys" in newWeapon: newWeapon.weapSys = self
			thisScale = newWeapon.scale.x
			parentNode.add_child(newWeapon)
		else:
			if flip:
				weaponNode.scale.x = -thisScale
			else:
				weaponNode.scale.x = thisScale
			
			if isAttacking:
				var step : float = delta / weapon.duration
				t += step * attackDir
			
			if t >= 1.0:
				t = 1.0
				isAttacking = false
				attackDir = -1
			elif t <= 0.0:
				t = 0.0
				isAttacking = false
				attackDir = 1
			
			var index : int = int(t * (points.size() - 1))
			index = clampi(index, 0, points.size() - 1)
			
			var newPos : Vector2 = parentNode.to_local(points[index])
			#if flip: newPos.y *= -1
			
			weaponNode.position = newPos.rotated(rot)
			
			var restRot : float = lerp(weapon.restAngle, -(weapon.restAngle - 180), t)
			if flip: restRot = -restRot
			
			weaponNode.rotation_degrees = rot + restRot
			
			if t < 0.5:
				weaponNode.z_index = weapon.zRange.x
			else:
				weaponNode.z_index = weapon.zRange.y

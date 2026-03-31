extends RigidBody2D

@export_category("This Object")
@export var area : Area2D = null
@export var hitEffect : PackedScene = null
@export var maxRange : float = 100
@export var rotSpeed : float = 10
@export var canDamage : bool = false

@export_category("Data")
@export var weapSys : WeaponSys = null

var dir : Vector2 = Vector2.ZERO
var excludeList : Array[RID] = []

var startPos : Vector2 = Vector2.ZERO
var mousePos : Vector2 = Vector2.ZERO
var initialVelocity : Vector2 = Vector2.ZERO
var maxDist : float = 0

func _ready() -> void:
	startPos = global_position
	mousePos = get_global_mouse_position()
	initialVelocity = linear_velocity
	
	if weapSys and weapSys.parentNode:
		set_collision_layer_value(1, false)
		set_collision_mask_value(1, true)
		area.set_collision_layer_value(1, false)
		area.set_collision_mask_value(1, true)
		
		if weapSys.parentNode.is_in_group("Player"):
			set_collision_layer_value(4, true)
			set_collision_mask_value(3, true)
			area.set_collision_layer_value(4, true)
			area.set_collision_mask_value(3, true)
		else:
			set_collision_layer_value(5, true)
			set_collision_mask_value(2, true)
			area.set_collision_layer_value(5, true)
			area.set_collision_mask_value(2, true)
	
	contact_monitor = true
	max_contacts_reported = 10
	
	excludeList.append(self)
	excludeList.append(area)
	excludeList.append(weapSys.parentNode)
	for i in get_tree().get_nodes_in_group("Exclude_From_Bullets"):
		excludeList.append(i)
	
	area.connect("area_entered", bulletArea)
	connect("body_entered", bulletCol)

func _physics_process(delta: float) -> void:
	if get_contact_count() == 0: 
		dir = linear_velocity.normalized()
	
	#startPos = global_position
	#mousePos = get_global_mouse_position()
	var dist : float = global_position.distance_to(startPos)
	maxDist = min(maxRange, mousePos.distance_to(startPos))
	var t : float = clamp(dist / maxDist, 0, 1)
	
	var thisRotSpeed : float = deg_to_rad((1 - t) * rotSpeed)
	
	rotation += thisRotSpeed if not weapSys.flip else -thisRotSpeed
	linear_velocity = initialVelocity.lerp(Vector2.ZERO, t)
	
	if t > 0.9: telePlayer()

func bulletCol(body: Node):
	if not body.is_in_group("Exclude_From_Bullets"):
		#Raycast to the colliding body to get the collision normal
		var space : PhysicsDirectSpaceState2D = get_world_2d().direct_space_state
		
		var to = global_position + dir * 5000.0
		
		var query : PhysicsRayQueryParameters2D = PhysicsRayQueryParameters2D.create(global_position, to)
		
		query.exclude = excludeList
		query.collide_with_areas = true
		query.collide_with_bodies = true
		
		var result : Dictionary = space.intersect_ray(query)
		
		if result:
			var pos : Vector2 = result.position
			var normal : Vector2 = (global_position - pos).normalized()
			
			var newEffect : GPUParticles2D = hitEffect.instantiate()
			newEffect.rotation = normal.angle()
			newEffect.global_position = pos
			Global.currentScene.add_child(newEffect)
			
			newEffect.emitting = true
		
		if body is RigidBody2D:
			var knBckDir : Vector2 = (body.global_position - global_position).normalized()
			if "knockbackVelocity" in body:
				body.knockbackVelocity += knBckDir * weapSys.weapon.knockback
		
		if body.has_method("take_damage") and canDamage:
			body.take_damage(weapSys.weapon.genDamage(), weapSys.parentNode)
		
		telePlayer()

func bulletArea(area: Area2D) -> void:
	var parent = area.get_parent()
	
	if not area.is_in_group("Exclude_From_Bullets"):
		linear_velocity = Vector2.ZERO
		
		#Raycast to the colliding body to get the collision normal
		var space : PhysicsDirectSpaceState2D = get_world_2d().direct_space_state
		
		var to = global_position + dir * 5000.0
		
		var query : PhysicsRayQueryParameters2D = PhysicsRayQueryParameters2D.create(global_position, to)
		query.exclude = [self, weapSys.parentNode]
		query.collide_with_areas = true
		query.collide_with_bodies = true
		
		var result : Dictionary = space.intersect_ray(query)
		
		if result:
			var pos : Vector2 = result.position
			var normal : Vector2 = (global_position - pos).normalized()
			
			var newEffect : GPUParticles2D = hitEffect.instantiate()
			newEffect.rotation = normal.angle()
			newEffect.global_position = global_position
			Global.currentScene.add_child(newEffect)
			
			newEffect.emitting = true
		
		if parent.has_method("take_damage") and canDamage:
			parent.take_damage(weapSys.weapon.genDamage(), weapSys.parentNode)
		
		telePlayer()

func telePlayer() -> void:
	global_position = startPos + initialVelocity.normalized() * maxDist
	Global.player.global_position = global_position
	queue_free()

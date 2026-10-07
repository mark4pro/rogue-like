extends RigidBody2D

@export_category("This Object")
@export var area : Area2D = null
@export var hitEffect : PackedScene = null
@export var rotSpeed : float = 0

@export_category("Data")
@export var weapSys : WeaponSys = null

var dir : Vector2 = Vector2.ZERO
var excludeList : Array[RID] = []
# A projectile can touch an enemy's body and its hit area in the same frame; only the first counts
# (both used to deal damage, so projectiles often hit twice)
var _spent : bool = false

func _ready() -> void:
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
	
	# Ray queries exclude by RID, not by node
	excludeList.append(get_rid())
	excludeList.append(area.get_rid())
	if weapSys and weapSys.parentNode is CollisionObject2D:
		excludeList.append(weapSys.parentNode.get_rid())
	for i in get_tree().get_nodes_in_group("Exclude_From_Bullets"):
		if i is CollisionObject2D: excludeList.append(i.get_rid())
	
	area.connect("area_entered", bulletArea)
	connect("body_entered", bulletCol)

func _physics_process(_delta: float) -> void:
	if get_contact_count() == 0: 
		dir = linear_velocity.normalized()
	
	var thisRotSpeed : float = deg_to_rad(rotSpeed)
	rotation += thisRotSpeed if not weapSys.flip else -thisRotSpeed

func bulletCol(body: Node):
	if _spent: return
	if not body.is_in_group("Exclude_From_Bullets"):
		_spent = true
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
			# Push along the bullet's flight, not just away from where it touched
			var knBckDir : Vector2 = dir if dir != Vector2.ZERO else body.global_position - global_position
			Knockback.apply(body, knBckDir, weapSys.weapon.knockback, weapSys.parentNode)
		
		if body.has_method("take_damage"):
			body.take_damage(weapSys.genDamage(), weapSys.parentNode)
		
		queue_free()

func bulletArea(thisArea: Area2D) -> void:
	var parent = thisArea.get_parent()
	if _spent: return
	
	if not thisArea.is_in_group("Exclude_From_Bullets"):
		_spent = true
		linear_velocity = Vector2.ZERO
		
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
			newEffect.global_position = global_position
			Global.currentScene.add_child(newEffect)
			
			newEffect.emitting = true
		
		if parent.has_method("take_damage"):
			parent.take_damage(weapSys.genDamage(), weapSys.parentNode)
		
		queue_free()

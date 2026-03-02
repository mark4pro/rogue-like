extends Resource
class_name BaseAI

var body = null
var navAgent = null
var target : Vector2 = Vector2.ZERO
var eyePos : Vector2 = Vector2.ZERO
var eyeDir : Vector2 = Vector2.ZERO
@export_category("For Vision Cone")
@export var coneSteps : int = 12
var shape : ConvexPolygonShape2D = null
var baseNode = null #Marker2D
var isFlipped : bool = false

@export_category("Movement")
@export var speed : float = 7
@export var stopDist : float = 65
@export var wonderUpdate : float = 2
@export_category("Vision")
@export var visionRange : float = 100
@export var visionAngle : float = 90
@export var timeUntilChase : float = 1
@export var timeUntilChaseEnd : float = 3

var cone = null

func newConeShape() -> ConvexPolygonShape2D:
	var shape : ConvexPolygonShape2D = ConvexPolygonShape2D.new()
	
	var points : PackedVector2Array = []
	points.append(Vector2.ZERO) # cone origin
	
	var halfAngle : float = deg_to_rad(visionAngle * 0.5)
	
	for i in range(coneSteps + 1):
		var t : float = float(i) / coneSteps
		var angle : float = lerp(-halfAngle, halfAngle, t)
		var dir : Vector2 = Vector2.RIGHT.rotated(angle)
		points.append(dir * visionRange)
	
	shape.points = points
	return shape

func canSeeTarget():
	var closest : Node = null
	var closestDist : float = INF
	
	if eyeDir == Vector2.ZERO: return closest
	
	var space : PhysicsDirectSpaceState2D = body.get_world_2d().direct_space_state
	
	if not shape: shape = newConeShape()
	else:
		var query := PhysicsShapeQueryParameters2D.new()
		query.shape = shape
		query.transform = Transform2D(
			eyeDir.angle(),
			eyePos
			)
		query.exclude = [body]
		query.collide_with_areas = true
		query.collide_with_bodies = true
		
		var results := space.intersect_shape(query)
		
		for result in results:
			if result.collider.is_in_group("Player"):
				var dist : float = eyePos.distance_to(result.collider.global_position)
				
				if dist < closestDist:
					closestDist = dist
					closest = result.collider
	
	return closest

func visionCone() -> void:
	cone = baseNode.get_node_or_null("Cone")
	
	if Global.debugVision and baseNode and shape:
		if not cone:
			var newCone : Node2D = load("res://Assets/prefabs/ui/vision_cone.tscn").instantiate()
			newCone.name = "Cone"
			newCone.shape = shape
			baseNode.add_child(newCone)
		else:
			cone.shape = shape
			var localDir : Vector2 = baseNode.to_local(eyePos + eyeDir) - baseNode.to_local(eyePos)
			cone.rotation = localDir.angle()
			cone.queue_redraw()
	else:
		if cone: cone.queue_free()

func update(delta: float) -> void:
	pass

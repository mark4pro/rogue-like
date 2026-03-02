extends Node2D

var visionDebugColor : Color = Color(0.64, 0.0, 0.0, 0.118)

var shape : ConvexPolygonShape2D = null

func _process(_delta: float) -> void:
	if not Global.debugVision: queue_redraw()

func _draw() -> void:
	if not Global.debugVision or shape == null:
		return
	
	draw_polygon(shape.points, [visionDebugColor])

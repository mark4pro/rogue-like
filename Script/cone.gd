extends Node2D

var visionDebugColor : Color = Color(0.64, 0.0, 0.0, 0.118)

var pos : Vector2 = Vector2.ZERO
var dir : Vector2 = Vector2.ZERO
var vAngle : float = 90
var vRange : float = 100

func _process(_delta: float) -> void:
	if not Global.debugVision: queue_redraw()

func _draw() -> void:
	if not Global.debugVision:
		return
	
	var halfAngle : float = deg_to_rad(vAngle * 0.5)
	var points : PackedVector2Array = []
	
	var localPos = to_local(pos)
	
	points.append(localPos)
	
	var steps : int = 24
	
	for i in range(steps + 1):
		var t : float = lerp(-halfAngle, halfAngle, float(i) / steps)
		var dir_ : Vector2 = dir.rotated(t)
		points.append(localPos + dir_ * vRange)
	
	draw_polygon(points, [visionDebugColor])

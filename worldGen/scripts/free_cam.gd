extends Camera2D

var limitSet : bool = false
var bounds : CollisionPolygon2D = null

func _process(delta: float) -> void:
	if is_current():
		var dir : Vector2 = Vector2(Input.get_axis("left", "right"), Input.get_axis("up", "down")).normalized()
		var speed : float = ((100 - zoom.x) / 100) * 1000
		position += dir * speed * delta
		var zoomDir : float = Input.get_axis("zoomOut", "zoomIn")
		zoom += Vector2(zoomDir, zoomDir) * 10 * delta
		zoom.x = clampf(zoom.x, 0.5, 100)
		zoom.y = clampf(zoom.y, 0.5, 100)
	
	var halfViewport = get_viewport_rect().size * 0.5 / zoom
	
	position.x = clamp(position.x, limit_left + halfViewport.x, limit_right - halfViewport.x)
	position.y = clamp(position.y, limit_top + halfViewport.y, limit_bottom - halfViewport.y)
	
	var boundsChk = get_tree().get_nodes_in_group("Bounds")
	if not boundsChk.is_empty(): bounds = boundsChk[0].get_node_or_null("CollisionPolygon2D")
	
	if bounds and not limitSet:
		var minX = INF
		var maxX = -INF
		var minY = INF
		var maxY = -INF
		
		for p in bounds.polygon:
			minX = min(minX, p.x)
			maxX = max(maxX, p.x)
			minY = min(minY, p.y)
			maxY = max(maxY, p.y)
		
		var topLeft = Vector2(minX, minY)
		var bottomRight = Vector2(maxX, maxY)
		
		limit_left = int(topLeft.x)
		limit_top = int(topLeft.y)
		limit_right = int(bottomRight.x)
		limit_bottom = int(bottomRight.y)
		
		limitSet = true

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
	
	position.x = clamp(position.x, limit_left, limit_right)
	position.y = clamp(position.y, limit_top, limit_bottom)
	
	var boundsChk = get_tree().get_nodes_in_group("Bounds")
	if not boundsChk.is_empty(): bounds = boundsChk[0].get_node_or_null("CollisionPolygon2D")
	
	if bounds and not limitSet:
		var min_x = INF
		var max_x = -INF
		var min_y = INF
		var max_y = -INF
		
		for p in bounds.polygon:
			min_x = min(min_x, p.x)
			max_x = max(max_x, p.x)
			min_y = min(min_y, p.y)
			max_y = max(max_y, p.y)
		
		var top_left = Vector2(min_x, min_y)
		var bottom_right = Vector2(max_x, max_y)
		
		limit_left = int(top_left.x)
		limit_top = int(top_left.y)
		limit_right = int(bottom_right.x)
		limit_bottom = int(bottom_right.y)
		
		limitSet = true

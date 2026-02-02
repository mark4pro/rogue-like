extends Camera2D

func _process(delta: float) -> void:
	var dir : Vector2 = Vector2(Input.get_axis("left", "right"), Input.get_axis("up", "down")).normalized()
	var speed : float = ((100 - zoom.x)/100) * 1000
	position += dir * speed * delta
	var zoomDir : float = Input.get_axis("zoomOut", "zoomIn")
	zoom += Vector2(zoomDir, zoomDir) * 10 * delta
	zoom.x = clampf(zoom.x, 0.5, 100)
	zoom.y = clampf(zoom.y, 0.5, 100)

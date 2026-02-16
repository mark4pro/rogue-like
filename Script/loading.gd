extends CanvasLayer

var time = 0

func _process(delta: float) -> void:
	time += delta * 3
	var t = int(time) % 4
	
	var label = $BG/Label
	var prog : String = "..."
	
	label.text = "LOADING" + prog.substr(0, t)

extends Node

var hasWorldNode : bool = false
var loaded : bool = false

func _ready() -> void:
	pass # Replace with function body.

func _process(delta: float) -> void:
	var isTestEnv : Node2D = get_tree().root.get_node_or_null("TestGen")
	if isTestEnv:
		if not hasWorldNode:
			var newWorldNode : Node2D = Node2D.new()
			newWorldNode.name = "World"
			isTestEnv.add_child(newWorldNode)
			hasWorldNode = true
		if not loaded:
			pass

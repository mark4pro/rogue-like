extends Node2D

@export var item : BaseItem

@onready var item_sprite = $Icon

var player_in_range = false

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	item_sprite.texture = item.itemIcon

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	if player_in_range and Input.is_action_just_pressed("pickup") and not get_tree().paused:
		pickup_item()

func pickup_item():
	if Global.player and Global.hasSpace(item):
		Global.add_item(item)
		queue_free()

func _on_area_2d_body_entered(body: Node2D) -> void:
	if body.is_in_group("Player"):
		player_in_range = true
		Global.sendMessage("Press E to pickup " + item.name, 1.0)

func _on_area_2d_body_exited(body: Node2D) -> void:
	if body.is_in_group("Player"):
		player_in_range = false

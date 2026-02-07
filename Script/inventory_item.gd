extends Node2D

@export var item : BaseItem

@onready var item_sprite = $Icon
@onready var interact_ui = $interactUI

var player_in_range = false

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	interact_ui.visible = false
	item_sprite.texture = item.itemIcon

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	if player_in_range and Input.is_action_just_pressed("pickup"):
		pickup_item()

func pickup_item():
	if Global.player:
		Global.add_item(item)
		self.queue_free()

func _on_area_2d_body_entered(body: Node2D) -> void:
	if body.is_in_group("Player"):
		player_in_range = true
		interact_ui.visible = true

func _on_area_2d_body_exited(body: Node2D) -> void:
	if body.is_in_group("Player"):
		player_in_range = false
		interact_ui.visible = false

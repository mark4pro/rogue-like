extends Node2D

@export var animPlayer : AnimationPlayer = null
@export var sprite : AnimatedSprite2D = null

var gpuPart : GPUParticles2D = null

func _ready() -> void:
	$Sprite2D/Col.set_collision_layer_value(1, false)
	$Sprite2D/Col.set_collision_mask_value(1, false)
	
	if get_parent().is_in_group("Player"):
		$Sprite2D/Col.set_collision_layer_value(4, true)
		$Sprite2D/Col.set_collision_mask_value(3, true)
	else:
		$Sprite2D/Col.set_collision_layer_value(5, true)
		$Sprite2D/Col.set_collision_mask_value(2, true)
	
	gpuPart = get_node_or_null("Sprite2D/GPUParticles2D")

func _process(_delta: float) -> void:
	if gpuPart and animPlayer.is_playing():
		gpuPart.amount_ratio = clampf(gpuPart.amount_ratio, 0.1, 0.1 + (animPlayer.current_animation_position / animPlayer.current_animation_length))

func _on_col_body_entered(_body: Node2D) -> void:
	pass

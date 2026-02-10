extends Node2D

@onready var idleTimer : Timer = $Idle
@onready var dialogue : CanvasLayer = $Text
@onready var head : AnimatedSprite2D = $Body/HeadAnchor/Head

@export var rest : bool = true
@export var wave : bool = false

@export var inRange : bool = false
@export var isShopOpen : bool = false
@export var inDialogue : bool = false

func _ready() -> void:
	head.animation = "default"
	dialogue.voice.set_sub_stream(load("res://addons/godot-voice-generator/sound/v1.ogg"))

func _process(delta: float) -> void:
	if inRange:
		idleTimer.stop()
		rest = false
		
		#Dialogue
		if not inDialogue and Input.is_action_just_pressed("interact"):
			dialogue.visible = true
			dialogue.start("Test")
	else:
		head.stop()
		inDialogue = false
		isShopOpen = false
		dialogue.visible = false
		if idleTimer.is_stopped(): idleTimer.start()

func _on_area_2d_body_entered(body: Node2D) -> void:
	if body.is_in_group("Player"):
		Global.sendMessage("Press " + Global.getKeyFromAction("interact") + " to talk to shop keeper.", 3.0, Color(0.0, 0.196, 0.667, 1.0))
		inRange = true

func _on_area_2d_body_exited(body: Node2D) -> void:
	if body.is_in_group("Player"):
		inRange = false

func _on_idle_timeout() -> void:
	rest = true

func _on_voice_audio_stream_player_saying_characters(position: int) -> void:
	head.stop()
	head.play("talking")

func _on_voice_audio_stream_player_finished_saying() -> void:
	head.play("default")

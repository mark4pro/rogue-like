extends Node2D

@onready var idleTimer : Timer = $Idle
@onready var head : AnimatedSprite2D = $Body/HeadAnchor/Head
@onready var zPart : GPUParticles2D = $Body/HeadAnchor/Head/Zzz

@export var rest : bool = true
@export var wave : bool = false

@export var inRange : bool = false
@export var isShopOpen : bool = false
@export var inDialogue : bool = false

@export var dialogue : DialogueResource = null
@export var dialogueBox : PackedScene = null

func _ready() -> void:
	rest = true
	head.animation = "sleeping"
	
	#thisDialogue.voice.set_sub_stream(load("res://addons/godot-voice-generator/sound/v1.ogg"))
	#thisDialogue.voice.connect("saying_characters", saying_characters)

func _process(_delta: float) -> void:
	if inRange:
		idleTimer.stop()
		rest = false
		zPart.visible = false
		zPart.emitting = false
		
		#Dialogue
		#inDialogue = thisDialogue.currentDial != null
		#thisDialogue.visible = inDialogue
		#
		#head.sprite_frames.set_animation_speed("talking", thisDialogue.textSpeed)
		
		if not inDialogue:
			head.play("default")
			
			if Input.is_action_just_pressed("interact"):
				DialogueManager.show_dialogue_balloon(dialogue, "start")
				#thisDialogue.start("Test")
	else:
		inDialogue = false
		isShopOpen = false
		
		if idleTimer.is_stopped(): idleTimer.start()
		if rest:
			head.play("sleeping")
			zPart.visible = true
			zPart.emitting = true

func _on_area_2d_body_entered(body: Node2D) -> void:
	if body.is_in_group("Player"):
		Global.sendMessage("Press " + Global.getKeyFromAction("interact") + " to talk to shop keeper.", 3.0, Color(0.0, 0.196, 0.667, 1.0))
		inRange = true

func _on_area_2d_body_exited(body: Node2D) -> void:
	if body.is_in_group("Player"):
		inRange = false

func _on_idle_timeout() -> void:
	rest = true

func saying_characters(_position: int) -> void:
	head.stop()
	head.play("talking")

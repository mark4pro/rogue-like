extends Node2D

@onready var shopMenu : PackedScene = preload("res://Assets/prefabs/ui/shop.tscn")

@export var list : Array[BaseItem] = []

@onready var idleTimer : Timer = $Idle
@onready var head : AnimatedSprite2D = $Body/HeadAnchor/Head
@onready var zPart : GPUParticles2D = $Body/HeadAnchor/Head/Zzz

@export var rest : bool = true
@export var wave : bool = false

@export var inRange : bool = false
@export var isShopOpen : bool = false
@export var inDialogue : bool = false
@export var isShopClosed : bool = false

@export var dialogue : DialogueResource = null
@export var dialogueBox : PackedScene = null

var txtBox : CanvasLayer = null
var shop : CanvasLayer = null

func _ready() -> void:
	rest = true
	head.animation = "sleeping"

func _process(_delta: float) -> void:
	txtBox = Global.currentScene.get_node_or_null("TextBox")
	shop = Global.currentScene.get_node_or_null("Shop")
	
	if inRange:
		idleTimer.stop()
		rest = false
		zPart.visible = false
		zPart.emitting = false
		
		if txtBox: head.speed_scale = txtBox.ratio
		else: inDialogue = false
		
		if not inDialogue:
			head.play("default")
			
			if Input.is_action_just_pressed("interact"):
				DialogueManager.show_dialogue_balloon(dialogue, "start", [self])
				inDialogue = true
				isShopOpen = false
			
			if isShopClosed:
				DialogueManager.show_dialogue_balloon(dialogue, "bye", [self])
				inDialogue = true
				isShopOpen = false
		
		if txtBox and not txtBox.dialogue_label.spoke.is_connected(saying_characters):
			txtBox.dialogue_label.connect("spoke", saying_characters)
		
		if isShopOpen and not shop:
			var newShop : CanvasLayer = shopMenu.instantiate()
			newShop.shopkeeper = self
			Global.currentScene.add_child(newShop)
	else:
		isShopOpen = false
		inDialogue = false
		
		if txtBox: txtBox.queue_free()
		if shop: shop.queue_free()
		
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

func saying_characters(letter: String, letter_index: int, speed: float) -> void:
	head.stop()
	head.play("talking")

extends CanvasLayer

@onready var textLabel : Label = $BG/Text
@onready var arrow : TextureRect = $BG/Arrow
@onready var voice : VoiceAudioStreamPlayer = $VoiceAudioStreamPlayer

@export var convoIndex : int = 0
@export var textSpeed : float = 5

var prevConvo : int = 0
var maxConvo : int = 0
var txtTime : float = 0
var textIndex : int = 0

var voiceTrigger : bool = false

var t : float = 0

func stop() -> void:
	textIndex = 0
	txtTime = 0
	convoIndex += 1
	voice.stop_saying()

func start(id: String) -> void:
	convoIndex = 0
	textLabel.text = ""
	textIndex = 0
	txtTime = 0
	t = 0
	voiceTrigger = false

func _process(delta: float) -> void:
	if prevConvo != convoIndex:
		voiceTrigger = false
		prevConvo = convoIndex
	
	#if Global.dialogue == endedDialogue and endedDialogue:
		#t = min(t + (5 * delta), 1)
		#if t == 1:
			#Global.dialogue = null
			#endedDialogue = null
			#t = 0
	
	#if currentDial:
		#convoIndex = clamp(convoIndex, 0, currentDial.convos.size() - 1)
		#currentConvo = currentDial.convos[convoIndex]
		#
		#txtTime += delta
		#
		#var charDelay : float = 1 / textSpeed
		#
		#if Input.is_action_just_pressed("space") and textIndex < currentConvo.text.length():
			#textIndex = currentConvo.text.length() - 1
			#voice.stop_saying()
		#
		#voice.text_speed = textSpeed / voice.syllable_size
		#voice.punctuation_speed = (textSpeed + 1) / voice.syllable_size
		#if textIndex < currentConvo.text.length() and not voiceTrigger:
			#voice.say(currentConvo.text)
			#voiceTrigger = true
		#
		#if currentConvo.speaker != "" and textIndex == 0: textLabel.text = currentConvo.speaker
		#
		#if txtTime >= charDelay and textIndex < currentConvo.text.length():
			#textIndex += 1
			#var currentString : String = currentConvo.text.substr(0, textIndex)
			#if currentConvo.speaker == "":
				#textLabel.text = currentString
			#else:
				#textLabel.text = currentConvo.speaker + ": " + currentString
			#txtTime = 0
		#
		#arrow.visible = textIndex >= currentConvo.text.length()
		#if arrow.visible and (Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) or Input.is_action_just_pressed("space")):
			#if convoIndex == currentDial.convos.size() - 1:
				#stop()
				#return
			#textIndex = 0
			#txtTime = 0
			#convoIndex += 1

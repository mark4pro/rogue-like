extends CanvasLayer

@onready var textLabel : Label = $BG/Text
@onready var arrow : TextureRect = $BG/Arrow
@onready var voice : VoiceAudioStreamPlayer = $VoiceAudioStreamPlayer

@export var dialogue : Array[Dialogue] = []
@export var currentDial : Dialogue = null
@export var convoIndex : int = 0
@export var currentConvo : Convo = null
@export var textSpeed : float = 5

var prevConvo : int = 0
var maxConvo : int = 0
var txtTime : float = 0
var textIndex : int = 0

var voiceTrigger : bool = false

func stop() -> void:
	currentDial = null
	textIndex = 0
	txtTime = 0
	convoIndex += 1
	voice.stop_saying()

func start(id: String) -> void:
	var index = dialogue.find_custom(func(d): return d.id == id)
	if not index == -1: currentDial = dialogue[index]
	
	convoIndex = 0
	maxConvo = currentDial.convos.size()
	textLabel.text = ""
	textIndex = 0
	txtTime = 0
	voiceTrigger = false

func _process(delta: float) -> void:
	if prevConvo != convoIndex:
		voiceTrigger = false
		prevConvo = convoIndex
	
	if currentDial:
		convoIndex = clamp(convoIndex, 0, currentDial.convos.size() - 1)
		currentConvo = currentDial.convos[convoIndex]
		
		txtTime += delta
		
		var charDelay : float = 1 / textSpeed
		
		voice.text_speed = textSpeed / voice.syllable_size
		voice.punctuation_speed = (textSpeed + 1) / voice.syllable_size
		if textIndex < currentConvo.text.length() and not voiceTrigger:
			voice.say(currentConvo.text)
			voiceTrigger = true
		
		if currentConvo.speaker != "" and textIndex == 0: textLabel.text = currentConvo.speaker
		
		if txtTime >= charDelay and textIndex < currentConvo.text.length():
			textIndex += 1
			var currentString : String = currentConvo.text.substr(0, textIndex)
			if currentConvo.speaker == "":
				textLabel.text = currentString
			else:
				textLabel.text = currentConvo.speaker + ": " + currentString
			txtTime = 0
		
		arrow.visible = textIndex >= currentConvo.text.length()
		if arrow.visible and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
			if convoIndex == currentDial.convos.size() - 1:
				stop()
				return
			textIndex = 0
			txtTime = 0
			convoIndex += 1

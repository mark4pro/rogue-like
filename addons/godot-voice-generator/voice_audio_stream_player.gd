class_name VoiceAudioStreamPlayer
extends AudioStreamPlayer

signal saying_characters(position: int)
signal started_saying
signal finished_saying

var saying_text : String = ""
var saying_words : Array[Word] = []
var saying_word : Word = Word.new()
var text_time : float = 0.0

@export var text_speed : float = 5
@export var punctuation_speed : float = 2.5

var stream_randomizer: AudioStreamRandomizer = AudioStreamRandomizer.new()
var stream_generator: AudioStreamWAV = AudioStreamWAV.new()
@export var source_type : SOURCE_TYPE = SOURCE_TYPE.FILE
@export_range(0.1, 4, 0.01) var main_pitch_scale : float = 1.0
var random_pitch: float:
	get:
		return (stream as AudioStreamRandomizer).random_pitch
	set(value):
		(stream as AudioStreamRandomizer).random_pitch = value
var random_volume_offset_db: float:
	get:
		return (stream as AudioStreamRandomizer).random_volume_offset_db
	set(value):
		(stream as AudioStreamRandomizer).random_volume_offset_db = value
@export_range(1, 3, 0.01) var question_pitch_scale : float = 1.4
@export_range(0, 10, 1) var syllable_size : int = 3
@export_range(0, 1, 0.01) var word_cutting_percentage : float = 0

@export_subgroup("Stream Generator")
@export var generator_type : GENERATOR_TYPE = GENERATOR_TYPE.SINE
@export_range(0, 1, 0.01) var generator_length : float = 0.2
@export_range(10, 8000, 1) var generator_frequence_hz : float = 440.0
@export_range(10, 8000, 1) var generator_frequence2_hz : float = 0.0
@export_range(0, 10, 0.01) var generator_amplitude : float = 0.5
@export_range(0, 1, 0.01) var generator_noise : float = 0.0
@export_range(0, 1000, 1) var generator_smooth_wave : float = 0

@export_subgroup("Alphabet")
@export var alphabet_mapping: Dictionary

class Word:
	var position : int = 0
	var text : String = ""
	var clear_text : String = ""
	var is_exclamation : bool = false
	var is_question : bool = false
	var has_pause : bool = false
	var word_parts : Array[String] = []
	var word_parts_positions : Array[int] = []

enum GENERATOR_TYPE {
	SINE,
	SQUARE,
	PULSE,
	TRIANGLE,
	SAWTOOTH_RISING,
	SAWTOOTH_FALLING,
	NOISE
}

enum SOURCE_TYPE {
	FILE,
	GENERATOR,
	ALPHABET,
}

func _ready() -> void:
	match source_type:
		SOURCE_TYPE.FILE:
			stream = stream_randomizer
		SOURCE_TYPE.GENERATOR:
			stream = stream_generator
			set_generator_sub_stream()

func _process(delta: float) -> void:
	if not saying_words.is_empty():
		text_time += delta
		
		saying_word = saying_words[0]
		
		var charDelay : float = 1.0 / max(text_speed, 0.01)
		if saying_word.has_pause:
			charDelay = 1.0 / max(punctuation_speed, 0.01)
		
		if (not playing or get_playback_position() <= 0.0) and text_time >= charDelay:
			if saying_word.word_parts.is_empty():
				saying_words.remove_at(0)
			else:
				emit_signal("saying_characters", saying_word.word_parts_positions[0])
				
				if source_type == SOURCE_TYPE.ALPHABET:
					var letter_stream : AudioStream = alphabet_mapping.get(saying_word.word_parts[0].to_lower(), alphabet_mapping.get("default"))
					if letter_stream:
						set_sub_stream(letter_stream)
				
				saying_word.word_parts.remove_at(0)
				saying_word.word_parts_positions.remove_at(0)
				pitch_scale = main_pitch_scale * (question_pitch_scale if saying_word.is_exclamation or saying_word.is_question else 1)
				stop()
				play()
			text_time = 0
	else:
		stop_saying()
		emit_signal("finished_saying")

func stop_saying() -> void:
	stop()
	text_time = 0
	saying_words = []
	saying_text = ""
	saying_word = null

func say(text: String) -> void:
	saying_words = []
	saying_text = text
	text_time = 0
	saying_word = null
	emit_signal("started_saying")
	
	var word_beginning : int = 0
	for i in text.length():
		var is_last_symbol : bool = i == text.length() - 1
		if is_last_symbol or text[i] == ' ' or text[i] == '\n':
			if word_beginning < i:
				var word : Word = Word.new()
				word.position = word_beginning
				word.text = text.substr(word_beginning, i - word_beginning + (1 if is_last_symbol else 0))
				var last_char : String = text[i - (0 if is_last_symbol else 1)]
				word.is_exclamation = last_char == '!'
				word.is_question = last_char == '?'
				word.has_pause = last_char == '.' or last_char == ',' or word.is_exclamation or word.is_question or is_last_symbol
				word.clear_text = make_clear(word.text)
				var keep_len := int(floor(word.clear_text.length() * (1.0 - word_cutting_percentage)))
				keep_len = clamp(keep_len, 1, word.clear_text.length())
				word.clear_text = word.clear_text.substr(0, keep_len)
				if syllable_size <= 0:
					word.word_parts.append(word.clear_text)
					word.word_parts_positions.append(word.position + word.text.length())
				else:
					var curr_syllable_size : int = 1 if source_type == SOURCE_TYPE.ALPHABET else syllable_size
					var clear_syllable_count : int = ceili(float(word.clear_text.length()) / curr_syllable_size)
					var dirty_syllable_size : int = ceili(float(word.text.length()) / clear_syllable_count)
					
					for syllable_idx: int in clear_syllable_count:
						var clear_syllable : String = word.clear_text.substr(syllable_idx * curr_syllable_size, curr_syllable_size)
						word.word_parts.append(clear_syllable)
						var dirty_pos : int = word.position + min(syllable_idx * dirty_syllable_size + dirty_syllable_size, word.text.length()) as int
						word.word_parts_positions.append(dirty_pos)
				saying_words.append(word)
			word_beginning = i + 1

func make_clear(text: String) -> String:
	var regex = RegEx.new()
	regex.compile("[^A-Za-z0-9 ]+")
	return regex.sub(text, "", true)

func set_sub_stream(sub_stream: AudioStream) -> void:
	stream_randomizer.add_stream(0, sub_stream)

func set_generator_sub_stream() -> void:
	stream_randomizer.add_stream(0, stream_generator)
	refresh_generator_data()

func refresh_generator_data() -> void:
	if source_type != SOURCE_TYPE.GENERATOR:
		return
	stream_generator.mix_rate = AudioServer.get_mix_rate()
	var buffer : PackedByteArray = PackedByteArray()
	stream_generator.format = AudioStreamWAV.FORMAT_16_BITS
	var samples_per_second : int = stream_generator.mix_rate
	
	var length : int = int(samples_per_second * generator_length)
	var stream_buffer : StreamPeerBuffer = StreamPeerBuffer.new()
	
	var noise : float = 0.0
	var array_buffer : PackedFloat32Array = PackedFloat32Array()
	for i in range(0, length):
		var value : float = 0
		match generator_type:
			GENERATOR_TYPE.SINE:
				value = sin(float(i) / samples_per_second * generator_frequence_hz * PI * 2.0)
				if generator_frequence2_hz > 0:
					value += sin(float(i) / samples_per_second * generator_frequence2_hz * PI * 2.0)
					value /= 2.0
			GENERATOR_TYPE.SQUARE:
				value = sign(sin(float(i) / samples_per_second * generator_frequence_hz * PI * 2.0))
			GENERATOR_TYPE.PULSE:
				#value = 1.0 if abs(sin(float(i) / samples_per_second * generator_frequence_hz * PI * 2.0)) > generator_frequence2_hz / 8000 else -1.0
				var freq_range : Array = range(10, generator_frequence2_hz, generator_frequence_hz)
				for j in freq_range.size():
					value += sin(float(i) / samples_per_second * freq_range[j] * PI * 2.0) * (1.0 - float(j) / freq_range.size())
				value /= freq_range.size()
			GENERATOR_TYPE.TRIANGLE:
				value = 2.0 / PI * asin(sin(float(i) / samples_per_second * generator_frequence_hz * PI * 2.0))
			GENERATOR_TYPE.SAWTOOTH_RISING:
				var tg : float = tan(float(i) / samples_per_second * generator_frequence_hz * PI)
				value = -2.0 / PI * atan(1.0 / (0.000001 if tg == 0 else tg))
			GENERATOR_TYPE.SAWTOOTH_FALLING:
				var tg : float = tan(float(i) / samples_per_second * generator_frequence_hz * PI)
				value = 2.0 / PI * atan(1.0 / (0.000001 if tg == 0 else tg))
			GENERATOR_TYPE.NOISE:
				value = randf_range(-1, 1)
		value *= (1.0 - generator_noise * randf_range(-1.0, 1.0))
		array_buffer.append(value * generator_amplitude)
		
	for j in generator_smooth_wave:
		for i in range(1, array_buffer.size() - 1):
			array_buffer[i] = (array_buffer[i - 1] + array_buffer[i] + array_buffer[i + 1]) / 3.0
	
	for i in array_buffer.size():
		var value : float = array_buffer[i]
		
		if stream_generator.format == AudioStreamWAV.FORMAT_8_BITS:
			stream_buffer.put_8(int(round(clamp(value, -1.0, 1.0) * 127)))
		else:
			stream_buffer.put_16(int(round(clamp(value, -1.0, 1.0) * 32766)))
		
	stream_generator.data = stream_buffer.data_array

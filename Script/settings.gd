extends Node

# Autoload "Settings": owns every option in the options menu.
# - Saved to user://settings.cfg (separate from the game save) every time something changes.
# - Loaded and applied on startup, after Global has loaded the save.
# - The game save still stores Global's toggles (damage numbers etc.) for older code, but the
#   values here win on startup, so the options menu is the source of truth.

const PATH : String = "user://settings.cfg"

const WINDOW_MODES : Array[String] = ["Windowed", "Fullscreen", "Exclusive fullscreen"]
const WINDOW_MODE_VALUES : Array[int] = [
	DisplayServer.WINDOW_MODE_WINDOWED,
	DisplayServer.WINDOW_MODE_FULLSCREEN,
	DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN,
]
const RESOLUTIONS : Array[Vector2i] = [Vector2i(1280, 720), Vector2i(1600, 900), Vector2i(1920, 1080), Vector2i(2560, 1440)]
const VSYNC_MODES : Array[String] = ["Off", "On", "Adaptive", "Mailbox"]
const VSYNC_VALUES : Array[int] = [
	DisplayServer.VSYNC_DISABLED,
	DisplayServer.VSYNC_ENABLED,
	DisplayServer.VSYNC_ADAPTIVE,
	DisplayServer.VSYNC_MAILBOX,
]
const MAX_FPS_VALUES : Array[int] = [0, 30, 60, 120, 144, 165, 240]
const MSAA_MODES : Array[String] = ["Off", "2x", "4x", "8x"]

const DEFAULTS : Dictionary = {
	"game": {
		"damage_numbers": true,
		"damage_tilt": true,
		"camera_zoom": 7.0,
	},
	"graphics": {
		"window_mode": 0,
		"borderless": false,
		"resolution": 2,
		"vsync": 1,
		"max_fps": 0,
		"msaa": 0,
		"shadows": true,
		"particles": true,
	},
	"debug": {
		"show_fps": true,
		"vision_cones": true,
		"blood_moons": true,
		"biome_overlay": false,
		"time_scale": 1.0,
	},
}

# What the debug options are forced to outside the editor (the Debug tab is editor-only)
const RELEASE_DEBUG : Dictionary = {
	"show_fps": false,
	"vision_cones": false,
	"blood_moons": true,
	"biome_overlay": false,
	"time_scale": 1.0,
}

var data : Dictionary = {}          # section -> key -> value (game / graphics / debug)
var audio : Dictionary = {}         # bus name -> {"volume": 0..1 linear, "mute": bool}
var audio_defaults : Dictionary = {}
var controls : Dictionary = {}      # action -> Array of event dicts (only actions changed from default)
var default_binds : Dictionary = {} # action -> Array[InputEvent] as set in the project

var options_open : bool = false
var _pause_consumed_ms : int = -100000

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_capture_defaults()
	load_settings()
	apply_all()
	get_tree().node_added.connect(_on_node_added)

func _process(_delta: float) -> void:
	# Things that live on the player get re-applied whenever a new player spawns
	var p = Global.player
	if p and is_instance_valid(p) and p.is_inside_tree():
		if "fpsTxt" in p and p.fpsTxt:
			p.fpsTxt.visible = get_debug("show_fps")
		if "camera" in p and p.camera:
			var z : float = data.game.camera_zoom
			if not is_equal_approx(p.camera.zoom.x, z):
				p.camera.zoom = Vector2(z, z)

#region Values

func is_editor() -> bool:
	return OS.has_feature("editor")

func get_value(section: String, key: String):
	return data[section][key]

# Debug values only count in the editor; exported builds always use RELEASE_DEBUG
func get_debug(key: String):
	return data.debug[key] if is_editor() else RELEASE_DEBUG[key]

func set_value(section: String, key: String, value) -> void:
	data[section][key] = value
	match section:
		"game": apply_game()
		"graphics": apply_graphics()
		"debug": apply_debug()
	save_settings()

func set_bus_volume(bus: String, volume: float) -> void:
	audio[bus].volume = clampf(volume, 0.0, 1.0)
	apply_audio()
	save_settings()

func set_bus_mute(bus: String, mute: bool) -> void:
	audio[bus].mute = mute
	apply_audio()
	save_settings()

func reset_section(section: String) -> void:
	match section:
		"audio":
			audio = audio_defaults.duplicate(true)
			apply_audio()
		"controls":
			for action in default_binds:
				_set_events(action, default_binds[action])
			controls.clear()
		_:
			data[section] = DEFAULTS[section].duplicate(true)
			apply_all()
	save_settings()

# Esc closes the options menu; this stops the same press from also toggling the pause menu
func consume_pause() -> void:
	_pause_consumed_ms = Time.get_ticks_msec()

func pause_input_free() -> bool:
	return not options_open and Time.get_ticks_msec() - _pause_consumed_ms > 150

#endregion

#region Save / load

func _capture_defaults() -> void:
	data = DEFAULTS.duplicate(true)
	# Release defaults follow Global's current toggles where they exist
	audio_defaults.clear()
	for i in AudioServer.bus_count:
		audio_defaults[AudioServer.get_bus_name(i)] = {
			"volume": db_to_linear(AudioServer.get_bus_volume_db(i)),
			"mute": AudioServer.is_bus_mute(i),
		}
	audio = audio_defaults.duplicate(true)
	default_binds.clear()
	for action in InputMap.get_actions():
		if String(action).begins_with("ui_"):
			continue
		default_binds[String(action)] = InputMap.action_get_events(action).duplicate()

func load_settings() -> void:
	var cfg : ConfigFile = ConfigFile.new()
	if cfg.load(PATH) != OK:
		return # first run: defaults
	
	for section in DEFAULTS:
		for key in DEFAULTS[section]:
			var def = DEFAULTS[section][key]
			var v = cfg.get_value(section, key, def)
			if typeof(v) == typeof(def) or (typeof(def) == TYPE_FLOAT and typeof(v) == TYPE_INT):
				data[section][key] = v
	
	for bus in audio:
		audio[bus].volume = clampf(float(cfg.get_value("audio", bus + "_volume", audio[bus].volume)), 0.0, 1.0)
		audio[bus].mute = bool(cfg.get_value("audio", bus + "_mute", audio[bus].mute))
	
	controls.clear()
	if cfg.has_section("controls"):
		for action in cfg.get_section_keys("controls"):
			if not default_binds.has(action):
				continue # action removed from the project since
			var list = cfg.get_value("controls", action, [])
			if list is Array:
				controls[action] = list

func save_settings() -> void:
	var cfg : ConfigFile = ConfigFile.new()
	for section in data:
		for key in data[section]:
			cfg.set_value(section, key, data[section][key])
	for bus in audio:
		cfg.set_value("audio", bus + "_volume", audio[bus].volume)
		cfg.set_value("audio", bus + "_mute", audio[bus].mute)
	for action in controls:
		cfg.set_value("controls", action, controls[action])
	var err : Error = cfg.save(PATH)
	if err != OK:
		push_warning("Couldn't save settings: %s" % error_string(err))

#endregion

#region Apply

func apply_all() -> void:
	apply_game()
	apply_audio()
	apply_graphics()
	apply_debug()
	apply_controls()

func apply_game() -> void:
	Global.damNumberEnable = data.game.damage_numbers
	Global.damAnimRotEnable = data.game.damage_tilt
	# camera_zoom is applied to the player in _process

func apply_audio() -> void:
	for i in AudioServer.bus_count:
		var bus : String = AudioServer.get_bus_name(i)
		if not audio.has(bus):
			continue
		AudioServer.set_bus_volume_db(i, linear_to_db(maxf(audio[bus].volume, 0.0001)))
		AudioServer.set_bus_mute(i, audio[bus].mute or audio[bus].volume <= 0.0)

func apply_graphics() -> void:
	var g : Dictionary = data.graphics
	var mode : int = WINDOW_MODE_VALUES[clampi(g.window_mode, 0, WINDOW_MODE_VALUES.size() - 1)]
	if DisplayServer.window_get_mode() != mode:
		DisplayServer.window_set_mode(mode)
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, g.borderless)
	if mode == DisplayServer.WINDOW_MODE_WINDOWED:
		var size : Vector2i = RESOLUTIONS[clampi(g.resolution, 0, RESOLUTIONS.size() - 1)]
		if DisplayServer.window_get_size() != size:
			DisplayServer.window_set_size(size)
			var screen : Rect2i = DisplayServer.screen_get_usable_rect(DisplayServer.window_get_current_screen())
			DisplayServer.window_set_position(screen.position + (screen.size - size) / 2)
	DisplayServer.window_set_vsync_mode(VSYNC_VALUES[clampi(g.vsync, 0, VSYNC_VALUES.size() - 1)])
	Engine.max_fps = MAX_FPS_VALUES[clampi(g.max_fps, 0, MAX_FPS_VALUES.size() - 1)]
	get_viewport().msaa_2d = clampi(g.msaa, 0, 3) as Viewport.MSAA
	_apply_to_tree(get_tree().root)

func apply_debug() -> void:
	Global.debugVision = get_debug("vision_cones")
	Global.bloodMoons = get_debug("blood_moons")
	Engine.time_scale = get_debug("time_scale")
	if Worldgen.worldNode and is_instance_valid(Worldgen.worldNode) and Worldgen.worldNode.debug:
		Worldgen.worldNode.debug.visible = get_debug("biome_overlay")

# Shadows / particles: remember each node's own setting so turning the option back on restores it
func _apply_to_node(n: Node) -> void:
	if n is Light2D:
		if not n.has_meta("_settings_shadow"):
			n.set_meta("_settings_shadow", n.shadow_enabled)
		n.shadow_enabled = n.get_meta("_settings_shadow") and data.graphics.shadows
	elif n is GPUParticles2D or n is CPUParticles2D:
		if not n.has_meta("_settings_visible"):
			n.set_meta("_settings_visible", n.visible)
		n.visible = n.get_meta("_settings_visible") and data.graphics.particles
	if n is CanvasItem and n.material is ShaderMaterial:
		_apply_shadow_shader(n)

# Drop shadow shaders (anything with a `disable_shadow` uniform).
# - Shadow-only sprites (drop_shadow_no_texture) get hidden, their shader would draw a copy of the sprite.
# - Everything else gets disable_shadow set on its material (materials are shared, so the
#   original value is remembered on the material itself).
func _apply_shadow_shader(n: CanvasItem) -> void:
	var mat : ShaderMaterial = n.material
	if not _has_shadow_uniform(mat.shader):
		return
	if mat.shader.resource_path.ends_with("drop_shadow_no_texture.gdshader"):
		if not n.has_meta("_settings_shadow_visible"):
			n.set_meta("_settings_shadow_visible", n.visible)
		n.visible = n.get_meta("_settings_shadow_visible") and data.graphics.shadows
	else:
		if not mat.has_meta("_settings_disable_shadow"):
			mat.set_meta("_settings_disable_shadow", bool(mat.get_shader_parameter("disable_shadow")))
		mat.set_shader_parameter("disable_shadow", mat.get_meta("_settings_disable_shadow") or not data.graphics.shadows)

var _shadow_shader_cache : Dictionary = {} # Shader -> bool

func _has_shadow_uniform(shader: Shader) -> bool:
	if not shader:
		return false
	if not _shadow_shader_cache.has(shader):
		var found : bool = false
		for u in shader.get_shader_uniform_list():
			if u.name == "disable_shadow":
				found = true
				break
		_shadow_shader_cache[shader] = found
	return _shadow_shader_cache[shader]

func _apply_to_tree(n: Node) -> void:
	_apply_to_node(n)
	for c in n.get_children():
		_apply_to_tree(c)

func _on_node_added(n: Node) -> void:
	if n is Light2D or n is GPUParticles2D or n is CPUParticles2D:
		_apply_to_node(n)
	elif n is CanvasItem and n.material is ShaderMaterial:
		_apply_shadow_shader(n)

#endregion

#region Controls

func rebindable_actions() -> Array:
	var list : Array = default_binds.keys()
	list.sort()
	return list

func set_bind(action: String, event: InputEvent) -> void:
	_set_events(action, [event])
	controls[action] = [_event_to_dict(event)]
	save_settings()

func reset_bind(action: String) -> void:
	_set_events(action, default_binds[action])
	controls.erase(action)
	save_settings()

func apply_controls() -> void:
	for action in controls:
		var events : Array = []
		for d in controls[action]:
			var ev : InputEvent = _dict_to_event(d)
			if ev:
				events.append(ev)
		if not events.is_empty():
			_set_events(action, events)

func _set_events(action: String, events: Array) -> void:
	InputMap.action_erase_events(action)
	for ev in events:
		InputMap.action_add_event(action, ev)

func _event_to_dict(ev: InputEvent) -> Dictionary:
	if ev is InputEventKey:
		return {"type": "key", "physical": ev.physical_keycode, "keycode": ev.keycode}
	if ev is InputEventMouseButton:
		return {"type": "mouse", "button": ev.button_index}
	if ev is InputEventJoypadButton:
		return {"type": "joy_button", "button": ev.button_index}
	return {}

func _dict_to_event(d: Dictionary) -> InputEvent:
	match d.get("type", ""):
		"key":
			var k : InputEventKey = InputEventKey.new()
			k.physical_keycode = int(d.get("physical", 0))
			k.keycode = int(d.get("keycode", 0))
			return k
		"mouse":
			var m : InputEventMouseButton = InputEventMouseButton.new()
			m.button_index = int(d.get("button", 1))
			return m
		"joy_button":
			var j : InputEventJoypadButton = InputEventJoypadButton.new()
			j.button_index = int(d.get("button", 0))
			return j
	return null

func event_text(ev: InputEvent) -> String:
	if ev is InputEventKey:
		# Numpad keys: name them as numpad keys (the layout lookup turns Kp 1 into "End" etc.)
		if ev.physical_keycode >= KEY_KP_MULTIPLY and ev.physical_keycode <= KEY_KP_9:
			return OS.get_keycode_string(ev.physical_keycode)
		if ev.physical_keycode != KEY_NONE:
			return OS.get_keycode_string(DisplayServer.keyboard_get_keycode_from_physical(ev.physical_keycode))
		return OS.get_keycode_string(ev.keycode)
	if ev is InputEventMouseButton:
		match ev.button_index:
			MOUSE_BUTTON_LEFT: return "Mouse Left"
			MOUSE_BUTTON_RIGHT: return "Mouse Right"
			MOUSE_BUTTON_MIDDLE: return "Mouse Middle"
			MOUSE_BUTTON_WHEEL_UP: return "Wheel Up"
			MOUSE_BUTTON_WHEEL_DOWN: return "Wheel Down"
			_: return "Mouse %d" % ev.button_index
	if ev is InputEventJoypadButton:
		return "Pad %d" % ev.button_index
	return ev.as_text()

func action_text(action: String) -> String:
	var events : Array = InputMap.action_get_events(action)
	if events.is_empty():
		return "(none)"
	var parts : PackedStringArray = PackedStringArray()
	for ev in events:
		parts.append(event_text(ev))
	return ", ".join(parts)

#endregion

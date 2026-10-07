extends RefCounted
class_name StatusVisuals

# Particles and tints for status effects. StatusEffects owns one of these per host.
# Each status gets a CPUParticles2D under the host, built the first time it's needed and
# switched on/off with the status. Sizes are in pixels and scaled from the host's sprite.
#
#   Burn    rising flames + flickering orange tint
#   Wet     falling drips + blue tint
#   Chill   drifting frost + pale blue tint
#   Freeze  ice sparkles + strong icy tint
#   Stun    sparks circling above the head + yellow flashing
#   Weaken  dark wisps sinking off the body + purple tint
#   Blind   acid drips + green tint (the player also gets the dark screen)
#   Sticky  slow slime drips + green tint
#   Poison  rising poison sprites (more with more stacks) + venom tint

const GLOW : Texture2D = preload("uid://oyvy6kab4ex8")
const POISON_TEX : Texture2D = preload("uid://dq5u4kcn5g2di")

const STATUSES : Array[String] = ["burn", "wet", "chill", "freeze", "stun", "weaken", "blind", "sticky", "poison"]

#region Tint colours (blended onto the sprite by status_tint.gdshader)
const TINT_FREEZE : Color = Color(0.6, 0.88, 1.0)
const TINT_STUN : Color = Color(1.0, 1.0, 0.4)
const TINT_BURN : Color = Color(1.0, 0.45, 0.15)
const TINT_POISON : Color = Color(0.8, 0.95, 0.25)
const TINT_BLIND : Color = Color(0.6, 0.9, 0.2)
const TINT_WEAKEN : Color = Color(0.5, 0.32, 0.75)
const TINT_CHILL : Color = Color(0.7, 0.92, 1.0)
const TINT_STICKY : Color = Color(0.5, 0.85, 0.35)
const TINT_WET : Color = Color(0.45, 0.62, 1.0)
#endregion

var fx : StatusEffects = null
var host : Node2D = null
var emitters : Dictionary = {}   # status -> CPUParticles2D
var _time : float = 0.0
var _w : float = 16.0            # sprite size and centre in host space
var _h : float = 16.0
var _center : Vector2 = Vector2.ZERO
var _measured : bool = false
var _poisonShown : int = 0
var _tintMat : ShaderMaterial = null

const TINT_SHADER : Shader = preload("uid://dvopdjbsktesv")

func _init(f: StatusEffects) -> void:
	fx = f
	host = f.host

func _sprite() -> CanvasItem:
	return host.sprite if ("sprite" in host and is_instance_valid(host.sprite)) else null

func _measure() -> void:
	_measured = true
	var spr : CanvasItem = _sprite()
	if not spr: return
	var rect : Rect2 = Rect2()
	if spr is Sprite2D and spr.texture:
		rect = spr.get_rect()
	elif spr is AnimatedSprite2D and spr.sprite_frames:
		var tex : Texture2D = spr.sprite_frames.get_frame_texture(spr.animation, spr.frame)
		if tex: rect = Rect2(-tex.get_size() * 0.5 + spr.offset, tex.get_size())
	if rect.size == Vector2.ZERO: return
	var sc : Vector2 = (spr as Node2D).global_scale.abs() / host.global_scale.abs()
	_w = maxf(rect.size.x * sc.x, 6.0)
	_h = maxf(rect.size.y * sc.y, 6.0)
	_center = host.to_local((spr as Node2D).to_global(rect.get_center()))

func update(delta: float) -> void:
	if not is_instance_valid(host): return
	_time += delta
	if not _measured: _measure()
	for s in STATUSES:
		var on : bool = fx.has(s)
		var p : CPUParticles2D = emitters.get(s)
		if on and not p:
			p = _make(s)
			emitters[s] = p
		if p and p.emitting != on: p.emitting = on
	# More poison sprites with more stacks (changing amount restarts the emitter, so only on change)
	if emitters.has("poison") and fx.poisonStacks > 0 and fx.poisonStacks != _poisonShown:
		_poisonShown = fx.poisonStacks
		emitters.poison.amount = 3 + 2 * fx.poisonStacks
	_applyTint()

# Sprites without their own material get the status_tint shader (blends toward the colour, so it
# shows on any sprite colour); sprites that already have a material fall back to self_modulate.
func _applyTint() -> void:
	var spr : CanvasItem = _sprite()
	if not spr: return
	var t : Array = tint()
	var col : Color = t[0]
	var amt : float = t[1]
	if spr.material == null and amt > 0.0:
		_tintMat = ShaderMaterial.new()
		_tintMat.shader = TINT_SHADER
		spr.material = _tintMat
	if _tintMat and spr.material == _tintMat:
		_tintMat.set_shader_parameter("tint_color", col)
		_tintMat.set_shader_parameter("tint_amount", amt)
		spr.self_modulate = Color.WHITE
	else:
		spr.self_modulate = Color.WHITE.lerp(col, amt)

# [colour, amount 0..1] for the strongest active status
func tint() -> Array:
	if fx.has("freeze"): return [TINT_FREEZE, 0.75]
	if fx.has("stun"): return [TINT_STUN, 0.25 + 0.4 * (0.5 + 0.5 * sin(_time * 28.0))]
	if fx.has("burn"): return [TINT_BURN, 0.5 + 0.12 * sin(_time * 17.0) + 0.08 * sin(_time * 41.0)]
	if fx.has("poison"): return [TINT_POISON, 0.35 + 0.05 * fx.poisonStacks]
	if fx.has("blind"): return [TINT_BLIND, 0.5]
	if fx.has("weaken"): return [TINT_WEAKEN, 0.55]
	if fx.has("chill"): return [TINT_CHILL, 0.5]
	if fx.has("sticky"): return [TINT_STICKY, 0.45]
	if fx.has("wet"): return [TINT_WET, 0.45]
	return [Color.WHITE, 0.0]

#region Emitters

func _make(status: String) -> CPUParticles2D:
	var w : float = _w
	var h : float = _h
	var p : CPUParticles2D
	match status:
		"burn":
			p = _particles(24, 0.7, GLOW, 7.0, true)
			p.position = _center + Vector2(0, h * 0.2)
			p.emission_rect_extents = Vector2(w * 0.32, h * 0.22)
			_motion(p, Vector2.UP, 15, Vector2(0, -90), 10, 24)
			p.scale_amount_curve = _curve([Vector2(0, 1), Vector2(1, 0.15)])
			p.color_ramp = _ramp([0.0, 0.35, 1.0], [Color(1, 0.95, 0.55, 1), Color(1, 0.45, 0.1, 0.9), Color(0.5, 0.08, 0.02, 0)])
		"wet":
			p = _particles(8, 0.7, GLOW, 4.0, false)
			p.emission_rect_extents = Vector2(w * 0.38, h * 0.3)
			_motion(p, Vector2.DOWN, 5, Vector2(0, 120), 0, 4)
			p.scale_amount_curve = _curve([Vector2(0, 1), Vector2(1, 0.6)])
			p.color_ramp = _ramp([0.0, 1.0], [Color(0.6, 0.8, 1, 1), Color(0.35, 0.55, 1, 0)])
		"chill":
			p = _particles(8, 1.2, GLOW, 3.5, true)
			p.emission_rect_extents = Vector2(w * 0.5, h * 0.45)
			_motion(p, Vector2.DOWN, 180, Vector2(0, 10), 0, 3)
			p.color_ramp = _ramp([0.0, 0.5, 1.0], [Color(0.85, 0.97, 1, 0), Color(0.85, 0.97, 1, 1), Color(0.85, 0.97, 1, 0)])
		"freeze":
			p = _particles(14, 0.9, GLOW, 5.0, true)
			p.emission_rect_extents = Vector2(w * 0.5, h * 0.45)
			_motion(p, Vector2.UP, 180, Vector2.ZERO, 0, 0)
			p.scale_amount_curve = _curve([Vector2(0, 0), Vector2(0.5, 1), Vector2(1, 0)])
			p.color_ramp = _ramp([0.0, 0.5, 1.0], [Color(0.8, 0.95, 1, 0.3), Color(0.9, 1, 1, 1), Color(0.8, 0.95, 1, 0.3)])
		"stun":
			# Sparks orbiting in a flattened ring around the top of the head
			p = _particles(4, 0.9, GLOW, 6.0, true)
			p.local_coords = true
			p.position = _center + Vector2(0, -h * 0.5)
			p.scale = Vector2(1, 0.45)
			p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RING
			var r : float = maxf(w * 0.4, 6.0)
			p.emission_ring_radius = r
			p.emission_ring_inner_radius = r
			_motion(p, Vector2.RIGHT, 0, Vector2.ZERO, 0, 0)
			p.orbit_velocity_min = 1.1
			p.orbit_velocity_max = 1.1
			p.explosiveness = 0.0
			p.color_ramp = _ramp([0.0, 0.2, 0.8, 1.0], [Color(1, 1, 0.5, 0), Color(1, 1, 0.5, 1), Color(1, 0.95, 0.3, 1), Color(1, 0.95, 0.3, 0)])
		"weaken":
			p = _particles(10, 1.1, GLOW, 7.0, false)
			p.position = _center - Vector2(0, h * 0.05)
			p.emission_rect_extents = Vector2(w * 0.4, h * 0.3)
			_motion(p, Vector2.DOWN, 15, Vector2(0, 30), 2, 6)
			p.scale_amount_curve = _curve([Vector2(0, 1), Vector2(1, 0.3)])
			p.color_ramp = _ramp([0.0, 1.0], [Color(0.65, 0.35, 1.0, 0.95), Color(0.15, 0.05, 0.25, 0)])
		"blind":
			p = _particles(7, 0.8, GLOW, 4.0, false)
			p.emission_rect_extents = Vector2(w * 0.38, h * 0.3)
			_motion(p, Vector2.DOWN, 5, Vector2(0, 100), 0, 4)
			p.scale_amount_curve = _curve([Vector2(0, 1), Vector2(1, 0.6)])
			p.color_ramp = _ramp([0.0, 1.0], [Color(0.8, 1, 0.25, 1), Color(0.45, 0.75, 0.1, 0)])
		"sticky":
			p = _particles(7, 1.0, GLOW, 5.0, false)
			p.position = _center + Vector2(0, h * 0.2)
			p.emission_rect_extents = Vector2(w * 0.42, h * 0.18)
			_motion(p, Vector2.DOWN, 5, Vector2(0, 45), 0, 2)
			p.scale_amount_curve = _curve([Vector2(0, 1), Vector2(1, 0.5)])
			p.color_ramp = _ramp([0.0, 1.0], [Color(0.55, 0.95, 0.35, 1), Color(0.3, 0.6, 0.2, 0)])
		"poison":
			# Puffs of the poison cloud sprite that swell as they rise and fade out
			p = _particles(8, 1.2, POISON_TEX, minf(POISON_TEX.get_width(), 8.0), false)
			p.position = _center - Vector2(0, h * 0.1)
			p.emission_rect_extents = Vector2(w * 0.4, h * 0.3)
			_motion(p, Vector2.UP, 25, Vector2(0, -20), 4, 10)
			p.scale_amount_curve = _curve([Vector2(0, 0.3), Vector2(0.6, 1), Vector2(1, 1)])
			p.color_ramp = _ramp([0.0, 0.15, 0.6, 1.0], [Color(1, 1, 1, 0), Color(1, 1, 1, 0.95), Color(1, 1, 1, 0.8), Color(1, 1, 1, 0)])
	return p

func _particles(amount: int, lifetime: float, tex: Texture2D, px: float, glow: bool) -> CPUParticles2D:
	var p : CPUParticles2D = CPUParticles2D.new()
	p.name = "StatusFx"
	p.amount = amount
	p.lifetime = lifetime
	p.texture = tex
	var s : float = px / float(maxi(tex.get_width(), 1))
	p.scale_amount_min = s * 0.7
	p.scale_amount_max = s
	p.local_coords = false   # trails behind a moving host
	p.emitting = false
	p.z_index = 1
	p.position = _center
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	if glow:
		var m : CanvasItemMaterial = CanvasItemMaterial.new()
		m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		p.material = m
	host.add_child(p)
	return p

func _motion(p: CPUParticles2D, dir: Vector2, spread: float, gravity: Vector2, vMin: float, vMax: float) -> void:
	p.direction = dir
	p.spread = spread
	p.gravity = gravity
	p.initial_velocity_min = vMin
	p.initial_velocity_max = vMax

static func _ramp(offsets: Array, colors: Array) -> Gradient:
	var g : Gradient = Gradient.new()
	g.offsets = PackedFloat32Array(offsets)
	g.colors = PackedColorArray(colors)
	return g

static func _curve(points: Array) -> Curve:
	var c : Curve = Curve.new()
	for pt in points: c.add_point(pt)
	return c

#endregion

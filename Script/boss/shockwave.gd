extends Node2D
class_name Shockwave

# Ring that expands along the ground from a body slam. It hurts the player once as it passes
# over them, unless they're rolling (roll through it) or already outside its reach (get away).
# The ring is drawn squashed (GROUND_SQUASH) to sit flat on the top-down ground, and the hit test
# uses the same ellipse.

const GROUND_SQUASH : float = 0.6

var source : Node = null        # who gets credit for the hit
var damage : float = 15.0
var knockback : float = 80.0
var speed : float = 360.0       # px/s the ring grows
var maxRadius : float = 260.0
var thickness : float = 18.0    # width of the band that hurts
var color : Color = Color(1.0, 0.85, 0.6)
var hurtsPlayer : bool = true
var pushGroups : Array[String] = ["evil_roaches"] # things shoved outward (no damage)

var radius : float = 6.0
var _hitPlayer : bool = false
var _pushed : Dictionary = {}
var _dust : CPUParticles2D = null

func _ready() -> void:
	z_index = 6 # above the tree canopy (5) so it can always be seen coming
	z_as_relative = false
	_dust = CPUParticles2D.new()
	_dust.amount = 40
	_dust.lifetime = 0.6
	_dust.one_shot = true
	_dust.explosiveness = 1.0
	_dust.local_coords = false
	_dust.texture = preload("uid://oyvy6kab4ex8")
	_dust.emission_shape = CPUParticles2D.EMISSION_SHAPE_RING
	_dust.emission_ring_radius = 18.0
	_dust.emission_ring_inner_radius = 10.0
	_dust.scale = Vector2(1, GROUND_SQUASH)
	_dust.direction = Vector2.RIGHT
	_dust.spread = 180
	_dust.gravity = Vector2.ZERO
	_dust.initial_velocity_min = 60
	_dust.initial_velocity_max = 140
	_dust.damping_min = 120
	_dust.damping_max = 180
	_dust.scale_amount_min = 0.08
	_dust.scale_amount_max = 0.16
	var g : Gradient = Gradient.new()
	g.colors = PackedColorArray([Color(0.75, 0.68, 0.55, 0.8), Color(0.5, 0.45, 0.38, 0)])
	_dust.color_ramp = g
	add_child(_dust)
	_dust.emitting = true

func _ellipseDist(p: Vector2) -> float:
	var d : Vector2 = p - global_position
	return Vector2(d.x, d.y / GROUND_SQUASH).length()

func _process(delta: float) -> void:
	if get_tree().paused: return
	radius += speed * delta
	
	var band : float = thickness * 0.5 + 6.0
	var p : Node = Global.player
	if hurtsPlayer and not _hitPlayer and is_instance_valid(p) and not p.is_dead:
		var d : float = _ellipseDist(p.global_position)
		if absf(d - radius) <= band and not p.is_rolling:
			_hitPlayer = true
			p.take_damage({"value": damage, "physical": damage, "isCrit": false, "kind": "melee"}, source)
			Knockback.apply(p, p.global_position - global_position, knockback, null)
	
	for grp in pushGroups:
		for b in get_tree().get_nodes_in_group(grp):
			if _pushed.has(b) or not is_instance_valid(b): continue
			if absf(_ellipseDist(b.global_position) - radius) <= band:
				_pushed[b] = true
				Knockback.apply(b, b.global_position - global_position, knockback, null)
	
	if radius >= maxRadius:
		if _dust and not _dust.emitting: queue_free()
		elif radius >= maxRadius + 120.0: queue_free()
	queue_redraw()

func _draw() -> void:
	var f : float = clampf(radius / maxRadius, 0.0, 1.0)
	if f >= 1.0: return
	var c : Color = color
	c.a = (1.0 - f) * 0.85
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, GROUND_SQUASH))
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 72, c, thickness * (1.0 - f * 0.5), true)
	var inner : Color = Color(1, 1, 1, c.a * 0.6)
	draw_arc(Vector2.ZERO, radius - thickness * 0.35, 0.0, TAU, 72, inner, 2.0, true)

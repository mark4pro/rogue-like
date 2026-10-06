extends Line2D

var weapSys : WeaponSys = null

var t : float = 0

#region Hit sparks
## Spark colour where the beam hits. Leave alpha at 0 to use the beam's own colour.
@export var sparkColor : Color = Color(0, 0, 0, 0)
const SPARK_INTERVAL : float = 0.07   # seconds between spark bursts while the beam touches something
const SPARK_AMOUNT : int = 8
var _sparkScene : PackedScene = preload("uid://ddtkbysspg0ai")
var _sparkMat : ParticleProcessMaterial = null
var _sparkT : float = 0.0

func beamColor() -> Color:
	var c : Color = sparkColor
	if c.a == 0.0:
		c = gradient.get_color(gradient.get_point_count() - 1) if gradient else default_color
	# Full brightness, full alpha (the beam itself is drawn see-through)
	var m : float = maxf(maxf(c.r, c.g), maxf(c.b, 0.001))
	return Color(c.r / m, c.g / m, c.b / m, 1.0)

func _buildSparkMat(proto: ParticleProcessMaterial) -> void:
	_sparkMat = proto.duplicate()
	var c : Color = beamColor()
	var g : Gradient = Gradient.new()
	g.colors = PackedColorArray([c.lightened(0.15), c.lightened(0.65)])
	var tex : GradientTexture1D = GradientTexture1D.new()
	tex.gradient = g
	_sparkMat.color_ramp = tex

# Called by WeaponSys every frame the full-length beam ends on something
func spark(pos: Vector2, normal: Vector2) -> void:
	if _sparkT > 0.0 or not Global.currentScene: return
	_sparkT = SPARK_INTERVAL
	var s : GPUParticles2D = _sparkScene.instantiate()
	if not _sparkMat: _buildSparkMat(s.process_material)
	s.process_material = _sparkMat
	s.amount = SPARK_AMOUNT
	s.rotation = normal.angle()
	s.global_position = pos
	Global.currentScene.add_child(s)
	s.emitting = true
#endregion

func damage(target: Node) -> void:
	if t == 1:
		target.take_damage(weapSys.genDamage(), weapSys.parentNode)
		
		if target is RigidBody2D:
			# Along the beam
			var knBckDir : Vector2 = to_global(points[-1]) - global_position
			Knockback.apply(target, knBckDir, weapSys.weapon.knockback, weapSys.parentNode)
		
		t = 0

func _ready() -> void:
	t = randf()

func _process(delta: float) -> void:
	_sparkT -= delta
	if weapSys:
		if weapSys.isAttacking and weapSys.t != 0:
			t = min(t + (weapSys.laserTickSpeed() * delta * randf()), 1)
		if not weapSys.isAttacking or weapSys.t == 0:
			t = randf()

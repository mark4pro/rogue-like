extends RigidBody2D
class_name EvilRoach

# Evil roaches repair the broken Robotic Spider Eye: they run to a scrap piece, carry it back to the
# eye and drop it in, over and over, until the eye wakes up (BossSite runs the show).
# They can't be killed and ignore the player. Hits shove them around and show "Immune".

const TEXTURE : Texture2D = preload("uid://chqenit07ckid") # 2 frames, faces right

enum Job { FETCH, CARRY, IDLE, FLEE }

var site : Node = null           # BossSite
var job : int = Job.IDLE
var targetPiece : Node2D = null
var carried : Sprite2D = null
var speed : float = 42.0

var sprite : Sprite2D = null
var knockbackVelocity : Vector2 = Vector2.ZERO
var knockbackWeight : float = 0.6
var _animT : float = 0.0
var _wiggle : float = randf() * TAU
var _immuneCooldown : float = 0.0
var _idleT : float = 0.0
var _fleeT : float = 0.0
var _fleeDir : Vector2 = Vector2.RIGHT

func _ready() -> void:
	gravity_scale = 0.0
	lock_rotation = true
	collision_layer = 4 # enemy layer, so player attacks hit (and get "Immune")
	collision_mask = 0  # scurries over everything
	add_to_group("evil_roaches")
	add_to_group("tree_cutout")
	
	sprite = Sprite2D.new()
	sprite.texture = TEXTURE
	sprite.hframes = 2
	sprite.offset = Vector2(0, -6)
	add_child(sprite)
	
	var shadow : Sprite2D = Sprite2D.new()
	shadow.texture = preload("uid://b70aujp6bewbx")
	shadow.modulate = Color(1, 1, 1, 0.35)
	shadow.show_behind_parent = true
	shadow.scale = Vector2(0.45, 0.2)
	shadow.position = Vector2(0, 1)
	add_child(shadow)
	
	var shape : CollisionShape2D = CollisionShape2D.new()
	var circle : CircleShape2D = CircleShape2D.new()
	circle.radius = 6.0
	shape.shape = circle
	shape.position = Vector2(0, -5)
	add_child(shape)

func take_damage(_data: Dictionary, _attacker: Node) -> void:
	if _immuneCooldown > 0.0 or not Global.damNum or not Global.currentScene: return
	_immuneCooldown = 0.4
	var l : Label = Global.damNum.instantiate()
	l.text = "Immune"
	l.add_theme_font_size_override("font_size", 8)
	l.add_theme_color_override("font_color", Color(0.75, 0.75, 0.75))
	l.position = global_position + Vector2(randf_range(-4, 4), -16)
	Global.currentScene.add_child(l)

func applyHitstun(_s: float) -> void:
	pass

# Run off and vanish (the eye woke up)
func flee(from: Vector2) -> void:
	job = Job.FLEE
	_fleeT = 0.0
	_fleeDir = (global_position - from).normalized()
	if _fleeDir == Vector2.ZERO: _fleeDir = Vector2.RIGHT.rotated(randf() * TAU)
	dropPiece()

func pickUp(piece: Node2D) -> void:
	if not is_instance_valid(piece): return
	piece.get_parent().remove_child(piece)
	add_child(piece)
	piece.position = Vector2(0, -12)
	piece.rotation = 0.0
	carried = piece
	targetPiece = null
	job = Job.CARRY

func dropPiece() -> void:
	if carried and is_instance_valid(carried):
		carried.queue_free()
	carried = null

func _physics_process(delta: float) -> void:
	if get_tree().paused: return
	_immuneCooldown = maxf(_immuneCooldown - delta, 0.0)
	var walk : Vector2 = Vector2.ZERO
	
	match job:
		Job.FETCH:
			if not is_instance_valid(targetPiece):
				job = Job.IDLE
			else:
				walk = _toward(targetPiece.global_position)
				if global_position.distance_to(targetPiece.global_position) < 6.0:
					pickUp(targetPiece)
		Job.CARRY:
			if not site or not is_instance_valid(site):
				job = Job.IDLE
			else:
				var dropAt : Vector2 = site.dropPoint(self)
				walk = _toward(dropAt)
				if global_position.distance_to(dropAt) < 8.0:
					dropPiece()
					site.delivered(self)
					job = Job.IDLE
					_idleT = randf_range(0.3, 1.0)
		Job.IDLE:
			_idleT -= delta
			if _idleT <= 0.0 and site and is_instance_valid(site):
				targetPiece = site.claimPiece(self)
				if targetPiece: job = Job.FETCH
				else: _idleT = 0.5
		Job.FLEE:
			_fleeT += delta
			walk = _fleeDir * speed * 1.8
			sprite.modulate.a = clampf(1.0 - (_fleeT - 1.5), 0.0, 1.0)
			if _fleeT > 2.6: queue_free()
	
	linear_velocity = walk + knockbackVelocity
	knockbackVelocity *= pow(Global.KNOCKBACK_DECAY, delta)
	
	# Scuttle animation and facing
	if walk.length() > 1.0:
		_animT += delta
		if _animT > 0.07:
			_animT = 0.0
			sprite.frame = (sprite.frame + 1) % 2
		sprite.flip_h = walk.x < 0.0

# Wobbly path toward a point, like a bug
func _toward(p: Vector2) -> Vector2:
	var d : Vector2 = p - global_position
	if d.length() < 1.0: return Vector2.ZERO
	_wiggle += get_physics_process_delta_time() * 9.0
	return d.normalized().rotated(sin(_wiggle) * 0.35) * speed

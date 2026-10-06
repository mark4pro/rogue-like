extends RefCounted
class_name Knockback

# One place for every knockback hit (swords, bullets, lasers, thrown things).
#
# A weapon's `knockback` stat goes through a diminishing curve (scaledForce), gets the attacker's
# knockback-dealt bonus (Strength), then is reduced by the target's
# knockback resistance (armour, later Vitality; capped at 80%) and divided by its weight
# (heavy enemies barely move, light ones fly).
#
# Big hits also cause hitstun (target can't move or attack for a moment), and a target
# knocked into a wall fast enough takes slam damage.
#
# Targets opt in by having `knockbackVelocity`. Optional on the target:
#   getKnockbackResist() -> float (0..1), knockbackWeight : float,
#   applyHitstun(seconds), and the wall slam vars (see Knockback.armSlam / checkSlam)

# Force (px/s) = FORCE_SCALE * knockback ^ FORCE_EXPONENT, so strong weapons still hit harder
# but don't explode (rolled knockback can reach 100+). Approx: 10 -> 79, 20 -> 132, 50 -> 263, 120 -> 506
const FORCE_SCALE : float = 14.0
const FORCE_EXPONENT : float = 0.75
const RESIST_CAP : float = 0.8

const HITSTUN_MIN_FORCE : float = 220.0  # px/s after resist/weight; smaller hits don't stun
const HITSTUN_PER_FORCE : float = 0.0007 # seconds of stun per px/s
const HITSTUN_MAX : float = 0.5

const SLAM_MIN_SPEED : float = 180.0     # knockback speed needed to count as a slam
const SLAM_DAMAGE_PER_SPEED : float = 0.05
const SLAM_MAX_DAMAGE : float = 40.0
const SLAM_BOUNCE : float = 0.3          # how much velocity is kept (reversed) after a slam

static func apply(target: Node, dir: Vector2, baseForce: float, attacker: Node = null) -> void:
	if not is_instance_valid(target) or not "knockbackVelocity" in target or baseForce <= 0:
		return
	if dir == Vector2.ZERO: return
	
	var resist : float = 0.0
	if target.has_method("getKnockbackResist"):
		resist = clampf(target.getKnockbackResist(), 0.0, RESIST_CAP)
	var weight : float = 1.0
	if "knockbackWeight" in target:
		weight = maxf(target.knockbackWeight, 0.1)
	
	# Attacker bonus (the player's Strength)
	var dealt : float = 1.0
	if is_instance_valid(attacker) and attacker.has_method("knockbackDealtMult"):
		dealt = attacker.knockbackDealtMult()
	
	var force : float = scaledForce(baseForce) * dealt * (1.0 - resist) / weight
	target.knockbackVelocity += dir.normalized() * force
	
	if force >= HITSTUN_MIN_FORCE and target.has_method("applyHitstun"):
		target.applyHitstun(minf(force * HITSTUN_PER_FORCE, HITSTUN_MAX))
	
	if "slamArmed" in target:
		target.slamArmed = true
		target.slamAttacker = attacker

static func scaledForce(knockbackStat: float) -> float:
	return FORCE_SCALE * pow(maxf(knockbackStat, 0.0), FORCE_EXPONENT)

# Call from the target's _physics_process. Needs contact_monitor on the body.
# Anything that isn't another moving body (walls, tilemaps, static props) counts as a wall.
static func checkSlam(body: RigidBody2D) -> void:
	if not body.slamArmed: return
	var speed : float = body.knockbackVelocity.length()
	if speed < SLAM_MIN_SPEED:
		body.slamArmed = false
		return
	
	for other in body.get_colliding_bodies():
		if other is RigidBody2D or other is CharacterBody2D: continue
		var dmg : float = minf(speed * SLAM_DAMAGE_PER_SPEED, SLAM_MAX_DAMAGE)
		body.slamArmed = false
		body.knockbackVelocity = -body.knockbackVelocity * SLAM_BOUNCE
		if body.has_method("take_damage"):
			var attacker : Node = body.slamAttacker if is_instance_valid(body.slamAttacker) else null
			body.take_damage({"value": dmg, "isCrit": false, "slam": true}, attacker)
		return

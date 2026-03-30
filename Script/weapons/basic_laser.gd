extends Line2D

var weapSys : WeaponSys = null

var t : float = 0

func damage(target: Node) -> void:
	if t == 1:
		target.take_damage(weapSys.weapon.genDamage(), weapSys.parentNode)
		
		if target is RigidBody2D:
			var knBckDir : Vector2 = (target.global_position - to_global(points[-1])).normalized()
			if "knockbackVelocity" in target:
				target.knockbackVelocity += knBckDir * weapSys.weapon.knockback
		
		t = 0

func _ready() -> void:
	t = randf()

func _process(delta: float) -> void:
	if weapSys:
		if weapSys.isAttacking and weapSys.t != 0:
			t = min(t + (weapSys.weapon.laserAttackSpeed * delta * randf()), 1)
		if not weapSys.isAttacking or weapSys.t == 0:
			t = randf()

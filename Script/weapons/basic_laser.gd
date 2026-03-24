extends Line2D

var weapSys : WeaponSys = null

var t : float = 0

func damage(target: Node) -> void:
	if t >= weapSys.weapon.laserAttackSpeed:
		target.take_damage(weapSys.weapon.genDamage(), weapSys.parentNode)
		t = randf()

func _ready() -> void:
	t = randf()

func _process(delta: float) -> void:
	if weapSys:
		if weapSys.isAttacking and weapSys.t != 0:
			t += delta * randf()
		if not weapSys.isAttacking or weapSys.t == 0:
			t = randf()

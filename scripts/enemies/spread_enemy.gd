class_name SpreadEnemy
extends RangedEnemy
## Enemigo común (antiguo jefe del nivel 1), rediseñado en 2026-11-11 como
## arquero con arco: dispara una sola flecha algo más rápida que la bola de
## fuego del mago.
## Cambio 2026-11: los jefes dejaron de bloquear el portal y se convirtieron
## en enemigos comunes que aparecen repartidos en los tres niveles.
## Cambio 2026-11-11 (visuales): ya no dispara abanicos de virotes; lanza una
## flecha horizontal por disparo (el abanico queda para el mago).


func _shoot(direction: float) -> void:
	# Flecha única: mismo origen y lógica horizontal, pero un solo proyectil.
	var projectile := PROJECTILE_SCENE.instantiate()
	_projectile_parent().add_child(projectile)
	projectile.global_position = global_position + Vector2(direction * 40.0, -18.0)
	projectile.direction = direction
	projectile.speed = projectile_speed
	projectile.damage = 18
	projectile.velocity = Vector2(direction, 0.0) * projectile_speed
	projectile.rotation = 0.0 if direction > 0.0 else PI
	projectile.use_bolt_style()

	Sfx.play("arrow", -8.0)

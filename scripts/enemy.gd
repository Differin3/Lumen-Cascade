extends CharacterBody2D

const SPEED = 150
const BOOST_MULT := 1.5 # как в фоне при boost
var hp := 5
var is_dead = false  # Флаг для отслеживания состояния смерти

func _ready():
	# Сложность из удалённой конфигурации (флаг enemy_hp в Консоли Яндекс Игр)
	var cfg: Dictionary = {}
	var rc = get_node_or_null("/root/RemoteConfig")
	if rc != null and "flags" in rc:
		cfg = rc.flags
	if cfg.size() > 0:
		var v: String = str(cfg.get("enemy_hp", "5"))
		hp = int(v) if v.is_valid_int() else 5
	hp = maxi(1, hp)
	set_as_top_level(true)
	add_to_group("enemies")

func _physics_process(delta):
	# Враг продолжает двигаться даже во время анимации смерти
	var spd := float(SPEED)
	if Input.is_action_pressed("boost"):
		spd *= BOOST_MULT
	position += Vector2.DOWN * spd * delta
	
	# Удаляем если ушёл за экран
	if position.y > get_viewport_rect().size.y + 50:
		queue_free()

func take_damage(damage = 1):
	if is_dead:
		return  # Игнорируем урон если уже мертвы
	
	hp -= damage
	
	# Визуальный эффект попадания
	$AnimatedSprite2D.modulate = Color.RED
	await get_tree().create_timer(0.1).timeout
	$AnimatedSprite2D.modulate = Color.WHITE
	
	if hp <= 0:
		destroy()

func destroy():
	is_dead = true
	
	# Отключаем коллизию
	$CollisionShape2D.set_deferred("disabled", true)
	
	# Запускаем анимацию смерти
	$AnimatedSprite2D.play("kill")
	
	# Ждем завершения анимации
	await $AnimatedSprite2D.animation_finished
	
	# Начисляем очки после анимации
	if get_parent().has_method("update_score"):
		get_parent().update_score(100)
	
	queue_free()

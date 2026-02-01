extends Area2D

const SPEED = 150
const BOOST_MULT := 1.5 # как в фоне при boost
var is_dead = false

func _ready():
	# Подключаем сигнал area_entered
	connect("area_entered", _on_area_entered)

func _physics_process(delta):
	if is_dead:
		return
	
	var spd := float(SPEED)
	if Input.is_action_pressed("boost"):
		spd *= BOOST_MULT
	position += Vector2.DOWN * spd * delta
	$AnimatedSprite2D.play("default")
	
	# Удаляем если вышли за пределы экрана
	if position.y > get_viewport_rect().size.y + 50:
		queue_free()

func _on_area_entered(area):
	if not is_dead:
		# Проверяем, что столкнулись с игроком
		if area.get_parent().has_method("activateShield_Buff"):
			# Вызываем функцию активации бафа у игрока
			area.get_parent().activateShield_Buff()
			
			# Помечаем баф как подобранный и скрываем
			is_dead = true
			$CollisionShape2D.set_deferred("disabled", true)
			$AnimatedSprite2D.visible = false
			
			# Удаляем баф через небольшой промежуток времени
			await get_tree().create_timer(0.1).timeout
			queue_free()

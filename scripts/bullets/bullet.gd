extends Area2D

const SPEED = 100
var direction = Vector2.UP
var damage = 8
func _ready():
	# Отслеживаем столкновения
	body_entered.connect(_on_body_entered)
	set_as_top_level(true)
	$AnimatedSprite2D.play("flight")
func _physics_process(delta):
	position += direction * SPEED * delta
	# Удаляем пулю, если она вышла за пределы экрана
	if position.y < -100:
		queue_free()
	
# Обработчик столкновения
func _on_body_entered(body):
	if body.is_in_group("enemies"):
		body.take_damage(damage)  # Наносим урон врагу
		queue_free()  # Уничтожаем пулю

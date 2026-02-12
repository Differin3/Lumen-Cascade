extends CharacterBody2D

signal destroyed

# Настройки
const NORMAL_SPEED = 300
const BOOST_SPEED = 500
const SHOOT_DELAY = 0.15
const ROCKET_BURST_DELAY = 0.5
const ACCELERATION = 15.0  # скорость ускорения
const FRICTION = 12.0  # скорость торможения

var current_speed = NORMAL_SPEED
var can_shoot = true
var can_boost_shoot = true
var screen_size
var margin = 10
var hp = 4
var is_invulnerable = false
var invulnerability_time = 0.5
var is_alive = true
var is_entering = false  # флаг для блокировки управления во время анимации появления
var rocket_buff = false  # Изначально баф выключен (ракеты)
var Shield_Buff = false # изначально баф щита выключен (щит)
var shield_timer: Timer = null  # таймер для щита
var shield_duration = 60.0  # длительность щита в секундах
var shield_reduce_time = 20.0  # на сколько уменьшается время при столкновении
var touch_drag_id := -1  # id пальца для перетаскивания
var touch_target_pos := Vector2.ZERO  # целевая позиция для touch drag
var mobile_boost := false  # активация буста через двойной тап и удержание
var last_tap_time := 0.0  # время последнего тапа для двойного тапа
var tap_position := Vector2.ZERO  # позиция последнего тапа
var double_tap_timeout := 0.3  # таймаут для двойного тапа (секунды)
var boost_touch_id := -1  # id пальца, который активировал буст
var touch_start_pos := Vector2.ZERO  # начальная позиция тапа для определения жестов
var swipe_threshold := 50.0  # минимальное расстояние для свайпа
var rocket_swipe_used := false  # чтобы ракеты сработали один раз за удержание

func is_boosting() -> bool:  # единая точка правды для буста (клава+тач)
	return Input.is_action_pressed("boost") or Input.is_key_pressed(KEY_SHIFT) or mobile_boost

func _ready():
	screen_size = get_viewport_rect().size
	update_animation()
	update_animation_engine()
	
	
	# Создаем область для подбора бафов
	var pickup_area = Area2D.new()
	pickup_area.name = "PickupArea"
	var collision = CollisionShape2D.new()
	var shape = RectangleShape2D.new()
	shape.extents = Vector2(30, 30)  # Размер области подбора
	collision.shape = shape
	pickup_area.add_child(collision)
	add_child(pickup_area)
	$rockets.frame = 15
	# Создаём таймер для щита
	shield_timer = Timer.new()
	shield_timer.wait_time = shield_duration
	shield_timer.one_shot = true
	shield_timer.autostart = false
	if not shield_timer.timeout.is_connected(_on_shield_timeout):
		shield_timer.timeout.connect(_on_shield_timeout)
	add_child(shield_timer)
	# Добавляем игрока в группу для обнаружения
	add_to_group("player")
	# Обновляем состояние UI по бафу ракет
	_update_rocket_ui()

func _physics_process(delta):
	if not is_alive:
		return
	
	# Обновляем полоску щита в реальном времени
	if Shield_Buff and shield_timer and shield_timer.time_left > 0:
		var hud = get_tree().get_first_node_in_group("hud")
		if hud:
			var shield_value = int(shield_timer.time_left)  # прямое значение времени в секундах
			hud.set_shield(shield_value)
	
	# Блокируем управление во время анимации появления
	if is_entering:
		# Во время анимации только обновляем анимацию двигателя
		update_animation_engine()
		return
	
	# Ускорение через action/Shift/тач (см. is_boosting)
	var boosting := is_boosting()
	current_speed = BOOST_SPEED if boosting else NORMAL_SPEED 
	update_animation_engine()
	
	# Вычисляем целевую скорость
	var target_velocity := Vector2.ZERO
	
	# Управление WASD/геймпад
	var input_dir = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	if input_dir.length() > 0:
		target_velocity = input_dir * current_speed
	
	# Touch drag управление
	if touch_drag_id >= 0:
		var direction = (touch_target_pos - position)
		var distance = direction.length()
		if distance > 5.0:  # минимальное расстояние для движения
			# При бусте используем полную скорость, иначе плавное приближение
			var move_speed = current_speed if boosting else min(distance * 8.0, current_speed)
			target_velocity = direction.normalized() * move_speed
		else:
			target_velocity = Vector2.ZERO
	
	# Плавная интерполяция скорости (ускорение/торможение)
	if target_velocity.length() > 0:
		velocity = velocity.lerp(target_velocity, ACCELERATION * delta)
	else:
		velocity = velocity.lerp(Vector2.ZERO, FRICTION * delta)
	
	# Ограничение в рамках экрана с отступами
	move_and_slide()
	var new_position = position
	new_position.x = clamp(new_position.x, margin, screen_size.x - margin)
	new_position.y = clamp(new_position.y, margin, screen_size.y - margin)
	position = new_position
	
	# Проверяем столкновения с врагами
	check_collisions()
	
	# Стрельба: ЛКМ на ПК или удержание пальца движения на мобиле (пока корабль реально двигается)
	var touch_moving := touch_drag_id >= 0 and ((touch_target_pos - position).length() > 5.0 or velocity.length() > 0.1)
	if (Input.is_action_pressed("shoot") or touch_moving) and can_shoot:
		shoot()
		can_shoot = false
		await get_tree().create_timer(SHOOT_DELAY).timeout
		can_shoot = true
		
	# Специальная стрельба на LMB (левая кнопка мыши)
	if Input.is_action_pressed("lcm"):
		await try_fire_rockets()

func set_entering(value: bool) -> void:  # установка флага анимации появления
	is_entering = value

# Тач обрабатываем в _input и accept_event — иначе на iOS события съедаются браузером/нодами
func _input(event: InputEvent) -> void:
	if not is_alive or is_entering:
		return
	if event is InputEventScreenTouch:
		var e := event as InputEventScreenTouch
		if e.pressed:
			var current_time := Time.get_ticks_msec() / 1000.0
			var distance: float = e.position.distance_to(tap_position)
			if current_time - last_tap_time < double_tap_timeout and distance < 80.0:
				mobile_boost = true
				boost_touch_id = e.index
			if touch_drag_id == -1:
				touch_drag_id = e.index
				touch_start_pos = e.position
				rocket_swipe_used = false
			var clamped_pos := Vector2(
				clamp(e.position.x, margin, screen_size.x - margin),
				clamp(e.position.y, margin, screen_size.y - margin)
			)
			touch_target_pos = clamped_pos
			last_tap_time = current_time
			tap_position = e.position
		else:
			if e.index == touch_drag_id:
				touch_drag_id = -1
				rocket_swipe_used = false
			if e.index == boost_touch_id:
				mobile_boost = false
				boost_touch_id = -1
		get_viewport().set_input_as_handled()
	elif event is InputEventScreenDrag:
		var e := event as InputEventScreenDrag
		if e.index == touch_drag_id:
			var clamped_pos := Vector2(
				clamp(e.position.x, margin, screen_size.x - margin),
				clamp(e.position.y, margin, screen_size.y - margin)
			)
			touch_target_pos = clamped_pos
			if mobile_boost and e.index == boost_touch_id:
				mobile_boost = true
			var swipe: Vector2 = e.position - touch_start_pos
			if not rocket_swipe_used and swipe.y < -swipe_threshold and abs(swipe.x) < swipe_threshold and rocket_buff and can_boost_shoot:
				rocket_swipe_used = true
				await try_fire_rockets()
		get_viewport().set_input_as_handled()

func shoot():
	if not is_alive:
		return
	else:
		# Обычная стрельба - по одной ракете из каждого узла
		var bullet1 = preload("res://scenes/bullets/big_space_gun.tscn").instantiate()
		bullet1.position = $Muzzle3.global_position
		get_parent().add_child(bullet1)

# Запуск очереди из 3 ракет с каждого узла
func start_rocket_burst():
	rocket_burst_sequence()

# Общий метод для запуска ракет (из ввода и из UI)
func try_fire_rockets() -> void:
	if not is_alive:
		return
	if not rocket_buff or not can_boost_shoot:
		return
	# Запускаем залп ракет
	start_rocket_burst()
	$rockets.frame = 0
	rocket_buff = false
	$rockets.play("rockets")
	can_boost_shoot = false
	_update_rocket_ui()
	await get_tree().create_timer(SHOOT_DELAY).timeout
	can_boost_shoot = true

func rocket_burst_sequence():
	for i in range(3):
		# Запуск из первого узла (Muzzle)
		var bullet1 = preload("res://scenes/bullets/bullet_rocket.tscn").instantiate()
		bullet1.position = $Muzzle.global_position
		get_parent().add_child(bullet1)
		
		# Запуск из второго узла (Muzzle2)
		var bullet2 = preload("res://scenes/bullets/bullet_rocket.tscn").instantiate()
		bullet2.position = $Muzzle2.global_position
		get_parent().add_child(bullet2)
		
		# Воспроизводим звук и анимацию только для первого выстрела в очереди
		if i == 0:
			$rockets.play("rockets")
		
		# Ждем перед следующим выстрелом в очереди (кроме последнего)
		if i < 2:
			await get_tree().create_timer(ROCKET_BURST_DELAY).timeout

# Проверка столкновений с врагами
func check_collisions():
	if not is_alive:
		return
	
	for i in get_slide_collision_count():
		var collision = get_slide_collision(i)
		var collider = collision.get_collider()
		
		# Если столкнулись с врагом
		if collider and collider.is_in_group("enemies"):
			# Если активен щит - уменьшаем время и не получаем урон
			if Shield_Buff and shield_timer:
				var current_time = shield_timer.time_left if shield_timer.time_left > 0 else shield_timer.wait_time
				var new_time = current_time - shield_reduce_time
				if new_time <= 0:
					# Время щита истекло - деактивируем
					_on_shield_timeout()
				else:
					# Уменьшаем время щита
					shield_timer.stop()
					shield_timer.wait_time = new_time
					shield_timer.start()  # Перезапускаем с новым временем
					# Обновляем HUD полоску щита
					var hud = get_tree().get_first_node_in_group("hud")
					if hud:
						var shield_value = int(new_time)  # прямое значение времени в секундах
						hud.set_shield(shield_value)
				# Уничтожаем врага
				if collider.has_method("destroy"):
					collider.destroy()
				return
			
			# Проверяем, не неуязвим ли игрок
			if is_invulnerable:
				return
				
			take_damage(1)
			# Уничтожаем врага при столкновении
			if collider.has_method("destroy"):
				collider.destroy()
			
func take_damage(damage = 1):
	if not is_alive or is_invulnerable:
		return
		
	# Включаем неуязвимость СРАЗУ при получении урона
	is_invulnerable = true
	
	# Усиливаем экранный сдвиг при серии урона
	var main = get_parent()
	if main and main.has_method("add_damage_fx"):
		main.add_damage_fx(0.7)
	
	hp -= damage
	
	# Обновляем анимацию в зависимости от HP
	update_animation()
	# Обновляем HUD полоску здоровья с анимацией
	var hud = get_tree().get_first_node_in_group("hud")
	if hud:
		hud.animate_hp_decrease(hp, 1.5)  # плавная анимация уменьшения здоровья (увеличена длительность для плавности)
	
	# Визуальный эффект получения урона
	$AnimatedSprite2D.modulate = Color.RED
	var timer = get_tree().create_timer(0.1)
	await timer.timeout
	$AnimatedSprite2D.modulate = Color.WHITE
	
	# Мигание спрайта во время неуязвимости
	start_invulnerability_effect()
	
	# Ждем окончания неуязвимости
	await get_tree().create_timer(invulnerability_time).timeout
	if not is_alive:
		return
	is_invulnerable = false
	$AnimatedSprite2D.modulate.a = 1.0
	
	if hp <= 0:
		destroy()

# Обновление анимации в зависимости от HP
func update_animation():
	if hp == 4:
		$AnimatedSprite2D.play("100 hp")
	elif hp == 3:
		$AnimatedSprite2D.play("70 hp")
	elif hp == 2:
		$AnimatedSprite2D.play("50 hp")
	elif hp == 1:
		$AnimatedSprite2D.play("30 hp")
func update_animation_engine():
	if current_speed == BOOST_SPEED:
		$engine.play("ran")
	else:
		$engine.play("slowly")
# Эффект мигания во время неуязвимости
func start_invulnerability_effect():
	var tween = create_tween()
	tween.tween_method(set_alpha, 1.0, 0.0, 0.1)
	tween.tween_method(set_alpha, 0.0, 1.0, 0.1)
	tween.set_loops(5)  # 5 циклов мигания

func set_alpha(value: float):
	$AnimatedSprite2D.modulate.a = value

func destroy():
	if not is_alive:
		return
	
	is_alive = false
	
	# Отключаем коллизию
	$CollisionShape2D.set_deferred("disabled", true)

	destroyed.emit()

	# Можно добавить анимацию смерти перед удалением
	await get_tree().create_timer(0.5).timeout
	queue_free()

# Функция для активации бафа ракет (вызывается при подбое бафа)
func activate_rocket_buff():
	$rockets.frame = 0
	rocket_buff = true
	_update_rocket_ui()
	if can_boost_shoot:
		await try_fire_rockets()  # сразу запускаем залп при подборе бафа
# Функция для активации бафа шита (вызывается при подбое бафа)
func activate_shield_buff():
	Shield_Buff = true
	if has_node("shield"):
		$shield.visible = true
		$shield.play("shield")
	
	# Запускаем таймер щита
	if shield_timer:
		shield_timer.wait_time = shield_duration
		shield_timer.start()
		# Анимируем заполнение полоски щита
		var hud = get_tree().get_first_node_in_group("hud")
		if hud:
			hud.animate_shield_fill(60, 0.5)  # анимация заполнения до 60 за 0.5 сек

# Функция деактивации щита (вызывается по таймеру)
func _on_shield_timeout():
	if not Shield_Buff:
		return  # Уже деактивирован
	
	Shield_Buff = false
	if shield_timer:
		shield_timer.stop()  # Останавливаем таймер
	if has_node("shield"):
		$shield.visible = false
		$shield.stop()
	
	# Обновляем HUD полоску щита (устанавливаем в 0)
	var hud = get_tree().get_first_node_in_group("hud")
	if hud:
		hud.set_shield(0)

func _update_rocket_ui() -> void:
	var hud = get_tree().get_first_node_in_group("hud")
	if hud and hud.has_method("set_rocket_buff_active"):
		hud.set_rocket_buff_active(rocket_buff)


func set_mobile_boost(active: bool) -> void:
	mobile_boost = active

	

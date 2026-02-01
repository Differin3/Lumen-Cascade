extends Camera2D  # плавное следование камеры за игроком

const FOLLOW_SPEED = 5.0  # скорость следования (чем больше, тем быстрее)

func _ready():
	# Ограничиваем камеру границами экрана
	var viewport_size = get_viewport_rect().size
	limit_left = 0
	limit_right = int(viewport_size.x)
	limit_top = 0
	limit_bottom = int(viewport_size.y)
	limit_smoothed = true  # плавное ограничение

func _physics_process(delta):
	var target = get_parent()  # камера следует за родителем (игроком)
	if not target or not is_instance_valid(target):
		return
	
	# Плавное следование только по Y (вертикально), X остаётся в центре
	var viewport_size = get_viewport_rect().size
	var target_x = viewport_size.x * 0.5  # центр экрана по X
	var target_y = target.global_position.y  # следует за игроком по Y
	
	var target_pos = Vector2(target_x, target_y)
	global_position = global_position.lerp(target_pos, FOLLOW_SPEED * delta)

extends Area2D

const SPEED := 150.0  # базовая скорость падения (множитель буста берём из main)
var is_dead = false

func _ready() -> void:
	add_to_group("fallen_ship")  # чтобы работала очистка по группе в main
	# Делаем обычный CanvasItem, чтобы корректно работать с z_index
	# и не резать облака.
	set_as_top_level(false)
	z_index = 0  # между планетой (-1) и облаками (1, 2)

	# Переносим узел в корень основной сцены (main),
	# чтобы он не попадал под mirroring ParallaxLayer.
	var root := get_tree().current_scene
	if root and get_parent() != root:
		get_parent().remove_child(self)
		root.add_child(self)

func _physics_process(delta: float) -> void:
	if is_dead:
		return

	# Скорость как у фона: на мобильном буст через touch, не Input — берём множитель из main
	var mult := 1.0
	var root = get_tree().current_scene
	if root and root.has_method("get_scroll_speed") and "base_scroll_speed" in root:
		mult = root.get_scroll_speed() / float(root.base_scroll_speed)
	position.y += SPEED * mult * delta

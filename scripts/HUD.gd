extends CanvasLayer  # HUD слой поверх игры

@onready var hp_bar: TextureProgressBar = _find_hp_bar()  # находим бар хп
@onready var shield_bar: TextureProgressBar = _find_shield_bar()  # находим бар щита
@onready var score_label: Label = _find_score_label()  # находим текст очков
@onready var rocket_buff_sprite: AnimatedSprite2D = get_node_or_null("rocket buff_Sprite") as AnimatedSprite2D  # индикатор бафа ракет

var max_hp: int = 4  # максимум здоровья
var max_shield: int = 60  # максимум щита (60 секунд)
var score: int = 0  # текущие очки
var hp_tween: Tween = null  # твин для анимации здоровья

func _ready():
	set_shield(0)  # инициализация полоски щита в 0
	set_hp(0)  # инициализация полоски здоровья в 0
	set_rocket_buff_active(false)  # прячем индикатор бафа ракет

func set_hp(hp: int) -> void:  # обновление значения бара
	if hp_bar:
		hp_bar.max_value = max_hp
		hp_bar.value = clamp(hp, 0, max_hp)

func animate_hp_decrease(target_hp: int, duration: float = 1.5) -> void:  # анимация уменьшения здоровья
	if not hp_bar:
		return
	
	# Останавливаем предыдущий твин, если он есть
	if hp_tween and hp_tween.is_valid():
		hp_tween.kill()
	
	hp_bar.max_value = max_hp
	var current_value = float(hp_bar.value)
	var target_value = float(clamp(target_hp, 0, max_hp))
	
	# Для плавной анимации при малом количестве делений используем более длительную и плавную анимацию
	hp_tween = create_tween()
	hp_tween.set_ease(Tween.EASE_OUT)
	hp_tween.set_trans(Tween.TRANS_QUART)  # Более плавная кривая для визуального эффекта
	hp_tween.tween_method(
		func(val: float): 
			hp_bar.value = val,
		current_value, 
		target_value, 
		duration
	)

func animate_hp_fill(target_hp: int, duration: float = 1.2) -> void:  # анимация заполнения здоровья
	if not hp_bar:
		return
	
	# Останавливаем предыдущий твин, если он есть
	if hp_tween and hp_tween.is_valid():
		hp_tween.kill()
	
	hp_bar.max_value = max_hp
	var current_value = float(hp_bar.value)
	var target_value = float(clamp(target_hp, 0, max_hp))
	
	# Создаём новый твин с более плавными настройками
	hp_tween = create_tween()
	hp_tween.set_ease(Tween.EASE_OUT)
	hp_tween.set_trans(Tween.TRANS_SINE)
	hp_tween.tween_method(
		func(val: float): 
			hp_bar.value = val,
		current_value, 
		target_value, 
		duration
	)

func set_shield(shield: int) -> void:  # обновление значения щита
	if shield_bar:
		shield_bar.max_value = max_shield
		shield_bar.value = clamp(shield, 0, max_shield)

func animate_shield_fill(target_value: int, duration: float = 0.5) -> void:  # анимация заполнения щита
	if shield_bar:
		shield_bar.max_value = max_shield
		var tween = create_tween()
		tween.tween_method(func(val): shield_bar.value = clamp(val, 0, max_shield), shield_bar.value, target_value, duration)

func set_score(value: int) -> void:  # обновление счёта
	score = value
	if score_label:
		score_label.text = str(score)

func _find_hp_bar() -> TextureProgressBar:  # ищем бар по типу
	for n in find_children("*", "TextureProgressBar", true, true):
		return n as TextureProgressBar
	return null

func _find_shield_bar() -> TextureProgressBar:  # ищем бар щита по имени
	for n in find_children("*", "TextureProgressBar", true, true):
		if n.name == "TextureProgressBar_shield":
			return n as TextureProgressBar
	return null

func _find_score_label() -> Label:  # ищем Label для очков
	for n in find_children("*", "Label", true, true):
		return n as Label
	return null

func set_rocket_buff_active(active: bool) -> void:
	if not rocket_buff_sprite:
		return
	rocket_buff_sprite.visible = active  # показать/скрыть индикатор
	if active:
		rocket_buff_sprite.play("default")  # анимация подбора/наличия бафа
	else:
		rocket_buff_sprite.stop()

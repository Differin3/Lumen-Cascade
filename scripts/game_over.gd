extends CanvasLayer  # слой поверх игры

@onready var audio_manager: AudioSystem = AudioManager
@onready var title_label: Label = $CenterContainer/VBoxContainer/ContentContainer/Title
@onready var score_text_label: Label = $CenterContainer/VBoxContainer/ContentContainer/ScoreContainer/ScoreText
@onready var score_value_label: Label = $CenterContainer/VBoxContainer/ContentContainer/ScoreContainer/ScoreValue
@onready var restart_button: Button = $CenterContainer/VBoxContainer/ContentContainer/RestartButton
@onready var continue_button: Button = $CenterContainer/VBoxContainer/ContentContainer/ContinueButton
@onready var ad_note_label: Label = $CenterContainer/VBoxContainer/ContentContainer/AdNoteLabel
@onready var window_root: Control = $CenterContainer

var final_score: int = 0
var yandex_games = null
var countdown_label: Label


func _ready() -> void:
	process_mode = PROCESS_MODE_ALWAYS  # чтобы кнопки работали при паузе дерева (гонка с focus-out)
	visible = true  # Сцена по умолчанию имеет visible=false, включаем при показе
	title_label.text = tr("game_over_title")
	score_text_label.text = tr("score_label")
	restart_button.text = tr("restart_btn")
	if continue_button:
		continue_button.text = tr("continue_btn")
	if ad_note_label:
		ad_note_label.text = tr("continue_ad_note")
	restart_button.pressed.connect(_on_restart_pressed)
	if continue_button:
		continue_button.pressed.connect(_on_continue_pressed)

	# Создаём поверх окна крупный текст для отсчёта 3..2..1
	countdown_label = Label.new()
	countdown_label.name = "CountdownLabel"
	countdown_label.text = ""
	countdown_label.visible = false
	countdown_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	countdown_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	countdown_label.anchor_left = 0.0
	countdown_label.anchor_top = 0.0
	countdown_label.anchor_right = 1.0
	countdown_label.anchor_bottom = 1.0
	countdown_label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	countdown_label.grow_vertical = Control.GROW_DIRECTION_BOTH
	countdown_label.add_theme_font_size_override("font_size", 48)
	add_child(countdown_label)

	# Инициализируем SDK Яндекс Игр (только веб)
	if OS.has_feature("web"):
		yandex_games = preload("res://scripts/yandex_games.gd").new()


const LEADERBOARD_NAME := "LumenCascadeliderboards1"

func set_score(score: int) -> void:
	final_score = score
	if score_value_label:
		score_value_label.text = str(score)
	# Блокируем кнопки до завершения обновления лидерборда
	if restart_button:
		restart_button.disabled = true
	if continue_button:
		continue_button.disabled = true
	if yandex_games != null:
		var local_best: int = yandex_games.get_local_best_score()
		if local_best < 0 or score > local_best:
			yandex_games.set_local_best_score(score)
		var best: int = await yandex_games.leaderboard_get_player_score_async(LEADERBOARD_NAME)
		if best < 0 or score > best:
			yandex_games.leaderboard_set_score(LEADERBOARD_NAME, score)
	# Разблокируем кнопки после обновления лидерборда (или сразу, если не веб)
	if restart_button and is_instance_valid(restart_button):
		restart_button.disabled = false
	if continue_button and is_instance_valid(continue_button):
		continue_button.disabled = false


func _on_restart_pressed() -> void:
	# Тот же красивый отсчёт перед полной перезагрузкой игры
	await _restart_with_countdown()


func _on_continue_pressed() -> void:
	# Блокируем кнопку сразу, чтобы избежать повторных нажатий
	if continue_button:
		continue_button.disabled = true
	# Всегда пробуем показать рекламу; адаптер сам решит, доступен ли SDK
	if yandex_games != null:
		if audio_manager:
			audio_manager.stop_all_audio()
		yandex_games.gameplay_stop()  # перед показом рекламы
		yandex_games.show_rewarded_ad(
			_on_ad_rewarded,  # успешный просмотр
			_on_ad_error      # ошибка
		)
	else:
		# Если адаптера нет, просто продолжаем игру с отсчётом
		await _continue_game_with_countdown()


func _on_ad_rewarded() -> void:
	# Реклама просмотрена успешно — запускаем отсчёт, потом продолжаем игру
	await _continue_game_with_countdown()


func _on_ad_error(error: String) -> void:
	# Ошибка при показе рекламы — всё равно разрешаем продолжение,
	# чтобы игрок не застрял на экране Game Over
	await _continue_game_with_countdown()


func _continue_game_with_countdown() -> void:
	# Блокируем кнопки, чтобы игрок не нажимал повторно
	restart_button.disabled = true
	if continue_button:
		continue_button.disabled = true

	# Прячем окно Game Over, оставляем только фон и цифры
	if window_root:
		window_root.visible = false
	# Прячем текст финального счёта
	if score_text_label:
		score_text_label.visible = false
	if score_value_label:
		score_value_label.visible = false

	# 3‑секундный анимированный отсчёт 3..2..1
	if countdown_label:
		countdown_label.visible = true
		for i in range(3, 0, -1):
			countdown_label.text = str(i)
			countdown_label.scale = Vector2(0.5, 0.5)
			countdown_label.modulate = Color.WHITE
			var tween := create_tween()
			tween.tween_property(
				countdown_label,
				"scale",
				Vector2(1.3, 1.3),
				0.25
			).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			tween.tween_property(
				countdown_label,
				"scale",
				Vector2.ONE,
				0.15
			)
			await tween.finished
			await get_tree().create_timer(0.25).timeout
		countdown_label.visible = false

	var main = get_parent()
	if main and main.has_method("continue_game"):
		main.continue_game()  # возрождение/продолжение
	queue_free()


func _restart_with_countdown() -> void:
	# Блокируем кнопки, чтобы не было повторных нажатий
	restart_button.disabled = true
	if continue_button:
		continue_button.disabled = true
	
	# Прячем всё окно и счёт, оставляем только фон и цифры
	if window_root:
		window_root.visible = false
	if score_text_label:
		score_text_label.visible = false
	if score_value_label:
		score_value_label.visible = false
	
	# Тот же анимированный отсчёт 3..2..1
	if countdown_label:
		countdown_label.visible = true
		for i in range(3, 0, -1):
			countdown_label.text = str(i)
			countdown_label.scale = Vector2(0.5, 0.5)
			countdown_label.modulate = Color.WHITE
			var tween := create_tween()
			tween.tween_property(
				countdown_label,
				"scale",
				Vector2(1.3, 1.3),
				0.25
			).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			tween.tween_property(
				countdown_label,
				"scale",
				Vector2.ONE,
				0.15
			)
			await tween.finished
			await get_tree().create_timer(0.25).timeout
		countdown_label.visible = false
	
	get_tree().reload_current_scene()

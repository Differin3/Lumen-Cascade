extends CanvasLayer

@onready var play_button: Button = $CenterContainer/VBoxContainer/Window/ContentContainer/PlayButton
@onready var parallax = $ParallaxBackground
@onready var title_label: Label = $CenterContainer/VBoxContainer/Window/ContentContainer/Title
@onready var pilot_label: Label = $CenterContainer/VBoxContainer/Window/ContentContainer/PilotLabel
@onready var auth_button: Button = $CenterContainer/VBoxContainer/Window/ContentContainer/AuthButton
@onready var auth_benefits_label: Label = $CenterContainer/VBoxContainer/Window/ContentContainer/AuthBenefitsLabel
@onready var auth_optional_label: Label = $CenterContainer/VBoxContainer/Window/ContentContainer/AuthOptionalLabel

var main_scene = preload("res://main.tscn")
var auth_confirm_dialog_scene = preload("res://scenes/ui/auth_confirm_dialog.tscn")
var base_scroll_speed = 50.0  # скорость прокрутки фона в меню
var yandex_games = null

func _ready():
	if OS.has_feature("web"):
		yandex_games = preload("res://scripts/yandex_games.gd").new()
		var loc = yandex_games.get_sdk_locale()
		if loc != "":
			TranslationServer.set_locale(loc)
		yandex_games.loading_ready()
		if play_button:
			play_button.disabled = true
		await _fetch_remote_flags()
		if play_button:
			play_button.disabled = false
		if yandex_games.has_auth_history():
			_fetch_player()
	title_label.text = tr("menu_title")
	play_button.text = tr("play_btn")
	auth_button.text = tr("auth_btn")
	auth_button.pressed.connect(_on_auth_pressed)
	play_button.pressed.connect(_on_play_pressed)
	if pilot_label:
		pilot_label.visible = false
	# На веб: кнопка «Войти», пояснение преимуществ и «можно играть без входа» (п. 1.2.1 требований Яндекса)
	var on_web := OS.has_feature("web")
	if auth_button:
		auth_button.visible = on_web
	if auth_benefits_label:
		auth_benefits_label.visible = on_web
		var benefits_text := tr("auth_benefits")
		if benefits_text == "auth_benefits":
			benefits_text = "Сохранить прогресс в облаке, таблица лидеров"
		auth_benefits_label.text = benefits_text
	if auth_optional_label:
		auth_optional_label.visible = on_web
		auth_optional_label.text = tr("auth_optional")
	_style_title()

func _physics_process(delta):
	update_parallax(delta)

func update_parallax(delta):
	if !parallax:
		return
	var scroll_speed = base_scroll_speed
	# Обновление параллакса
	for layer in parallax.get_children():
		if layer is ParallaxLayer:
			layer.motion_offset.y += scroll_speed * layer.motion_scale.y * delta

func _style_title():
	if not title_label:
		return
	# Космический стиль: градиент, свечение, тень
	title_label.add_theme_color_override("font_color", Color(0.4, 0.8, 1.0))  # голубой
	title_label.add_theme_color_override("font_shadow_color", Color(0.2, 0.4, 0.8, 0.8))  # тень
	title_label.add_theme_constant_override("shadow_offset_x", 3)
	title_label.add_theme_constant_override("shadow_offset_y", 3)
	title_label.add_theme_constant_override("outline_size", 4)
	title_label.add_theme_color_override("font_outline_color", Color(0.1, 0.2, 0.4))
	# Анимация свечения
	var tween = create_tween()
	tween.set_loops()
	tween.tween_method(_set_title_glow, 0.7, 1.0, 1.5)
	tween.tween_method(_set_title_glow, 1.0, 0.7, 1.5)

func _set_title_glow(alpha: float):
	if title_label:
		title_label.modulate = Color(0.4 + alpha * 0.3, 0.8 + alpha * 0.2, 1.0, 1.0)

func _fetch_remote_flags() -> void:
	if yandex_games == null:
		return
	var default_flags := {
		"difficult": "easy",
		"enemy_hp": "5",
		"rocket_spawn_rate": "70",
		"shield_spawn_rate": "100",
		"enemy_spawn_rate": "1.5"
	}
	var rc = get_node_or_null("/root/RemoteConfig")
	if rc != null:
		rc.set("flags", await yandex_games.get_flags_async(default_flags, []))

func _fetch_player() -> void:
	if yandex_games == null:
		return
	var player_data: Dictionary = await yandex_games.get_player_async()
	# Сцена могла смениться (игрок нажал Играть) — не трогать удалённые ноды
	if not is_instance_valid(pilot_label):
		return
	var name_str: String = str(player_data.get("name", ""))
	if player_data.get("authorized", false) and name_str != "":
		pilot_label.text = tr("pilot_name") % [name_str]
		pilot_label.visible = true
		if is_instance_valid(auth_button):
			auth_button.visible = false
		if is_instance_valid(auth_benefits_label):
			auth_benefits_label.visible = false
		if is_instance_valid(auth_optional_label):
			auth_optional_label.visible = false
	else:
		pilot_label.visible = false
		var on_web := OS.has_feature("web")
		if is_instance_valid(auth_button):
			auth_button.visible = on_web
		if is_instance_valid(auth_benefits_label):
			auth_benefits_label.visible = on_web
		if is_instance_valid(auth_optional_label):
			auth_optional_label.visible = on_web

func _on_auth_pressed() -> void:
	if yandex_games == null or not is_instance_valid(auth_button):
		return
	auth_button.disabled = true
	if is_instance_valid(pilot_label):
		pilot_label.visible = false
	# Сначала проверяем по SDK: уже авторизован — не открываем окно (избегаем "auth window opener")
	var player_data: Dictionary = await yandex_games.get_player_async()
	if player_data.get("authorized", false):
		if is_instance_valid(auth_button):
			auth_button.disabled = false
		yandex_games.set_auth_history()
		await _fetch_player()
		return
	# П. 1.2.1: показываем всплывающее окно с подтверждением и отменой (CanvasLayer + затемнение + карточка)
	var dialog = auth_confirm_dialog_scene.instantiate()
	add_child(dialog)
	var confirmed := false
	dialog.confirmed.connect(func() -> void: confirmed = true)
	dialog.canceled.connect(func() -> void: pass)  # confirmed остаётся false
	dialog.visible = true
	while dialog.visible:
		await get_tree().process_frame
	dialog.queue_free()
	if not confirmed:
		if is_instance_valid(auth_button):
			auth_button.disabled = false
		return
	var ok: bool = await yandex_games.open_auth_dialog_async()
	if is_instance_valid(auth_button):
		auth_button.disabled = false
	if ok:
		yandex_games.set_auth_history()
		await _fetch_player()
	else:
		if is_instance_valid(pilot_label):
			pilot_label.text = tr("auth_failed_msg")
			pilot_label.visible = true
			await get_tree().create_timer(5.0).timeout
			if is_instance_valid(pilot_label):
				pilot_label.visible = false

func _on_play_pressed():
	get_tree().change_scene_to_packed(main_scene)

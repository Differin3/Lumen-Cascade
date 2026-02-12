extends Node2D

# ===== НОДЫ СЦЕНЫ =====
@onready var parallax = $ParallaxBackground
@onready var postfx_rect: ColorRect = $PostFX/ColorRect
@onready var enemy_timer = $Timer_enemy
@onready var rocket_baff_timer = $rocket_buff
@onready var shield_buff_timer = $shield_buff
@onready var player = $player
@onready var fallen_ship_timer = $fallen_ship

# ===== АУДИО =====
@onready var audio_manager: AudioSystem = AudioManager

# ===== НАСТРОЙКИ ИГРЫ =====
var base_scroll_speed = 100
var enemy_spawn_rate = 1.5
var rocket_spawn_rate = 70.0
var shield_spawn_rate = 100.0
var fallen_ship_rate = 100.0
var enemy_spawn_margin = 50
var enemy_count = 0

# ===== ПЕРЕМЕННЫЕ ДЛЯ АНИМАЦИЙ И ЭФФЕКТОВ =====
var player_final_position: Vector2
var boost_fx_amount: float = 0.0
var damage_fx_amount: float = 0.0

# ===== ПЕРЕМЕННЫЕ ДЛЯ РАБОТЫ С ЯНДЕКС SDK И УПРАВЛЕНИЯ ЗВУКОМ =====
var yandex_games = null
var _web_page_hidden := false
var _sdk_pause_requested := false
var _music_was_playing := false
var _window_focus_lost := false
var _game_over_active := false

# ===== ПРЕДЗАГРУЖЕННЫЕ СЦЕНЫ =====
var enemy_scene = preload("res://scenes/enemy/enemy.tscn")
var rocket_buff_scene = preload("res://scenes/buffs/rocket_buff.tscn")
var shield_buff_scene = preload("res://scenes/buffs/shield_buff.tscn")
var game_over_scene = preload("res://scenes/ui/game_over.tscn")
var pause_menu_scene = preload("res://scenes/ui/pause_menu.tscn")
var fallen_ship_scene = preload("res://scenes/enemy/fallen ship.tscn")
var player_scene = preload("res://scenes/player/player.tscn")


func _ready():
	# --- АУДИО: загрузка настроек и регистрация BackgroundMusic ---
	if AudioManager:
		AudioManager.load_settings()
	var bg = get_node_or_null("BackgroundMusic")
	if bg:
		if bg.stream is AudioStreamOggVorbis:
			bg.stream.loop = true
		AudioManager.register_player(bg, AudioSystem.SoundType.MUSIC)

	# --- ИНИЦИАЛИЗАЦИЯ ЯНДЕКС SDK ---
	if OS.has_feature("web"):
		yandex_games = preload("res://scripts/yandex_games.gd").new()
		var loc = yandex_games.get_sdk_locale()
		if loc != "":
			TranslationServer.set_locale(loc)
		yandex_games.init_sdk_pause_listeners()

	# --- НАСТРОЙКА ОБРАБОТЧИКОВ ФОКУСА ОКНА ---
	var window = get_window()
	if window:
		if window.has_signal("window_focus_out"):
			if not window.window_focus_out.is_connected(_on_window_focus_out):
				window.window_focus_out.connect(_on_window_focus_out)
		if window.has_signal("window_focus_in"):
			if not window.window_focus_in.is_connected(_on_window_focus_in):
				window.window_focus_in.connect(_on_window_focus_in)

	# --- НАСТРОЙКА ТАЙМЕРОВ ---
	if enemy_timer:
		if not enemy_timer.timeout.is_connected(_on_enemy_timer_timeout):
			enemy_timer.timeout.connect(_on_enemy_timer_timeout)
		enemy_timer.wait_time = enemy_spawn_rate
		enemy_timer.start()
	else:
		push_error("ОШИБКА: Таймер врагов не найден!")

	if rocket_baff_timer:
		if not rocket_baff_timer.timeout.is_connected(_on_rocket_buff_timer_timeout):
			rocket_baff_timer.timeout.connect(_on_rocket_buff_timer_timeout)
		rocket_baff_timer.wait_time = rocket_spawn_rate
		rocket_baff_timer.start()
	else:
		push_error("ОШИБКА: Таймер ракетных баффов не найден!")

	if shield_buff_timer:
		if not shield_buff_timer.timeout.is_connected(_on_shield_buff_timer_timeout):
			shield_buff_timer.timeout.connect(_on_shield_buff_timer_timeout)
		shield_buff_timer.wait_time = shield_spawn_rate
		shield_buff_timer.start()
	else:
		push_error("ОШИБКА: Таймер баффов щитов не найден!")

	if fallen_ship_timer:
		if not fallen_ship_timer.timeout.is_connected(_on_fallen_ship_timer_timeout):
			fallen_ship_timer.timeout.connect(_on_fallen_ship_timer_timeout)
		fallen_ship_timer.wait_time = fallen_ship_rate
		fallen_ship_timer.start()
	else:
		push_error("ОШИБКА: Таймер упавшего корабля не найден!")

	# --- АНИМАЦИЯ ПОЯВЛЕНИЯ ИГРОКА ---
	if player:
		player_final_position = player.position
		var viewport_size = get_viewport_rect().size
		player.position = Vector2(player_final_position.x, viewport_size.y + 100)
		animate_player_entrance()
	else:
		push_error("ОШИБКА: Игрок не найден в сцене!")


func _exit_tree() -> void:
	var bg = get_node_or_null("BackgroundMusic")
	if AudioManager and bg:
		AudioManager.unregister_player(bg)


func _on_window_focus_out() -> void:
	var bg = get_node_or_null("BackgroundMusic")
	_music_was_playing = bg and bg.playing
	_window_focus_lost = true
	if audio_manager:
		audio_manager.pause_all_audio()

	if not get_tree().paused and player and not _game_over_active:
		var pm = pause_menu_scene.instantiate()
		add_child(pm)
		get_tree().paused = true
		if yandex_games:
			yandex_games.gameplay_stop()


func _on_window_focus_in() -> void:
	if _window_focus_lost:
		_window_focus_lost = false
		call_deferred("_resume_audio_after_focus")


func _resume_audio_after_focus() -> void:
	if not get_tree().paused and _music_was_playing and not _game_over_active and audio_manager:
		audio_manager.resume_all_audio()
	_music_was_playing = false


func _notification(what: int) -> void:
	match what:
		NOTIFICATION_WM_WINDOW_FOCUS_OUT:
			var bg = get_node_or_null("BackgroundMusic")
			_music_was_playing = bg and bg.playing
			_window_focus_lost = true
			if audio_manager:
				audio_manager.pause_all_audio()
			if not get_tree().paused and player and not _game_over_active:
				var pm = pause_menu_scene.instantiate()
				add_child(pm)
				get_tree().paused = true
				if yandex_games:
					yandex_games.gameplay_stop()
		NOTIFICATION_WM_WINDOW_FOCUS_IN:
			if _window_focus_lost:
				_window_focus_lost = false
				call_deferred("_resume_audio_after_focus")


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and player and not get_tree().paused and not _game_over_active:
		_open_pause_menu()
		get_viewport().set_input_as_handled()


func _open_pause_menu() -> void:
	var pm = pause_menu_scene.instantiate()
	add_child(pm)
	get_tree().paused = true
	var bg = get_node_or_null("BackgroundMusic")
	_music_was_playing = bg and bg.playing
	if audio_manager:
		audio_manager.pause_all_audio()
	if yandex_games:
		yandex_games.gameplay_stop()


func resume_game() -> void:
	_web_page_hidden = false
	_window_focus_lost = false
	get_tree().paused = false
	call_deferred("_resume_audio_in_game")
	if yandex_games:
		yandex_games.gameplay_start()


func _resume_audio_in_game() -> void:
	if audio_manager and _music_was_playing:
		audio_manager.resume_all_audio()
	_music_was_playing = false


func _physics_process(delta):
	# --- ОБРАБОТКА ПАУЗ ОТ SDK ЯНДЕКС ИГР ---
	if OS.has_feature("web") and yandex_games:
		var sdk_pause = yandex_games.get_sdk_pause_state()
		if sdk_pause == "pause" and not _sdk_pause_requested:
			_sdk_pause_requested = true
			if audio_manager:
				audio_manager.pause_all_audio()
			yandex_games.gameplay_stop()
			if not _game_over_active:
				var pm = pause_menu_scene.instantiate()
				add_child(pm)
				get_tree().paused = true
		elif sdk_pause == "resume" and _sdk_pause_requested:
			_sdk_pause_requested = false
			resume_game()

	# --- ОБРАБОТКА СВОРАЧИВАНИЯ ВКЛАДКИ БРАУЗЕРА ---
	if OS.has_feature("web") and yandex_games and not _window_focus_lost:
		var hidden = JavaScriptBridge.eval("window.yaGamesPageHidden === true", true)
		if hidden and not _web_page_hidden:
			var bg = get_node_or_null("BackgroundMusic")
			_music_was_playing = bg and bg.playing
			if audio_manager:
				audio_manager.pause_all_audio()
			yandex_games.gameplay_stop()
			if player and not _game_over_active:
				_web_page_hidden = true
				var pm = pause_menu_scene.instantiate()
				add_child(pm)
				get_tree().paused = true
		elif not hidden and _web_page_hidden:
			_web_page_hidden = false
			resume_game()

	# --- ОБНОВЛЕНИЕ ПАРАЛЛАКСА И ЭФФЕКТОВ ---
	update_parallax(delta)

	var boosting := _is_player_boosting()
	boost_fx_amount = lerpf(boost_fx_amount, 1.0 if boosting else 0.0, 8.0 * delta)
	damage_fx_amount = lerpf(damage_fx_amount, 0.0, 6.0 * delta)

	if postfx_rect and postfx_rect.material is ShaderMaterial:
		var sm: ShaderMaterial = postfx_rect.material
		sm.set_shader_parameter("lens_strength", 0.14 * boost_fx_amount)
		var tear_boost: float = lerpf(0.01, 0.03, boost_fx_amount)
		var tear_damage: float = lerpf(0.0, 0.10, damage_fx_amount)
		sm.set_shader_parameter("tear_strength", tear_boost + tear_damage)


func update_parallax(delta):
	if !parallax:
		return
	var scroll_speed = base_scroll_speed
	if player and _is_player_boosting():
		scroll_speed *= 1.5
	for layer in parallax.get_children():
		if layer is ParallaxLayer:
			layer.motion_offset.y += scroll_speed * layer.motion_scale.y * delta


func get_scroll_speed() -> float:
	var scroll_speed = base_scroll_speed
	if player and _is_player_boosting():
		scroll_speed *= 1.5
	return scroll_speed


func _is_player_boosting() -> bool:
	if player and player.has_method("is_boosting"):
		return player.is_boosting()
	return Input.is_action_pressed("boost")


func _on_enemy_timer_timeout():
	spawn_enemy()


func _on_rocket_buff_timer_timeout():
	spawn_rocket_buff()


func _on_shield_buff_timer_timeout():
	spawn_shield_buff()


func _on_fallen_ship_timer_timeout():
	spawn_fallen_ship()


func spawn_enemy():
	if !player:
		return
	if !enemy_scene:
		return
	var enemy = enemy_scene.instantiate()
	if !enemy:
		return
	var viewport_size = get_viewport_rect().size
	var spawn_x = randf_range(enemy_spawn_margin, viewport_size.x - enemy_spawn_margin)
	enemy.position = Vector2(spawn_x, -50)
	add_child(enemy)
	enemy_count += 1
	enemy_spawn_rate = max(0.5, enemy_spawn_rate * .99)
	enemy_timer.wait_time = enemy_spawn_rate


func spawn_rocket_buff():
	if !player:
		return
	if !rocket_buff_scene:
		return
	var rocket_buff = rocket_buff_scene.instantiate()
	if !rocket_buff:
		return
	var viewport_size = get_viewport_rect().size
	var spawn_x = randf_range(enemy_spawn_margin, viewport_size.x - enemy_spawn_margin)
	rocket_buff.position = Vector2(spawn_x, -50)
	add_child(rocket_buff)


func spawn_shield_buff():
	if !player:
		return
	if !shield_buff_scene:
		return
	var shield_buff = shield_buff_scene.instantiate()
	if !shield_buff:
		return
	var viewport_size = get_viewport_rect().size
	var spawn_x = randf_range(enemy_spawn_margin, viewport_size.x - enemy_spawn_margin)
	shield_buff.position = Vector2(spawn_x, -50)
	add_child(shield_buff)


func spawn_fallen_ship():
	if !player:
		return
	var existing_fallen := get_tree().get_nodes_in_group("fallen_ship")
	if existing_fallen.size() >= 3:
		return
	if !fallen_ship_scene:
		return
	var fallen_ship = fallen_ship_scene.instantiate()
	if !fallen_ship:
		return
	var viewport_size = get_viewport_rect().size
	var spawn_x = randf_range(enemy_spawn_margin, viewport_size.x - enemy_spawn_margin)
	fallen_ship.position = Vector2(spawn_x, -50)
	var ground_layer := parallax.get_node("ParallaxLayer") if parallax and parallax.has_node("ParallaxLayer") else null
	if ground_layer:
		ground_layer.add_child(fallen_ship)
	else:
		add_child(fallen_ship)


func update_score(amount: int) -> void:
	enemy_count += amount / 100
	var hud = get_tree().get_first_node_in_group("hud")
	if hud:
		hud.set_score(enemy_count * 100)


func animate_player_entrance():
	if not player:
		return
	if player.has_method("set_entering"):
		player.set_entering(true)
	var hud = get_tree().get_first_node_in_group("hud")
	if hud and hud.has_method("animate_hp_fill"):
		hud.animate_hp_fill(4, 1.2)
	var tween = create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(player, "position", player_final_position, 1.2)
	await tween.finished
	if player and player.has_method("set_entering"):
		player.set_entering(false)
	if yandex_games:
		yandex_games.gameplay_start()


func add_damage_fx(amount: float = 0.6) -> void:
	damage_fx_amount = clamp(damage_fx_amount + amount, 0.0, 1.0)


func on_player_destroyed():
	print("Игрок уничтожен!")
	_game_over_active = true
	if audio_manager:
		audio_manager.stop_all_audio()
	if yandex_games:
		yandex_games.gameplay_stop()
	player = null
	enemy_timer.stop()
	rocket_baff_timer.stop()
	shield_buff_timer.stop()
	fallen_ship_timer.stop()
	var game_over = game_over_scene.instantiate()
	add_child(game_over)
	if game_over.has_method("set_score"):
		game_over.set_score(enemy_count * 100)


func continue_game():
	if player:
		return
	if not player_scene:
		return
	_game_over_active = false
	get_tree().paused = false
	if audio_manager:
		audio_manager.play_music()
	if yandex_games:
		yandex_games.gameplay_start()
	var p = player_scene.instantiate()
	p.name = "player"
	add_child(p)
	player = p
	player.position = player_final_position
	if enemy_timer:
		enemy_timer.start()
	if rocket_baff_timer:
		rocket_baff_timer.start()
	if shield_buff_timer:
		shield_buff_timer.start()
	if fallen_ship_timer:
		fallen_ship_timer.start()


func check_fallen_ships_out_of_bounds():
	pass

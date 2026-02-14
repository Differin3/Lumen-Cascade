# AudioManager.gd
extends Node
class_name AudioSystem

# ===== КОНСТАНТЫ =====
enum SoundType {
	MUSIC = 0,
	SFX = 1,
	UI = 2
}

# ===== СИГНАЛЫ =====
signal music_volume_changed(volume: float)
signal sfx_volume_changed(volume: float)
signal ui_volume_changed(volume: float)
signal audio_muted(muted: bool)

# ===== НАСТРОЙКИ =====
@export_category("Audio Settings")
@export_range(0.0, 1.0, 0.01) var music_volume: float = 1.0:
	set(value):
		music_volume = clamp(value, 0.0, 1.0)
		_update_all_volumes()
		music_volume_changed.emit(music_volume)
		_save_settings()

@export_range(0.0, 1.0, 0.01) var sfx_volume: float = 1.0:
	set(value):
		sfx_volume = clamp(value, 0.0, 1.0)
		_update_all_volumes()
		sfx_volume_changed.emit(sfx_volume)
		_save_settings()

@export_range(0.0, 1.0, 0.01) var ui_volume: float = 1.0:
	set(value):
		ui_volume = clamp(value, 0.0, 1.0)
		_update_all_volumes()
		ui_volume_changed.emit(ui_volume)
		_save_settings()

@export var is_muted: bool = false:
	set(value):
		is_muted = value
		_update_all_volumes()
		audio_muted.emit(is_muted)
		_save_settings()

# ===== ПЕРЕМЕННЫЕ =====
var _registered_players: Array[AudioStreamPlayer] = []
var _paused_players: Array[AudioStreamPlayer] = []
var _music_players: Array[AudioStreamPlayer] = []
var _sfx_players: Array[AudioStreamPlayer] = []
var _ui_players: Array[AudioStreamPlayer] = []

# ===== ПУБЛИЧНЫЕ МЕТОДЫ =====

# Регистрация аудиоплеера
func register_player(player: AudioStreamPlayer, sound_type: SoundType = SoundType.SFX) -> void:
	if not player:
		return
	
	# Если уже зарегистрирован, сначала удаляем
	unregister_player(player)
	
	# Регистрируем
	_registered_players.append(player)
	
	# Добавляем в соответствующую категорию
	match sound_type:
		SoundType.MUSIC:
			_music_players.append(player)
		SoundType.SFX:
			_sfx_players.append(player)
		SoundType.UI:
			_ui_players.append(player)
	
	# Обновляем громкость
	_update_player_volume(player, sound_type)
	
	# Автоматически добавляем в группу для удобства
	if not player.is_in_group("audio"):
		player.add_to_group("audio")

# Удаление регистрации аудиоплеера
func unregister_player(player: AudioStreamPlayer) -> void:
	if not player:
		return
	
	if player in _registered_players:
		_registered_players.erase(player)
	if player in _music_players:
		_music_players.erase(player)
	if player in _sfx_players:
		_sfx_players.erase(player)
	if player in _ui_players:
		_ui_players.erase(player)
	if player in _paused_players:
		_paused_players.erase(player)

# Полная остановка всех звуков (требование Яндекс Игр)
func stop_all_audio() -> void:
	for player in _registered_players:
		if is_instance_valid(player):
			player.stream_paused = false  # сбрасываем перед stop для чистого состояния
			if player.playing:
				player.stop()
	
	# Очищаем список приостановленных плееров
	_paused_players.clear()

# Приостановка всех звуков (при паузе)
func pause_all_audio() -> void:
	for player in _registered_players:
		if player.playing:
			player.stream_paused = true
			if not player in _paused_players:
				_paused_players.append(player)

# Возобновление всех звуков (снятие паузы)
func resume_all_audio() -> void:
	for player in _paused_players:
		if is_instance_valid(player):
			player.stream_paused = false
	_paused_players.clear()

# Остановка только музыки
func stop_music() -> void:
	for player in _music_players:
		if player.playing:
			player.stop()

# Воспроизведение только музыки
func play_music() -> void:
	for player in _music_players:
		if is_instance_valid(player):
			player.stream_paused = false  # сбрасываем паузу (важно после рекламы/stop_all)
			if not player.playing:
				player.play()

# Воспроизведение звука с учетом типа
func play_sound(sound_type: SoundType = SoundType.SFX) -> void:
	var players: Array[AudioStreamPlayer]
	match sound_type:
		SoundType.MUSIC:
			players = _music_players
		SoundType.SFX:
			players = _sfx_players
		SoundType.UI:
			players = _ui_players
	
	for player in players:
		if is_instance_valid(player) and not player.playing:
			player.play()

# Переключение режима "Mute"
func toggle_mute() -> void:
	is_muted = !is_muted
	_save_settings()

# Загрузка сохраненных настроек
func load_settings() -> void:
	var config = ConfigFile.new()
	if config.load("user://audio_settings.cfg") == OK:
		music_volume = config.get_value("audio", "music_volume", 1.0)
		sfx_volume = config.get_value("audio", "sfx_volume", 1.0)
		ui_volume = config.get_value("audio", "ui_volume", 1.0)
		is_muted = config.get_value("audio", "is_muted", false)

# ===== ПРИВАТНЫЕ МЕТОДЫ =====

# Обновление громкости всех плееров
func _update_all_volumes() -> void:
	for player in _music_players:
		if is_instance_valid(player):
			_update_player_volume(player, SoundType.MUSIC)
	
	for player in _sfx_players:
		if is_instance_valid(player):
			_update_player_volume(player, SoundType.SFX)
	
	for player in _ui_players:
		if is_instance_valid(player):
			_update_player_volume(player, SoundType.UI)

# Обновление громкости конкретного плеера
func _update_player_volume(player: AudioStreamPlayer, sound_type: SoundType) -> void:
	if not player:
		return
	
	var target_volume: float = 1.0
	
	match sound_type:
		SoundType.MUSIC:
			target_volume = music_volume
		SoundType.SFX:
			target_volume = sfx_volume
		SoundType.UI:
			target_volume = ui_volume
	
	# Применяем mute
	if is_muted:
		target_volume = 0.0
	
	# Преобразуем линейную громкость в децибелы
	player.volume_db = linear_to_db(target_volume)

# Сохранение настроек
func _save_settings() -> void:
	var config = ConfigFile.new()
	config.set_value("audio", "music_volume", music_volume)
	config.set_value("audio", "sfx_volume", sfx_volume)
	config.set_value("audio", "ui_volume", ui_volume)
	config.set_value("audio", "is_muted", is_muted)
	config.save("user://audio_settings.cfg")

# Очистка при выходе
func _exit_tree() -> void:
	for player in _registered_players:
		if is_instance_valid(player):
			player.remove_from_group("audio")
	_registered_players.clear()
	_music_players.clear()
	_sfx_players.clear()
	_ui_players.clear()
	_paused_players.clear()

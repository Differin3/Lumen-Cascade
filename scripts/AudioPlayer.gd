# AudioPlayer.gd - компонент для автоматической регистрации в AudioManager
extends AudioStreamPlayer
class_name AudioPlayerComponent

@export var sound_type: AudioSystem.SoundType = AudioSystem.SoundType.SFX
@export var auto_register: bool = true
@export var auto_play: bool = false


func _ready() -> void:
	if auto_register and AudioManager:
		AudioManager.register_player(self, sound_type)
	if auto_play:
		play()


func _exit_tree() -> void:
	if AudioManager:
		AudioManager.unregister_player(self)

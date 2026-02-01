extends CanvasLayer
# Окно паузы: работает при get_tree().paused (process_mode = ALWAYS)

@onready var title_label: Label = $CenterContainer/VBoxContainer/ContentContainer/Title
@onready var resume_btn: Button = $CenterContainer/VBoxContainer/ContentContainer/ResumeButton
@onready var restart_btn: Button = $CenterContainer/VBoxContainer/ContentContainer/RestartButton

func _ready() -> void:
	process_mode = PROCESS_MODE_ALWAYS
	title_label.text = tr("pause_title")
	resume_btn.text = tr("resume_btn")
	restart_btn.text = tr("restart_btn")
	resume_btn.pressed.connect(_on_resume_pressed)
	restart_btn.pressed.connect(_on_restart_pressed)

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_on_resume_pressed()
		get_viewport().set_input_as_handled()

func _on_resume_pressed() -> void:
	if get_parent().has_method("resume_game"):
		get_parent().resume_game()
	queue_free()

func _on_restart_pressed() -> void:
	get_tree().paused = false
	get_tree().reload_current_scene()

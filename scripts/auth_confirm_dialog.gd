extends CanvasLayer

## Всплывающее окно подтверждения авторизации (п. 1.2.1 требований Яндекс Игр).
## CanvasLayer + затемнённый фон + карточка; кнопки «Подтвердить» / «Отмена», анимация появления.

signal confirmed
signal canceled

@onready var backdrop: ColorRect = $Backdrop
@onready var panel_root: PanelContainer = $CenterContainer/PanelRoot
@onready var title_label: Label = $CenterContainer/PanelRoot/MarginContainer/VBox/TitleLabel
@onready var body_label: Label = $CenterContainer/PanelRoot/MarginContainer/VBox/BodyLabel
@onready var confirm_btn: Button = $CenterContainer/PanelRoot/MarginContainer/VBox/ButtonsHBox/ConfirmButton
@onready var cancel_btn: Button = $CenterContainer/PanelRoot/MarginContainer/VBox/ButtonsHBox/CancelButton

const ANIM_DURATION := 0.22
const ANIM_SCALE_START := 0.88


func _ready() -> void:
	title_label.text = tr("auth_confirm_title")
	body_label.text = tr("auth_benefits")
	confirm_btn.text = tr("auth_confirm_ok")
	cancel_btn.text = tr("auth_cancel")
	confirm_btn.pressed.connect(_on_confirm)
	cancel_btn.pressed.connect(_on_cancel)
	backdrop.gui_input.connect(_on_backdrop_gui_input)
	visibility_changed.connect(_on_visibility_changed)


func _on_visibility_changed() -> void:
	if visible and is_node_ready():
		_play_show_animation()


func _play_show_animation() -> void:
	if not is_instance_valid(panel_root):
		return
	panel_root.modulate.a = 0.0
	panel_root.scale = Vector2(ANIM_SCALE_START, ANIM_SCALE_START)
	var tween := create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_BACK)
	tween.tween_property(panel_root, "scale", Vector2.ONE, ANIM_DURATION)
	tween.parallel().tween_property(panel_root, "modulate:a", 1.0, ANIM_DURATION * 0.85)


func _on_backdrop_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton or event is InputEventScreenTouch:
		if event.pressed:
			_on_cancel()
			get_viewport().set_input_as_handled()


func _on_confirm() -> void:
	confirmed.emit()
	visible = false


func _on_cancel() -> void:
	canceled.emit()
	visible = false

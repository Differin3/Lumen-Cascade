extends Area2D
class_name PickupBase

const SPEED := 150
const BOOST_MULT := 1.5

@export var activation_method: String = ""

var is_dead := false


func _ready() -> void:
	connect("area_entered", _on_area_entered)


func _physics_process(delta: float) -> void:
	if is_dead:
		return

	var spd := float(SPEED)
	if Input.is_action_pressed("boost"):
		spd *= BOOST_MULT
	position += Vector2.DOWN * spd * delta
	if has_node("AnimatedSprite2D"):
		$AnimatedSprite2D.play("default")

	if position.y > get_viewport_rect().size.y + 50:
		queue_free()


func _on_area_entered(area: Area2D) -> void:
	if is_dead or activation_method.is_empty():
		return

	var player_node = area.get_parent()
	if player_node.has_method(activation_method):
		player_node.call(activation_method)
		is_dead = true
		if has_node("CollisionShape2D"):
			$CollisionShape2D.set_deferred("disabled", true)
		if has_node("AnimatedSprite2D"):
			$AnimatedSprite2D.visible = false
		await get_tree().create_timer(0.1).timeout
		queue_free()

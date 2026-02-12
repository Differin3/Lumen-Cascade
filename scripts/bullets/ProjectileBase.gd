extends Area2D
class_name ProjectileBase

@export var speed: float = 100.0
@export var damage: int = 1

var direction := Vector2.UP


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	set_as_top_level(true)
	if has_node("AnimatedSprite2D"):
		$AnimatedSprite2D.play("flight")


func _physics_process(delta: float) -> void:
	position += direction * speed * delta
	if position.y < -100:
		queue_free()


func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("enemies"):
		body.take_damage(damage)
		queue_free()

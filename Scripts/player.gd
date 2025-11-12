extends CharacterBody2D

@export var player_speed: float = 300.0 # Velocidad constante del jugador hacia la izquierda (aumentada)
var _movement_enabled: bool = true
var _saved_speed: float = player_speed

func _physics_process(delta: float) -> void:
	# Mover el jugador constantemente hacia la izquierda
	if _movement_enabled:
		velocity = Vector2(-player_speed, 0)
	else:
		velocity = Vector2(0, 0)
	move_and_slide()

func disable_movement() -> void:
	_movement_enabled = false

func enable_movement() -> void:
	_movement_enabled = true

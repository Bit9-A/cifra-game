extends CharacterBody2D

@export var player_speed: float = 200.0 # Velocidad constante del jugador hacia la izquierda (aumentada)

func _physics_process(delta: float) -> void:
	# Mover el jugador constantemente hacia la izquierda
	velocity = Vector2(-player_speed, 0)
	move_and_slide()

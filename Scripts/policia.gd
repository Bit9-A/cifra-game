extends CharacterBody2D

@export var speed: float = 50.0 # Velocidad controlada por el Level
@onready var player: CharacterBody2D = get_parent().get_node("Player") # Obtener referencia al Player

func _physics_process(delta: float) -> void:
	if player:
		# La policía persigue al jugador.
		# Ambos se mueven a la izquierda, la policía ajusta su velocidad para acercarse/alejarse.
		var direction = (player.global_position - global_position).normalized()
		# Solo nos interesa el movimiento horizontal para la persecución
		velocity = Vector2(direction.x * speed, 0)
		move_and_slide()
	else:
		# Si no hay jugador, la policía se mueve a la izquierda por defecto
		velocity = Vector2(-speed, 0)
		move_and_slide()

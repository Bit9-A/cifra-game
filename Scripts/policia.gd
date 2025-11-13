extends CharacterBody2D

# Este script controla las patrullas de policía.
#
# ESTRUCTURA DE ESCENA RECOMENDADA en Godot para PoliceCar.tscn:
#
# - PoliceCar (CharacterBody2D, con este script adjunto)
#   |
#   |- Sprite (Sprite2D o AnimatedSprite2D)
#   |
#   `- Collision (CollisionShape2D)
#

# --- Variables de Persecución ---
@export var target: Node2D = null # El nodo del jugador, se asignará desde la escena
@export var min_distance: float = 50.0 # Distancia mínima del policía al jugador (cuando el tiempo es 0), ajustada para simular captura
@export var max_distance: float = 520.0 # Distancia máxima del policía al jugador (cuando el tiempo es max_time)
@export var lerp_speed: float = 0.1 # Velocidad de interpolación para un movimiento más suave

var is_lunging: bool = false # Mantener por si hay lógica visual o de captura asociada
var lunge_timer: Timer # Mantener por si hay lógica visual o de captura asociada

func _ready():
	# Creamos un Timer para la embestida (mantener por si hay lógica visual o de captura asociada)
	lunge_timer = Timer.new()
	add_child(lunge_timer)
	lunge_timer.one_shot = true
	lunge_timer.timeout.connect(_on_lunge_timer_timeout)

func _physics_process(delta):
	# La velocidad del policía ya no se calcula aquí, se establece directamente por el GameManager
	# El coche del policía no se mueve por sí mismo, su posición X será ajustada por GameManager
	velocity = Vector2.ZERO # Asegurarse de que no se mueva por física propia
	move_and_slide()

# --- Funciones de Control de Posición ---

# Esta función será llamada por GameManager para establecer la posición del policía
func update_position_based_on_time(current_game_time: float, max_game_time: float, player_x_position: float):
	if max_game_time <= 0:
		# Evitar división por cero si max_game_time es 0
		global_position.x = player_x_position - min_distance
		return

	# Calcular el porcentaje de tiempo restante (0 a 1)
	var time_percentage = current_game_time / max_game_time
	
	# Interpolar la distancia entre min_distance y max_distance
	# Cuando time_percentage es 1 (tiempo máximo), la distancia es max_distance
	# Cuando time_percentage es 0 (tiempo agotado), la distancia es min_distance
	var desired_distance = lerp(min_distance, max_distance, time_percentage)
	
	# Establecer la posición X del policía
	# Calcular la posición X deseada para el policía
	var desired_x_position = player_x_position + desired_distance
	
	# Interpolar suavemente la posición actual del policía hacia la posición deseada
	global_position.x = lerp(global_position.x, desired_x_position, lerp_speed)

# --- Funciones de Embestida (mantener por si hay lógica visual o de captura asociada) ---

# Se llama desde GameManager cuando el jugador falla una pregunta
func lunge():
	if not is_lunging:
		push_warning("¡La policía embiste!")
		is_lunging = true
		lunge_timer.start(0.5) # Duración de la embestida, puede ser un @export var si se necesita
		# No hay cambio de velocidad aquí, solo el estado visual/de captura

func _on_lunge_timer_timeout():
	push_warning("La embestida de la policía ha terminado.")
	is_lunging = false

extends Node2D

@export var initial_time: float = 60.0
@export var time_bonus_on_correct_answer: float = 5.0
@export var police_initial_speed: float = 50.0
@export var police_max_speed: float = 200.0
@export var game_over_distance_threshold: float = 50.0 # Distancia de colisión cuando el tiempo es 0
@export var police_close_distance_threshold: float = 200.0 # Distancia cuando quedan 5 segundos

@onready var player: CharacterBody2D
@onready var policia: CharacterBody2D
@onready var hud: CanvasLayer
@onready var parallax_backgrounds: Array[ParallaxBackground] = []

var time_left: float = initial_time
var game_over: bool = false
var player_not_found_error_logged: bool = false # Bandera para el error del Player
var policia_not_found_error_logged: bool = false # Bandera para el error de Policia
var hud_not_found_error_logged: bool = false # Bandera para el error del HUD

signal time_updated(new_time: float)
signal game_over_signal()

func _ready() -> void:
	time_left = initial_time
	game_over = false
	time_updated.emit(time_left)
	
	# Obtener referencia al Player de forma explícita
	player = get_node_or_null("Player")
	if player == null:
		push_error("El nodo 'Player' no se encontró en el Level en _ready().")
		player_not_found_error_logged = true # Registrar el error una vez

	# Obtener referencia a Policia de forma explícita
	policia = get_node_or_null("Policia")
	if policia == null:
		push_error("El nodo 'Policia' no se encontró en el Level en _ready().")
		policia_not_found_error_logged = true # Registrar el error una vez

	# Obtener referencia al HUD de forma explícita
	hud = get_node_or_null("Hud")
	if hud == null:
		push_error("El nodo 'Hud' no se encontró en el Level en _ready().")
		hud_not_found_error_logged = true # Registrar el error una vez
	
	# Obtener referencias a los ParallaxBackgrounds
	var background_node = get_node("Background")
	if background_node:
		for child in background_node.get_children():
			if child is ParallaxBackground:
				parallax_backgrounds.append(child)

	if hud:
		hud.answer_selected.connect(Callable(self, "_on_hud_answer_selected"))
		time_updated.connect(Callable(hud, "_on_level_time_updated"))
		game_over_signal.connect(Callable(hud, "_on_level_game_over_signal"))
		hud.load_random_question() # Cargar la primera pregunta al inicio del nivel

func _process(delta: float) -> void:
	if game_over:
		return

	time_left -= delta
	time_updated.emit(time_left)

	if time_left <= 0:
		time_left = 0
		set_game_over(true) # El juego termina cuando el tiempo llega a 0
	
	update_police_speed()
	update_parallax_background(delta)

func update_police_speed() -> void:
	if player and policia:
		var player_current_speed = player.player_speed
		
		# Calcular una velocidad relativa de la policía con respecto al jugador.
		# Esta velocidad será negativa (se aleja) si el tiempo es alto,
		# y positiva (se acerca) si el tiempo es bajo.
		# Definimos un rango para esta velocidad relativa, por ejemplo, de -50 a 100.
		var min_relative_speed: float = -50.0 # La policía se aleja si el tiempo es alto
		var max_relative_speed: float = 100.0 # La policía se acerca si el tiempo es bajo
		
		var time_ratio = time_left / initial_time # 1 al inicio, 0 al final
		
		# Interpolamos la velocidad relativa:
		# Si time_ratio es 1 (tiempo_left = initial_time), relative_speed = min_relative_speed
		# Si time_ratio es 0 (tiempo_left = 0), relative_speed = max_relative_speed
		var relative_speed = lerp(max_relative_speed, min_relative_speed, time_ratio)
		
		policia.speed = player_current_speed + relative_speed
		
		# Asegurarse de que la policía no exceda la velocidad máxima absoluta si se desea
		policia.speed = min(policia.speed, police_max_speed)
		
		# Lógica para que la policía esté "muy cerca" a los 5 segundos
		if time_left <= 5.0 and time_left > 0:
			var distance_to_player = player.global_position.distance_to(policia.global_position)
			if distance_to_player > police_close_distance_threshold:
				# Si la policía está lejos, acelerar para que se acerque a la distancia deseada
				policia.speed = player_current_speed + max_relative_speed * 1.5 # Forzar velocidad de acercamiento
	elif not policia_not_found_error_logged:
		push_error("El nodo 'Policia' o 'Player' no se encontró en el Level para actualizar la velocidad.")
		policia_not_found_error_logged = true

# check_game_over_condition ya no es necesaria como función separada
# La condición de Game Over se maneja directamente en _process cuando time_left <= 0
# y la colisión se manejará en el script de la policía o con un área de detección.
# Por ahora, la colisión final se asume cuando time_left es 0 y la policía está cerca.
# La lógica de colisión real (detectar el contacto) se implementaría en Policia o Player.
# Para la condición de Game Over, si time_left es 0, el juego termina.
# La distancia de game_over_distance_threshold se usará para la colisión visual/lógica.

func set_game_over(state: bool) -> void:
	game_over = state
	if game_over:
		game_over_signal.emit()
		print("¡Game Over!")
		get_tree().paused = true # Pausar el juego

func _on_hud_answer_selected(selected_answer_index: int) -> void:
	if game_over:
		return

	if hud:
		var current_question_data = hud.get_current_question_data()
		if current_question_data and current_question_data.has("answers") and current_question_data["answers"] is Array:
			var question_type = current_question_data["type"]
			var answers = current_question_data["answers"]

			var is_correct = false
			match question_type:
				"percentage_choice":
					# Para percentage_choice, asumimos que cualquier respuesta es "correcta"
					# en el sentido de que permite continuar, pero la "success_chance"
					# se usaría para otra lógica (ej. daño al jugador, etc.).
					# Por ahora, cualquier respuesta seleccionada suma tiempo.
					is_correct = true
				"single_choice":
					if current_question_data.has("correct_answer_index"):
						is_correct = (selected_answer_index == current_question_data["correct_answer_index"])
				"true_false":
					if current_question_data.has("correct_answer"):
						var selected_answer_text = answers[selected_answer_index]
						var correct_answer_bool = current_question_data["correct_answer"]
						is_correct = (selected_answer_text == "Verdadero" and correct_answer_bool) or \
									 (selected_answer_text == "Falso" and not correct_answer_bool)
			
			if is_correct:
				time_left += time_bonus_on_correct_answer
				time_left = min(time_left, initial_time) # Limitar el tiempo máximo a initial_time
				time_updated.emit(time_left)
				print("¡Respuesta correcta! Tiempo añadido.")
			else:
				print("Respuesta incorrecta.")
			
			hud.load_random_question() # Cargar la siguiente pregunta
		else:
			push_error("No se pudo obtener la pregunta actual del HUD o no tiene la clave 'answers' o no es un Array.")
	elif not hud_not_found_error_logged:
		push_error("El nodo 'Hud' no se encontró para manejar la respuesta seleccionada.")
		hud_not_found_error_logged = true

func update_parallax_background(delta: float) -> void:
	if player: # Asegurarse de que el nodo Player exista
		for pb in parallax_backgrounds:
			pb.scroll_offset.x -= player.player_speed * delta # Mover el fondo a la velocidad del jugador
	elif not player_not_found_error_logged:
		push_error("El nodo 'Player' no se encontró en el Level para actualizar el ParallaxBackground.")
		player_not_found_error_logged = true # Registrar el error una vez

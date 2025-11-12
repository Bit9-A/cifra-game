extends Node2D

@export var initial_time: float = 60.0
@export var time_bonus_on_correct_answer: float = 5.0
@export var time_penalty_on_wrong_answer: float = 5.0

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
signal game_won_signal() # Nueva señal para indicar la victoria del juego

@export var win_time_threshold: float = 120.0 # Tiempo mínimo para ganar
@export var questions_to_win: int = 15 # Número de preguntas correctas para ganar
var questions_answered_count: int = 0 # Contador de preguntas respondidas

@export var time_drain_increase_interval: int = 5 # Cada cuántas preguntas aumenta la dificultad
@export var time_drain_increase_amount: float = 0.1 # Cuánto más rápido baja el tiempo (multiplicador)
@export var penalty_increase_amount: float = 1.0 # Cuánto más se penaliza por respuesta incorrecta

var current_time_drain_rate: float = 1.0 # Multiplicador actual para la velocidad de bajada del tiempo

@export var laptop_minigame_scene: PackedScene = preload("res://Scenes/UI/LaptopMinigame.tscn")
@export var minigame_activation_chance: float = 0.2 # Probabilidad de activar el minijuego (20%)
var current_laptop_minigame: CanvasLayer = null # Referencia a la instancia del minijuego


func _process(delta: float) -> void:
	if game_over or current_laptop_minigame: # No actualizar el tiempo si el minijuego está activo
		return

	time_left -= delta * current_time_drain_rate # Usar el multiplicador de dificultad
	time_updated.emit(time_left)

	if time_left <= 0:
		time_left = 0
		set_game_over(true) # El juego termina cuando el tiempo llega a 0
	
	update_police_position()
	update_parallax_background(delta)

func update_police_position() -> void:
	if player and policia:
		# Llamar a la función en el script de la policía para que actualice su posición
		policia.update_position_based_on_time(time_left, initial_time, player.global_position.x)
	elif not policia_not_found_error_logged:
		push_error("El nodo 'Policia' o 'Player' no se encontró en el Level para actualizar la posición.")
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
					if selected_answer_index >= 0 and selected_answer_index < answers.size():
						var selected_answer_data = answers[selected_answer_index]
						if selected_answer_data is Dictionary and selected_answer_data.has("success_chance"):
							var success_chance = selected_answer_data["success_chance"]
							randomize()
							var random_roll = randi_range(0, 99) # Número aleatorio entre 0 y 99
							is_correct = (random_roll < success_chance)
						else:
							push_error("HUD: La respuesta seleccionada para percentage_choice no tiene 'success_chance'.")
					else:
						push_error("HUD: Índice de respuesta seleccionado fuera de rango para percentage_choice.")
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
				time_left -= time_penalty_on_wrong_answer
				time_updated.emit(time_left)
				print("Respuesta incorrecta. Tiempo reducido.")
			
			questions_answered_count += 1 # Incrementar el contador de preguntas respondidas
			hud.update_score_display(questions_answered_count, questions_to_win) # Actualizar el score en el HUD
			
			# Aumentar la dificultad cada 'time_drain_increase_interval' preguntas
			if questions_answered_count > 0 and questions_answered_count % time_drain_increase_interval == 0:
				current_time_drain_rate += time_drain_increase_amount
				time_penalty_on_wrong_answer += penalty_increase_amount
				print("¡Dificultad aumentada! Nueva velocidad de tiempo: ", current_time_drain_rate, ", Nueva penalización: ", time_penalty_on_wrong_answer)
				# Opcional: Emitir una señal para que el HUD muestre un mensaje de dificultad aumentada
			
			check_win_condition() # Verificar si se cumple la condición de victoria
			hud.process_answer_feedback(is_correct, selected_answer_index) # Procesar feedback y cargar siguiente pregunta en HUD
			
			# Intentar activar el minijuego de la laptop
			randomize()
			if randf() < minigame_activation_chance and current_laptop_minigame == null:
				activate_laptop_minigame()
				
		else:
			push_error("No se pudo obtener la pregunta actual del HUD o no tiene la clave 'answers' o no es un Array.")
	elif not hud_not_found_error_logged:
		push_error("El nodo 'Hud' no se encontró para manejar la respuesta seleccionada.")
		hud_not_found_error_logged = true

func activate_laptop_minigame() -> void:
	if laptop_minigame_scene:
		current_laptop_minigame = laptop_minigame_scene.instantiate()
		add_child(current_laptop_minigame)
		current_laptop_minigame.minigame_completed.connect(on_laptop_minigame_completed)
		get_tree().paused = true # Pausar el juego principal
		print("Minijuego de la laptop activado.")
	else:
		push_error("Level: No se ha asignado la escena del minijuego de la laptop.")

func on_laptop_minigame_completed(is_success: bool, time_change: float) -> void:
	get_tree().paused = false # Reanudar el juego principal
	time_left += time_change
	time_left = min(time_left, initial_time) # Limitar el tiempo máximo
	time_updated.emit(time_left)
	
	if is_success:
		print("Minijuego de la laptop completado con éxito. Tiempo añadido: ", time_change)
	else:
		print("Minijuego de la laptop fallido. Tiempo penalizado: ", time_change)
		
	current_laptop_minigame.queue_free()
	current_laptop_minigame = null
	check_win_condition() # Volver a verificar la condición de victoria después del minijuego

func check_win_condition() -> void:
	if not game_over and time_left >= win_time_threshold and questions_answered_count >= questions_to_win:
		game_won_signal.emit()
		set_game_over(true) # Pausar el juego y mostrar mensaje de victoria
		print("¡Felicidades! ¡Has ganado el juego!")

func update_parallax_background(delta: float) -> void:
	if player: # Asegurarse de que el nodo Player exista
		for pb in parallax_backgrounds:
			pb.scroll_offset.x -= player.player_speed * delta # Mover el fondo a la velocidad del jugador
	elif not player_not_found_error_logged:
		push_error("El nodo 'Player' no se encontró en el Level para actualizar el ParallaxBackground.")
		player_not_found_error_logged = true # Registrar el error una vez

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
		game_won_signal.connect(Callable(hud, "_on_level_game_won_signal")) # Conectar la señal de victoria
		hud.load_random_question() # Cargar la primera pregunta al inicio del nivel
		hud.update_score_display(questions_answered_count, questions_to_win) # Inicializar el score en el HUD

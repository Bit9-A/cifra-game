extends CanvasLayer

@onready var question_label: RichTextLabel = get_node("Panel/Text")
@onready var answer_buttons_container: Control = get_node("Panel/AnswersButton")
@onready var answer_buttons: Array[Button] = []
@onready var time_label: Label = get_node("Panel/TimeLabel") # Asumiendo que tienes un Label para el tiempo
@onready var score_label: Label = get_node("Panel/Score") # Asumiendo que tienes un Label para el Score

var questions_data: Dictionary
var current_question_index: int = -1
var current_question_data: Dictionary
var answer_delay_time: float = 1.5 # Tiempo de retardo en segundos

signal answer_selected(selected_answer_index: int)
signal request_current_question() # Señal para que el Level pida la pregunta actual
signal question_loaded() # Nueva señal para indicar que una nueva pregunta ha sido cargada

func _ready() -> void:
	print("HUD: _ready() llamado.")
	# Obtener referencias a los botones
	if answer_buttons_container:
		for i in range(answer_buttons_container.get_children().size()):
			var child = answer_buttons_container.get_children()[i]
			if child is Button:
				answer_buttons.append(child)
				child.pressed.connect(on_answer_button_pressed.bind(i)) # Pasar el índice del botón
	else:
		push_error("HUD: El nodo 'Panel/AnswersButton' no se encontró en el HUD.")
		return # Salir si el contenedor de botones no se encuentra

	if question_label == null:
		push_error("HUD: El nodo 'Panel/Text' no se encontró en el HUD.")
		return
	if time_label == null:
		push_error("HUD: El nodo 'Panel/TimeLabel' no se encontró en el HUD.")
		# No retornamos aquí, ya que la falta del TimeLabel no impide mostrar preguntas/respuestas
		
	load_questions_data("res://Data/Questions.json")
	# La carga de la primera pregunta se moverá al Level para que el Level la controle.
	# El Level llamará a load_random_question() en el HUD.

func load_questions_data(path: String) -> void:
	var file = FileAccess.open(path, FileAccess.READ)
	if file:
		var content = file.get_as_text()
		var parse_result = JSON.parse_string(content)
		print("HUD: Resultado del parseo JSON: ", parse_result, " (Tipo: ", typeof(parse_result), ")")
		if parse_result is Dictionary and parse_result.has("questions"):
			questions_data = parse_result
			print("HUD: Preguntas cargadas. Número de preguntas: ", questions_data["questions"].size())
			print("HUD: Contenido de questions_data['questions']: ", questions_data["questions"])
		else:
			push_error("HUD: Error al parsear el JSON de preguntas o falta la clave 'questions': ", parse_result)
		file.close()
	else:
		push_error("HUD: No se pudo abrir el archivo de preguntas: ", path)

func load_random_question() -> void:
	print("HUD: load_random_question() llamado.")
	if questions_data.has("questions") and not questions_data["questions"].is_empty():
		randomize()
		current_question_index = randi() % questions_data["questions"].size()
		var selected_question = questions_data["questions"][current_question_index]
		print("HUD: Pregunta seleccionada: ", selected_question, " (Tipo: ", typeof(selected_question), ")")
		
		if selected_question is Dictionary and selected_question.has("question"):
			current_question_data = selected_question # Establecer current_question_data con la pregunta completa
			display_question(current_question_data)
			print("HUD: Pregunta mostrada: ", current_question_data["question"])
		else:
			push_error("HUD: La pregunta seleccionada no tiene el formato esperado (falta 'question').")
			current_question_data = {} # Asegurarse de que sea un diccionario vacío si hay un error
	else:
		push_error("HUD: No hay preguntas para cargar o questions_data está vacío.")
		current_question_data = {} # Asegurarse de que sea un diccionario vacío si hay un error

func display_question(question_obj: Dictionary) -> void:
	if not question_obj.has("question"):
		push_error("HUD: El objeto de pregunta no tiene la clave 'question'.")
		return
	question_label.text = question_obj["question"]

	var answers_to_display: Array[String] = []
	if question_obj.has("type"):
		var question_type = question_obj["type"]
		if question_type == "true_false":
			answers_to_display = ["Verdadero", "Falso"]
		elif question_type == "single_choice":
			if question_obj.has("answers") and question_obj["answers"] is Array:
				# Asegurarnos de convertir todos los elementos a String para evitar errores de tipo
				for ans in question_obj["answers"]:
					answers_to_display.append(str(ans))
			else:
				push_error("HUD: single_choice sin 'answers' o 'answers' no es Array en display_question.")
		elif question_type == "percentage_choice":
			if question_obj.has("answers") and question_obj["answers"] is Array:
				# Para percentage_choice, extraemos solo el texto de las respuestas
				for ans_dict in question_obj["answers"]:
					if ans_dict is Dictionary and ans_dict.has("text"):
						answers_to_display.append(str(ans_dict["text"]))
					else:
						answers_to_display.append("Respuesta inválida")
			else:
				push_error("HUD: percentage_choice sin 'answers' o 'answers' no es Array en display_question.")
		else:
			push_error("HUD: Tipo de pregunta desconocido o respuestas mal formadas para display_question: ", question_type)
	else:
		push_error("HUD: El objeto de pregunta no tiene la clave 'type' para display_question.")

	print("HUD: Respuestas a mostrar: ", answers_to_display, " (Tipo: ", typeof(answers_to_display), ")")

	for i in range(answer_buttons.size()):
		if i < answers_to_display.size():
			answer_buttons[i].text = answers_to_display[i]
			answer_buttons[i].show()
		else:
			answer_buttons[i].hide()

func on_answer_button_pressed(index: int) -> void:
	# Deshabilitar todos los botones para evitar múltiples selecciones
	for button in answer_buttons:
		button.disabled = true
	answer_selected.emit(index) # Emitir la señal con el índice de la respuesta

func process_answer_feedback(is_correct: bool, selected_index: int) -> void:
	if selected_index >= 0 and selected_index < answer_buttons.size():
		var selected_button = answer_buttons[selected_index]
		if is_correct:
			selected_button.modulate = Color.GREEN
		else:
			selected_button.modulate = Color.RED
	
	await get_tree().create_timer(answer_delay_time).timeout
	
	# Restablecer colores y habilitar botones
	for button in answer_buttons:
		button.modulate = Color.WHITE # Restablecer el color a blanco (o el color original)
		button.disabled = false
	
	load_random_question() # Cargar la siguiente pregunta después del retardo

func get_current_question_data() -> Dictionary:
	if current_question_data:
		var data_to_return = current_question_data.duplicate() # Devolver una copia para evitar modificaciones externas
		
		if data_to_return.has("type"):
			var question_type = data_to_return["type"]
			
			if question_type == "true_false":
				# Para true_false, las respuestas son fijas "Verdadero" y "Falso"
				data_to_return["answers"] = ["Verdadero", "Falso"]
			elif question_type == "single_choice":
				# Para single_choice, las respuestas ya son un array de strings
				# Asegurarse de que la clave 'answers' exista y sea un Array
				if not data_to_return.has("answers") or not (data_to_return["answers"] is Array):
					push_error("HUD: Pregunta single_choice mal formada: falta 'answers' o no es un Array.")
					data_to_return["answers"] = []
				else:
					# Convertir todos los elementos a String para mantener Array[String]
					var str_answers: Array[String] = []
					for a in data_to_return["answers"]:
						str_answers.append(str(a))
					data_to_return["answers"] = str_answers
			elif question_type == "percentage_choice":
				# Para percentage_choice, las respuestas son un array de diccionarios con "text"
				# Asegurarse de que la clave 'answers' exista y sea un Array
				if not data_to_return.has("answers") or not (data_to_return["answers"] is Array):
					push_error("HUD: Pregunta percentage_choice mal formada: falta 'answers' o no es un Array.")
					data_to_return["answers"] = []
			else:
				push_error("HUD: Tipo de pregunta desconocido: ", question_type)
				data_to_return["answers"] = [] # Fallback
		else:
			push_error("HUD: current_question_data no tiene la clave 'type'.")
			data_to_return["answers"] = [] # Fallback
		
		# Asegurarse de que 'answers' siempre sea un Array antes de devolver
		if not data_to_return.has("answers") or not (data_to_return["answers"] is Array):
			push_error("HUD: Fallback: 'answers' no es un Array después de procesar.")
			data_to_return["answers"] = []
			
		return data_to_return
	else:
		push_error("HUD: current_question_data es nulo.")
		return {} # Devolver un diccionario vacío si no es válido

func _on_level_time_updated(new_time: float) -> void:
	time_label.text = "Tiempo: %d" % int(new_time)

func update_score_display(answered_count: int, total_to_win: int) -> void:
	if score_label:
		score_label.text = "Preguntas: %d/%d" % [answered_count, total_to_win]

func _on_level_game_over_signal() -> void:
	time_label.text = "¡Game Over!"
	# Aquí puedes añadir más lógica para la pantalla de Game Over en el HUD

func _on_level_game_won_signal() -> void:
	time_label.text = "¡Has Ganado!"
	# Aquí puedes añadir más lógica para la pantalla de victoria en el HUD

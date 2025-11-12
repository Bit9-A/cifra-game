extends CanvasLayer

@onready var word_display_label: RichTextLabel = get_node("Panel/WordDisplay")
@onready var guess_input: LineEdit = get_node("Panel/GuessInput")
@onready var submit_button: Button = get_node("Panel/SubmitButton")
@onready var feedback_label: Label = get_node("Panel/FeedbackLabel")
@onready var timer: Timer = get_node("Panel/Timer")

@export var minigame_time_limit: float = 10.0 # Tiempo para completar el minijuego
@export var time_reward_on_success: float = 10.0
@export var time_penalty_on_fail: float = 7.0

@export var attempts_required: int = 5 # Número de palabras/rounds que hay que completar dentro del minijuego

var words_data: Array[String] = []
var current_word: String = ""
var hidden_word_display: String = ""

var attempts_done: int = 0
var successes: int = 0

signal minigame_completed(is_success: bool, time_change: float)

func _ready() -> void:
	submit_button.pressed.connect(on_submit_button_pressed)
	timer.timeout.connect(on_timer_timeout)
	timer.wait_time = minigame_time_limit
	
	load_words_data("res://Data/Words.json")
	start_minigame()

	# Permitir enviar la respuesta con Enter (conectar la señal disponible según la versión de Godot)
	if guess_input and guess_input.has_signal("text_entered"):
		guess_input.text_entered.connect(on_guess_text_entered)
	elif guess_input and guess_input.has_signal("text_submitted"):
		guess_input.text_submitted.connect(on_guess_text_entered)

func load_words_data(path: String) -> void:
	var file = FileAccess.open(path, FileAccess.READ)
	if file:
		var content = file.get_as_text()
		var parse_result = JSON.parse_string(content)
		if parse_result is Dictionary and parse_result.has("words") and parse_result["words"] is Array:
			# Convertir a Array[String] para evitar errores de tipo si el JSON contiene valores no-string
			var raw_words = parse_result["words"]
			var str_words: Array[String] = []
			for w in raw_words:
				str_words.append(str(w))
			words_data = str_words
		else:
			push_error("LaptopMinigame: Error al parsear el JSON de palabras o falta la clave 'words'.")
		file.close()
	else:
		push_error("LaptopMinigame: No se pudo abrir el archivo de palabras: ", path)

func start_minigame() -> void:
	if words_data.is_empty():
		push_error("LaptopMinigame: No hay palabras para el minijuego.")
		minigame_completed.emit(false, -time_penalty_on_fail)
		queue_free()
		return

	# Inicializar contadores y comenzar la primera palabra
	randomize()
	attempts_done = 0
	successes = 0
	start_next_attempt()
	guess_input.grab_focus()

func start_next_attempt() -> void:
	# Selecciona una nueva palabra, la oculta y prepara la UI para el intento
	current_word = words_data[randi() % words_data.size()].to_upper()
	hidden_word_display = hide_word(current_word)

	word_display_label.text = hidden_word_display
	guess_input.text = ""
	feedback_label.text = ""
	guess_input.editable = true
	submit_button.disabled = false
	timer.start()

func hide_word(word: String) -> String:
	var hidden = ""
	var chars_to_hide = max(1, word.length() / 3) # Ocultar al menos 1/3 de las letras
	var hidden_indices = []
	
	while hidden_indices.size() < chars_to_hide:
		var rand_index = randi() % word.length()
		if not rand_index in hidden_indices:
			hidden_indices.append(rand_index)
			
	for i in range(word.length()):
		if i in hidden_indices:
			hidden += "_"
		else:
			hidden += word[i]
	return hidden

func on_submit_button_pressed() -> void:
	timer.stop()
	check_guess()

func on_timer_timeout() -> void:
	# Contar como intento fallido y continuar o terminar según corresponda
	feedback_label.text = "¡Tiempo agotado! La palabra era: %s" % current_word
	guess_input.editable = false
	submit_button.disabled = true
	attempts_done += 1
	# Pequeño retardo para mostrar feedback
	await get_tree().create_timer(1.0).timeout
	if attempts_done < attempts_required:
		# Continuar con la siguiente palabra
		start_next_attempt()
	else:
		# Finalizar minijuego: emitir resultado acumulado
		finalize_minigame()

func check_guess() -> void:
	var player_guess = guess_input.text.to_upper()
	if player_guess == current_word:
		# Intento exitoso
		feedback_label.text = "¡Correcto!"
		guess_input.editable = false
		submit_button.disabled = true
		successes += 1
		attempts_done += 1
		await get_tree().create_timer(1.0).timeout
		if attempts_done < attempts_required:
			start_next_attempt()
		else:
			finalize_minigame()
	else:
		# Intento fallido: mostrar feedback y reintentar (cuenta como intento fallido)
		feedback_label.text = "Incorrecto. Intenta de nuevo."
		guess_input.text = ""
		guess_input.grab_focus()
		attempts_done += 1
		if attempts_done < attempts_required:
			timer.start() # Reiniciar el temporizador para otro intento
		else:
			# Ya se completaron todos los intentos
			finalize_minigame()

func finalize_minigame() -> void:
	# Calcular el cambio total de tiempo según éxitos y fallos
	var fails = attempts_required - successes
	var total_time_change = successes * time_reward_on_success - fails * time_penalty_on_fail
	var is_success = total_time_change > 0
	# Emitir el resultado acumulado
	minigame_completed.emit(is_success, total_time_change)
	queue_free()

func on_guess_text_entered(submitted_text: String) -> void:
	# Maneja el envío con Enter desde el LineEdit
	# Parar el temporizador y procesar la respuesta tal como hace el botón
	timer.stop()
	check_guess()

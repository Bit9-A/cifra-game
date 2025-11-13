extends CanvasLayer

@onready var question_label: RichTextLabel = get_node("Panel/Panel2/Text")
@onready var answer_buttons_container: Control = get_node("Panel/Panel2/AnswersButton")
@onready var answer_buttons: Array[Button] = []
@onready var time_label: Label = get_node("Panel/TimeLabel")
@onready var score_label: Label = get_node("Panel/Panel2/Score")

var questions_data: Dictionary = {}
var current_question_index: int = -1
var current_question_data: Dictionary = {}
var answer_delay_time: float = 1.5

signal answer_selected(selected_answer_index: int)
signal request_current_question()
signal question_loaded()

func _ready() -> void:
	# Inicializar botones de respuesta
	if answer_buttons_container:
		for child in answer_buttons_container.get_children():
			if child is Button:
				var idx = answer_buttons.size()
				answer_buttons.append(child)
				child.pressed.connect(on_answer_button_pressed.bind(idx))
	else:
		push_error("HUD: El contenedor de botones no existe: Panel/Panel2/AnswersButton")

	# Mantener un LaptopMinigame precolocado oculto si existe
	var preplaced_lm = get_node_or_null("LaptopMinigame")
	if preplaced_lm:
		preplaced_lm.visible = false

	load_questions_data("res://Data/Questions.json")

func load_questions_data(path: String) -> void:
	var f = FileAccess.open(path, FileAccess.READ)
	if not f:
		push_error("HUD: No se pudo abrir archivo: %s" % path)
		return
	var content = f.get_as_text()
	f.close()
	var parsed = JSON.parse_string(content)
	if parsed is Dictionary and parsed.has("questions"):
		questions_data = parsed
		# emitir señal para que otros nodos sepan que hay preguntas cargadas
		emit_signal("question_loaded")
	else:
		push_error("HUD: JSON de preguntas inválido o falta 'questions'")

func load_random_question() -> void:
	if not questions_data or not questions_data.has("questions"):
		push_error("HUD: No hay preguntas cargadas para elegir.")
		return
	var list = questions_data["questions"]
	if list.is_empty():
		push_error("HUD: La lista de preguntas está vacía.")
		return
	current_question_index = randi() % list.size()
	current_question_data = list[current_question_index]
	display_question(current_question_data)

func display_question(question_obj: Dictionary) -> void:
	if not question_obj or not question_obj.has("question"):
		push_error("HUD: Pregunta mal formada en display_question")
		return
	question_label.text = str(question_obj["question"])

	var answers_to_display: Array = []
	var qtype = question_obj.get("type", "single_choice")
	if qtype == "true_false":
		answers_to_display = ["Verdadero", "Falso"]
	elif qtype == "single_choice":
		var raw = question_obj.get("answers", [])
		for a in raw:
			answers_to_display.append(str(a))
	elif qtype == "percentage_choice":
		var raw2 = question_obj.get("answers", [])
		for d in raw2:
			if d is Dictionary and d.has("text"):
				answers_to_display.append(str(d["text"]))
			else:
				answers_to_display.append("Respuesta")

	# Rellenar botones
	for i in range(answer_buttons.size()):
		if i < answers_to_display.size():
			answer_buttons[i].text = str(answers_to_display[i])
			answer_buttons[i].visible = true
			answer_buttons[i].disabled = false
			answer_buttons[i].modulate = Color(1,1,1)
		else:
			answer_buttons[i].visible = false

func on_answer_button_pressed(index: int) -> void:
	for b in answer_buttons:
		b.disabled = true
	emit_signal("answer_selected", index)

func process_answer_feedback(is_correct: bool, selected_index: int) -> void:
	if selected_index >=0 and selected_index < answer_buttons.size():
		var btn = answer_buttons[selected_index]
		btn.modulate = Color(0,1,0) if is_correct else Color(1,0,0)
	await get_tree().create_timer(answer_delay_time).timeout
	for b in answer_buttons:
		b.modulate = Color(1,1,1)
		b.disabled = false
	load_random_question()

func get_current_question_data() -> Dictionary:
	if not current_question_data:
		return {}
	var copy = current_question_data.duplicate()
	var qtype = copy.get("type", "single_choice")
	if qtype == "true_false":
		copy["answers"] = ["Verdadero","Falso"]
	elif qtype == "single_choice":
		var out: Array = []
		for a in copy.get("answers", []):
			out.append(str(a))
		copy["answers"] = out
	return copy

func _on_level_time_updated(new_time: float) -> void:
	if time_label:
		time_label.text = "Tiempo: %d" % int(new_time)

func update_score_display(answered_count: int, total_to_win: int) -> void:
	if score_label:
		score_label.text = "Preguntas: %d/%d" % [answered_count, total_to_win]

func _on_level_game_over_signal() -> void:
	if time_label:
		time_label.text = "¡Game Over!"

func _on_level_game_won_signal() -> void:
	if time_label:
		time_label.text = "¡Has Ganado!"

func hide_game_ui(fade: bool = true) -> void:
	var panel2 = get_node_or_null("Panel/Panel2")
	if not panel2:
		return
	if fade and panel2 is CanvasItem:
		panel2.modulate.a = panel2.modulate.a if panel2.modulate else 1.0
		var tw = create_tween()
		tw.tween_property(panel2, "modulate:a", 0.0, 0.25)
		tw.connect("finished", Callable(self, "_on_panel2_hidden_finished"))
	else:
		panel2.visible = false
	if question_label:
		question_label.visible = false
	for b in answer_buttons:
		b.visible = false

func _on_panel2_hidden_finished() -> void:
	var panel2 = get_node_or_null("Panel/Panel2")
	if panel2:
		panel2.visible = false

func show_game_ui(fade: bool = true) -> void:
	var panel2 = get_node_or_null("Panel/Panel2")
	if not panel2:
		return
	panel2.visible = true
	if fade and panel2 is CanvasItem:
		panel2.modulate.a = 0.0
		var tw = create_tween()
		tw.tween_property(panel2, "modulate:a", 1.0, 0.25)
	if question_label:
		question_label.visible = true
	for b in answer_buttons:
		b.visible = true

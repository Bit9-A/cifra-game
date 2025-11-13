extends Control


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	$Center/Score.bbcode_text = "[center]Preguntas contestadas[/center] \n %d" % Global.last_questions_answered
	
	$Center/Correct.bbcode_text = "[center][color=green]Respuestas correctas:[/color][/center] %d" % Global.last_correct_answers
	
	$Center/Wrong.bbcode_text = "[center][color=red]Respuestas incorrectas:[/color][/center] %d" % Global.last_wrong_answers
	Global.reset_scores()

	# Iniciar timer para cambiar al menú automáticamente luego de un tiempo
	$Timer.start()
func _on_timer_timeout() -> void:
	get_tree().change_scene_to_file("res://Scenes/UI/Menu.tscn")


func _on_play_again_pressed() -> void:
	get_tree().change_scene_to_file("res://Scenes/Level/level.tscn")


func _on_exit_menu_pressed() -> void:
	get_tree().change_scene_to_file("res://Scenes/UI/Menu.tscn")

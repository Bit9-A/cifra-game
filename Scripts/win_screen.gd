extends Control


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
# Construir texto con formato BBCode para cada RichTextLabel

	$Center/Score.bbcode_text = "\n\n[center]Preguntas contestadas[/center] \n"
	
	$Center/Correct.bbcode_text = "\n\n[center][color=green]Respuestas correctas:[/color][/center] %d" % Global.last_correct_answers
	
	$Center/Wrong.bbcode_text = "\n\n[center][color=red]Respuestas incorrectas:[/color][/center] %d" % Global.last_wrong_answers
	# Limpiar scores para la próxima partida
	Global.reset_scores()

func _on_play_again_pressed() -> void:
	get_tree().change_scene_to_file("res://Scenes/Level/level.tscn")


func _on_exit_menu_pressed() -> void:
	get_tree().change_scene_to_file("res://Scenes/UI/Menu.tscn")

extends Node

# Variables para almacenar datos del score
var last_questions_answered: int = 0
var last_correct_answers: int = 0
var last_wrong_answers: int = 0
var last_time_left: float = 0.0

# Método para resetear valores si quieres (opcional)
func reset_scores():
	last_questions_answered = 0
	last_correct_answers = 0
	last_wrong_answers = 0
	last_time_left = 0.0

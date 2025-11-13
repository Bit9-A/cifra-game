extends Control
@onready var start_button = $MenuButtons/Start
@onready var options_button = $MenuButtons/Options
@onready var exit_button = $MenuButtons/Exit

@onready var options_panel = $OptionsPanel
@onready var close_options_button = $OptionsPanel/VBoxContainer/CloseButton
@onready var volume_slider = $OptionsPanel/VBoxContainer/Music

func _ready():
	start_button.pressed.connect(_on_start_pressed)
	options_button.pressed.connect(_on_options_pressed)
	exit_button.pressed.connect(_on_exit_pressed)
	close_options_button.pressed.connect(_on_close_options_pressed)
	
	options_panel.visible = false
	# Configurar slider volumen y conectar señal de cambio
	volume_slider.min_value = 0.0
	volume_slider.max_value = 1.0
	volume_slider.step = 0.01
	
	var master_bus_index = AudioServer.get_bus_index("Master")
	var current_db = AudioServer.get_bus_volume_db(master_bus_index)
	volume_slider.value = db_to_linear(current_db)  # Convertir dB a valor lineal para ajustar slider
	
	volume_slider.value_changed.connect(_on_volume_slider_changed)

func _on_start_pressed() -> void:
	get_tree().change_scene_to_file("res://Scenes/Level/level.tscn")


func _on_options_pressed() -> void:
	options_panel.visible = true
	$MenuButtons.visible = false

func _on_exit_pressed() -> void:
	get_tree().quit()
	
	
func _on_close_options_pressed():
	print("Cerrar menú de opciones")
	options_panel.visible = false
	$MenuButtons.visible = true

func _on_volume_slider_changed(value):
	var master_bus_index = AudioServer.get_bus_index("Master")
	var db_volume = linear_to_db(value)  # Función correcta para pasar valor lineal a decibelios
	AudioServer.set_bus_volume_db(master_bus_index, db_volume)

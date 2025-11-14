extends CanvasLayer

# Exported arrays to map character names -> textures. Keep them in the same index order.
# Prefer `avatar_map` (below) for an inspector-friendly single mapping. Arrays are kept for
# backward compatibility.
@export var avatar_names: Array[String] = []
@export var avatar_textures: Array[Texture2D] = []

# A Dictionary mapping character name -> Texture2D. This is the preferred way to assign
# avatars in the inspector: e.g. { "Cifra": preload("res://path/to/cifra.png"), ... }
@export var avatar_map: Dictionary = {}

# The action to use for advancing the dialogue
@export var next_action: StringName = &"ui_accept"

# The action to use to skip typing the dialogue
@export var skip_action: StringName = &"ui_cancel"


var resource
var temporary_game_states: Array = []
var is_waiting_for_input: bool = false

var _avatar_map: Dictionary = {}

@onready var dialogue_label = $Panel/DialogueLabel
@onready var avatar = $Panel/Avatar
@onready var nameC = $Panel/Name

# Enable to print avatar-lookup debug info to the console
@export var debug_avatar_lookup: bool = false

# If true, attempt to auto-start a dialogue resource at `res://Data/Dialogo.dialogue` when this node is ready.
@export var auto_start_dialogue: bool = true


func _ready() -> void:
	# Rebuild/populate avatar map from exports/arrays and try auto-loading from folder
	refresh_avatar_map_from_export()

	# If still empty, try the explicit default avatar files included in the project.
	if _avatar_map.size() == 0:
		var try_paths: Dictionary = {
			"Cifra": "res://Assets/sprites/avatars/cifra.jpg",
			"IA": "res://Assets/sprites/avatars/IA.jpg",
			"MM": "res://Assets/sprites/avatars/MM.png",
			"Oficial John": "res://Assets/sprites/avatars/policia.png",
		}
		for name in try_paths.keys():
			var p: String = try_paths[name]
			var tex = ResourceLoader.load(p)
			if tex is Texture2D:
				_avatar_map[str(name)] = tex
				_avatar_map[str(name).to_lower()] = tex
				_avatar_map[str(name).to_upper()] = tex
				_avatar_map[str(name).strip_edges()] = tex

		if _avatar_map.size() > 0:
			push_warning("GUIDialog: loaded default avatar(s): %d" % _avatar_map.size())

	# Start hidden (dialogue will show when needed)
	visible = true
	avatar.visible = false
	# Hide name label until a speaker is set
	if nameC:
		nameC.visible = false

	# Connect signals from the label
	if dialogue_label and dialogue_label.has_method("finished_typing"):
		dialogue_label.finished_typing.connect(_on_finished_typing)

	# Optionally auto-start a known dialogue resource (convenience for intro/dialog files)
	if auto_start_dialogue and FileAccess.file_exists("res://Data/Dialogo.dialogue"):
		var dlg_res = load("res://Data/Dialogo.dialogue")
		if dlg_res:
			# Before starting an intro dialogue, hide the main gameplay UI (if parent HUD provides it)
			var parent_hud = get_parent()
			if parent_hud and parent_hud.has_method("hide_game_ui"):
				# Don't animate the hide; we want it hidden immediately for the intro
				parent_hud.hide_game_ui(false)
			# Also attempt to disable player movement while the intro runs (if player provides the API)
			var cur_scene = get_tree().get_current_scene()
			if cur_scene:
				var p = cur_scene.get_node_or_null("Player")
				if p and p.has_method("disable_movement"):
					p.disable_movement()
			# Use empty title to start at the resource's configured first title
			self.start(dlg_res, "")


## Start some dialogue
func start(dialogue_resource, title: String = "", extra_game_states: Array = []) -> void:
	temporary_game_states = [self] + extra_game_states
	resource = dialogue_resource
	is_waiting_for_input = false
	self.dialogue_line = await resource.get_next_dialogue_line(title, temporary_game_states)


## Property-like holder for the current dialogue line. When set, apply its contents.
var dialogue_line:
	set(value):
		dialogue_line = value
		if value:
			apply_dialogue_line()
		else:
			# conversation ended
			queue_free()
	get:
		return dialogue_line


func apply_dialogue_line() -> void:
	is_waiting_for_input = false

	# Update avatar according to the speaking character (if we have a mapping)
	var character_name: String = dialogue_line.character if dialogue_line and dialogue_line.character != null else ""
	if debug_avatar_lookup:
		print("GUIDialog: apply_dialogue_line - speaker raw=<'%s'>" % [str(character_name)])
	# Update name label
	if nameC:
		if character_name != "":
			nameC.text = str(character_name)
			nameC.visible = true
		else:
			nameC.text = ""
			nameC.visible = false

	var tex: Texture2D = _lookup_avatar(character_name)
	if tex:
		if debug_avatar_lookup:
			print("GUIDialog: avatar found for '%s'" % [str(character_name)])
		avatar.texture = tex
		avatar.visible = true
	else:
		if debug_avatar_lookup:
			print("GUIDialog: NO avatar found for '%s'" % [str(character_name)])
		avatar.texture = null
		avatar.visible = false

	# Set the dialogue on the label and start typing
	if dialogue_label != null:
		dialogue_label.hide()
		dialogue_label.dialogue_line = dialogue_line
		dialogue_label.show()
		if not str(dialogue_line.text).is_empty():
			dialogue_label.type_out()
			await dialogue_label.finished_typing

	# If the line contains an auto-time then advance after the given time
	if dialogue_line.time != "":
		var t = float(dialogue_line.text.length()) * 0.02 if dialogue_line.time == "auto" else float(dialogue_line.time)
		await get_tree().create_timer(t).timeout
		next(dialogue_line.next_id)
	else:
		# Wait for user input to advance unless responses exist (not handled here)
		is_waiting_for_input = true


func next(next_id: String) -> void:
	# Fetch and apply the next line
	is_waiting_for_input = false
	self.dialogue_line = await resource.get_next_dialogue_line(next_id, temporary_game_states)


func _unhandled_input(event) -> void:
	# Allow skipping typing
	if dialogue_label and dialogue_label.is_typing and Input.is_action_pressed(skip_action):
		get_viewport().set_input_as_handled()
		dialogue_label.skip_typing()
		return

	if not is_waiting_for_input: return
	# When there are no response options the balloon itself is the clickable thing
	get_viewport().set_input_as_handled()

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.is_pressed():
		next(dialogue_line.next_id)
	elif event is InputEventKey and event.is_pressed() and Input.is_action_pressed(next_action):
		next(dialogue_line.next_id)


func _on_finished_typing() -> void:
	# Called when the DialogueLabel finished typing; allow advancing
	is_waiting_for_input = true


## Runtime helpers for avatar management
func set_avatar(name: String, texture: Texture2D) -> void:
	"""Set or replace an avatar at runtime for `name`. Updates the internal mapping used when
	a character speaks."""
	if name == "":
		return
	_avatar_map[name] = texture


func remove_avatar(name: String) -> void:
	if _avatar_map.has(name):
		_avatar_map.erase(name)


func clear_avatars() -> void:
	_avatar_map.clear()


func refresh_avatar_map_from_export() -> void:
	"""Rebuild internal avatar mapping from the exported `avatar_map` Dictionary or the
	parallel arrays (fallback). Call this if you change exports at runtime."""
	_avatar_map.clear()
	if avatar_map.size() > 0:
		for k in avatar_map.keys():
			var key_name: String = str(k).strip_edges()
			var val = avatar_map[k]
			if val is Texture2D:
				_avatar_map[key_name] = val
				_avatar_map[key_name.to_lower()] = val
				_avatar_map[key_name.to_upper()] = val
				_avatar_map[key_name.strip_edges()] = val
	else:
		var max_len: int = max(avatar_names.size(), avatar_textures.size())
		for i in range(max_len):
			if i < avatar_names.size() and i < avatar_textures.size():
				var name: String = str(avatar_names[i])
				var tex: Texture2D = avatar_textures[i]
				if name != "" and tex != null:
					_avatar_map[name] = tex
					_avatar_map[name.to_lower()] = tex
					_avatar_map[name.to_upper()] = tex
					_avatar_map[name.strip_edges()] = tex

	# If still empty, try to auto-load textures from the avatars folder by filename
	if _avatar_map.size() == 0:
		var dir_path: String = "res://Assets/sprites/avatars"
		var dir := DirAccess.open(dir_path)
		if dir:
				dir.list_dir_begin()
				var file_name: String = dir.get_next()
				while file_name != "":
					# skip directories
					if dir.current_is_dir():
						file_name = dir.get_next()
						continue
					# Handle Godot .import files by stripping the trailing .import
					var candidate: String = file_name
					if candidate.ends_with(".import"):
						candidate = candidate.substr(0, candidate.length() - ".import".length())
					# Attempt to load the resource at the candidate path
					var candidate_path: String = "%s/%s" % [dir_path, candidate]
					var tex = ResourceLoader.load(candidate_path)
					if tex is Texture2D:
						var base = candidate
						# strip extension from base name
						var dot = base.rfind(".")
						if dot >= 0:
							base = base.substr(0, dot)
						# register multiple lookup keys to be forgiving with capitalization and spacing
						_avatar_map[base] = tex
						_avatar_map[base.to_lower()] = tex
						_avatar_map[base.to_upper()] = tex
						_avatar_map[base.strip_edges()] = tex
					file_name = dir.get_next()
				dir.list_dir_end()
				if _avatar_map.size() > 0:
					push_warning("GUIDialog: auto-loaded %d avatar(s) from %s" % [_avatar_map.size(), dir_path])


# --- Avatar name helpers -------------------------------------------------
func _remove_accents(s: String) -> String:
	# Minimal replacement table for common accented characters used in names.
	var table := {
		"á": "a", "à": "a", "ä": "a", "â": "a", "ã": "a",
		"Á": "A", "À": "A", "Ä": "A", "Â": "A", "Ã": "A",
		"é": "e", "è": "e", "ë": "e", "ê": "e",
		"É": "E", "È": "E", "Ë": "E", "Ê": "E",
		"í": "i", "ì": "i", "ï": "i", "î": "i",
		"Í": "I", "Ì": "I", "Ï": "I", "Î": "I",
		"ó": "o", "ò": "o", "ö": "o", "ô": "o", "õ": "o",
		"Ó": "O", "Ò": "O", "Ö": "O", "Ô": "O", "Õ": "O",
		"ú": "u", "ù": "u", "ü": "u", "û": "u",
		"Ú": "U", "Ù": "U", "Ü": "U", "Û": "U",
		"ñ": "n", "Ñ": "N"
	}
	var out := ""
	for i in s:
		var ch = String(i)
		out += table[ch] if table.has(ch) else ch
	return out


func _lookup_avatar(name: String) -> Texture2D:
	if name == null:
		return null
	var n: String = str(name).strip_edges()
	if n == "":
		return null

	var tries: Array = []
	tries.append(n)
	tries.append(n.strip_edges())
	tries.append(n.to_lower())
	tries.append(n.to_upper())
	tries.append(_remove_accents(n))
	tries.append(_remove_accents(n).to_lower())
	tries.append(n.replace(" ", "").to_lower())

	for t in tries:
		if t != null and _avatar_map.has(t):
			if debug_avatar_lookup:
				print("GUIDialog: _lookup_avatar - tried key=<'%s'> -> matched" % [str(t)])
			return _avatar_map[t]

	# Try loose substring matching (case-insensitive)
	var nl = n.to_lower()
	for k in _avatar_map.keys():
		if String(k).to_lower().find(nl) != -1 or nl.find(String(k).to_lower()) != -1:
			if debug_avatar_lookup:
				print("GUIDialog: _lookup_avatar - substring match speaker=<'%s'> matched_key=<'%s'>" % [str(n), str(k)])
			return _avatar_map[k]

	return null

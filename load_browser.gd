extends Window

signal load_selected(save_name)
signal cancelled

@onready var load_list: ItemList = $MarginContainer/VBoxContainer/LoadList
@onready var load_button: Button = $MarginContainer/VBoxContainer/HBoxContainer/LoadButton

const SAVE_FOLDER = "res://data/savefiles"

func _ready():
	DirAccess.make_dir_recursive_absolute(SAVE_FOLDER)
	refresh_list()

func refresh_list():
	load_list.clear()

	var dir := DirAccess.open(SAVE_FOLDER)

	if dir == null:
		return

	dir.list_dir_begin()

	while true:
		var file = dir.get_next()
		
		var file_name = file.get_basename()

		if file == "":
			break

		if dir.current_is_dir():
			continue

		if file.ends_with(".json") and not file_name.ends_with(".state"):
			load_list.add_item(file_name)

	dir.list_dir_end()

	load_button.disabled = load_list.item_count == 0

func _on_load_list_item_selected(index: int):
	load_button.disabled = false

func _on_load_button_pressed():

	var selected := load_list.get_selected_items()

	if selected.is_empty():
		return

	var save_name := load_list.get_item_text(selected[0])
	
	print(save_name)

	emit_signal("load_selected", save_name)

	hide()

func _on_cancel_button_pressed():
	emit_signal("cancelled")
	hide()

func _on_close_requested():
	emit_signal("cancelled")
	hide()

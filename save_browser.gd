extends Window

signal save_selected(save_name)
signal cancelled

@onready var save_name = $MarginContainer/VBoxContainer/SaveName
@onready var save_list = $MarginContainer/VBoxContainer/SaveList
@onready var save_button = %SaveButton

const SAVE_FOLDER = "user://saves"

func _ready():
	DirAccess.make_dir_recursive_absolute(SAVE_FOLDER)
	save_name.text = get_default_save_name()
	refresh_list()

func get_default_save_name() -> String:
	var datetime = Time.get_datetime_dict_from_system()

	return "%04d-%02d-%02d_%02d-%02d-%02d" % [
		datetime.year,
		datetime.month,
		datetime.day,
		datetime.hour,
		datetime.minute,
		datetime.second
	]

func refresh_list():

	save_list.clear()

	var dir = DirAccess.open(SAVE_FOLDER)

	if dir == null:
		return

	dir.list_dir_begin()

	while true:

		var file = dir.get_next()
		
		var file_name = file.get_basename()

		if file == "":
			break

		if file.ends_with(".json") and not file_name.ends_with(".state"):
			save_list.add_item(file_name)

	dir.list_dir_end()
	
func _on_save_list_item_selected(index):

	save_name.text = save_list.get_item_text(index)

func _on_save_button_pressed():
	if save_name.text.strip_edges() == "":
		return
		
	emit_signal("save_selected", save_name.text.strip_edges())
	
	hide()

func _on_cancel_button_pressed():
	emit_signal("cancelled")
	
	hide()

func _on_close_requested():
	emit_signal("cancelled")
	
	hide()

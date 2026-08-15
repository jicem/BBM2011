extends Node2D
var database : SQLite
var save_folder = "res://data/savefiles/"
@onready var titletext = $TitleText
@onready var loadingtext = $LoadingText
@onready var manual = $Manual
@onready var timer = $Timer

# Called when the node enters the scene tree for the first time.
func _ready():
	# Open database from bball.db file
	database = SQLite.new()
	database.path = "res://data/bball.db"
	database.open_db()

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass


func _on_button_pressed():
	Global.nba_players = true
	titletext.hide()
	loadingtext.show()
	timer.start()


func _on_button_2_pressed():
	Global.nba_players = false
	titletext.hide()
	loadingtext.show()
	timer.start()


func _on_quit_pressed():
	get_tree().quit()


func _on_timer_timeout():
	LeagueGenerator.generate(database)
	get_tree().change_scene_to_file("res://schoolselection.tscn")


func _on_load_pressed():
	var browser = preload("res://LoadBrowser.tscn").instantiate()
	add_child(browser)
	browser.title = "Load League"
	browser.load_selected.connect(load_league)


func load_league(save_name: String):
	# Load the database
	database.import_from_json("%s%s.json" % [save_folder, save_name])

	# Load the global state
	var file = FileAccess.open(
		"%s%s.state.json" % [save_folder, save_name],
		FileAccess.READ
	)

	if file == null:
		push_error("Couldn't load save state.")
		return

	var state = JSON.parse_string(file.get_as_text())
	file.close()

	Global.load_save_state(state)

	get_tree().change_scene_to_file("res://simulation/main.tscn")


func _on_manual_pressed():
	manual.popup()

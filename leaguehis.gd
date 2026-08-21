extends Node2D

@onready var game_menu = $MenuBar/Game
@onready var team_menu = $MenuBar/Team
@onready var players_menu = $MenuBar/Players
@onready var help_menu = $MenuBar/Help

@onready var history_tree: Tree = $Tree

@onready var roster = $Roster
@onready var history = $History
@onready var manual = $Manual
@onready var trade = $Trade
@onready var draft_history = $DraftHis
@onready var roster_warning = $AcceptDialog
@onready var awards = $Awards

var db: SQLite

var load_scene = preload("res://LoadBrowser.tscn")
var load_browser
var save_scene = preload("res://SaveBrowser.tscn")
var save_browser

func _ready():
	
	setup_menus()

	db = SQLite.new()
	db.path = "res://data/bball.db"
	db.open_db()

	setup_history_tree()
	update_history()

func setup_menus():

	game_menu.clear()

	game_menu.add_item("Load League", 0)
	game_menu.add_item("Save League", 1)
	game_menu.add_item("Quit to Title", 2)
	game_menu.add_item("Quit to Desktop", 3)

	team_menu.add_item("Roster", 0)
	team_menu.add_item("History", 1)

	players_menu.add_item("Trade", 0)
	players_menu.add_item("Draft History", 1)

	help_menu.add_item("Manual", 0)

func setup_history_tree():

	history_tree.columns = 4

	history_tree.set_column_title(0, "Season")
	history_tree.set_column_title(1, "Champion")
	history_tree.set_column_title(2, "Runner-Up")
	history_tree.set_column_title(3, "Awards")

	history_tree.set_column_titles_visible(true)

	history_tree.item_selected.connect(_on_history_item_selected)
	history_tree.item_activated.connect(_on_history_item_activated)

func update_history():

	history_tree.clear()

	var root := history_tree.create_item()

	# Get every season that has a champion.
	db.query("""
		SELECT
			season,
			team_id
		FROM team_attributes
		WHERE won_championship = 1
		ORDER BY season DESC
	""")

	for row in db.query_result:

		var season := int(row["season"])
		var champion_id := int(row["team_id"])

		var champion := get_team_name(
			champion_id,
			season
		)

		# Find the conference champion that did not win
		# the league championship.
		db.query("""
			SELECT
				team_id
			FROM team_attributes
			WHERE season = %d
			AND won_conference = 1
			AND won_championship = 0
		""" % season)

		var runner_up := "Unknown"

		if not db.query_result.is_empty():

			var runner_up_id := int(
				db.query_result[0]["team_id"]
			)

			runner_up = get_team_name(
				runner_up_id,
				season
			)

		var item := history_tree.create_item(root)

		item.set_metadata(
			0,
			season
		)
		
		item.set_text(
			0,
			str(season)
		)

		item.set_text(
			1,
			champion
		)

		item.set_text(
			2,
			runner_up
		)
		
		item.set_text(
			3,
			"Double-Click to View Awards"
		)
		
		item.set_custom_color(
			3,
			Color(1.0, 1.0, 0.0)
		)

func _on_history_item_selected():
	var item := history_tree.get_selected()

	if item == null:
		return

	var season := int(
		item.get_metadata(0)
	)

	Global.awards_season = season
	Global.changed_season = true

func _on_history_item_activated():
	awards.popup_centered()
	
func get_team_name(
	team_id: int,
	season: int
) -> String:

	db.query("""
		SELECT
			region,
			name
		FROM team_attributes
		WHERE team_id = %d
		AND season = %d
	""" % [
		team_id,
		season
	])

	if db.query_result.is_empty():
		return "Unknown"

	var row = db.query_result[0]

	return "%s %s" % [
		str(row["region"]),
		str(row["name"])
	]

func _on_game_id_pressed(id: int):
	match id:
		0:
			open_load_browser()
		1:
			open_save_browser()
		2:
			get_tree().change_scene_to_file("res://titlescreen.tscn")
		3:
			get_tree().quit()
			
func _on_team_id_pressed(id: int):

	match id:

		0:
			roster.popup()
			
		1:
			history.popup()


func _on_button_1_pressed():
	get_tree().change_scene_to_file("res://simulation/main.tscn")


func _on_playoffs_pressed():
	get_tree().change_scene_to_file("res://simulation/playoffs.tscn")


func _on_draft_pressed():
	get_tree().change_scene_to_file("res://simulation/draft.tscn")


func _on_free_agents_pressed():
	get_tree().change_scene_to_file("res://simulation/fa.tscn")

func _on_finances_pressed():
	get_tree().change_scene_to_file("res://finances.tscn")


func _on_ratings_pressed():
	get_tree().change_scene_to_file("res://ratings.tscn")


func _on_player_stats_pressed():
	get_tree().change_scene_to_file("res://playerstats.tscn")


func _on_team_stats_pressed():
	get_tree().change_scene_to_file("res://teamstats.tscn")


func _on_game_log_pressed():
	get_tree().change_scene_to_file("res://gamelog.tscn")

func open_load_browser():
	load_browser = load_scene.instantiate()
	add_child(load_browser)
	load_browser.title = "Load League"
	load_browser.load_selected.connect(_load_league)
	load_browser.cancelled.connect(func():
		load_browser.queue_free()
	)
	load_browser.popup_centered()
	
func _load_league(save_name: String):
	var db_path := "user://saves/%s.json" % save_name
	var state_path := "user://saves/%s.state.json" % save_name
	if not FileAccess.file_exists(db_path):
		print("Save database not found: ", db_path)
		return
	if not FileAccess.file_exists(state_path):
		print("Save state not found: ", state_path)
		return
	db.import_from_json(db_path)
	var file := FileAccess.open(state_path, FileAccess.READ)
	if file == null:
		print("Could not open state file.")
		return
	var state_text := file.get_as_text()
	file.close()
	var state = JSON.parse_string(state_text)
	if state == null:
		print("Could not parse save state.")
		return
	Global.load_save_state(state)
	print("League loaded: ", save_name)
	get_tree().reload_current_scene()

func open_save_browser():
	save_browser = save_scene.instantiate()
	add_child(save_browser)
	save_browser.title = "Save League"
	save_browser.save_selected.connect(_save_league)
	save_browser.cancelled.connect(func():
		save_browser.queue_free()
	)
	save_browser.popup_centered()
	
func _save_league(save_name: String):
	DirAccess.make_dir_recursive_absolute("user://saves")
	var db_path := "user://saves/%s.json" % save_name
	var state_path := "user://saves/%s.state.json" % save_name
	db.export_to_json(db_path)
	var save_state = Global.get_save_state()
	var file := FileAccess.open(
		state_path,
		FileAccess.WRITE
	)
	if file == null:
		print("Could not create save-state file.")
		return
	file.store_string(
		JSON.stringify(save_state)
	)
	file.close()
	print("Database and game state saved as ", save_name)
	if is_instance_valid(save_browser):
		save_browser.queue_free()
		save_browser = null


func _on_help_id_pressed(id):
	match id:
		0:
			manual.popup()


func _on_players_id_pressed(id):
	match id:
		0:
			trade.popup()
		1:
			draft_history.popup()

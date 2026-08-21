extends Node2D

@onready var game_menu = $MenuBar/Game
@onready var team_menu = $MenuBar/Team
@onready var players_menu = $MenuBar/Players
@onready var help_menu = $MenuBar/Help
@onready var roster = $Roster
@onready var history = $History
@onready var manual = $Manual
@onready var trade = $Trade
@onready var draft_history = $DraftHis
@onready var roster_warning = $AcceptDialog
@onready var team_dropdown: OptionButton = $TeamDropdown
@onready var player_ratings: Tree = $PlayerRatings

var db: SQLite

var selected_team_id: int = 0
var team_ids: Array[int] = []

var load_scene = preload("res://LoadBrowser.tscn")
var load_browser
var save_scene = preload("res://SaveBrowser.tscn")
var save_browser

func _ready():
	setup_menus()
	setup_db()

	setup_team_dropdown()
	setup_player_ratings_tree()

	team_dropdown.item_selected.connect(
		_on_team_selected
	)

	# Load the first team initially.
	if team_dropdown.item_count > 0:
		team_dropdown.select(0)
		_on_team_selected(0)

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

func setup_db():

	db = SQLite.new()
	db.path = "res://data/bball.db"
	db.open_db()

func setup_team_dropdown():

	team_dropdown.clear()
	team_ids.clear()

	team_dropdown.add_item("All Teams")
	team_ids.append(-1)

	var current_season := 2011 + Global.season

	db.query("""
		SELECT
			team_id,
			region,
			name
		FROM team_attributes
		WHERE season = %d
		ORDER BY region ASC, name ASC
	""" % current_season)

	for team in db.query_result:

		team_ids.append(int(team["team_id"]))

		team_dropdown.add_item(
			str(team["region"]) + " " + str(team["name"])
		)

func setup_player_ratings_tree():

	player_ratings.clear()

	player_ratings.columns = 21

	var columns = [
		"Name",
		"Team",
		"Age",
		"Ovr",
		"Pot",
		"Hgt",
		"Str",
		"Spd",
		"Jmp",
		"End",
		"Ins",
		"Dnk",
		"FT",
		"2pt",
		"3pt",
		"Blk",
		"Stl",
		"Drb",
		"Pss",
		"Reb"
	]

	for i in range(columns.size()):

		player_ratings.set_column_title(
			i,
			columns[i]
		)


	player_ratings.set_column_custom_minimum_width(
		0,
		200
	)

	player_ratings.set_column_custom_minimum_width(
		1,
		200
	)

func _on_team_selected(index: int):

	if index < 0:
		return

	if index >= team_ids.size():
		return

	selected_team_id = team_ids[index]

	update_player_ratings()

func update_player_ratings():

	player_ratings.clear()

	var root := player_ratings.create_item()

	var current_season := 2011 + Global.season

	db.query("""
		SELECT
			pa.player_id,
			pa.team_id,
			pa.name,
			%d - pa.born_date AS age,
			pr.overall,
			pr.potential,
			pr.height,
			pr.strength,
			pr.speed,
			pr.jumping,
			pr.endurance,
			pr.shooting_inside,
			pr.shooting_layups,
			pr.shooting_free_throws,
			pr.shooting_two_pointers,
			pr.shooting_three_pointers,
			pr.blocks,
			pr.steals,
			pr.dribbling,
			pr.passing,
			pr.rebounding,
			ta.region,
			ta.name AS team_name
		FROM player_attributes pa
		INNER JOIN player_ratings pr
			ON pa.player_id = pr.player_id
		INNER JOIN team_attributes ta
			ON pa.team_id = ta.team_id
		WHERE (%d = -1 OR pa.team_id = %d)
		AND ta.season = %d
		ORDER BY pr.overall DESC
	""" % [
		current_season,
		selected_team_id,
		selected_team_id,
		current_season
	])


	for player in db.query_result:

		var item := player_ratings.create_item(root)

		item.set_text(
			0,
			str(player["name"])
		)

		item.set_text(
			1,
			str(player["region"]) + " " + str(player["team_name"])
		)

		item.set_text(
			2,
			str(player["age"])
		)

		item.set_text(
			3,
			str(player["overall"])
		)

		item.set_text(
			4,
			str(player["potential"])
		)

		item.set_text(
			5,
			str(player["height"])
		)

		item.set_text(
			6,
			str(player["strength"])
		)

		item.set_text(
			7,
			str(player["speed"])
		)

		item.set_text(
			8,
			str(player["jumping"])
		)

		item.set_text(
			9,
			str(player["endurance"])
		)

		item.set_text(
			10,
			str(player["shooting_inside"])
		)

		item.set_text(
			11,
			str(player["shooting_layups"])
		)

		item.set_text(
			12,
			str(player["shooting_free_throws"])
		)

		item.set_text(
			13,
			str(player["shooting_two_pointers"])
		)

		item.set_text(
			14,
			str(player["shooting_three_pointers"])
		)

		item.set_text(
			15,
			str(player["blocks"])
		)

		item.set_text(
			16,
			str(player["steals"])
		)

		item.set_text(
			17,
			str(player["dribbling"])
		)

		item.set_text(
			18,
			str(player["passing"])
		)

		item.set_text(
			19,
			str(player["rebounding"])
		)

		# Store player ID as metadata.
		item.set_metadata(
			0,
			int(player["player_id"])
		)
		
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

func _on_player_stats_pressed():
	get_tree().change_scene_to_file("res://playerstats.tscn")


func _on_team_stats_pressed():
	get_tree().change_scene_to_file("res://teamstats.tscn")


func _on_game_log_pressed():
	get_tree().change_scene_to_file("res://gamelog.tscn")


func _on_button_pressed():
	get_tree().change_scene_to_file("res://leaguehis.tscn")

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

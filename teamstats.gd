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

@onready var season_dropdown: OptionButton = $SeasonDropdown
@onready var team_stats: Tree = $TeamStats

var db: SQLite

var selected_season: int = 0
var seasons: Array[int] = []

var load_scene = preload("res://LoadBrowser.tscn")
var load_browser
var save_scene = preload("res://SaveBrowser.tscn")
var save_browser

func _ready():

	setup_menus()
	setup_db()

	setup_season_dropdown()
	setup_team_stats_tree()

	season_dropdown.item_selected.connect(
		_on_season_selected
	)

	# Load the first season.
	if season_dropdown.item_count > 0:

		season_dropdown.select(0)

		selected_season = seasons[0]

		update_team_stats()
		
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
	
func setup_season_dropdown():

	season_dropdown.clear()

	seasons.clear()

	db.query("""
		SELECT DISTINCT season
		FROM team_attributes
		ORDER BY season DESC
	""")

	for row in db.query_result:

		var season := int(row["season"])

		seasons.append(season)

		season_dropdown.add_item(
			str(season)
		)
		
func _on_season_selected(index: int):

	if index < 0:
		return

	if index >= seasons.size():
		return

	selected_season = seasons[index]

	update_team_stats()
	
func setup_team_stats_tree():

	team_stats.clear()

	team_stats.columns = 23

	var columns = [
		"Team",
		"GP",
		"W",
		"L",
		"FGM",
		"FGA",
		"FG%",
		"3PM",
		"3PA",
		"3P%",
		"FTM",
		"FTA",
		"FT%",
		"Oreb",
		"Dreb",
		"Reb",
		"Ast",
		"TO",
		"Stl",
		"Blk",
		"PF",
		"Pts",
		"OPts"
	]

	for i in range(columns.size()):

		team_stats.set_column_title(
			i,
			columns[i]
		)

	team_stats.set_column_custom_minimum_width(
		0,
		200
	)
	
func update_team_stats() -> void:

	team_stats.clear()

	var root := team_stats.create_item()

	db.query("""
		SELECT
			ta.team_id,
			ta.region,
			ta.name,

			COUNT(ts.game_id) AS games_played,

			SUM(ts.won) AS wins,

			COUNT(ts.game_id) - SUM(ts.won) AS losses,

			SUM(ts.field_goals_made) AS field_goals_made,

			SUM(ts.field_goals_attempted) AS field_goals_attempted,

			CASE
				WHEN SUM(ts.field_goals_attempted) > 0
				THEN
					100.0 * SUM(ts.field_goals_made)
					/ SUM(ts.field_goals_attempted)
				ELSE 0
			END AS field_goal_percentage,

			SUM(ts.three_pointers_made) AS three_pointers_made,

			SUM(ts.three_pointers_attempted) AS three_pointers_attempted,

			CASE
				WHEN SUM(ts.three_pointers_attempted) > 0
				THEN
					100.0 * SUM(ts.three_pointers_made)
					/ SUM(ts.three_pointers_attempted)
				ELSE 0
			END AS three_point_percentage,

			SUM(ts.free_throws_made) AS free_throws_made,

			SUM(ts.free_throws_attempted) AS free_throws_attempted,

			CASE
				WHEN SUM(ts.free_throws_attempted) > 0
				THEN
					100.0 * SUM(ts.free_throws_made)
					/ SUM(ts.free_throws_attempted)
				ELSE 0
			END AS free_throw_percentage,

			AVG(ts.offensive_rebounds) AS offensive_rebounds,

			AVG(ts.defensive_rebounds) AS defensive_rebounds,

			AVG(
				ts.offensive_rebounds
				+ ts.defensive_rebounds
			) AS rebounds,

			AVG(ts.assists) AS assists,

			AVG(ts.turnovers) AS turnovers,

			AVG(ts.steals) AS steals,

			AVG(ts.blocks) AS blocks,

			AVG(ts.personal_fouls) AS personal_fouls,

			AVG(ts.points) AS points,

			AVG(ts.opponent_points) AS opponent_points

		FROM team_attributes ta

		LEFT JOIN team_stats ts
			ON ta.team_id = ts.team_id
			AND ta.season = ts.season
			AND ts.is_playoffs = 0

		WHERE ta.season = %d

		GROUP BY
			ta.team_id,
			ta.region,
			ta.name

		ORDER BY
			ta.region ASC,
			ta.name ASC

	""" % selected_season)


	for team in db.query_result:

		var item := team_stats.create_item(root)

		item.set_text(
			0,
			str(team["region"]) + " " + str(team["name"])
		)

		item.set_text(
			1,
			str(team["games_played"])
		)

		if(team["wins"] != null):
			item.set_text(
				2,
					str(team["wins"])
			)
		else:
			item.set_text(2, "0")

		if(team["losses"] != null):
			item.set_text(
				3,
					str(team["losses"])
			)
		else:
			item.set_text(3, "0")

		if(team["field_goals_made"] != null):
			item.set_text(
				4,
					str(team["field_goals_made"])
			)
		else:
			item.set_text(4, "0")

		if(team["field_goals_attempted"] != null):
			item.set_text(
				5,
					str(team["field_goals_attempted"])
			)
		else:
			item.set_text(5, "0")

		item.set_text(
			6,
			"%.1f%%" % float(
				team["field_goal_percentage"]
			)
		)

		if(team["three_pointers_made"] != null):
			item.set_text(
				7,
					str(team["three_pointers_made"])
			)
		else:
			item.set_text(7, "0")

		if(team["three_pointers_attempted"] != null):
			item.set_text(
				8,
					str(team["three_pointers_attempted"])
			)
		else:
			item.set_text(8, "0")

		item.set_text(
			9,
			"%.1f%%" % float(
				team["three_point_percentage"]
			)
		)

		if(team["free_throws_made"] != null):
			item.set_text(
				10,
					str(team["free_throws_made"])
			)
		else:
			item.set_text(10, "0")

		if(team["free_throws_attempted"] != null):
			item.set_text(
				11,
					str(team["free_throws_attempted"])
			)
		else:
			item.set_text(11, "0")

		item.set_text(
			12,
			"%.1f%%" % float(
				team["free_throw_percentage"]
			)
		)
		
		if(team["offensive_rebounds"] != null):
			item.set_text(
				13,
				"%.1f" % float(
					team["offensive_rebounds"]
				)
			)
		else:
			item.set_text(13, "0")

		if(team["defensive_rebounds"] != null):
			item.set_text(
				14,
				"%.1f" % float(
					team["defensive_rebounds"]
				)
			)
		else:
			item.set_text(14, "0")

		if(team["rebounds"] != null):
			item.set_text(
				15,
				"%.1f" % float(
					team["rebounds"]
				)
			)
		else:
			item.set_text(15, "0")

		if(team["assists"] != null):
			item.set_text(
				16,
				"%.1f" % float(
					team["assists"]
				)
			)
		else:
			item.set_text(16, "0")

		if(team["turnovers"] != null):
			item.set_text(
				17,
				"%.1f" % float(
					team["turnovers"]
				)
			)
		else:
			item.set_text(17, "0")

		if(team["steals"] != null):
			item.set_text(
				18,
				"%.1f" % float(
					team["steals"]
				)
			)
		else:
			item.set_text(18, "0")

		if(team["blocks"] != null):
			item.set_text(
				19,
				"%.1f" % float(
					team["blocks"]
				)
			)
		else:
			item.set_text(19, "0")

		if(team["personal_fouls"] != null):
			item.set_text(
				20,
				"%.1f" % float(
					team["personal_fouls"]
				)
			)
		else:
			item.set_text(20, "0")

		if(team["points"] != null):
			item.set_text(
				21,
				"%.1f" % float(
					team["points"]
				)
			)
		else:
			item.set_text(21, "0")

		if(team["opponent_points"] != null):
			item.set_text(
				22,
				"%.1f" % float(
					team["opponent_points"]
				)
			)
		else:
			item.set_text(22, "0")
		
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

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
@onready var team_dropdown: OptionButton = $TeamDropdown

@onready var games: Tree = $Games
@onready var team_box: Tree = $BoxScorePanel/TeamBox
@onready var opponent_box: Tree = $BoxScorePanel/OpponentBox

@onready var team_name = %TeamName
@onready var opponent_name = %OpponentName

var db: SQLite

var selected_season: int = 2011
var selected_team_id: int = 0
var game_ids: Array[int] = []

var load_scene = preload("res://LoadBrowser.tscn")
var load_browser
var save_scene = preload("res://SaveBrowser.tscn")
var save_browser

func _ready():

	setup_menus()
	setup_db()

	setup_game_log_tree()

	setup_box_score_trees()

	setup_season_dropdown()
	setup_team_dropdown()

	update_game_log()

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

func setup_game_log_tree():

	games.clear()

	games.columns = 3

	games.set_column_title(0, "Opponent")
	games.set_column_title(1, "W/L")
	games.set_column_title(2, "Score")

	games.item_selected.connect(_on_game_selected)
	
func setup_season_dropdown():

	season_dropdown.clear()

	var seasons: Array[int] = []

	db.query("""
		SELECT DISTINCT season
		FROM team_stats
		ORDER BY season DESC
	""")

	for row in db.query_result:

		var season := int(row["season"])

		seasons.append(season)
		season_dropdown.add_item(str(season))

	# Select current season.
	var current_season := 2011 + Global.season

	var current_index := seasons.find(current_season)

	if current_index != -1:

		season_dropdown.select(current_index)
		selected_season = current_season

	season_dropdown.item_selected.connect(
		_on_season_selected
	)
	
func _on_season_selected(index: int):

	selected_season = int(
		season_dropdown.get_item_text(index)
	)

	update_game_log()
	
func setup_team_dropdown():

	team_dropdown.clear()

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

	var selected_index := 0

	for i in range(db.query_result.size()):

		var team = db.query_result[i]

		var team_id := int(team["team_id"])

		team_dropdown.add_item(str(team["region"]) + " " + str(team["name"]))

		team_dropdown.set_item_metadata(
			i,
			team_id
		)

		if team_id == Global.team:

			selected_index = i

	team_dropdown.select(selected_index)

	selected_team_id = int(
		team_dropdown.get_item_metadata(selected_index)
	)

	team_dropdown.item_selected.connect(
		_on_team_selected
	)
	
func _on_team_selected(index: int):

	selected_team_id = int(
		team_dropdown.get_item_metadata(index)
	)

	update_game_log()
	
func update_game_log():

	games.clear()
	game_ids.clear()

	var root := games.create_item()

	db.query("""
		SELECT
			game_id,
			opponent_team_id,
			won,
			points,
			opponent_points
		FROM team_stats
		WHERE team_id = %d
		AND season = %d
		ORDER BY game_id ASC
	""" % [
		selected_team_id,
		selected_season
	])

	for game in db.query_result:

		var game_id := int(game["game_id"])

		game_ids.append(game_id)

		var opp_name := get_team_abbrev(
			int(game["opponent_team_id"]),
			selected_season
		)

		var won := int(game["won"]) == 1

		var result := "W" if won else "L"

		var score := "%d-%d" % [
			int(game["points"]),
			int(game["opponent_points"])
		]

		var item := games.create_item(root)

		item.set_text(
			0,
			opp_name
		)

		item.set_text(
			1,
			result
		)

		item.set_text(
			2,
			score
		)

		# Store game ID on the TreeItem.
		item.set_metadata(
			0,
			game_id
		)
		
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

	var team = db.query_result[0]

	return "%s %s" % [
		str(team["region"]),
		str(team["name"])
	]
	
func get_team_abbrev(
	team_id: int,
	season: int
) -> String:

	db.query("""
		SELECT abbreviation
		FROM team_attributes
		WHERE team_id = %d
		AND season = %d
	""" % [
		team_id,
		season
	])

	if db.query_result.is_empty():
		return "Unknown"

	return str(
		db.query_result[0]["abbreviation"]
	)
	
func _on_game_selected():

	var item := games.get_selected()

	if item == null:
		return

	var game_id := int(
		item.get_metadata(0)
	)

	display_box_score(game_id)
	
func setup_box_score_trees() -> void:

	setup_box_score_tree(team_box)
	setup_box_score_tree(opponent_box)


func setup_box_score_tree(tree: Tree) -> void:

	tree.clear()
	tree.columns = 13

	var columns = [
		"Name",
		"Pos",
		"Min",
		"FG",
		"3PT",
		"FT",
		"Off",
		"Reb",
		"Ast",
		"TO",
		"Stl",
		"Blk",
		"Pts"
	]

	for i in range(columns.size()):
		tree.set_column_title(i, columns[i])

	tree.set_column_custom_minimum_width(0, 150)
	tree.set_column_custom_minimum_width(3, 50)
	tree.set_column_custom_minimum_width(4, 50)
	tree.set_column_custom_minimum_width(5, 50)
	
func populate_player_box_score(
	tree: Tree,
	game_id: int,
	team_id: int
):

	tree.clear()

	var root := tree.create_item()

	# Get players for this team in this game.
	db.query("""
		SELECT
			pa.name,
			pa.position,
			ps.minutes,
			ps.field_goals_made,
			ps.field_goals_attempted,
			ps.three_pointers_made,
			ps.three_pointers_attempted,
			ps.free_throws_made,
			ps.free_throws_attempted,
			ps.offensive_rebounds,
			ps.defensive_rebounds,
			ps.assists,
			ps.turnovers,
			ps.steals,
			ps.blocks,
			ps.points,
			ps.starter
		FROM player_attributes pa
		INNER JOIN player_stats ps
			ON pa.player_id = ps.player_id
		WHERE ps.game_id = %d
		AND ps.team_id = %d
		AND ps.season = %d
		ORDER BY ps.starter DESC, ps.minutes DESC
	""" % [
		game_id,
		team_id,
		selected_season
	])

	for player in db.query_result:

		var item := tree.create_item(root)

		var rebounds := (
			int(player["offensive_rebounds"])
			+ int(player["defensive_rebounds"])
		)

		item.set_text(0, str(player["name"]))
		item.set_text(1, str(player["position"]))
		item.set_text(2, str(int(player["minutes"])))

		item.set_text(
			3,
			"%d-%d" % [
				int(player["field_goals_made"]),
				int(player["field_goals_attempted"])
			]
		)

		item.set_text(
			4,
			"%d-%d" % [
				int(player["three_pointers_made"]),
				int(player["three_pointers_attempted"])
			]
		)

		item.set_text(
			5,
			"%d-%d" % [
				int(player["free_throws_made"]),
				int(player["free_throws_attempted"])
			]
		)

		item.set_text(
			6,
			str(player["offensive_rebounds"])
		)

		item.set_text(
			7,
			str(rebounds)
		)

		item.set_text(
			8,
			str(player["assists"])
		)

		item.set_text(
			9,
			str(player["turnovers"])
		)

		item.set_text(
			10,
			str(player["steals"])
		)

		item.set_text(
			11,
			str(player["blocks"])
		)

		item.set_text(
			12,
			str(player["points"])
		)

	# Add team total as final row.
	add_team_total_row(tree, game_id, team_id)
	
func add_team_total_row(
	tree: Tree,
	game_id: int,
	team_id: int
):

	db.query("""
		SELECT
			field_goals_made,
			field_goals_attempted,
			three_pointers_made,
			three_pointers_attempted,
			free_throws_made,
			free_throws_attempted,
			offensive_rebounds,
			defensive_rebounds,
			assists,
			turnovers,
			steals,
			blocks,
			points
		FROM team_stats
		WHERE game_id = %d
		AND team_id = %d
		AND season = %d
	""" % [
		game_id,
		team_id,
		selected_season
	])

	if db.query_result.is_empty():
		return

	var stats = db.query_result[0]

	var item := tree.create_item()

	var rebounds := (
		int(stats["offensive_rebounds"])
		+ int(stats["defensive_rebounds"])
	)

	item.set_text(0, "Total")
	item.set_text(1, "")
	item.set_text(2, "240")

	item.set_text(
		3,
		"%d-%d" % [
			int(stats["field_goals_made"]),
			int(stats["field_goals_attempted"])
		]
	)

	item.set_text(
		4,
		"%d-%d" % [
			int(stats["three_pointers_made"]),
			int(stats["three_pointers_attempted"])
		]
	)

	item.set_text(
		5,
		"%d-%d" % [
			int(stats["free_throws_made"]),
			int(stats["free_throws_attempted"])
		]
	)

	item.set_text(6, str(stats["offensive_rebounds"]))
	item.set_text(7, str(rebounds))
	item.set_text(8, str(stats["assists"]))
	item.set_text(9, str(stats["turnovers"]))
	item.set_text(10, str(stats["steals"]))
	item.set_text(11, str(stats["blocks"]))
	item.set_text(12, str(stats["points"]))

func display_box_score(game_id: int):

	db.query("""
		SELECT
			team_id,
			opponent_team_id
		FROM team_stats
		WHERE game_id = %d
		AND team_id = %d
		AND season = %d
	""" % [
		game_id,
		selected_team_id,
		selected_season
	])

	if db.query_result.is_empty():
		return

	var game = db.query_result[0]

	var team_id := int(game["team_id"])
	var opponent_id := int(game["opponent_team_id"])
	
	# Get the display names.
	var selected_team_name := get_team_name(
		team_id,
		selected_season
	)

	var selected_opponent_name := get_team_name(
		opponent_id,
		selected_season
	)

	# Set the labels.
	team_name.text = selected_team_name
	opponent_name.text = selected_opponent_name

	populate_player_box_score(
		team_box,
		game_id,
		team_id
	)

	populate_player_box_score(
		opponent_box,
		game_id,
		opponent_id
	)
	
func populate_box_score_tree(
	tree: Tree,
	game_id: int,
	team_id: int
) -> void:

	tree.clear()

	var root := tree.create_item()

	# Get player stats.
	db.query("""
		=SELECT
			pa.player_id,
			pa.name,
			pa.position,
			ps.minutes,
			ps.field_goals_made,
			ps.field_goals_attempted,
			ps.three_pointers_made,
			ps.three_pointers_attempted,
			ps.free_throws_made,
			ps.free_throws_attempted,
			ps.offensive_rebounds,
			ps.defensive_rebounds,
			ps.assists,
			ps.turnovers,
			ps.steals,
			ps.blocks,
			ps.points,
			ps.starter
		FROM player_attributes pa
		INNER JOIN player_stats ps
			ON pa.player_id = ps.player_id
		WHERE ps.game_id = %d
		AND ps.team_id = %d
		ORDER BY ps.starter DESC, ps.minutes DESC
	""" % [
		game_id,
		team_id
	])

	for player in db.query_result:

		var item := tree.create_item(root)

		var rebounds := (
			int(player["offensive_rebounds"])
			+ int(player["defensive_rebounds"])
		)

		item.set_text(
			0,
			str(player["name"])
		)

		item.set_text(
			1,
			str(player["position"])
		)

		item.set_text(
			2,
			str(int(player["minutes"]))
		)

		item.set_text(
			3,
			"%d-%d" % [
				int(player["field_goals_made"]),
				int(player["field_goals_attempted"])
			]
		)

		item.set_text(
			4,
			"%d-%d" % [
				int(player["three_pointers_made"]),
				int(player["three_pointers_attempted"])
			]
		)

		item.set_text(
			5,
			"%d-%d" % [
				int(player["free_throws_made"]),
				int(player["free_throws_attempted"])
			]
		)

		item.set_text(
			6,
			str(player["offensive_rebounds"])
		)

		item.set_text(
			7,
			str(rebounds)
		)

		item.set_text(
			8,
			str(player["assists"])
		)

		item.set_text(
			9,
			str(player["turnovers"])
		)

		item.set_text(
			10,
			str(player["steals"])
		)

		item.set_text(
			11,
			str(player["blocks"])
		)

		item.set_text(
			12,
			str(player["points"])
		)

		item.set_metadata(
			0,
			int(player["player_id"])
		)

	# Add team total.
	add_box_score_total(
		tree,
		root,
		game_id,
		team_id
	)

func add_box_score_total(
	tree: Tree,
	root: TreeItem,
	game_id: int,
	team_id: int
) -> void:

	db.query("""
		SELECT
			minutes,
			field_goals_made,
			field_goals_attempted,
			three_pointers_made,
			three_pointers_attempted,
			free_throws_made,
			free_throws_attempted,
			offensive_rebounds,
			defensive_rebounds,
			assists,
			turnovers,
			steals,
			blocks,
			points
		FROM team_stats
		WHERE game_id = %d
		AND team_id = %d
	""" % [
		game_id,
		team_id
	])

	if db.query_result.is_empty():
		return

	var stats = db.query_result[0]

	var item := tree.create_item(root)

	var rebounds := (
		int(stats["offensive_rebounds"])
		+ int(stats["defensive_rebounds"])
	)

	item.set_text(0, "Total")
	item.set_text(1, "")
	item.set_text(2, str(stats["minutes"]))

	item.set_text(
		3,
		"%d-%d" % [
			int(stats["field_goals_made"]),
			int(stats["field_goals_attempted"])
		]
	)

	item.set_text(
		4,
		"%d-%d" % [
			int(stats["three_pointers_made"]),
			int(stats["three_pointers_attempted"])
		]
	)

	item.set_text(
		5,
		"%d-%d" % [
			int(stats["free_throws_made"]),
			int(stats["free_throws_attempted"])
		]
	)

	item.set_text(
		6,
		str(stats["offensive_rebounds"])
	)

	item.set_text(
		7,
		str(rebounds)
	)

	item.set_text(
		8,
		str(stats["assists"])
	)

	item.set_text(
		9,
		str(stats["turnovers"])
	)

	item.set_text(
		10,
		str(stats["steals"])
	)

	item.set_text(
		11,
		str(stats["blocks"])
	)

	item.set_text(
		12,
		str(stats["points"])
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

func _on_ratings_pressed():
	get_tree().change_scene_to_file("res://ratings.tscn")


func _on_player_stats_pressed():
	get_tree().change_scene_to_file("res://playerstats.tscn")


func _on_team_stats_pressed():
	get_tree().change_scene_to_file("res://teamstats.tscn")


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

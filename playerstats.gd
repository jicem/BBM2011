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
@onready var player_stats: Tree = $PlayerStats

var db: SQLite

var selected_season: int
var selected_team_id: int = -1

var team_ids: Array[int] = []
var seasons: Array[int] = []

var load_scene = preload("res://LoadBrowser.tscn")
var load_browser
var save_scene = preload("res://SaveBrowser.tscn")
var save_browser

func _ready():

	setup_menus()
	setup_db()

	setup_season_dropdown()
	setup_team_dropdown()
	setup_player_stats_tree()

	season_dropdown.item_selected.connect(
		_on_season_selected
	)

	team_dropdown.item_selected.connect(
		_on_team_selected
	)

	# Select current season initially.
	if season_dropdown.item_count > 0:

		season_dropdown.select(0)

		selected_season = seasons[0]

		setup_team_dropdown()

		if team_dropdown.item_count > 0:

			team_dropdown.select(0)

			selected_team_id = team_ids[0]

			update_player_stats()

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
		
func setup_team_dropdown():

	team_dropdown.clear()

	team_ids.clear()

	# All Teams
	team_dropdown.add_item("All Teams")
	team_ids.append(-1)

	if selected_season == 0:
		return

	db.query("""
		SELECT
			team_id,
			region,
			name
		FROM team_attributes
		WHERE season = %d
		ORDER BY region ASC, name ASC
	""" % selected_season)

	for team in db.query_result:

		var team_id := int(team["team_id"])

		team_ids.append(team_id)

		team_dropdown.add_item(
			str(team["region"]) + " " + str(team["name"])
		)
		
func setup_player_stats_tree():

	player_stats.clear()

	player_stats.columns = 23

	var columns = [
		"Name",
		"Team",
		"G",
		"GS",
		"Min",
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
		"Pts"
	]

	for i in range(columns.size()):

		player_stats.set_column_title(
			i,
			columns[i]
		)

	player_stats.set_column_custom_minimum_width(
		0,
		200
	)
	
func _on_season_selected(index: int):

	if index < 0:
		return

	if index >= seasons.size():
		return

	selected_season = seasons[index]

	# Select All Teams by default.
	team_dropdown.select(0)

	selected_team_id = -1

	update_player_stats()
	
func _on_team_selected(index: int):

	if index < 0:
		return

	if index >= team_ids.size():
		return

	selected_team_id = team_ids[index]

	update_player_stats()
	
func update_player_stats():

	player_stats.clear()

	var root := player_stats.create_item()

	if selected_season == 0:
		return

	var team_filter := ""

	if selected_team_id != -1:

		team_filter = """
			AND pa.team_id = %d
		""" % selected_team_id


	db.query("""
		SELECT
			pa.player_id,
			pa.team_id,
			pa.name,

			COALESCE(ta.abbreviation, 'FA') AS team,

			COALESCE(SUM(
				CASE
					WHEN ps.minutes > 0 THEN 1
					ELSE 0
				END
			), 0) AS games,

			COALESCE(SUM(ps.starter), 0) AS games_started,

			COALESCE(AVG(ps.minutes), 0) AS minutes,

			COALESCE(AVG(ps.field_goals_made), 0) AS fgm,
			COALESCE(AVG(ps.field_goals_attempted), 0) AS fga,

			CASE
				WHEN SUM(ps.field_goals_attempted) > 0
				THEN
					100.0 * SUM(ps.field_goals_made)
					/ SUM(ps.field_goals_attempted)
				ELSE 0
			END AS fg_pct,

			COALESCE(AVG(ps.three_pointers_made), 0) AS tpm,
			COALESCE(AVG(ps.three_pointers_attempted), 0) AS tpa,

			CASE
				WHEN SUM(ps.three_pointers_attempted) > 0
				THEN
					100.0 * SUM(ps.three_pointers_made)
					/ SUM(ps.three_pointers_attempted)
				ELSE 0
			END AS tp_pct,

			COALESCE(AVG(ps.free_throws_made), 0) AS ftm,
			COALESCE(AVG(ps.free_throws_attempted), 0) AS fta,

			CASE
				WHEN SUM(ps.free_throws_attempted) > 0
				THEN
					100.0 * SUM(ps.free_throws_made)
					/ SUM(ps.free_throws_attempted)
				ELSE 0
			END AS ft_pct,

			COALESCE(AVG(ps.offensive_rebounds), 0) AS oreb,
			COALESCE(AVG(ps.defensive_rebounds), 0) AS dreb,

			COALESCE(AVG(
				ps.offensive_rebounds +
				ps.defensive_rebounds
			), 0) AS reb,

			COALESCE(AVG(ps.assists), 0) AS ast,
			COALESCE(AVG(ps.turnovers), 0) AS turnovers,
			COALESCE(AVG(ps.steals), 0) AS steals,
			COALESCE(AVG(ps.blocks), 0) AS blocks,
			COALESCE(AVG(ps.personal_fouls), 0) AS fouls,
			COALESCE(AVG(ps.points), 0) AS points

		FROM player_attributes pa

		LEFT JOIN player_stats ps
			ON pa.player_id = ps.player_id
			AND ps.season = %d
			AND ps.is_playoffs = 0

		LEFT JOIN team_attributes ta
			ON pa.team_id = ta.team_id
			AND ta.season = %d

		WHERE 1 = 1
		%s

		GROUP BY
			pa.player_id,
			pa.team_id,
			pa.name,
			ta.abbreviation

		ORDER BY
			points DESC,
			pa.name ASC
	""" % [
		selected_season,
		selected_season,
		team_filter
	])


	for player in db.query_result:

		var item := player_stats.create_item(root)

		item.set_text(
			0,
			str(player["name"])
		)

		item.set_text(
			1,
			str(player["team"])
		)

		item.set_text(
			2,
			str(player["games"])
		)

		item.set_text(
			3,
			str(player["games_started"])
		)

		item.set_text(
			4,
			"%.1f" % float(player["minutes"])
		)

		item.set_text(
			5,
			"%.1f" % float(player["fgm"])
		)

		item.set_text(
			6,
			"%.1f" % float(player["fga"])
		)

		item.set_text(
			7,
			"%.1f%%" % float(player["fg_pct"])
		)

		item.set_text(
			8,
			"%.1f" % float(player["tpm"])
		)

		item.set_text(
			9,
			"%.1f" % float(player["tpa"])
		)

		item.set_text(
			10,
			"%.1f%%" % float(player["tp_pct"])
		)

		item.set_text(
			11,
			"%.1f" % float(player["ftm"])
		)

		item.set_text(
			12,
			"%.1f" % float(player["fta"])
		)

		item.set_text(
			13,
			"%.1f%%" % float(player["ft_pct"])
		)

		item.set_text(
			14,
			"%.1f" % float(player["oreb"])
		)

		item.set_text(
			15,
			"%.1f" % float(player["dreb"])
		)

		item.set_text(
			16,
			"%.1f" % float(player["reb"])
		)

		item.set_text(
			17,
			"%.1f" % float(player["ast"])
		)

		item.set_text(
			18,
			"%.1f" % float(player["turnovers"])
		)

		item.set_text(
			19,
			"%.1f" % float(player["steals"])
		)

		item.set_text(
			20,
			"%.1f" % float(player["blocks"])
		)

		item.set_text(
			21,
			"%.1f" % float(player["fouls"])
		)

		item.set_text(
			22,
			"%.1f" % float(player["points"])
		)

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

func _on_ratings_pressed():
	get_tree().change_scene_to_file("res://ratings.tscn")

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
	
func _load_league(save_name):
	db.import_from_json("res://data/savefiles/%s.json" % save_name)
	var file = FileAccess.open(
		"res://data/savefiles/%s.json" % save_name,
		FileAccess.READ
	)
	var state = JSON.parse_string(file.get_as_text())
	file.close()
	Global.load_save_state(state)
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
	
func _save_league(save_name):
	db.export_to_json("res://data/savefiles/%s.json" % save_name)
	var save_state = Global.get_save_state()
	var file = FileAccess.open(
		"res://data/savefiles/%s.state.json" % save_name,
		FileAccess.WRITE
	)
	file.store_string(JSON.stringify(save_state))
	file.close()
	print("Database and game state saved as ", save_name)
	save_browser.queue_free()

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

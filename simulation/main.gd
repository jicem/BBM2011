extends Node2D

@onready var game_menu = $MenuBar/Game
@onready var play_menu = $MenuBar/Play
@onready var team_menu = $MenuBar/Team
@onready var players_menu = $MenuBar/Players
@onready var help_menu = $MenuBar/Help
@onready var east_tree = $HBoxContainer/East/Tree
@onready var west_tree = $HBoxContainer/West/Tree
@onready var seasontext = $SeasonText
@onready var daytext = $DayText
@onready var daytrack = %DayTrack
@onready var timer = $Timer
@onready var roster = $Roster
@onready var history = $History
@onready var manual = $Manual
@onready var trade = $Trade
@onready var draft_history = $DraftHis
@onready var roster_warning = $AcceptDialog

var tiebreak_rng := RandomNumberGenerator.new()
var db: SQLite

# schedule tracking
var days := 0
var games_per_day := 10

var load_scene = preload("res://LoadBrowser.tscn")
var load_browser
var save_scene = preload("res://SaveBrowser.tscn")
var save_browser

func _ready():
	tiebreak_rng.randomize()
	setup_menus()
	setup_db()
	setup_standings_trees()
	refresh_standings()

	# load schedule generated BEFORE scene load
	if Global.schedule.is_empty():
		push_error("No schedule found in Global!")
	else:
		print("Schedule loaded: ", Global.schedule.size(), "games")

func _process(delta):
	if Input.is_action_just_pressed("simulate"):
		var player_count = 0

		db.query("SELECT COUNT(*) AS cnt FROM player_attributes WHERE team_id = %d" % Global.team)

		if db.query_result.size() > 0:
			player_count = int(db.query_result[0]["cnt"])
		if Global.phase == 1:
			seasontext.show()
			timer.start()
		else:
			if player_count > 15:
				roster_warning.popup()
				return
			simulate_day()

func setup_menus():
	seasontext.hide()
	game_menu.clear()
	play_menu.clear()
	team_menu.clear()
	players_menu.clear()
	help_menu.clear()

	game_menu.add_item("Load League", 0)
	game_menu.add_item("Save League", 1)
	game_menu.add_item("Quit to Title", 2)
	game_menu.add_item("Quit to Desktop", 3)
	
	if(Global.phase == 1):
		play_menu.add_item("Until Reg Season", 0)
	else:
		play_menu.add_item("One Day (Alt+P)", 0)
		play_menu.add_item("One Week", 1)
		play_menu.add_item("One Month", 2)
		play_menu.add_item("Until Playoffs", 3)

	team_menu.add_item("Roster", 0)
	team_menu.add_item("History", 1)
	
	players_menu.add_item("Trade", 0)
	players_menu.add_item("Draft History", 1)
	
	help_menu.add_item("Manual", 0)

func setup_db():
	db = SQLite.new()
	db.path = "res://data/bball.db"
	db.open_db()
	
func setup_standings_trees():
	for tree in [east_tree, west_tree]:
		tree.columns = 7
		tree.set_column_custom_minimum_width(1, 220)
		tree.set_column_title(0, "Seed")
		tree.set_column_title(1, "Team")
		tree.set_column_title(2, "W")
		tree.set_column_title(3, "L")
		tree.set_column_title(4, "PCT")
		tree.set_column_title(5, "DIV")
		tree.set_column_title(6, "CONF")
	
func refresh_standings():

	daytext.hide()
	daytrack.hide()

	east_tree.clear()
	west_tree.clear()

	var east_root = east_tree.create_item()
	var west_root = west_tree.create_item()

	var standings = get_sorted_standings()

	var east = standings["east"]
	var west = standings["west"]

	var playoff_seed = 1

	for t in east:
		var item = east_tree.create_item(east_root)
		item.set_text(0, str(playoff_seed))
		item.set_text(1, t.name)
		item.set_text(2, str(t.wins))
		item.set_text(3, str(t.losses))
		item.set_text(4, str(roundi(t.pct * 100)) + "%")
		item.set_text(5, t.div)
		item.set_text(6, t.conf)
		playoff_seed += 1

	playoff_seed = 1

	for t in west:
		var item = west_tree.create_item(west_root)
		item.set_text(0, str(playoff_seed))
		item.set_text(1, t.name)
		item.set_text(2, str(t.wins))
		item.set_text(3, str(t.losses))
		item.set_text(4, str(roundi(t.pct * 100)) + "%")
		item.set_text(5, t.div)
		item.set_text(6, t.conf)
		playoff_seed += 1
		
func _setup_tree_columns(tree: Tree):
	if tree.columns > 0:
		return

	tree.columns = 6

	tree.set_column_title(0, "Team")
	tree.set_column_title(1, "W")
	tree.set_column_title(2, "L")
	tree.set_column_title(3, "PCT")
	tree.set_column_title(4, "DIV")
	tree.set_column_title(5, "CONF")


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


func _on_play_id_pressed(id: int):
	var player_count = 0

	db.query("SELECT COUNT(*) AS cnt FROM player_attributes WHERE team_id = %d" % Global.team)

	if db.query_result.size() > 0:
		player_count = int(db.query_result[0]["cnt"])

	match id:
		0:
			if Global.phase == 1:
				seasontext.show()
				timer.start()
			else:
				if player_count > 15:
					roster_warning.popup()
					return
				simulate_day()
		1:
			if player_count > 15:
				roster_warning.popup()
				return
			simulate_week()
		2:
			if player_count > 15:
				roster_warning.popup()
				return
			simulate_month()
		3:
			if player_count > 15:
				roster_warning.popup()
				return
			simulate_until_playoffs()
	
func roster_auto_sort(team_id: int) -> void:
	var players = db.select_rows(
		"player_attributes pa \
		INNER JOIN player_ratings pr \
		ON pa.player_id = pr.player_id",
		"pa.team_id = %d" % team_id,
		["pa.player_id", "pr.overall", "pr.endurance", "pr.roster_position"]
	)

	players.sort_custom(func(a, b):
		return int(a["roster_position"]) < int(b["roster_position"])
	)

	players.sort_custom(func(a, b):
		return int(a["overall"]) > int(b["overall"])
	)

	var roster_position = 1

	for player in players:
		db.query("""
			UPDATE player_ratings
			SET roster_position = %d
			WHERE player_id = %d
		""" % [roster_position, player["player_id"]])

		roster_position += 1

func simulate_day():
	if(Global.phase == 2):
		print("Simulating day")
		daytext.show()
		days = 1
		timer.start()

func simulate_week():
	if(Global.phase == 2):
		print("Simulating week")
		daytrack.text = "Simulating 7 days..."
		daytrack.show()
		days = 7
		timer.start()

func simulate_month():
	if(Global.phase == 2):
		print("Simulating month")
		daytrack.text = "Simulating 30 days..."
		daytrack.show()
		days = 30
		timer.start()
	
func simulate_until_playoffs():
	if(Global.phase == 2):
		var days_left = ceili((Global.schedule.size() - Global.games_played) / games_per_day)
		print("Simulating until playoffs")
		daytrack.text = "Simulating %d days..." % days_left
		daytrack.show()
		days = -1
		timer.start()
		
func team_games_played(team_id: int) -> int:
	var rows = db.select_rows(
		"team_attributes",
		"team_id = %d AND season = %d" % [team_id, Global.season + 2011],
		["won", "lost"]
	)

	if rows.is_empty():
		return 0

	return int(rows[0]["won"]) + int(rows[0]["lost"])

func run_next_game():

	while Global.games_played < Global.schedule.size():

		var matchup = Global.schedule[Global.games_played]

		var home_id = matchup[0]
		var away_id = matchup[1]

		var game = Game.new(db, home_id, away_id, false)
		game.play()

		Global.games_played += 1

		return

	timer.stop()

func enter_playoffs():

	print("Season complete")

	create_playoff_bracket()

	Global.phase = 3

	get_tree().change_scene_to_file("res://simulation/playoffs.tscn")

func add_series(
	series_id:int,
	playoff_round:int,
	home_team:int,
	away_team:int,
	home_seed:int,
	away_seed:int):

	db.insert_row("active_playoff_series", {
		"series_id": series_id,
		"series_round": playoff_round,
		"team_id_home": home_team,
		"team_id_away": away_team,
		"seed_home": home_seed,
		"seed_away": away_seed,
		"won_home": 0,
		"won_away": 0
	})
	
func create_playoff_bracket():

	db.query("DELETE FROM active_playoff_series")

	var standings = get_sorted_standings()

	var east = standings["east"]
	var west = standings["west"]

	var id = 1

	for conference in [east, west]:

		add_series(
			id, 1,
			conference[0].row["team_id"],
			conference[7].row["team_id"],
			1, 8
		)
		id += 1

		add_series(
			id, 1,
			conference[1].row["team_id"],
			conference[6].row["team_id"],
			2, 7
		)
		id += 1

		add_series(
			id, 1,
			conference[2].row["team_id"],
			conference[5].row["team_id"],
			3, 6
		)
		id += 1

		add_series(
			id, 1,
			conference[3].row["team_id"],
			conference[4].row["team_id"],
			4, 5
		)
		id += 1
	
func get_sorted_standings() -> Dictionary:

	var rows = db.select_rows(
		"team_attributes",
		"season = %d" % (Global.season + 2011),
		[
			"team_id",
			"region",
			"name",
			"won",
			"lost",
			"won_div",
			"lost_div",
			"won_conf",
			"lost_conf",
			"division_id"
		]
	)

	var east := []
	var west := []

	for row in rows:

		var wins = int(row["won"])
		var losses = int(row["lost"])

		var gp = wins + losses
		var pct = float(wins) / gp if gp > 0 else 0.0

		var team_data = {
			"row": row,
			"name": "%s %s" % [row["region"], row["name"]],
			"wins": wins,
			"losses": losses,
			"pct": pct,
			"div": "%d-%d" % [row["won_div"], row["lost_div"]],
			"conf": "%d-%d" % [row["won_conf"], row["lost_conf"]],
			"tie": tiebreak_rng.randf()
		}

		if int(row["division_id"] / 3) == 0:
			east.append(team_data)
		else:
			west.append(team_data)

	var sort_fn = func(a,b):

		if a.pct != b.pct:
			return a.pct > b.pct

		var a_conf_games = int(a.row["won_conf"]) + int(a.row["lost_conf"])
		var b_conf_games = int(b.row["won_conf"]) + int(b.row["lost_conf"])

		var a_conf_pct = float(a.row["won_conf"]) / a_conf_games if a_conf_games > 0 else 0.0
		var b_conf_pct = float(b.row["won_conf"]) / b_conf_games if b_conf_games > 0 else 0.0

		if a_conf_pct != b_conf_pct:
			return a_conf_pct > b_conf_pct

		var a_div_games = int(a.row["won_div"]) + int(a.row["lost_div"])
		var b_div_games = int(b.row["won_div"]) + int(b.row["lost_div"])

		var a_div_pct = float(a.row["won_div"]) / a_div_games if a_div_games > 0 else 0.0
		var b_div_pct = float(b.row["won_div"]) / b_div_games if b_div_games > 0 else 0.0

		if a_div_pct != b_div_pct:
			return a_div_pct > b_div_pct

		return a.tie > b.tie

	east.sort_custom(sort_fn)
	west.sort_custom(sort_fn)

	return {
		"east": east,
		"west": west
	}

func cpu_free_agent_signings():
	# Get all free agents rated 45+
	var free_agents = db.select_rows(
		"player_attributes pa INNER JOIN player_ratings pr ON pa.player_id = pr.player_id",
		"pa.team_id = -1 AND pr.overall >= 45",
		["pa.player_id", "pr.overall"]
	)

	if free_agents.is_empty():
		return

	# Highest rated free agent
	free_agents.sort_custom(func(a, b):
		return int(a["overall"]) > int(b["overall"])
	)

	var best_fa = free_agents[0]

	var rng = RandomNumberGenerator.new()
	rng.randomize()

	for team_id in range(30):

		# Skip the human-controlled team
		if team_id == Global.team:
			continue

		# 50% chance
		if rng.randf() >= 0.5:
			continue

		# Find lowest-rated player
		var ai_roster = db.select_rows(
			"player_attributes pa INNER JOIN player_ratings pr ON pa.player_id = pr.player_id",
			"pa.team_id = %d" % team_id,
			["pa.player_id", "pr.overall"]
		)

		if ai_roster.is_empty():
			continue

		ai_roster.sort_custom(func(a, b):
			return int(a["overall"]) < int(b["overall"])
		)

		var worst_player = ai_roster[0]

		# Only sign if the FA is actually better
		if int(best_fa["overall"]) <= int(worst_player["overall"]):
			continue

		# Release worst player
		db.query("""
			UPDATE player_attributes
			SET team_id = -1
			WHERE player_id = %d
		""" % int(worst_player["player_id"]))

		# Sign best free agent
		db.query("""
			UPDATE player_attributes
			SET team_id = %d
			WHERE player_id = %d
		""" % [team_id, int(best_fa["player_id"])])

		# Give him the last roster spot
		db.query("""
			UPDATE player_ratings
			SET roster_position = 15
			WHERE player_id = %d
		""" % int(best_fa["player_id"]))

		# Resort roster
		roster_auto_sort(team_id)

		print("Team %d signed player %d and released player %d" %
			[team_id,
			best_fa["player_id"],
			worst_player["player_id"]])

		# Refresh free agent list so the same player can't sign twice
		free_agents = db.select_rows(
			"player_attributes pa INNER JOIN player_ratings pr ON pa.player_id = pr.player_id",
			"pa.team_id = -1 AND pr.overall >= 50",
			["pa.player_id", "pr.overall"]
		)

		if free_agents.is_empty():
			break

		free_agents.sort_custom(func(a, b):
			return int(a["overall"]) > int(b["overall"])
		)

		best_fa = free_agents[0]

func _on_timer_timeout():
	if Global.phase == 1:
		for team_id in range(30):
			if team_id != Global.team:
				roster_auto_sort(team_id)
		Global.phase = 2
		setup_menus()
	else:
		if days == -1:
			while Global.games_played < 1240:
				for g in range(games_per_day):
					if Global.games_played == Global.schedule.size():
						print("Schedule complete.")
						enter_playoffs()
						return
					run_next_game()
				cpu_free_agent_signings()
				print("Day %d simmed." % (Global.games_played / 10))
		else:
			for d in range(days):
				for g in range(games_per_day):
					if Global.games_played == Global.schedule.size():
						refresh_standings()
						enter_playoffs()
						return
					run_next_game()
				cpu_free_agent_signings()
				print("Day %d simmed." % (Global.games_played / 10))
			refresh_standings()

func _on_team_id_pressed(id):
	match id:
		0:
			roster.popup()
		1:
			history.popup()

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


func _on_button_pressed():
	get_tree().change_scene_to_file("res://leaguehis.tscn")


func _on_players_id_pressed(id):
	match id:
		0:
			trade.popup()
		1:
			draft_history.popup()

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

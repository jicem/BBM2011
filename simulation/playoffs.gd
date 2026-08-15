extends Node2D

@onready var game_menu = $MenuBar/Game
@onready var play_menu = $MenuBar/Play
@onready var team_menu = $MenuBar/Team
@onready var players_menu = $MenuBar/Players
@onready var help_menu = $MenuBar/Help
@onready var roster = $Roster
@onready var history = $History
@onready var manual = $Manual
@onready var awards = $Awards
@onready var east_seeds = $HBoxContainer/East/EastSeeds
@onready var west_seeds = $HBoxContainer/West/WestSeeds
@onready var finals_seeds = $FinalsSeeds
@onready var endtimer = $EndTimer
@onready var bracket = {
	"west": {
		"round1": {
			1:%West1,
			8:%West8,
			4:%West4,
			5:%West5,
			3:%West3,
			6:%West6,
			2:%West2,
			7:%West7
		},
		"semis": {
			1:%SemiWest1,
			2:%SemiWest4,
			3:%SemiWest2,
			4:%SemiWest3
		},
		"finals": {
			1:%FinalWest1,
			2:%FinalWest2
		}
	},

	"east": {
		"round1": {
			1:%East1,
			8:%East8,
			4:%East4,
			5:%East5,
			3:%East3,
			6:%East6,
			2:%East2,
			7:%East7
		},
		"semis": {
			1:%SemiEast1,
			2:%SemiEast4,
			3:%SemiEast2,
			4:%SemiEast3
		},
		"finals": {
			1:%FinalEast1,
			2:%FinalEast2
		}
	},

	"nba_finals": {
		1:%Final1,
		2:%Final2
	}
}
@onready var timer = $Timer

var db: SQLite
var sim_mode
enum SimMode {
	ONE_DAY,
	ROUND,
	PLAYOFFS
}

var load_scene = preload("res://LoadBrowser.tscn")
var load_browser
var save_scene = preload("res://SaveBrowser.tscn")
var save_browser

func _ready():
	setup_menus()
	setup_db()
	
	if(Global.phase == 3):
		Global.awards_season = Global.season + 2011
		Global.changed_season = true
		awards.popup()

	east_seeds.hide()
	west_seeds.hide()
	finals_seeds.hide()

	if Global.phase < 3:
		push_error("Playoffs have not started!")
		return

	load_playoff_state()
	refresh_playoff_bracket()

func _process(delta):
	if Input.is_action_just_pressed("simulate"):
		sim_mode = SimMode.ONE_DAY
		simulate_day()

func setup_menus():
	game_menu.clear()
	play_menu.clear()

	game_menu.add_item("Load League", 0)
	game_menu.add_item("Save League", 1)
	game_menu.add_item("Quit to Title", 2)
	game_menu.add_item("Quit to Desktop", 3)

	play_menu.add_item("One Game (Alt+P)", 0)
	play_menu.add_item("Through Round", 1)
	play_menu.add_item("Through Playoffs", 2)

	team_menu.add_item("Roster", 0)
	team_menu.add_item("History", 1)
	
	players_menu.add_item("Trade", 0)
	players_menu.add_item("Draft History", 1)
	
	help_menu.add_item("Manual", 0)

func setup_db():
	db = SQLite.new()
	db.path = "res://data/bball.db"
	db.open_db()
	
func load_playoff_state():
	
	east_seeds.show()
	west_seeds.show()

	var rows = db.select_rows(
		"active_playoff_series",
		"won_home < 4 AND won_away < 4",
		["series_round"]
	)

	if rows.is_empty():
		Global.playoff_round = 4
		return

	Global.playoff_round = int(rows[0]["series_round"])
	Global.playoff_day = 1
	
func refresh_playoff_bracket():

	clear_bracket()

	var finals = db.select_rows(
		"active_playoff_series",
		"series_round = 4",
		["series_id"]
	)

	if !finals.is_empty():
		finals_seeds.show()

	var series = db.select_rows(
		"active_playoff_series",
		"",
		["*"]
	)

	for s in series:

		var conference := ""

		if int(s["series_round"]) < 4:
			conference = get_conference(int(s["team_id_home"]))

		var home = "%d. %s (%d)" % [
			int(s["seed_home"]),
			get_team_abbreviation(int(s["team_id_home"])),
			int(s["won_home"])
		]

		var away = "%d. %s (%d)" % [
			int(s["seed_away"]),
			get_team_abbreviation(int(s["team_id_away"])),
			int(s["won_away"])
		]

		match int(s["series_round"]):

			1:
				bracket[conference]["round1"][int(s["seed_home"])].text = home
				bracket[conference]["round1"][int(s["seed_away"])].text = away

			2:
				var slot = get_semifinal_slot(s)

				if slot == 1:
					bracket[conference]["semis"][1].text = home
					bracket[conference]["semis"][2].text = away
				else:
					bracket[conference]["semis"][3].text = home
					bracket[conference]["semis"][4].text = away

			3:
				bracket[conference]["finals"][1].text = home
				bracket[conference]["finals"][2].text = away

			4:
				bracket["nba_finals"][1].text = home
				bracket["nba_finals"][2].text = away
				
func get_semifinal_slot(series) -> int:

	var a = int(series["seed_home"])
	var b = int(series["seed_away"])

	var top_half = [1, 8, 4, 5]

	if top_half.has(a) and top_half.has(b):
		return 1

	return 2

func get_team_abbreviation(team_id:int) -> String:

	var rows = db.select_rows(
		"team_attributes",
		"team_id=%d AND season=%d" % [team_id, Global.season + 2011],
		["abbreviation"]
	)

	if rows.is_empty():
		return "---"

	return rows[0]["abbreviation"]
	
func get_conference(team_id:int) -> String:

	var rows = db.select_rows(
		"team_attributes",
		"team_id=%d AND season=%d" % [team_id, Global.season + 2011],
		["division_id"]
	)

	var division = int(rows[0]["division_id"])

	if division < 3:
		return "east"

	return "west"
	
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

func clear_bracket():

	for conference in ["west","east"]:

		for playoff_round in ["round1","semis","finals"]:

			for label in bracket[conference][playoff_round].values():
				label.text = ""

	for label in bracket["nba_finals"].values():
		label.text = ""

func _on_play_id_pressed(id:int):

	match id:
		0:
			sim_mode = SimMode.ONE_DAY
			simulate_day()

		1:
			sim_mode = SimMode.ROUND
			simulate_round()

		2:
			sim_mode = SimMode.PLAYOFFS
			simulate_thru_playoffs()


func simulate_day():
	if Global.phase != 3:
		return

	timer.start()


func simulate_round():
	if Global.phase != 3:
		return

	timer.start()


func simulate_thru_playoffs():
	if Global.phase != 3:
		return

	timer.start()
	
func _on_timer_timeout():
	simulate_playoff_day()

	refresh_playoff_bracket()

	if current_round_finished():

		if Global.playoff_round == 4:

			finish_playoffs()

		advance_playoff_round()

		refresh_playoff_bracket()

		if sim_mode == SimMode.ROUND:
			timer.stop()
			return

	if sim_mode == SimMode.ONE_DAY:
		timer.stop()
	else:
		timer.start()
		
func simulate_playoff_day():

	var series_list = db.select_rows(
		"active_playoff_series",
		"series_round = %d" % Global.playoff_round,
		["*"]
	)

	for s in series_list:

		if int(s["won_home"]) < 4 and int(s["won_away"]) < 4:
			play_series_game(s)
	
func play_series_game(series):

	var game = Game.new(
		db,
		series["team_id_home"],
		series["team_id_away"],
		true # playoff game
	)

	var winner = game.play()

	if winner == series["team_id_home"]:
		db.query("""
			UPDATE active_playoff_series
			SET won_home = won_home + 1
			WHERE series_id = %d
		""" % series["series_id"])
	else:
		db.query("""
			UPDATE active_playoff_series
			SET won_away = won_away + 1
			WHERE series_id = %d
		""" % series["series_id"])
		
	print("Winner: Team ", winner)

	check_series_finished(series["series_id"])
	
func check_series_finished(series_id:int) -> bool:

	var s = db.select_rows(
		"active_playoff_series",
		"series_id=%d" % series_id,
		["*"]
	)[0]

	return int(s["won_home"]) >= 4 or int(s["won_away"]) >= 4
	
func playoffs_finished() -> bool:

	var rows = db.select_rows(
		"active_playoff_series",
		"series_round = 4",
		["*"]
	)

	if rows.is_empty():
		return false

	var finals = rows[0]

	return int(finals["won_home"]) >= 4 or int(finals["won_away"]) >= 4
	
func current_round_finished() -> bool:

	var rows = db.select_rows(
		"active_playoff_series",
		"series_round = %d" % Global.playoff_round,
		["*"]
	)

	for s in rows:
		if int(s["won_home"]) < 4 and int(s["won_away"]) < 4:
			return false

	return true
	
func advance_playoff_round():

	match Global.playoff_round:

		1:
			var round1 = db.select_rows(
				"active_playoff_series",
				"series_round = 1",
				["*"]
			)

			var east := []
			var west := []

			for s in round1:
				if get_conference(s["team_id_home"]) == "east":
					east.append(s)
				else:
					west.append(s)

			create_next_round(east, 2)
			create_next_round(west, 2)

			Global.playoff_round = 2
			Global.playoff_day = 1

		2:
			var round2 = db.select_rows(
				"active_playoff_series",
				"series_round = 2",
				["*"]
			)

			var east := []
			var west := []

			for s in round2:
				if get_conference(s["team_id_home"]) == "east":
					east.append(s)
				else:
					west.append(s)

			create_next_round(east, 3)
			create_next_round(west, 3)

			Global.playoff_round = 3
			Global.playoff_day = 1

		3:
			var round3 = db.select_rows(
				"active_playoff_series",
				"series_round = 3",
				["*"]
			)

			var east_series
			var west_series

			for s in round3:
				if get_conference(s["team_id_home"]) == "east":
					east_series = s
				else:
					west_series = s

			var east_winner = get_series_winner(east_series)
			var west_winner = get_series_winner(west_series)

			add_series(
				get_next_series_id(),
				4,
				west_winner["team_id"],
				east_winner["team_id"],
				west_winner["seed"],
				east_winner["seed"]
			)

			Global.playoff_round = 4
			Global.playoff_day = 1

		4:
			finish_playoffs()
		
func create_next_round(previous_round:Array, next_round:int):

	match next_round:

		2:
			var winner_1_8
			var winner_4_5
			var winner_3_6
			var winner_2_7

			for series in previous_round:
				var seeds = [int(series["seed_home"]), int(series["seed_away"])]
				seeds.sort()

				match seeds:
					[1, 8]:
						winner_1_8 = get_series_winner(series)

					[4, 5]:
						winner_4_5 = get_series_winner(series)

					[3, 6]:
						winner_3_6 = get_series_winner(series)

					[2, 7]:
						winner_2_7 = get_series_winner(series)

			add_series(
				get_next_series_id(),
				2,
				winner_1_8["team_id"],
				winner_4_5["team_id"],
				winner_1_8["seed"],
				winner_4_5["seed"]
			)

			add_series(
				get_next_series_id(),
				2,
				winner_3_6["team_id"],
				winner_2_7["team_id"],
				winner_3_6["seed"],
				winner_2_7["seed"]
			)

		3:
			var winner_top = get_series_winner(previous_round[0])
			var winner_bottom = get_series_winner(previous_round[1])

			add_series(
				get_next_series_id(),
				3,
				winner_top["team_id"],
				winner_bottom["team_id"],
				winner_top["seed"],
				winner_bottom["seed"]
			)
	
func get_series_winner(series) -> Dictionary:

	if series["won_home"] > series["won_away"]:
		return {
			"team_id": series["team_id_home"],
			"seed": series["seed_home"]
		}

	return {
		"team_id": series["team_id_away"],
		"seed": series["seed_away"]
	}
	
func add_series(
	series_id: int,
	playoff_round: int,
	home_team: int,
	away_team: int,
	home_seed: int,
	away_seed: int
):

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
	
func get_next_series_id() -> int:

	var rows = db.select_rows(
		"active_playoff_series",
		"",
		["MAX(series_id) AS max_id"]
	)

	if rows.is_empty() or rows[0]["max_id"] == null:
		return 1

	return int(rows[0]["max_id"]) + 1

func finish_playoffs() -> void:

	# Find the NBA Finals series
	var finals = db.select_rows(
		"active_playoff_series",
		"series_round = 4",
		["*"]
	)

	if finals.is_empty():
		return

	var series = finals[0]

	var champion : int
	var runner_up : int

	if int(series["won_home"]) > int(series["won_away"]):
		champion = int(series["team_id_home"])
		runner_up = int(series["team_id_away"])
	else:
		champion = int(series["team_id_away"])
		runner_up = int(series["team_id_home"])

	# Mark champion
	db.query("""
		UPDATE team_attributes
		SET won_championship = 1
		WHERE season = %d
		AND team_id = %d
	""" % [Global.season + 2011, champion])
	
	# Both Finals participants are conference champions
	db.query("""
		UPDATE team_attributes
		SET won_conference = 1
		WHERE season = %d
		AND (team_id = %d OR team_id = %d)
	""" % [Global.season + 2011, champion, runner_up])
	
	# Remove expired dead salary
	db.query("""
		DELETE FROM released_players_salaries
		WHERE contract_expiration <= %d
			""" % [Global.season + 2011])

	# Every free agent waits another year before their contract expires
	db.query("""
		UPDATE player_attributes
		SET contract_expiration = contract_expiration + 1
		WHERE team_id = -1
			""")
	
	print("%s won the NBA Championship!" % get_team_abbreviation(champion))
	
	# Continue to the draft
	Global.phase = 4
	endtimer.start()

func _on_button_1_pressed():
	get_tree().change_scene_to_file("res://simulation/main.tscn")


func _on_team_id_pressed(id):
	match id:
		0:
			roster.popup()
		1:
			history.popup()


func _on_draft_pressed():
	get_tree().change_scene_to_file("res://simulation/draft.tscn")


func _on_end_timer_timeout():
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

extends Node2D

@onready var game_menu = $MenuBar/Game
@onready var play_menu = $MenuBar/Play
@onready var team_menu = $MenuBar/Team
@onready var players_menu = $MenuBar/Players
@onready var help_menu = $MenuBar/Help
@onready var roster = $Roster
@onready var history = $History
@onready var manual = $Manual
@onready var trade = $Trade
@onready var draft_history = $DraftHis
@onready var roster_warning = $AcceptDialog
@onready var retirements = $Retirements
@onready var prospects: Tree = $Prospects
@onready var results: Tree = $Results
@onready var draft_button: Button = %DraftButton
@onready var endtimer = $EndTimer

var db: SQLite

var season := 2011 + Global.season

var draft_order = []        # 60 picks
var current_pick := 0
var player_team := Global.team

var waiting_for_player := false

var prospect_root: TreeItem
var result_root: TreeItem

var rng := RandomNumberGenerator.new()

var load_scene = preload("res://LoadBrowser.tscn")
var load_browser
var save_scene = preload("res://SaveBrowser.tscn")
var save_browser

func _ready():
	rng.randomize()
	
	if Global.phase == 4:
		retirements.popup()

	setup_menus()
	
	setup_db()

	setup_trees()

	load_draft_order()

	load_available_prospects()

	load_results()
	
func _process(delta):
	if Input.is_action_just_pressed("simulate"):
		_on_draft_button_pressed()
	
func setup_menus():
	game_menu.clear()
	play_menu.clear()

	game_menu.add_item("Load League", 0)
	game_menu.add_item("Save League", 1)
	game_menu.add_item("Quit to Title", 2)
	game_menu.add_item("Quit to Desktop", 3)

	play_menu.add_item("To Next Pick (Alt+P)", 0)
	play_menu.add_item("To Free Agency", 1)

	team_menu.add_item("Roster", 0)
	team_menu.add_item("History", 1)
	
	players_menu.add_item("Trade", 0)
	players_menu.add_item("Draft History", 1)
	
	help_menu.add_item("Manual", 0)

func setup_db():
	db = SQLite.new()
	db.path = "res://data/bball.db"
	db.open_db()
	
func setup_trees():
	
	prospects.columns = 6
	prospects.set_column_custom_minimum_width(1, 200)
	prospects.set_column_title(0, "Rank")
	prospects.set_column_title(1, "Name")
	prospects.set_column_title(2, "Pos")
	prospects.set_column_title(3, "Age")
	prospects.set_column_title(4, "Ovr")
	prospects.set_column_title(5, "Pot")

	prospect_root = prospects.create_item()

	results.columns = 4
	results.set_column_custom_minimum_width(3, 240)
	results.set_column_title(0, "Round")
	results.set_column_title(1, "Pick")
	results.set_column_title(2, "Team")
	results.set_column_title(3, "Player")

	result_root = results.create_item()
	
func load_draft_order():

	draft_order.clear()

	var rows = db.select_rows(
		"team_attributes",
		"season=%d" % season,
		["team_id","won","lost","abbreviation"]
	)

	rows.sort_custom(func(a,b):
		return a["won"] < b["won"]
	)

	# Round 1
	for i in range(rows.size()):
		draft_order.append({
			"team_id": rows[i]["team_id"],
			"abbreviation": rows[i]["abbreviation"],
			"round": 1,
			"pick": i + 1
		})

	# Round 2 (same order for now)
	for i in range(rows.size()):
		draft_order.append({
			"team_id": rows[i]["team_id"],
			"abbreviation": rows[i]["abbreviation"],
			"round": 2,
			"pick": i + 1
		})
		
func load_available_prospects():

	prospects.clear()
	prospect_root = prospects.create_item()

	db.query("""
		SELECT
			pa.player_id,
			pa.name,
			pa.position,
			pa.born_date,
			pr.overall,
			pr.potential
		FROM player_attributes pa
		INNER JOIN player_ratings pr
			ON pa.player_id = pr.player_id
		WHERE pa.team_id = -2
		ORDER BY pr.overall DESC, pr.potential DESC
	""")

	var players = db.query_result

	var rank := 1

	for p in players:

		var item = prospects.create_item(prospect_root)

		item.set_text(0, str(rank))
		item.set_text(1, str(p["name"]))
		item.set_text(2, str(p["position"]))
		item.set_text(3, str(season - int(p["born_date"])))
		item.set_text(4, str(p["overall"]))
		item.set_text(5, str(p["potential"]))

		item.set_metadata(0, p["player_id"])

		rank += 1

func load_results():

	results.clear()
	result_root = results.create_item()

	db.query("""
		SELECT
			dr.round,
			dr.pick,
			ta.abbreviation,
			pa.name
		FROM draft_results dr
		INNER JOIN player_attributes pa
			ON pa.player_id = dr.player_id
		INNER JOIN team_attributes ta
			ON ta.team_id = dr.team_id
			AND ta.season = dr.season
		WHERE dr.season = %d
		ORDER BY dr.round ASC, dr.pick ASC
	""" % season)

	var rows = db.query_result

	for row in rows:

		var item = results.create_item(result_root)

		item.set_text(0, str(row["round"]))
		item.set_text(1, str(row["pick"]))
		item.set_text(2, str(row["abbreviation"]))
		item.set_text(3, str(row["name"]))
		
func _on_draft_button_pressed():
	if Global.phase == 4:
		if waiting_for_player:
			draft_selected_player()
		else:
			advance_until_player_pick()


func advance_until_player_pick():

	while current_pick < draft_order.size():

		var pick = draft_order[current_pick]

		if pick.team_id == player_team:

			waiting_for_player = true

			draft_button.text = "Draft Player"
			draft_button.disabled = false

			return

		ai_make_pick(pick)

		current_pick += 1

	finish_draft()

func draft_selected_player():

	var player_id := -1

	var item = prospects.get_selected()

	if item != null:
		player_id = item.get_metadata(0)
	else:
		# Auto-pick the highest potential player
		player_id = choose_player()

		if player_id == -1:
			return

	draft_player(player_team, player_id)

	current_pick += 1

	waiting_for_player = false

	draft_button.text = "Simulating..."
	draft_button.disabled = true

	load_available_prospects()
	load_results()

	advance_until_player_pick()
	

func ai_make_pick(pick):

	var player_id = choose_player()

	draft_player(
		pick.team_id,
		player_id
	)

	load_available_prospects()
	load_results()
	
	
func choose_player() -> int:
	db.query("""
		SELECT pa.player_id
		FROM player_attributes pa
		INNER JOIN player_ratings pr
			ON pa.player_id = pr.player_id
		WHERE pa.team_id = -2
		ORDER BY
			pr.potential DESC,
			pr.overall DESC
		LIMIT 1
	""")

	if db.query_result.is_empty():
		return -1

	return db.query_result[0]["player_id"]


func draft_player(team_id:int, player_id:int):

	db.query("""
		UPDATE player_attributes
		SET
			team_id = %d,
			draft_team_id = %d,
			draft_year = %d,
			draft_round = %d,
			draft_pick = %d
		WHERE player_id = %d
	""" % [
		team_id,
		team_id,
		season,
		draft_order[current_pick].round,
		draft_order[current_pick].pick,
		player_id
	])

	db.insert_row("draft_results",{
		"season":season,
		"round":draft_order[current_pick].round,
		"pick":draft_order[current_pick].pick,
		"team_id":team_id,
		"player_id":player_id
	})
	
func generate_contract(
	overall: int,
	potential: int,
	current_season: int
) -> Dictionary:

	var years := 1

	if overall >= 80:
		years = rng.randi_range(4, 5)

	elif overall >= 70:
		years = rng.randi_range(3, 5)

	elif overall >= 60:
		years = rng.randi_range(2, 4)

	else:
		years = rng.randi_range(1, 2)


	var value := ((2.0 * float(overall) + float(potential)) * 0.85 - 120.0) / 90
	
	value *= (20000000 - 500000
	) + 500000

	value *= rng.randf_range(0.90, 1.10)


	var salary := clampi(
		roundi(value),
		500000,
		20000000
	)

	salary = 50000.0 * round(salary / 50000.0)

	return {
		"contract_amount": roundi(salary),
		"contract_expiration": current_season + years
	}
	
func process_expiring_contracts() -> void:

	# Get all players whose contracts expire this season.
	db.query("""
		SELECT
			pa.player_id,
			pa.team_id,
			pr.overall,
			pr.potential
		FROM player_attributes pa
		INNER JOIN player_ratings pr
			ON pa.player_id = pr.player_id
		WHERE pa.team_id > 0
		AND pa.contract_expiration <= %d
	""" % season)

	var players = db.query_result

	Global.expirings.clear()
	
	for row in players:

		var player_id: int = int(row["player_id"])
		var team_id: int = int(row["team_id"])
		var overall: int = int(row["overall"])
		var potential: int = int(row["potential"])
		
		if team_id == Global.team:
			# Player becomes a free agent and is added to expirings array.
			db.query("""
				UPDATE player_attributes
				SET
					team_id = -1,
					free_agent_times_asked = 0
				WHERE player_id = %d
			""" % player_id)
			Global.expirings.append(player_id)
			Global.current_player = player_id
		else:
			if rng.randf() < 0.5:
				# Player becomes a free agent.
				db.query("""
					UPDATE player_attributes
					SET
						team_id = -1,
						free_agent_times_asked = 0
					WHERE player_id = %d
				""" % player_id)
				
		var contract := generate_contract(
			overall,
			potential,
			season
		)

		db.query("""
				UPDATE player_attributes
				SET
					contract_amount = %d,
					contract_expiration = %d
					WHERE player_id = %d
				""" % [
			contract["contract_amount"],
			contract["contract_expiration"],
			player_id
		])
				
		print(contract["contract_amount"])

func give_rookie_contracts() -> void:

	db.query("""
		SELECT
			pa.player_id,
			pr.overall,
			pr.potential
		FROM player_attributes pa
		INNER JOIN player_ratings pr
			ON pa.player_id = pr.player_id
		WHERE pa.draft_year = %d
		AND pa.team_id >= 0
	""" % season)

	var players = db.query_result

	for row in players:

		var player_id: int = int(row["player_id"])
		var overall: int = int(row["overall"])
		var potential: int = int(row["potential"])

		var contract := generate_contract(
			overall,
			potential,
			season
		)

		db.query("""
			UPDATE player_attributes
			SET
				contract_amount = %d,
				contract_expiration = %d
			WHERE player_id = %d
		""" % [
			contract["contract_amount"],
			contract["contract_expiration"],
			player_id
		])
		
func finish_draft():

	# Give every drafted player a contract.
	give_rookie_contracts()

	# Process expiring contracts for existing players.
	process_expiring_contracts()

	# Refresh results one last time.
	load_results()
	
	# Prevent further drafting.
	draft_button.disabled = true
	draft_button.text = "Draft Complete"

	# Make remaining prospects free agents.
	db.query("""
		UPDATE player_attributes
		SET team_id = -1
		WHERE team_id = -2
	""")
	Global.phase = 5

	endtimer.start()
	
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
	match id:
		0:
			_on_draft_button_pressed()
		1:
			if Global.phase == 5:
				to_fa()
			
func to_fa():
	get_tree().change_scene_to_file("res://freeagency.tscn")


func _on_button_1_pressed():
	get_tree().change_scene_to_file("res://simulation/main.tscn")


func _on_playoffs_pressed():
	get_tree().change_scene_to_file("res://simulation/playoffs.tscn")


func _on_end_timer_timeout():
	get_tree().change_scene_to_file("res://simulation/fa.tscn")


func _on_team_id_pressed(id):
	match id:
		0:
			roster.popup()
		1:
			history.popup()


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

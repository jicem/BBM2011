extends Node2D

@onready var game_menu = $MenuBar/Game
@onready var play_menu = $MenuBar/Play
@onready var team_menu = $MenuBar/Team
@onready var players_menu = $MenuBar/Players
@onready var help_menu = $MenuBar/Help

@onready var roster = $Roster
@onready var history = $History
@onready var manual = $Manual
@onready var negotiations = $Negotiations

@onready var alert = $AcceptDialog

@onready var free_agents: Tree = $FreeAgents
@onready var player_signing = $PlayerSigning
@onready var player_info = $PlayerInfo

@onready var sign_button = $SignPlayer
@onready var season_txt = $SeasonText
@onready var timer = $Timer

var db: SQLite

var season := 2011 + Global.season

var free_agent_root: TreeItem

const SALARY_CAP := 90000000

var load_scene = preload("res://LoadBrowser.tscn")
var load_browser
var save_scene = preload("res://SaveBrowser.tscn")
var save_browser

func _ready():
	db = SQLite.new()
	db.path = "res://data/bball.db"
	db.open_db()
	if Global.phase == 5:
		if !Global.expirings.is_empty():
			Global.current_player = Global.expirings[0]
			Global.negotiating = true
			negotiations.popup_centered()
	setup_menus()
	setup_free_agents_tree()
	update_free_agents()

func _process(delta):
	if(!Global.negotiating):
		negotiations.hide()
		player_signing.hide()
	if(Global.player_signed):
		update_free_agents()
		Global.player_signed = false
	if Input.is_action_just_pressed("simulate"):
		if(Global.phase == 5):
			sign_button.hide()
			season_txt.show()
			timer.start()

func has_expiring_contracts() -> bool:
	var current_season := 2011 + Global.season

	db.query("""
		SELECT COUNT(*) AS expiring_count
		FROM player_attributes
		WHERE team_id = %d
		AND contract_expiration <= %d
	""" % [
		Global.team,
		current_season
	])

	if db.query_result.is_empty():
		return false

	return int(db.query_result[0]["expiring_count"]) > 0

func setup_menus():

	game_menu.clear()
	play_menu.clear()

	game_menu.add_item("Load League", 0)
	game_menu.add_item("Save League", 1)
	game_menu.add_item("Quit to Title", 2)
	game_menu.add_item("Quit to Desktop", 3)

	play_menu.add_item("To Next Season (Alt+P)", 0)

	team_menu.add_item("Roster", 0)
	team_menu.add_item("History", 1)

	players_menu.add_item("Trade", 0)
	players_menu.add_item("Draft History", 1)

	help_menu.add_item("Manual", 0)

func setup_free_agents_tree():

	free_agents.columns = 11
	free_agents.set_column_custom_minimum_width(0, 150)
	free_agents.set_column_custom_minimum_width(9, 150)
	free_agents.set_column_title(0, "Name")
	free_agents.set_column_title(1, "Position")
	free_agents.set_column_title(2, "Age")
	free_agents.set_column_title(3, "Ovr")
	free_agents.set_column_title(4, "Pot")
	free_agents.set_column_title(5, "Min")
	free_agents.set_column_title(6, "Pts")
	free_agents.set_column_title(7, "Reb")
	free_agents.set_column_title(8, "Ast")
	free_agents.set_column_title(9, "Asking For")

	free_agent_root = free_agents.create_item()

func update_free_agents():

	free_agents.clear()

	free_agent_root = free_agents.create_item()

	# First get all free agents.
	db.query("""
		SELECT
			pa.player_id,
			pa.name,
			pa.position,
			%d - pa.born_date AS age,
			pr.overall,
			pr.potential,
			pa.contract_amount,
			pa.contract_expiration,
			pa.free_agent_times_asked
		FROM player_attributes pa
		INNER JOIN player_ratings pr
			ON pa.player_id = pr.player_id
		WHERE pa.team_id = -1
		ORDER BY pr.overall DESC
	""" % season)

	var players = db.query_result

	for p in players:

		var player_id = int(p["player_id"])

		var stats = get_player_stats(player_id)

		var item = free_agents.create_item(free_agent_root)

		item.set_text(0, str(p["name"]))
		item.set_text(1, str(p["position"]))
		item.set_text(2, str(p["age"]))
		item.set_text(3, str(p["overall"]))
		item.set_text(4, str(p["potential"]))

		item.set_text(5, "%.1f" % stats["minutes"])
		item.set_text(6, "%.1f" % stats["points"])
		item.set_text(7, "%.1f" % stats["rebounds"])
		item.set_text(8, "%.1f" % stats["assists"])

		var asking_for = calculate_asking_price(
			p["contract_amount"],
			p["contract_expiration"],
			p["free_agent_times_asked"]
		)

		item.set_text(9, asking_for)

		# Store player ID on the TreeItem.
		item.set_metadata(0, player_id)

func get_player_stats(player_id: int) -> Dictionary:

	# Try current season first.
	db.query("""
		SELECT
			AVG(minutes) AS minutes,
			AVG(points) AS points,
			AVG(offensive_rebounds + defensive_rebounds) AS rebounds,
			AVG(assists) AS assists
		FROM player_stats
		WHERE player_id = %d
		AND season = %d
	""" % [player_id, season])

	var rows = db.query_result

	if not rows.is_empty() and rows[0]["minutes"] != null:

		return {
			"minutes": float(rows[0]["minutes"]),
			"points": float(rows[0]["points"]),
			"rebounds": float(rows[0]["rebounds"]),
			"assists": float(rows[0]["assists"])
		}


	# If no current season stats, try previous season.
	db.query("""
		SELECT
			AVG(minutes) AS minutes,
			AVG(points) AS points,
			AVG(offensive_rebounds + defensive_rebounds) AS rebounds,
			AVG(assists) AS assists
		FROM player_stats
		WHERE player_id = %d
		AND season = %d
	""" % [player_id, season - 1])

	rows = db.query_result

	if not rows.is_empty() and rows[0]["minutes"] != null:

		return {
			"minutes": float(rows[0]["minutes"]),
			"points": float(rows[0]["points"]),
			"rebounds": float(rows[0]["rebounds"]),
			"assists": float(rows[0]["assists"])
		}


	# No stats available.
	return {
		"minutes": 0.0,
		"points": 0.0,
		"rebounds": 0.0,
		"assists": 0.0
	}

func calculate_asking_price(
	contract_amount,
	contract_expiration,
	free_agent_times_asked
) -> String:

	var amount := float(contract_amount)
	var times_asked := int(free_agent_times_asked)

	# Increase asking price by 10% for each previous negotiation.
	var asking := amount * (1.0 + times_asked / 10.0)

	# Keep asking price within league salary limits.
	asking = clamp(
		asking,
		500000.0,
		20000000.0
	)

	# Format the salary.
	var salary_text := format_salary(asking)

	return "%s thru %s" % [
		salary_text,
		str(contract_expiration)
	]
	
func format_salary(amount: float) -> String:

	if amount >= 1000000.0:

		var millions := amount / 1000000.0

		return "$%.2fM" % millions

	else:

		var thousands := amount / 1000.0

		return "$%.0fK" % thousands

func get_selected_player_id() -> int:

	var item = free_agents.get_selected()

	if item == null:
		return -1

	return int(item.get_metadata(0))

func _on_sign_player_pressed():

	var player_id = get_selected_player_id()

	if player_id == -1:
		return

	# Check roster size.
	db.query("""
		SELECT COUNT(*) AS roster_size
		FROM player_attributes
		WHERE team_id = %d
	""" % Global.team)

	if db.query_result.is_empty():
		return

	var roster_size = int(
		db.query_result[0]["roster_size"]
	)


	if roster_size >= 15:

		alert.popup()

		return


	# Open contract window.
	print("Opening contract negotiation for player ", player_id)
	
	Global.current_player = player_id
	Global.negotiating = true
	Global.changed_player = true
	player_signing.popup_centered()

func advance_to_next_season():

	var old_season := Global.season
	var new_season := old_season + 1

	# Advance the global season.
	Global.season = new_season

	# Copy the previous season's team attributes
	# into the new season.
	create_new_team_attributes(
		old_season,
		new_season
	)
	
	var id = 525 * new_season
	create_draft_class(db, id)

	# Develop all players by one year.
	develop_players()

	# Have AI teams sign available free agents.
	auto_sign_free_agents()
	
func create_new_team_attributes(
	old_season: int,
	new_season: int
):

	db.query("""
		SELECT
			team_id,
			division_id,
			region,
			name,
			abbreviation,
			cash
		FROM team_attributes
		WHERE season = %d
	""" % (old_season + 2011))

	for row in db.query_result:

		db.query("""
			INSERT INTO team_attributes (
				team_id,
				division_id,
				region,
				name,
				abbreviation,
				cash,
				season
			)
			VALUES (
				%d,
				%d,
				'%s',
				'%s',
				'%s',
				%f,
				%d
			)
		""" % [
			int(row["team_id"]),
			int(row["division_id"]),
			str(row["region"]).replace("'", "''"),
			str(row["name"]).replace("'", "''"),
			str(row["abbreviation"]).replace("'", "''"),
			float(row["cash"]),
			(new_season + 2011)
		])

func develop_players():

	db.query("""
		SELECT
			player_id,
			born_date
		FROM player_attributes
	""")

	for player in db.query_result:

		var player_id := int(player["player_id"])
		var current_year = 2011 + Global.season
		var age = current_year - int(player["born_date"])

		develop_player(
			player_id,
			age
		)
		
func develop_player(
	player_id: int,
	age: int
):

	db.query("""
		SELECT
			*
		FROM player_ratings
		WHERE player_id = %d
	""" % player_id)

	if db.query_result.is_empty():
		return

	var ratings = db.query_result[0]

	var overall := calculate_overall(ratings)
	
	ratings["overall"] = overall

	var potential := float(ratings["potential"])

	var rating_keys = [
		"strength",
		"speed",
		"jumping",
		"endurance",
		"shooting_inside",
		"shooting_layups",
		"shooting_free_throws",
		"shooting_two_pointers",
		"shooting_three_pointers",
		"blocks",
		"steals",
		"dribbling",
		"passing",
		"rebounding"
	]

	for key in rating_keys:

		var plus_minus := 28.0 - age

		if plus_minus > 0:

			if potential > overall:

				if potential - overall < 20:

					plus_minus *= (
						(potential - overall) / 20.0
						+ 0.5
					)

				else:

					plus_minus *= 1.5

			else:

				plus_minus *= 0.5

		else:

			if potential > 0:
				plus_minus *= 30.0 / potential

		var increase := randfn(
			1.0,
			2.0
		) * plus_minus

		var new_rating := float(
			ratings[key]
		) + increase

		ratings[key] = clamp(
			new_rating,
			0.0,
			100.0
		)

	# Recalculate overall after development.
	overall = calculate_overall(ratings)
	ratings["overall"] = overall

	# Decrease potential over time.
	ratings["potential"] = float(
		ratings["potential"]
	) - 2.0 + int(
		randfn(0.0, 2.0)
	)

	# Potential cannot fall below overall.
	if age > 26:
		ratings["potential"] = ratings["overall"]
	else:
		ratings["potential"] = max(
			ratings["potential"],
			ratings["overall"]
	)

	# Save updated ratings.
	update_player_ratings(
		player_id,
		ratings
	)

func update_player_ratings(
	player_id: int,
	ratings
):

	db.query("""
		UPDATE player_ratings
		SET
			overall = %d,
			strength = %f,
			speed = %f,
			jumping = %f,
			endurance = %f,
			shooting_inside = %f,
			shooting_layups = %f,
			shooting_free_throws = %f,
			shooting_two_pointers = %f,
			shooting_three_pointers = %f,
			blocks = %f,
			steals = %f,
			dribbling = %f,
			passing = %f,
			rebounding = %f,
			potential = %f
		WHERE player_id = %d
	""" % [
		int(ratings["overall"]),
		int(ratings["strength"]),
		int(ratings["speed"]),
		int(ratings["jumping"]),
		int(ratings["endurance"]),
		int(ratings["shooting_inside"]),
		int(ratings["shooting_layups"]),
		int(ratings["shooting_free_throws"]),
		int(ratings["shooting_two_pointers"]),
		int(ratings["shooting_three_pointers"]),
		int(ratings["blocks"]),
		int(ratings["steals"]),
		int(ratings["dribbling"]),
		int(ratings["passing"]),
		int(ratings["rebounding"]),
		int(ratings["potential"]),
		player_id
	])
	
func calculate_overall(ratings) -> int:

	var overall : float = 0.0

	overall += ratings["shooting_inside"] * 0.07
	overall += ratings["shooting_layups"] * 0.07
	overall += ratings["shooting_two_pointers"] * 0.08
	overall += ratings["shooting_three_pointers"] * 0.10

	overall += ratings["passing"] * 0.10
	overall += ratings["dribbling"] * 0.10

	overall += ratings["rebounding"] * 0.08
	overall += ratings["blocks"] * 0.06
	overall += ratings["steals"] * 0.06

	overall += ratings["speed"] * 0.08
	overall += ratings["jumping"] * 0.05
	overall += ratings["strength"] * 0.05
	overall += ratings["height"] * 0.05
	overall += ratings["endurance"] * 0.05

	overall += ratings["shooting_free_throws"] * 0.05

	return clampi(roundi(overall), 0, 100)

func auto_sign_free_agents():
	# Get available free agents.
	var fas: Array = []

	db.query("""
		SELECT
			pa.player_id,
			pa.contract_amount,
			pa.contract_expiration
		FROM player_attributes pa
		INNER JOIN player_ratings pr
			ON pa.player_id = pr.player_id
		WHERE pa.team_id = -1
		ORDER BY pr.overall + pr.potential DESC
	""")

	for row in db.query_result:

		fas.append({
			"player_id": int(row["player_id"]),
			"amount": float(row["contract_amount"]),
			"expiration": int(row["contract_expiration"]),
			"signed": false
		})

	# Create team IDs.
	var team_ids: Array[int] = []

	for team_id in range(30):
		team_ids.append(team_id)

	team_ids.shuffle()

	# Let each AI team sign players.
	for team_id in team_ids:

		# Don't manage the user's team.
		if team_id == Global.team:
			continue

		sign_free_agents_for_team(
			team_id,
			fas
		)

func sign_free_agents_for_team(
	team_id: int,
	players: Array
):

	var num_players := 0
	var payroll := 0.0

	db.query("""
		SELECT
			COUNT(*) AS player_count,
			COALESCE(SUM(contract_amount), 0) AS payroll
		FROM player_attributes
		WHERE team_id = %d
		AND contract_expiration >= %d
	""" % [
		team_id,
		Global.season
	])

	if not db.query_result.is_empty():

		var row = db.query_result[0]

		num_players = int(
			row["player_count"]
		)

		payroll = float(
			row["payroll"]
		)

	while (
		payroll < SALARY_CAP
		and num_players < 15
	):

		var new_player := false

		for player in players:

			if player["signed"]:
				continue

			var amount := float(
				player["amount"]
			)

			if payroll + amount > SALARY_CAP:
				continue

			db.query("""
				UPDATE player_attributes
				SET
					team_id = %d,
					contract_amount = %f,
					contract_expiration = %d
				WHERE player_id = %d
			""" % [
				team_id,
				amount,
				int(player["expiration"]),
				int(player["player_id"])
			])

			player["signed"] = true

			num_players += 1
			payroll += amount

			new_player = true

			if num_players >= 15:
				break

		if not new_player:
			break

static func create_draft_class(db: SQLite, start_id:int) -> void:

	var id := start_id

	for i in range(75):

		var player = Player.new()

		var age = randi_range(19, 22)

		var base_rating = randi_range(5, 30)
		var potential = randi_range(base_rating + 5, 99)

		player.generate(
			id,
			-2,                     # Undrafted prospect pool
			age,
			random_profile(),
			base_rating,
			potential,
			2011 + (Global.season + 1),
			2011 + Global.season                   # Current season
		)

		player.save(db)

		id += 1
		
static func random_profile() -> String:

	var r = randf()

	if r < 0.20:
		return "Point"
	elif r < 0.40:
		return "ShootingGuard"
	elif r < 0.60:
		return "SmallForward"
	elif r < 0.80:
		return "PowerForward"
	else:
		return "Center"

func _on_play_id_pressed(id: int):

	match id:
		0:
			if(Global.phase == 5):
				sign_button.hide()
				season_txt.show()
				timer.start()

func _on_game_id_pressed(id: int):

	match id:
		0:
			open_load_browser()
		1:
			open_save_browser()
		2:
			get_tree().change_scene_to_file(
				"res://titlescreen.tscn"
			)
		3:
			get_tree().quit()


func _on_team_id_pressed(id: int):

	match id:

		0:
			roster.popup()
			
		1:
			history.popup()

func _on_free_agents_item_activated():

	var player_id = get_selected_player_id()

	if player_id == -1:
		return

	print("Player activated: ", player_id)
	
	Global.setup_player_trees = true
	
	player_info.popup_centered()

func get_next_expiring_player() -> int:

	var current_season := 2011 + Global.season

	db.query("""
		SELECT player_id
		FROM player_attributes
		WHERE team_id = %d
		AND contract_expiration <= %d
		ORDER BY contract_expiration ASC, player_id ASC
		LIMIT 1
	""" % [
		Global.team,
		current_season
	])

	if db.query_result.is_empty():
		return -1

	return int(db.query_result[0]["player_id"])

func _on_negotiations_close_requested():
	var current_player_id = Global.current_player
	
	# Release the current player into free agency.
	
	db.query("""
		UPDATE player_attributes
		SET
			team_id = -1,
			free_agent_times_asked = 0
		WHERE player_id = %d
	""" % current_player_id)

	# Release all remaining players in Global.expirings.
	
	for expiring_player_id in Global.expirings:

		# Don't process the current player twice.
		if expiring_player_id == current_player_id:
			continue

		db.query("""
			UPDATE player_attributes
			SET
				team_id = -1,
				free_agent_times_asked = 0
			WHERE player_id = %d
		""" % expiring_player_id)

	Global.expirings.clear()

func generate_schedule(teams:Array) -> Array:
	var schedule := []
	var meta := []

	for t in teams:
		meta.append({
			"team_id": t["team_id"],
			"division_id": t["division_id"],
			"conference_id": t["conference_id"],
			"home_games": 0,
			"away_games": 0
		})

	for i in range(meta.size()):
		for j in range(meta.size()):

			if i == j:
				continue

			var game = [
				meta[i].team_id,
				meta[j].team_id
			]

			# Other conference
			if meta[i].conference_id != meta[j].conference_id:
				schedule.append(game)
				meta[i].home_games += 1
				meta[j].away_games += 1

			# Same division
			if meta[i].division_id == meta[j].division_id:
				schedule.append(game)
				schedule.append(game)

				meta[i].home_games += 2
				meta[j].away_games += 2

			# Same conference, different division
			if meta[i].conference_id == meta[j].conference_id \
			and meta[i].division_id != meta[j].division_id:

				schedule.append(game)

				meta[i].home_games += 1
				meta[j].away_games += 1
				
	var conference_teams := [[], []]
	var division_ids := [[], []]

	for i in range(meta.size()):
		var c = meta[i].conference_id

		conference_teams[c].append(i)
		division_ids[c].append(meta[i].division_id)
		
	var rng = RandomNumberGenerator.new()
	rng.randomize()

	for conference in range(2):

		var matchups := []

		# Dummy first matchup
		matchups.append(range(15))

		var rounds = 0

		while rounds < 8:

			var new_matchup := []

			var n = 0

			while n < 15:

				var attempts = 0

				while true:

					var try_n = rng.randi_range(0,14)

					# Different division
					if division_ids[conference][try_n] != division_ids[conference][n]:

						# Not already chosen this round
						if !new_matchup.has(try_n):

							var good = true

							# Avoid duplicate home opponents
							for previous in matchups:
								if previous[n] == try_n:
									good = false
									break

							if good:
								new_matchup.append(try_n)
								break

					attempts += 1

					if attempts > 50:
						new_matchup.clear()
						n = -1
						break

				n += 1

			matchups.append(new_matchup)
			rounds += 1

		matchups.remove_at(0)
		
		for matchup in matchups:

			for t in range(matchup.size()):

				var i = conference_teams[conference][t]
				var j = conference_teams[conference][matchup[t]]

				schedule.append([
					meta[i].team_id,
					meta[j].team_id
				])

				meta[i].home_games += 1
				meta[j].away_games += 1
				
	schedule.shuffle()
	
	for t in meta:
		print(
			t.team_id,
			" Home:", t.home_games,
			" Away:", t.away_games,
			" Total:", t.home_games + t.away_games
		)
		
	return schedule

func _on_draft_pressed():
	get_tree().change_scene_to_file("res://simulation/draft.tscn")
	
	
func _on_free_agents_item_selected():
	Global.current_player = get_selected_player_id()


func _on_button_1_pressed():
	get_tree().change_scene_to_file("res://simulation/main.tscn")


func _on_playoffs_pressed():
	get_tree().change_scene_to_file("res://simulation/playoffs.tscn")


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


func _on_timer_timeout():
	# Advance to the next season.
	advance_to_next_season()

	# Generate the new regular-season schedule.
	Global.schedule = generate_schedule(Global.teams)

	# Move to the regular season.
	Global.game_count = 0
	Global.games_played = 0
	Global.phase = 1

	# Return to the main screen.
	get_tree().change_scene_to_file("res://simulation/main.tscn")

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

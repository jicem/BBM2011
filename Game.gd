class_name Game
extends RefCounted

var db : SQLite

var teams := []
var players_on_court := []

var offense := 0
var defense := 1

var game_id : int
var season : int
var attendance : int

var possessions : int

var same_conference := false
var same_division := false

var playoffs := false

var rng := RandomNumberGenerator.new()

func _init(database:SQLite, home_id:int, away_id:int, is_playoffs:=false):

	rng.randomize()

	db = database
	playoffs = is_playoffs

	game_id = Global.game_count

	season = Global.season + 2011

	teams.append(Team.new(db, home_id))
	teams.append(Team.new(db, away_id))

	players_on_court = [
		[0,1,2,3,4],
		[0,1,2,3,4]
	]

	possessions = roundi(get_num_possessions())

	load_game_attributes()
	
func play():

	var total_possessions := possessions * 2

	# Total game time is 48 minutes.
	var dt := 48.0 / float(total_possessions)

	for possession in range(total_possessions):

		offense = possession % 2
		defense = 1 - offense


		# --------------------------------
		# Check for substitutions.
		# --------------------------------

		if possession % 10 == 0:
			update_players_on_court()


		# --------------------------------
		# Simulate possession.
		# --------------------------------

		if is_turnover():

			update_minutes(dt)
			continue


		var shooter = choose_shooter()


		if is_block():

			update_minutes(dt)
			continue


		if is_free_throw(shooter):

			update_minutes(dt)
			continue


		if !is_made_shot(shooter):
			do_rebound()


		# --------------------------------
		# Advance game clock.
		# --------------------------------

		update_minutes(dt)


	write_stats()


	if teams[0].stats["points"] > teams[1].stats["points"]:
		return teams[0].id
	else:
		return teams[1].id
		
func update_minutes(dt: float) -> void:

	for t in range(2):

		teams[t].update_rotation(
			players_on_court[t],
			dt
		)
	
func get_num_possessions() -> float:

	return (
		teams[0].pace +
		teams[1].pace
	) / 2.0 * Global.gaussian(1.0,0.03)
	
func choose_shooter() -> int:

	var weights := []

	for index in players_on_court[offense]:

		weights.append(
			teams[offense].players[index]
			.composite_ratings["shot_ratio"]
		)

	return pick_player(weights)
	
func is_turnover() -> bool:

	if rng.randf() < 0.10 + teams[defense].defense:

		do_turnover()

		return true

	return false
	
func is_block() -> bool:

	if rng.randf() < 0.02 + teams[defense].defense:

		do_block()

		return true

	return false
	
func is_made_shot(shooter:int) -> bool:

	var p = players_on_court[offense][shooter]

	var player = teams[offense].players[p]

	player.record_stat("field_goals_attempted")

	var is_three = false
	var percentage

	if player.composite_ratings["three_pointer_percentage"] > 0.25 \
	and rng.randf() < player.composite_ratings["three_pointer_percentage"] * 0.5:

		is_three = true
		player.record_stat("three_pointers_attempted")

		percentage = player.composite_ratings["three_pointer_percentage"]

	else:

		percentage = player.composite_ratings["field_goal_percentage"]

	if rng.randf() < percentage - teams[defense].defense:

		do_made_shot(shooter,is_three)

		if rng.randf() < 0.10:
			do_free_throw(shooter,1)

		return true

	return false
	
func do_made_shot(shooter: int, is_three: bool) -> void:

	var shooter_id: int = players_on_court[offense][shooter]
	var player = teams[offense].players[shooter_id]

	# Assist logic
	if rng.randf() < 0.60:
		var assist_weights := rating_array("assist_ratio", offense)
		var assist_slot := pick_player(assist_weights, shooter)

		if assist_slot != shooter:
			var assist_id: int = players_on_court[offense][assist_slot]
			var assist_player = teams[offense].players[assist_id]
			assist_player.record_stat("assists")

	# Core scoring stats
	player.record_stat("field_goals_made")
	player.record_stat("points", 2)

	if is_three:
		player.record_stat("three_pointers_made")
		player.record_stat("points", 1)
	
func is_free_throw(shooter:int) -> bool:

	var p = players_on_court[offense][shooter]
	var player = teams[offense].players[p]

	var chance := 0.05

	# Players who attack the rim draw more fouls
	chance += player.ratings["shooting_inside"] / 1000.0
	chance += player.ratings["shooting_layups"] / 1000.0

	# Aggressive defenses foul slightly more
	chance += teams[defense].defense * 0.05

	if rng.randf() < chance:
		do_free_throw(shooter, 2)
		return true

	return false
	
func do_free_throw(shooter:int, amount:int) -> void:

	do_foul()

	var p = players_on_court[offense][shooter]
	var player = teams[offense].players[p]

	for i in range(amount):

		player.record_stat("free_throws_attempted")

		var pct = player.composite_ratings["free_throw_percentage"]

		if rng.randf() < pct:

			player.record_stat("free_throws_made")
			player.record_stat("points")
			
func do_foul() -> void:

	var weights := []

	for p in players_on_court[defense]:
		weights.append(
			teams[defense].players[p].composite_ratings["foul_ratio"]
		)

	var fouler = pick_player(weights)

	var player = teams[defense].players[
		players_on_court[defense][fouler]
	]

	player.record_stat("personal_fouls")
	
func do_turnover():

	# Pick offensive player in rotation slot (0–4)
	var ratios = rating_array("turnover_ratio", offense)
	var slot = pick_player(ratios)

	# Convert slot → actual player index
	var player_id = players_on_court[offense][slot]
	var player = teams[offense].players[player_id]

	# Record turnover on player
	player.record_stat("turnovers")

	# Team turnover
	teams[offense].stats["turnovers"] += 1

	# Chance of steal
	is_steal()
	
func is_steal() -> bool:
	if rng.randf() < 0.55:
		do_steal()
		return true

	return false
	
func do_steal():

	var defender_slot = pick_player(
		rating_array("steal_ratio", defense)
	)

	var defender_id = players_on_court[defense][defender_slot]
	var defender = teams[defense].players[defender_id]

	defender.record_stat("steals")
	
func do_block():

	# Pick best blocker among defenders on court
	var blocker_slot = pick_player(
		rating_array("block_ratio", defense)
	)

	# Convert slot → player index
	var blocker_id = players_on_court[defense][blocker_slot]

	# Get actual player object
	var blocker = teams[defense].players[blocker_id]

	# Record block
	blocker.record_stat("blocks")
	
func do_rebound():

	var team

	if rng.randf() < 0.8:
		team = defense
	else:
		team = offense

	var weights := []

	for p in players_on_court[team]:

		weights.append(
			teams[team].players[p]
			.composite_ratings["rebound_ratio"]
		)

	var rebounder = pick_player(weights)

	var player = teams[team].players[
		players_on_court[team][rebounder]
	]

	if team == defense:
		player.record_stat("defensive_rebounds")
	else:
		player.record_stat("offensive_rebounds")
		
func rating_array(rating: String, t: int) -> Array:
	var arr := []

	for i in range(players_on_court[t].size()):
		var player_idx: int = players_on_court[t][i]
		var player = teams[t].players[player_idx]

		arr.append(player.composite_ratings[rating])

	return arr
		
func pick_player(weights: Array, exempt: int = -1) -> int:
	var total := 0.0

	# Calculate total weight
	for i in range(weights.size()):
		if i == exempt:
			continue
		total += max(weights[i], 0.0)

	if total <= 0.0:
		# Fall back to a random eligible player
		var choices := []
		for i in range(weights.size()):
			if i != exempt:
				choices.append(i)
		return choices[rng.randi_range(0, choices.size() - 1)]

	# Weighted random selection
	var r = rng.randf() * total
	var cumulative := 0.0

	for i in range(weights.size()):
		if i == exempt:
			continue

		cumulative += max(weights[i], 0.0)

		if r <= cumulative:
			return i

	# Should never happen, but just in case
	for i in range(weights.size()):
		if i != exempt:
			return i

	return 0
	
		
func update_players_on_court() -> void:

	for t in range(2):

		var team = teams[t]
		var court = players_on_court[t]

		# Calculate playing-time ratios

		var minutes_ratios := []

		for player in team.players:

			var target: float = float(
				player.target_minutes
			)

			var actual: float = float(
				player.stat.get("minutes", 0.0)
			)

			var ratio: float = actual / max(target, 0.01)

			minutes_ratios.append(ratio)

		# Look for substitutions
		for i in range(court.size()):

			var current_id: int = court[i]
			var current_player = team.players[current_id]

			# Don't substitute someone who just entered.
			if current_player.stat.get("court_time", 0.0) < 3.0:
				continue

			var current_ratio: float = minutes_ratios[current_id]

			# Find the best replacement.
			var best_bench_id := -1
			var best_score := INF

			for bench_id in range(team.players.size()):

				if bench_id in court:
					continue

				var bench_player = team.players[bench_id]

				var roster_position: int = int(
					bench_player.ratings.get(
						"roster_position",
						99
					)
				)

				# Players outside the 10-man rotation
				# don't play.
				if roster_position > 9:
					continue

				# Must have rested for a reasonable amount of time.
				if bench_player.stat.get(
					"bench_time",
					0.0
				) < 3.0:
					continue

				var bench_ratio: float = minutes_ratios[bench_id]

				# We primarily want to get the player
				# furthest behind their target minutes
				# onto the court.
				if bench_ratio >= current_ratio:
					continue

				# Lower ratio = greater need for minutes.
				var score: float = bench_ratio

				if score < best_score:
					best_score = score
					best_bench_id = bench_id

			# Make substitution
			if best_bench_id != -1:

				var bench_player = team.players[best_bench_id]

				court[i] = best_bench_id

				# Reset rotation timers.
				bench_player.stat["court_time"] = 0.0
				bench_player.stat["bench_time"] = 0.0

				current_player.stat["court_time"] = 0.0
				current_player.stat["bench_time"] = 0.0

		players_on_court[t] = court
		
func write_stats():
	# Mark starters
	for t in range(2):
		for i in players_on_court[t]:
			var player = teams[t].players[i]
			player.record_stat("starter")

	# Write team + player stats
	for t in range(2):
		write_team_stats(t)

		for player in teams[t].players:
			player.save_game_stats(
				db,
				game_id,
				season,
				playoffs,
				teams[t].id
			)
			
	Global.game_count += 1
			
func write_team_stats(team_index: int) -> void:
	var team = teams[team_index]
	var opponent_index = 1 - team_index
	var opponent = teams[opponent_index]

	var won: bool = team.stats["points"] > opponent.stats["points"]

	update_team_record(team_index, won)

	# Cash / attendance / salary cost
	var ticket_price := 50
	var revenue := attendance * ticket_price

	var cost := 0.0

	# Only charge player salaries during the regular season.
	if not playoffs:

		# Get current player payroll.
		db.query("""
			SELECT
				COALESCE(SUM(contract_amount), 0) AS payroll
			FROM player_attributes
			WHERE team_id = %d
		""" % team.id)

		var payroll := 0.0

		if not db.query_result.is_empty():
			payroll = float(
				db.query_result[0]["payroll"]
			)


		# Get salaries of released players that still
		# count against the team's finances.
		db.query("""
			SELECT
				COALESCE(TOTAL(contract_amount), 0) AS released_payroll
			FROM released_players_salaries
			WHERE team_id = %d
		""" % team.id)

		var released_payroll := 0.0

		if not db.query_result.is_empty():
			released_payroll = float(
				db.query_result[0]["released_payroll"]
			)


		# Convert annual payroll to a per-game cost.
		cost = (payroll + released_payroll) / 82.0


	# Add revenue and subtract salary cost
	db.query("""
		UPDATE team_attributes
		SET cash = cash + %f - %f
		WHERE team_id = %d
		AND season = %d
	""" % [
		revenue,
		cost,
		team.id,
		season
	])


	# Insert team game stats row
	var data = {
		"team_id": team.id,
		"opponent_team_id": opponent.id,
		"game_id": game_id,
		"season": season,
		"is_playoffs": int(playoffs),
		"won": int(won),

		"minutes": team.stats.get("minutes", 0),

		"field_goals_made": team.stats.get("field_goals_made", 0),
		"field_goals_attempted": team.stats.get("field_goals_attempted", 0),

		"three_pointers_made": team.stats.get("three_pointers_made", 0),
		"three_pointers_attempted": team.stats.get("three_pointers_attempted", 0),

		"free_throws_made": team.stats.get("free_throws_made", 0),
		"free_throws_attempted": team.stats.get("free_throws_attempted", 0),

		"offensive_rebounds": team.stats.get("offensive_rebounds", 0),
		"defensive_rebounds": team.stats.get("defensive_rebounds", 0),

		"assists": team.stats.get("assists", 0),
		"turnovers": team.stats.get("turnovers", 0),
		"steals": team.stats.get("steals", 0),
		"blocks": team.stats.get("blocks", 0),

		"personal_fouls": team.stats.get("personal_fouls", 0),
		"points": team.stats.get("points", 0),

		"opponent_points": opponent.stats.get("points", 0),
		"attendance": attendance,

		# Store the salary cost for this game.
		"cost": cost
	}

	db.insert_row("team_stats", data)

func load_game_attributes() -> void:
	# Default values
	attendance = 18000
	same_conference = false
	same_division = false

	# Load division IDs
	var home = db.select_rows(
		"team_attributes",
		"team_id = %d" % teams[0].id,
		["division_id", "won", "lost"]
	)

	var away = db.select_rows(
		"team_attributes",
		"team_id = %d" % teams[1].id,
		["division_id", "won", "lost"]
	)

	if home.is_empty() or away.is_empty():
		return

	var home_div = home[0]["division_id"]
	var away_div = away[0]["division_id"]

	# Determine conference from division
	# 0-2 = Eastern Conference
	# 3-5 = Western Conference
	var home_conf = int(home_div / 3)
	var away_conf = int(away_div / 3)

	same_division = home_div == away_div
	same_conference = home_conf == away_conf

	# Attendance calculation
	var games_played = home[0]["won"] + home[0]["lost"]

	if games_played < 5:
		attendance = roundi(Global.gaussian(22000 + games_played * 1000, 1000))
	else:
		var win_pct = 0.5

		if games_played > 0:
			win_pct = float(home[0]["won"]) / games_played

		attendance = roundi(Global.gaussian(win_pct * 36000, 1000))

	attendance = clamp(attendance, 10000, 25000)

func update_team_record(team_index: int, won_game: bool) -> void:
	if playoffs:
		return
	var team = teams[team_index]

	# base win/loss
	if won_game:
		db.query(
			"UPDATE team_attributes
			SET won = won + 1
			WHERE team_id = %d AND season = %d"
			% [team.id, season]
		)
	else:
		db.query(
			"UPDATE team_attributes
			SET lost = lost + 1
			WHERE team_id = %d AND season = %d"
			% [team.id, season]
		)

	# division record
	if same_division:
		if won_game:
			db.query(
				"UPDATE team_attributes
				SET won_div = won_div + 1
				WHERE team_id = %d AND season = %d"
				% [team.id, season]
			)
		else:
			db.query(
				"UPDATE team_attributes
				SET lost_div = lost_div + 1
				WHERE team_id = %d AND season = %d"
				% [team.id, season]
			)

	# conference record
	if same_conference:
		if won_game:
			db.query(
				"UPDATE team_attributes
				SET won_conf = won_conf + 1
				WHERE team_id = %d AND season = %d"
				% [team.id, season]
			)
		else:
			db.query(
				"UPDATE team_attributes
				SET lost_conf = lost_conf + 1
				WHERE team_id = %d AND season = %d"
				% [team.id, season]
			)

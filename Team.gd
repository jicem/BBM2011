class_name Team
extends RefCounted

var db : SQLite
var id : int

var name := ""
var region := ""

var players: Array = []

var stats := {}

var pace := 100.0
var defense := 0.0

var division_id: int
var conference_id: int

var rng := RandomNumberGenerator.new()

func _init(database: SQLite, team_id: int) -> void:

	db = database
	id = team_id

	initialize_stats()
	load_players()
	load_attributes()
	calculate_rotation_minutes()
	
func initialize_stats() -> void:
	stats = {
		"minutes": 0,
		"field_goals_made": 0,
		"field_goals_attempted": 0,
		"three_pointers_made": 0,
		"three_pointers_attempted": 0,
		"free_throws_made": 0,
		"free_throws_attempted": 0,
		"offensive_rebounds": 0,
		"defensive_rebounds": 0,
		"assists": 0,
		"turnovers": 0,
		"steals": 0,
		"blocks": 0,
		"personal_fouls": 0,
		"points": 0
	}
	
func load_players():

	players.clear()

	db.query("""
		SELECT pa.player_id
		FROM player_attributes pa
		INNER JOIN player_ratings pr
			ON pa.player_id = pr.player_id
		WHERE pa.team_id = %d
		ORDER BY pr.roster_position ASC
	""" % id)

	for row in db.query_result:
		players.append(
			SimPlayer.new(db, row["player_id"], stats)
		)
		
func load_attributes() -> void:
	var rows = db.select_rows(
		"team_attributes",
		"team_id = %d" % id,
		["region", "name", "division_id"]
	)

	division_id = rows[0]["division_id"]
	conference_id = int(division_id / 3)

	if rows.is_empty():
		return

	region = rows[0]["region"]
	name = rows[0]["name"]

	# compute pace + defense from top players

	var n: int= min(players.size(), 7)

	var pace_sum := 0.0
	var defense_sum := 0.0

	for i in range(n):
		pace_sum += players[i].composite_ratings["pace"]
		defense_sum += players[i].composite_ratings["defense"]

	pace = pace_sum / max(n, 1)
	defense = (defense_sum / max(n, 1)) / 4.0
	
func calculate_rotation_minutes() -> void:

	var rotation_players: Array = []
	var total_weight := 0.0

	for player in players:

		var roster_position = int(
			player.ratings.get("roster_position", 99)
		)

		if roster_position >= 0 and roster_position <= 9:
			rotation_players.append(player)
		else:
			player.target_minutes = 0.0

	if rotation_players.is_empty():
		return

	for player in rotation_players:

		var roster_position = int(
			player.ratings.get("roster_position", 9)
		)

		var overall = float(
			player.ratings.get("overall", 70)
		)

		# Position 0 = 10
		# Position 9 = 1
		var position_weight = pow(
			10.0 - float(roster_position),
			1.5
		)

		# Overall makes a difference, but not too much.
		var overall_factor = lerp(
			0.85,
			1.15,
			clamp((overall - 60.0) / 40.0, 0.0, 1.0)
		)

		var weight = position_weight * overall_factor

		player.target_minutes = weight
		total_weight += weight

	for player in rotation_players:

		player.target_minutes = (
			player.target_minutes
			/ total_weight
			* 240.0
		)
	
func update_rotation(on_court: Array, dt: float) -> void:

	for i in range(players.size()):

		var player = players[i]

		if i in on_court:

			# Player is on the court.
			player.stat["minutes"] += dt
			player.stat["court_time"] += dt

			# Fatigue.
			player.stat["energy"] -= dt * 0.01

		else:

			# Player is on the bench.
			player.stat["bench_time"] += dt

			# Recovery.
			player.stat["energy"] += dt * 0.015

		player.stat["energy"] = clamp(
			player.stat["energy"],
			0.0,
			1.0
		)

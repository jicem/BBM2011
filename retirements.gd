extends Control

@onready var retired_players: Tree = $Tree

var db: SQLite
var rng := RandomNumberGenerator.new()

var season: int
var min_potential := 40
var max_age := 39

var retired_root: TreeItem


func _ready():

	rng.randomize()

	season = Global.season + 2011

	setup_db()
	setup_tree()

	process_retirements()

func setup_db():

	db = SQLite.new()
	db.path = "res://data/bball.db"
	db.open_db()
	
func setup_tree():

	retired_players.columns = 4
	retired_players.set_column_custom_minimum_width(0, 200)
	retired_players.set_column_title(0, "Name")
	retired_players.set_column_title(1, "Team")
	retired_players.set_column_title(2, "Age")
	retired_players.set_column_title(3, "Overall")

	retired_root = retired_players.create_item()
	
func process_retirements():

	retired_players.clear()
	retired_root = retired_players.create_item()

	process_old_and_low_potential_players()
	process_long_term_free_agents()

	update_free_agent_years()
	
func process_old_and_low_potential_players():

	db.query("""
		SELECT
			pa.player_id,
			pa.name,
			(
				SELECT abbreviation
				FROM team_attributes
				WHERE team_id = pa.team_id
				AND season = %d
			) AS abbreviation,
			%d - pa.born_date AS age,
			pr.overall,
			pr.potential,
			pa.team_id
		FROM player_attributes pa
		INNER JOIN player_ratings pr
			ON pa.player_id = pr.player_id
		WHERE
			(
				pr.potential < %d
				OR (%d - pa.born_date) > %d
			)
			AND pa.team_id != -3
		ORDER BY pr.overall DESC
	""" % [
		season,
		season,
		min_potential,
		season,
		max_age
	])

	var players = db.query_result

	for row in players:

		var player_id = int(row["player_id"])
		var player_name = str(row["name"])
		var team_id = int(row["team_id"])

		var team = row["abbreviation"]

		if team == null:
			team = "FA"
		else:
			team = str(team)

		var age = int(row["age"])
		var overall = int(row["overall"])
		var potential = int(row["potential"])

		# Only players older than 39 or free agents
		# are eligible to retire.
		if age > max_age or team_id == -1:

			var age_excess := 0.0

			if age > max_age:
				age_excess = float(age - max_age) / 20.0

			# Lower potential increases retirement chance.
			var potential_excess := float(min_potential - potential) / 50.0

			var retirement_score := (
				age_excess
				+ potential_excess
				+ rng.randfn(0.0, 1.0)
			)

			if retirement_score > 0.0:

				retire_player(player_id)

				add_retired_player(
					player_id,
					player_name,
					team,
					age,
					overall
				)
				
func retire_player(player_id: int):

	db.query("""
		UPDATE player_attributes
		SET team_id = -3
		WHERE player_id = %d
	""" % player_id)
	
func add_retired_player(
	player_id: int,
	player_name: String,
	team: String,
	age: int,
	overall: int
):

	var item = retired_players.create_item(retired_root)

	item.set_text(0, player_name)
	item.set_text(1, team)
	item.set_text(2, str(age))
	item.set_text(3, str(overall))

	item.set_metadata(0, player_id)
	
func process_long_term_free_agents():

	db.query("""
		SELECT
			pa.player_id,
			pa.name,
			%d - pa.born_date AS age,
			pr.overall,
			pr.potential
		FROM player_attributes pa
		INNER JOIN player_ratings pr
			ON pa.player_id = pr.player_id
		WHERE
			pa.years_free_agent >= 1
			AND pa.team_id = -1
		ORDER BY pr.overall DESC
	""" % season)

	var players = db.query_result

	for row in players:

		var player_id = int(row["player_id"])
		var player_name = str(row["name"])
		var age = int(row["age"])
		var overall = int(row["overall"])

		retire_player(player_id)

		add_retired_player(
			player_id,
			player_name,
			"FA",
			age,
			overall
		)
		
func update_free_agent_years():

	# Increase the counter for current free agents.
	db.query("""
		UPDATE player_attributes
		SET years_free_agent = years_free_agent + 1
		WHERE team_id = -1
	""")

	# Reset the counter for players who are on a team.
	db.query("""
		UPDATE player_attributes
		SET years_free_agent = 0
		WHERE team_id >= 0
	""")

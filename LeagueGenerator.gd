class_name LeagueGenerator

static func execute_sql_file(db: SQLite, path: String) -> bool:
	var file := FileAccess.open(path, FileAccess.READ)

	if file == null:
		push_error("Unable to open SQL file: " + path)
		return false

	var sql := file.get_as_text()
	file.close()

	return db.query(sql)
	
static func delete_tables(db):
	var tables = [
		"player_stats",
		"player_ratings",
		"player_attributes",
		"released_players_salaries",
		"draft_results",
		"team_stats",
		"team_attributes",
		"active_playoff_series"
	]
	
	for table in tables:
		db.query("DROP TABLE IF EXISTS " + table)
	
static func create_tables(db: SQLite) -> void:
	if !execute_sql_file(db, "res://data/tables.sql"):
		push_error("Error creating tables.")
		
static func create_teams(db: SQLite) -> void:
	if !execute_sql_file(db, "res://data/teams.sql"):
		push_error("Error inserting teams.")
		
static func create_players(db: SQLite) -> void:
	var id := 0

	for team_id in range(30):
		for roster in range(15):

			var player = Player.new()

			var age = randi_range(20, 40)
			var base_rating = randi_range(15, 60)
			var potential = randi_range(30, 79)
			var draft_year = 2011 - randi_range(0, 5)

			player.generate(
				id,
				team_id,
				age,
				random_profile(),
				base_rating,
				potential,
				draft_year,
				2011
			)

			player.save(db)

			id += 1

	create_draft_class(db, id)
	
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
			2012,                   # Upcoming draft class
			2011                    # Current season
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

static func generate(db: SQLite):
	delete_tables(db)

	create_tables(db)

	create_teams(db)

	# Player tables will only be regenerated for new rosters
	if(Global.nba_players):
		db.query("INSERT INTO player_ratings
					SELECT *
					FROM nba_player_ratings")
					
		db.query("INSERT INTO player_attributes
					SELECT *
					FROM nba_player_attributes")

	else:
		create_players(db)

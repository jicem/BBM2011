extends Control

@onready var name_label = %PlayerName
@onready var team_label = %PosAndTeam
@onready var change_button = %ChangeTable

@onready var height_label = %Height
@onready var weight_label = %Weight
@onready var age_label = %Age
@onready var born_label = %Born
@onready var college_label = %College
@onready var draft_label = %Draft
@onready var contract_label = %Contract

@onready var overall_label = %Overall
@onready var potential_label = %Potential

@onready var physical_height_label = %Hgt
@onready var strength_label = %Str
@onready var speed_label = %Spd
@onready var jumping_label = %Jmp
@onready var endurance_label = %End

@onready var inside_label = %Ins
@onready var dunks_label = %Dnk
@onready var free_throws_label = %FT
@onready var two_pointers_label = %Twos
@onready var three_pointers_label = %Threes

@onready var blocks_label = %Blks
@onready var steals_label = %Stls
@onready var dribbling_label = %Drb
@onready var passing_label = %Pass
@onready var rebounding_label = %Reb

@onready var tree = $Tree

var db: SQLite
var player_id
var season := 2011 + Global.season
var showing_game_log := false

var roster_players: Array = []
var current_player_index: int = 0

func _ready():
	setup_db()
	
func _process(delta):
	player_id = Global.current_player
	if Global.setup_player_trees:
		
		showing_game_log = false
		change_button.text = "Change to Game Log"

		setup_stats_tree()
		load_roster()
		load_player_info()
		load_player_stats()

		Global.setup_player_trees = false
	
func setup_db():

	db = SQLite.new()
	db.path = "res://data/bball.db"
	db.open_db()


func setup_stats_tree():

	tree.columns = 23

	var headers = [
		"Year",
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

	for i in range(headers.size()):
		tree.set_column_title(i, headers[i])

	tree.create_item()
	
func setup_game_log_tree():

	tree.clear()
	tree.columns = 21

	var headers = [
		"Team",
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

	for i in range(headers.size()):
		tree.set_column_title(i, headers[i])

	tree.create_item()
	
func load_player_game_log():

	tree.clear()

	var root = tree.create_item()

	db.query("""
		SELECT
			ps.game_id,

			(
				SELECT abbreviation
				FROM team_attributes
				WHERE team_id = ps.team_id
				AND season = ps.season
				LIMIT 1
			) AS abbreviation,

			ps.starter,
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
			ps.personal_fouls,
			ps.points

		FROM player_stats ps

		WHERE ps.player_id = %d
		AND ps.season = %d

		ORDER BY ps.game_id ASC
	""" % [
		player_id,
		season
	])

	for row in db.query_result:

		var item = tree.create_item(root)

		var fgm = int(row["field_goals_made"])
		var fga = int(row["field_goals_attempted"])

		var three_pm = int(row["three_pointers_made"])
		var three_pa = int(row["three_pointers_attempted"])

		var ftm = int(row["free_throws_made"])
		var fta = int(row["free_throws_attempted"])

		var oreb = int(row["offensive_rebounds"])
		var dreb = int(row["defensive_rebounds"])

		var reb = oreb + dreb

		var fg_pct := 0.0
		var three_pct := 0.0
		var ft_pct := 0.0

		if fga > 0:
			fg_pct = 100.0 * float(fgm) / float(fga)

		if three_pa > 0:
			three_pct = 100.0 * float(three_pm) / float(three_pa)

		if fta > 0:
			ft_pct = 100.0 * float(ftm) / float(fta)

		# Team
		item.set_text(
			0,
			str(row["abbreviation"])
			if row["abbreviation"] != null
			else "FA"
		)

		# Starter
		item.set_text(
			1,
			"Yes" if int(row["starter"]) == 1 else "No"
		)

		# Minutes
		item.set_text(
			2,
			"%.1f" % float(row["minutes"])
		)

		# Field goals
		item.set_text(3, str(fgm))
		item.set_text(4, str(fga))
		item.set_text(5, "%.1f" % fg_pct)

		# Three pointers
		item.set_text(6, str(three_pm))
		item.set_text(7, str(three_pa))
		item.set_text(8, "%.1f" % three_pct)

		# Free throws
		item.set_text(9, str(ftm))
		item.set_text(10, str(fta))
		item.set_text(11, "%.1f" % ft_pct)

		# Rebounds
		item.set_text(12, str(oreb))
		item.set_text(13, str(dreb))
		item.set_text(14, str(reb))

		# Other stats
		item.set_text(15, str(row["assists"]))
		item.set_text(16, str(row["turnovers"]))
		item.set_text(17, str(row["steals"]))
		item.set_text(18, str(row["blocks"]))
		item.set_text(19, str(row["personal_fouls"]))
		item.set_text(20, str(row["points"]))
	
func load_player_info():

	db.query("""
		SELECT
			pa.name,
			pa.team_id,
			pa.position,
			pa.height,
			pa.weight,
			pa.born_date,
			pa.born_location,
			pa.college,
			pa.draft_year,
			pa.draft_round,
			pa.draft_pick,
			pa.draft_team_id,
			pa.contract_amount,
			pa.contract_expiration,
			ta.abbreviation,
			pr.overall,
			pr.height AS rating_height,
			pr.strength,
			pr.speed,
			pr.jumping,
			pr.endurance,
			pr.shooting_inside,
			pr.shooting_layups,
			pr.shooting_free_throws,
			pr.shooting_two_pointers,
			pr.shooting_three_pointers,
			pr.blocks,
			pr.steals,
			pr.dribbling,
			pr.passing,
			pr.rebounding,
			pr.potential

		FROM player_attributes pa
		LEFT JOIN team_attributes ta
			ON ta.team_id = pa.team_id
			AND ta.season = %d
		INNER JOIN player_ratings pr
			ON pa.player_id = pr.player_id

		WHERE pa.player_id = %d
	""" % [season, player_id])

	if db.query_result.is_empty():
		push_error("PlayerInfo: Player ID %d was not found." % player_id)
		return

	var player = db.query_result[0]
	
	# Basic information
	
	name_label.text = "[b]" + str(player["name"]) + "[/b]"

	var team_name = "Free Agent"

	if player["abbreviation"] != null:
		team_name = str(player["abbreviation"])

	team_label.text = "[b]%s - %s[/b]" % [
		str(player["position"]),
		team_name
	]

	age_label.text = "Age: %d" % (
		season - int(player["born_date"])
	)

	born_label.text = "Born: %d - %s" % [
		int(player["born_date"]),
		str(player["born_location"])
	]

	height_label.text = "Height: %s" % format_height(int(player["height"]))

	weight_label.text = "Weight: %s lbs" % str(player["weight"])

	college_label.text = "College: %s" % str(player["college"])
	
	# Draft information

	var draft_year = int(player["draft_year"])
	var draft_round = int(player["draft_round"])
	var draft_pick = int(player["draft_pick"])

	if draft_year > 0:
		var draft_team = "FA"

		if player["draft_team_id"] != null:
			db.query("""
				SELECT abbreviation
				FROM team_attributes
				WHERE team_id = %d
				AND season = %d
			""" % [
				int(player["draft_team_id"]),
				draft_year
			])

			if !db.query_result.is_empty():
				draft_team = str(db.query_result[0]["abbreviation"])

		draft_label.text = "Draft: %d - Round %d (Pick %d) by %s" % [
			draft_year,
			draft_round,
			draft_pick,
			draft_team
		]
	else:
		draft_label.text = "Draft: Undrafted"
		
	# Contract

	var contract_amount = float(player["contract_amount"])
	var contract_expiration = int(player["contract_expiration"])

	if contract_amount > 0:
		contract_label.text = "Contract: $%.1fM per year through %d" % [
			contract_amount / 1000000.0,
			contract_expiration
		]
	else:
		contract_label.text = "Contract: Free Agent"
		
	# Overall / potential

	overall_label.text = "[b]Overall Rating: %d[/b]" % int(player["overall"])
	potential_label.text = "Potential: %d" % int(player["potential"])


	# Physical

	physical_height_label.text = "Height: %s" % str(player["rating_height"])
	strength_label.text = "Strength: %d" % int(player["strength"])
	speed_label.text = "Speed: %d" % int(player["speed"])
	jumping_label.text = "Jumping: %d" % int(player["jumping"])
	endurance_label.text = "Endurance: %d" % int(player["endurance"])


	# Shooting

	inside_label.text = "Inside: %d" % int(player["shooting_inside"])
	dunks_label.text = "Dunks/Layups: %d" % int(player["shooting_layups"])
	free_throws_label.text = "Free Throws: %d" % int(player["shooting_free_throws"])
	two_pointers_label.text = "Two Pointers: %d" % int(player["shooting_two_pointers"])
	three_pointers_label.text = "Three Pointers: %d" % int(player["shooting_three_pointers"])


	# Skills

	blocks_label.text = "Blocks: %d" % int(player["blocks"])
	steals_label.text = "Steals: %d" % int(player["steals"])
	dribbling_label.text = "Dribbling: %d" % int(player["dribbling"])
	passing_label.text = "Passing: %d" % int(player["passing"])
	rebounding_label.text = "Rebounding: %d" % int(player["rebounding"])
	
func format_height(inches: int) -> String:

	var feet = inches / 12
	var remaining_inches = inches % 12

	return "%d'%d\"" % [
		feet,
		remaining_inches
	]
	
func load_player_stats():

	tree.clear()

	var root = tree.create_item()

	db.query("""
		SELECT
			ps.season,
			ta.abbreviation,

			-- Games played
			SUM(ps.minutes > 0) AS games,

			-- Games started
			SUM(ps.starter) AS games_started,

			-- Per-game averages
			AVG(ps.minutes) AS minutes,

			AVG(ps.field_goals_made) AS field_goals,
			AVG(ps.field_goals_attempted) AS field_goal_attempts,

			AVG(
				CASE
					WHEN ps.field_goals_attempted > 0
					THEN 100.0 * ps.field_goals_made / ps.field_goals_attempted
					ELSE 0
				END
			) AS fg_pct,

			AVG(ps.three_pointers_made) AS three_pointers,
			AVG(ps.three_pointers_attempted) AS three_point_attempts,

			AVG(
				CASE
					WHEN ps.three_pointers_attempted > 0
					THEN 100.0 * ps.three_pointers_made / ps.three_pointers_attempted
					ELSE 0
				END
			) AS three_pct,

			AVG(ps.free_throws_made) AS free_throws,
			AVG(ps.free_throws_attempted) AS free_throw_attempts,

			AVG(
				CASE
					WHEN ps.free_throws_attempted > 0
					THEN 100.0 * ps.free_throws_made / ps.free_throws_attempted
					ELSE 0
				END
			) AS ft_pct,

			AVG(ps.offensive_rebounds) AS offensive_rebounds,
			AVG(ps.defensive_rebounds) AS defensive_rebounds,

			AVG(
				ps.offensive_rebounds + ps.defensive_rebounds
			) AS rebounds,

			AVG(ps.assists) AS assists,
			AVG(ps.turnovers) AS turnovers,
			AVG(ps.steals) AS steals,
			AVG(ps.blocks) AS blocks,
			AVG(ps.personal_fouls) AS personal_fouls,
			AVG(ps.points) AS points

		FROM player_stats ps

		LEFT JOIN team_attributes ta
			ON ta.team_id = ps.team_id
			AND ta.season = ps.season

		WHERE ps.player_id = %d
		AND ps.is_playoffs = 0

		GROUP BY
			ps.season,
			ps.team_id,
			ta.abbreviation

		ORDER BY
			ps.season DESC
	""" % player_id)

	for row in db.query_result:

		var item = tree.create_item(root)

		item.set_text(0, str(row["season"]))

		if row["abbreviation"] != null:
			item.set_text(1, str(row["abbreviation"]))
		else:
			item.set_text(1, "FA")

		item.set_text(2, str(int(row["games"])))
		item.set_text(3, str(int(row["games_started"])))

		item.set_text(
			4,
			"%.1f" % float(row["minutes"])
		)

		item.set_text(
			5,
			"%.1f" % float(row["field_goals"])
		)

		item.set_text(
			6,
			"%.1f" % float(row["field_goal_attempts"])
		)

		item.set_text(
			7,
			"%.1f" % float(row["fg_pct"])
		)

		item.set_text(
			8,
			"%.1f" % float(row["three_pointers"])
		)

		item.set_text(
			9,
			"%.1f" % float(row["three_point_attempts"])
		)

		item.set_text(
			10,
			"%.1f" % float(row["three_pct"])
		)

		item.set_text(
			11,
			"%.1f" % float(row["free_throws"])
		)

		item.set_text(
			12,
			"%.1f" % float(row["free_throw_attempts"])
		)

		item.set_text(
			13,
			"%.1f" % float(row["ft_pct"])
		)

		item.set_text(
			14,
			"%.1f" % float(row["offensive_rebounds"])
		)

		item.set_text(
			15,
			"%.1f" % float(row["defensive_rebounds"])
		)

		item.set_text(
			16,
			"%.1f" % float(row["rebounds"])
		)

		item.set_text(
			17,
			"%.1f" % float(row["assists"])
		)

		item.set_text(
			18,
			"%.1f" % float(row["turnovers"])
		)

		item.set_text(
			19,
			"%.1f" % float(row["steals"])
		)

		item.set_text(
			20,
			"%.1f" % float(row["blocks"])
		)

		item.set_text(
			21,
			"%.1f" % float(row["personal_fouls"])
		)

		item.set_text(
			22,
			"%.1f" % float(row["points"])
		)


func _on_change_table_pressed():

	showing_game_log = !showing_game_log

	if showing_game_log:

		change_button.text = "Change to Stats"

		setup_game_log_tree()
		load_player_game_log()

	else:

		change_button.text = "Change to Game Log"

		setup_stats_tree()
		load_player_stats()

func load_roster() -> void:
	roster_players.clear()

	# Get the current player's team.
	var player_rows = db.select_rows(
		"player_attributes",
		"player_id = %d" % player_id,
		["team_id"]
	)

	if player_rows.is_empty():
		return

	var player_team_id: int = int(player_rows[0]["team_id"])

	# Get all players on that player's team.
	var rows = db.select_rows(
		"player_attributes",
		"team_id = %d" % player_team_id,
		["player_id", "name"]
	)

	for row in rows:
		print(row["name"])
		roster_players.append(row["player_id"])

	current_player_index = 0
	

func _on_button_1_pressed() -> void:
	
	if roster_players.is_empty():
		return

	if current_player_index > 0:
		current_player_index -= 1
		
	player_id = roster_players[current_player_index]
	
	load_player_info()
	
	load_player_stats()

func _on_button_2_pressed() -> void:

	if roster_players.is_empty():
		return

	if current_player_index < roster_players.size():
		current_player_index += 1
		
	player_id = roster_players[current_player_index]
	
	load_player_info()
	
	load_player_stats()

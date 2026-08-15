class_name SimPlayer
extends RefCounted

var db : SQLite
var id : int

var ratings := {}
var attribute := {}

var target_minutes := 0.0
var composite_ratings := {}

var stat := {}
var team_stat_ref := {}

func _init(database: SQLite, player_id: int, team_stats_ref: Dictionary) -> void:
	db = database
	id = player_id
	team_stat_ref = team_stats_ref

	load_ratings()
	make_composite_ratings()
	initialize_stats()
	
func load_ratings() -> void:

	var rows = db.select_rows(
		"player_ratings",
		"player_id = %d" % id,
		["*"]
	)

	if rows.is_empty():
		return

	ratings = rows[0]

	var attr = db.select_rows(
		"player_attributes",
		"player_id = %d" % id,
		["name", "position"]
	)

	if !attr.is_empty():
		attribute = attr[0]
		
func make_composite_ratings() -> void:
	composite_ratings = {}

	composite_ratings["pace"] = _composite(90, 140,
		["speed", "jumping", "dribbling", "passing", "steals", "endurance"]
	)

	composite_ratings["shot_ratio"] = _composite(0, 0.5,
		["shooting_inside", "shooting_layups", "shooting_two_pointers", "shooting_three_pointers"]
	)

	composite_ratings["assist_ratio"] = _composite(0, 0.5,
		["dribbling", "passing", "speed"]
	)

	composite_ratings["turnover_ratio"] = _composite(0, 0.5,
		["dribbling", "passing", "speed"],
		true
	)

	composite_ratings["field_goal_percentage"] = _composite(0.38, 0.68,
		["height", "jumping", "shooting_inside", "shooting_layups",
		"shooting_two_pointers", "shooting_three_pointers"]
	)

	composite_ratings["three_pointer_percentage"] = _composite(0.0, 0.45,
		["shooting_three_pointers"]
	)

	composite_ratings["free_throw_percentage"] = _composite(0.65, 0.90,
		["shooting_free_throws"]
	)

	composite_ratings["rebound_ratio"] = _composite(0, 0.5,
		["height", "strength", "jumping", "rebounding"]
	)

	composite_ratings["steal_ratio"] = _composite(0, 0.5,
		["speed", "steals"]
	)

	composite_ratings["block_ratio"] = _composite(0, 0.5,
		["height", "jumping", "blocks"]
	)

	composite_ratings["foul_ratio"] = _composite(0, 0.5,
		["speed"],
		true
	)

	composite_ratings["defense"] = _composite(0, 0.5,
		["strength", "speed"]
	)
	
func _composite(min_val: float, max_val: float, components: Array, inverse := false) -> float:
	var r := 0.0

	for c in components:
		var val = float(ratings.get(c, 70))

		var y = (val - 70.0) / 10.0
		var rcomp = y / sqrt(1.0 + pow(y, 2))
		rcomp = (rcomp + 1.0) * 50.0

		if inverse:
			rcomp = 100.0 - rcomp

		r += rcomp

	r /= float(components.size())

	var scaled = min_val + (r / 100.0) * (max_val - min_val)

	return scaled * randf_range(0.9, 1.1)
	
func initialize_stats() -> void:
	stat = {
		"starter": 0,
		"minutes": 0,
		"court_time": 0,
		"bench_time": 0,
		"energy": 1.0,

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
	
func record_stat(key: String, value := 1) -> void:
	stat[key] += value

	# don't double-count these into team totals
	if key in ["starter", "court_time", "bench_time", "energy"]:
		return

	if team_stat_ref.has(key):
		team_stat_ref[key] += value
		
func save_game_stats(db: SQLite, game_id: int, season: int, playoffs: bool, team_id: int) -> void:
	var data = {
		"player_id": id,
		"team_id": team_id,
		"game_id": game_id,
		"season": season,
		"is_playoffs": int(playoffs),

		"starter": stat.get("starter", 0),
		"minutes": stat.get("minutes", 0),

		"field_goals_made": stat.get("field_goals_made", 0),
		"field_goals_attempted": stat.get("field_goals_attempted", 0),

		"three_pointers_made": stat.get("three_pointers_made", 0),
		"three_pointers_attempted": stat.get("three_pointers_attempted", 0),

		"free_throws_made": stat.get("free_throws_made", 0),
		"free_throws_attempted": stat.get("free_throws_attempted", 0),

		"offensive_rebounds": stat.get("offensive_rebounds", 0),
		"defensive_rebounds": stat.get("defensive_rebounds", 0),

		"assists": stat.get("assists", 0),
		"turnovers": stat.get("turnovers", 0),
		"steals": stat.get("steals", 0),
		"blocks": stat.get("blocks", 0),

		"personal_fouls": stat.get("personal_fouls", 0),
		"points": stat.get("points", 0)
	}

	db.insert_row("player_stats", data)

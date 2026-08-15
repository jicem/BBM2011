class_name Player
extends RefCounted

var id : int

var attributes := {}
var ratings := {}

var rng := RandomNumberGenerator.new()

var first_names = []
var last_names = []
var nationalities = []

var names_loaded = false

var first_name_max := {}
var last_name_max := {}

const PROFILES = {

	"Point":[
		-30,-10,40,20,5,
		0,5,15,20,10,
		-10,20,40,45,-10
	],

	"ShootingGuard":[
		-15,0,30,20,5,
		5,15,15,25,35,
		-10,10,20,10,0
	],

	"SmallForward":[
		5,15,20,15,5,
		15,15,10,20,20,
		10,10,10,0,15
	],

	"PowerForward":[
		30,30,0,5,10,
		25,20,0,10,-10,
		25,0,-5,-10,35
	],

	"Center":[
		45,40,-15,-10,15,
		35,30,-5,-10,-25,
		40,0,-15,-15,45
	]
}

func _init():

	rng.randomize()

	load_name_files()
	
func load_name_files():

	if names_loaded:
		return

	load_csv("res://data/first_names.txt", first_names)
	load_csv("res://data/last_names.txt", last_names)
	load_csv("res://data/nationalities.txt", nationalities)
	
	build_max_probabilities()

	names_loaded = true
	
func load_csv(path: String, destination: Array):

	destination.clear()

	var file := FileAccess.open(path, FileAccess.READ)

	if file == null:
		push_error("Couldn't open " + path)
		return

	while !file.eof_reached():
		var row = file.get_csv_line()
		if row.size() < 5:
			continue
		destination.append(row)

	file.close()
	
func build_max_probabilities():
	first_name_max.clear()
	last_name_max.clear()

	for row in first_names:
		var country = row[4]
		var val = float(row[2])
		first_name_max[country] = max(first_name_max.get(country, 0.0), val)

	for row in last_names:
		var country = row[4]
		var val = float(row[2])
		last_name_max[country] = max(last_name_max.get(country, 0.0), val)
		
func pick_from_cumulative(rows: Array, country: String, max_map: Dictionary) -> String:
	var max_prob = max_map.get(country, 1.0)

	var r = rng.randf_range(0.0, max_prob)

	for row in rows:
		if row.size() < 5:
			continue

		if row[4] != country:
			continue

		if float(row[2]) >= r:
			return row[0].capitalize()

	return "Unknown"
		
func random_first_name(country:String) -> String:
	return pick_from_cumulative(first_names, country, first_name_max)

func random_last_name(country:String) -> String:
	return pick_from_cumulative(last_names, country, last_name_max)
	
func random_name(country:String) -> String:

	return "%s %s" % [
		random_first_name(country),
		random_last_name(country)
	]
	
func generate(player_id, team_id, age, profile, base_rating, potential, draft_year, season):
	id = player_id
	generate_ratings(profile, base_rating, potential)
	generate_attributes(team_id, age, draft_year, season)
	ratings["overall"] = calculate_overall()
	if age > 28:
		ratings["potential"] = ratings["overall"]
	elif ratings["overall"] > potential:
		ratings["potential"] = ratings["overall"] + rng.randi_range(1, 5)
	attributes["position"] = determine_position(profile)
	first_contract(team_id, season)

func generate_ratings(profile:String,
		base_rating:int,
		potential:int):

		ratings.clear()
		ratings["potential"] = potential
		ratings["roster_position"] = 0

		var values = PROFILES[profile].duplicate()

		var keys = [
			"height",
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

		var adjusted_base = Global.gaussian(base_rating, 5)

		for i in values.size():
			var value = adjusted_base + values[i]
			value = Global.gaussian(value, 10)
			ratings[keys[i]] = clampi(roundi(value), 0, 100)

		ratings["overall"] = calculate_overall()
	
	
func first_contract(team_id: int, season: int) -> void:

	attributes["team_id"] = team_id

	# Contract expires 0–3 seasons from the current season.
	# 0 = expires at the end of the current season
	# 1 = expires at the end of next season
	# 2 = expires in two seasons
	# 3 = expires in three seasons
	var years := rng.randi_range(0, 3)

	var salary = calculate_contract_value()

	attributes["contract_amount"] = salary
	attributes["contract_expiration"] = season + years

	
func generate_attributes(
		team_id:int,
		age:int,
		draft_year:int,
		season:int,
		nationality:String = ""):

	attributes.clear()

	attributes["team_id"] = team_id

	attributes["born_date"] = season - age

	attributes["draft_year"] = draft_year
	attributes["draft_round"] = 0
	attributes["draft_pick"] = 0
	attributes["draft_team_id"] = 0

	# Physical measurements
	attributes["height"] = generate_height()
	attributes["weight"] = generate_weight()

	# Name and birthplace
	if nationality == "":
		nationality = random_nationality()

	attributes["born_location"] = nationality
	attributes["name"] = random_name(nationality)

	# Optional
	attributes["college"] = "None"
	
func generate_height() -> int:

	const MIN_HEIGHT = 71
	const MAX_HEIGHT = 89

	var mean = 78.5
	var std_dev = 3.0

	var inches = Global.gaussian(mean, std_dev)

	# Taller players still benefit from high height ratings
	inches += (ratings["height"] - 50) * 0.08

	return clampi(roundi(inches), MIN_HEIGHT, MAX_HEIGHT)
	
func generate_weight() -> int:

	const MIN_WEIGHT = 150
	const MAX_WEIGHT = 290

	var build = ratings["height"] + ratings["strength"] * 0.5

	var pounds = MIN_WEIGHT + (MAX_WEIGHT - MIN_WEIGHT) * build / 150.0

	pounds *= Global.gaussian(1.0,0.02)

	return roundi(pounds)
	
func random_nationality() -> String:

	var max_probability = float(nationalities.back()[2])

	var r = rng.randf_range(0,max_probability)

	for row in nationalities:

		if float(row[2]) >= r:
			return row[0]

	return "USA"
	
func determine_position(profile:String) -> String:

	var r = rng.randf()

	match profile:

		"Point":
			return "SG" if r < 0.15 else "PG"

		"ShootingGuard":
			if r < 0.10:
				return "PG"
			elif r < 0.85:
				return "SG"
			return "SF"

		"SmallForward":
			if r < 0.10:
				return "SG"
			elif r < 0.90:
				return "SF"
			return "PF"

		"PowerForward":
			if r < 0.15:
				return "SF"
			elif r < 0.85:
				return "PF"
			return "C"

		"Center":
			return "PF" if r < 0.20 else "C"

	return "SF"

func calculate_overall() -> int:

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
	
func calculate_contract_value() -> int:
	var overall := float(ratings["overall"])
	var potential := float(ratings["potential"])

	const MIN_SALARY := 500000.0
	const MAX_SALARY := 20000000.0

	var amount := (
		(2.0 * overall + potential) * 0.85 - 120.0) / 90

	amount = amount * (
		MAX_SALARY - MIN_SALARY
	) + MIN_SALARY

	amount *= rng.randf_range(0.90, 1.10)

	amount = clampf(
		amount,
		MIN_SALARY,
		MAX_SALARY
	)

	amount = 50000.0 * round(amount / 50000.0)

	return roundi(amount)
	
func insert_attributes(db):
	var data = {
		"player_id": id,
		"name": attributes.get("name"),
		"team_id": attributes.get("team_id"),
		"position": attributes.get("position"),
		"height": attributes.get("height"),
		"weight": attributes.get("weight"),
		"born_date": attributes.get("born_date"),
		"born_location": attributes.get("born_location"),
		"college": attributes.get("college"),
		"draft_year": attributes.get("draft_year"),
		"draft_round": attributes.get("draft_round"),
		"draft_pick": attributes.get("draft_pick"),
		"draft_team_id": attributes.get("draft_team_id"),
		"contract_amount": attributes.get("contract_amount"),
		"contract_expiration": attributes.get("contract_expiration"),
		"free_agent_times_asked": attributes.get("free_agent_times_asked", 0.0),
		"years_free_agent": attributes.get("years_free_agent", 0)
	}

	db.insert_row("player_attributes", data)
	
func insert_ratings(db):
	var data = {
		"player_id": id,
		"roster_position": ratings.get("roster_position", 0),
		"overall": ratings.get("overall"),
		"height": ratings.get("height"),
		"strength": ratings.get("strength"),
		"speed": ratings.get("speed"),
		"jumping": ratings.get("jumping"),
		"endurance": ratings.get("endurance"),
		"shooting_inside": ratings.get("shooting_inside"),
		"shooting_layups": ratings.get("shooting_layups"),
		"shooting_free_throws": ratings.get("shooting_free_throws"),
		"shooting_two_pointers": ratings.get("shooting_two_pointers"),
		"shooting_three_pointers": ratings.get("shooting_three_pointers"),
		"blocks": ratings.get("blocks"),
		"steals": ratings.get("steals"),
		"dribbling": ratings.get("dribbling"),
		"passing": ratings.get("passing"),
		"rebounding": ratings.get("rebounding"),
		"potential": ratings.get("potential")
	}

	db.insert_row("player_ratings", data)

func save(db):

	insert_attributes(db)

	insert_ratings(db)

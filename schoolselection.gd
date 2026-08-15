extends Control
var database : SQLite
var treerow : TreeItem
var team = Global.team
@onready var tree = $Tree
@onready var button = $Button
@onready var selection = $LineEdit

# Called when the node enters the scene tree for the first time.
func _ready():
	# Add column names for tree
	tree.set_column_title(0, "ID")
	tree.set_column_title(1, "Region")
	tree.set_column_title(2, "Team")
	tree.set_column_title(3, "Division")
	# The root node is hidden in the tree
	treerow = tree.create_item()
	treerow.set_text(0, "Hidden")
	treerow.set_text(1, "Hidden")
	treerow.set_text(2, "Hidden")
	treerow.set_text(3, "Hidden")
	# Open database
	database = SQLite.new()
	database.path = "res://data/bball.db"
	database.open_db()
	# Define division names
	var division_map = {
		0: "Atlantic",
		1: "Central",
		2: "Southeast",
		3: "Southwest",
		4: "Northwest",
		5: "Pacific"
	}
	# Change label to include the name of the team
	var array = database.select_rows("team_attributes", "", ["*"])
	for row in array:
		treerow = tree.create_item()

		var division_name = division_map.get(row["division_id"], "Unknown")

		treerow.set_text(0, str(row["ind"]))
		treerow.set_text(1, row["region"])
		treerow.set_text(2, row["name"])
		treerow.set_text(3, division_name)

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass
	
func _on_button_pressed():
	if selection.text != "":
		var id = int(selection.text)
		if id > 0 and id < 31:
			Global.team = id - 1
			Global.teams = load_teams(database)
			Global.schedule = generate_schedule(Global.teams)
			Global.phase = 1
			get_tree().change_scene_to_file("res://simulation/main.tscn")
	else: pass

func _on_line_edit_text_submitted(new_text):
	if selection.text != "":
		var id = int(selection.text)
		if id > 0 and id < 31:
			Global.team = id - 1
			Global.teams = load_teams(database)
			Global.schedule = generate_schedule(Global.teams)
			Global.phase = 1
			get_tree().change_scene_to_file("res://simulation/main.tscn")
	else: pass
	
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
	
func load_teams(db: SQLite) -> Array:
	var rows = db.select_rows(
		"team_attributes",
		"",
		["team_id", "division_id", "region", "name"]
	)

	var teams := []

	for r in rows:
		teams.append({
			"team_id": r["team_id"],
			"division_id": r["division_id"],
			"region": r["region"],
			"name": r["name"],
			"conference_id": int(r["division_id"] / 3)
		})

	return teams
	
func _on_tree_item_selected():
	selection.text = str(tree.get_selected().get_index() + 1)

func _on_title_pressed():
	get_tree().change_scene_to_file("res://titlescreen.tscn")

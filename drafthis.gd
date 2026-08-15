extends Control

@onready var season_dropdown: OptionButton = $SeasonDropdown
@onready var tree: Tree = $Tree

var db: SQLite

var selected_season: int = 0
var seasons: Array[int] = []


func _ready():

	db = SQLite.new()
	db.path = "res://data/bball.db"
	db.open_db()

	setup_tree()

	setup_season_dropdown()

	season_dropdown.item_selected.connect(
		_on_season_selected
	)

	# Load the first season.
	if season_dropdown.item_count > 0:

		season_dropdown.select(0)

		selected_season = seasons[0]

		update_history()


func setup_tree():

	tree.clear()

	tree.columns = 4

	tree.set_column_title(0, "Player")
	tree.set_column_title(1, "Team")
	tree.set_column_title(2, "Round")
	tree.set_column_title(3, "Pick")

	tree.set_column_titles_visible(true)


func setup_season_dropdown():

	season_dropdown.clear()

	seasons.clear()

	db.query("""
		SELECT DISTINCT season
		FROM draft_results
		ORDER BY season DESC
	""")

	for row in db.query_result:

		var season := int(row["season"])

		seasons.append(season)

		season_dropdown.add_item(
			str(season)
		)


func _on_season_selected(index: int):

	if index < 0:
		return

	if index >= seasons.size():
		return

	selected_season = seasons[index]

	update_history()


func update_history():

	tree.clear()

	var root := tree.create_item()

	db.query("""
		SELECT
			dr.player_id,
			dr.team_id,
			dr.round,
			dr.pick,
			pa.name,
			ta.abbreviation
		FROM draft_results dr
		LEFT JOIN player_attributes pa
			ON dr.player_id = pa.player_id
		LEFT JOIN team_attributes ta
			ON dr.team_id = ta.team_id
			AND ta.season = dr.season
		WHERE dr.season = %d
		ORDER BY dr.pick ASC
	""" % selected_season)

	for row in db.query_result:

		var player_name := str(row["name"])

		var team := str(
			row["abbreviation"]
		)

		var draft_round := int(row["round"])
		var pick := int(row["pick"])

		var item := tree.create_item(root)

		item.set_text(
			0,
			player_name
		)

		item.set_text(
			1,
			team
		)

		item.set_text(
			2,
			str(draft_round)
		)

		item.set_text(
			3,
			str(pick)
		)

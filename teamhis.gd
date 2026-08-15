extends Control

@onready var title = %Title
@onready var history_tree = $Tree

var db: SQLite

func _ready():

	db = SQLite.new()
	db.path = "res://data/bball.db"
	db.open_db()
	
	db.query("""
	SELECT region
	FROM team_attributes
	WHERE team_id=%d
	AND season=%d
	""" % [Global.team, Global.season + 2011])

	if !db.query_result.is_empty():
		title.text = "%s History" % db.query_result[0]["region"]
	else:
		title.text = "History"

	history_tree.columns = 2
	history_tree.set_column_title(0, "Season")
	history_tree.set_column_title(1, "Result")
	history_tree.set_column_titles_visible(true)

	update_history()
	
func update_history():

	history_tree.clear()

	var root = history_tree.create_item()

	var sql = """
	SELECT
		season,
		won,
		lost,
		playoffs,
		won_conference,
		won_championship
	FROM team_attributes
	WHERE team_id = %d
	ORDER BY season DESC
	""" % Global.team

	db.query(sql)

	for row in db.query_result:

		var item = history_tree.create_item(root)

		item.set_text(0, str(row["season"]))

		var result = "%d-%d" % [
			row["won"],
			row["lost"]
		]

		if int(row["won_championship"]) == 1:
			result += " • League Champions"

		elif int(row["won_conference"]) == 1:
			result += " • Conference Champions"

		elif int(row["playoffs"]) == 1:
			result += " • Made Playoffs"

		item.set_text(1, result)

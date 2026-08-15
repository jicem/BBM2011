extends Node2D

@onready var game_menu = $MenuBar/Game
@onready var team_menu = $MenuBar/Team
@onready var players_menu = $MenuBar/Players
@onready var help_menu = $MenuBar/Help

@onready var teams: Tree = $Teams

@onready var roster = $Roster
@onready var history = $History
@onready var manual = $Manual
@onready var trade = $Trade
@onready var draft_history = $DraftHis
@onready var roster_warning = $AcceptDialog

var db: SQLite

var season := 2011 + Global.season

const TICKET_PRICE := 50.0

var load_scene = preload("res://LoadBrowser.tscn")
var load_browser
var save_scene = preload("res://SaveBrowser.tscn")
var save_browser

func _ready():
	setup_menus()
	setup_db()
	setup_teams_tree()
	update_finances()

func setup_menus():

	game_menu.clear()

	game_menu.add_item("Load League", 0)
	game_menu.add_item("Save League", 1)
	game_menu.add_item("Quit to Title", 2)
	game_menu.add_item("Quit to Desktop", 3)

	team_menu.add_item("Roster", 0)
	team_menu.add_item("History", 1)

	players_menu.add_item("Trade", 0)
	players_menu.add_item("Draft History", 1)

	help_menu.add_item("Manual", 0)

func setup_db():

	db = SQLite.new()
	db.path = "res://data/bball.db"
	db.open_db()


func setup_teams_tree():

	teams.clear()

	teams.columns = 6

	teams.set_column_title(0, "Team")
	teams.set_column_title(1, "Avg Attendance")
	teams.set_column_title(2, "Revenue (YTD)")
	teams.set_column_title(3, "Profit (YTD)")
	teams.set_column_title(4, "Cash")
	teams.set_column_title(5, "Payroll")

	teams.set_column_custom_minimum_width(0, 200)
	teams.set_column_custom_minimum_width(1, 150)
	teams.set_column_custom_minimum_width(2, 130)
	teams.set_column_custom_minimum_width(3, 120)
	teams.set_column_custom_minimum_width(4, 120)
	teams.set_column_custom_minimum_width(5, 120)


func update_finances():

	teams.clear()

	var root := teams.create_item()

	db.query("""
		SELECT
			ta.team_id,
			ta.region,
			ta.name,
			ta.cash,

			COALESCE(AVG(ts.attendance), 0) AS avg_attendance,

			COALESCE(SUM(ts.attendance), 0) * %f AS revenue,

			(
				COALESCE(SUM(ts.attendance), 0) * %f
				- COALESCE(SUM(ts.cost), 0)
			) AS profit,

			(
			    COALESCE(
			        (
			            SELECT SUM(pa.contract_amount)
			            FROM player_attributes pa
			            WHERE pa.team_id = ta.team_id
			        ),
			        0
			    )
			    +
			    COALESCE(
			        (
			            SELECT SUM(rps.contract_amount)
			            FROM released_players_salaries rps
			            WHERE rps.team_id = ta.team_id
			        ),
			        0
			    )
			) AS payroll

		FROM team_attributes ta

		LEFT JOIN team_stats ts
			ON ta.team_id = ts.team_id
			AND ta.season = ts.season

		WHERE ta.season = %d

		GROUP BY
			ta.team_id,
			ta.region,
			ta.name,
			ta.cash

		ORDER BY
			ta.region ASC,
			ta.name ASC
	""" % [
		TICKET_PRICE,
		TICKET_PRICE,
		season
	])


	for row in db.query_result:

		var item := teams.create_item(root)

		var team_id := int(row["team_id"])
		var team_name := (
			str(row["region"])
			+ " "
			+ str(row["name"])
		)

		var avg_attendance := float(
			row["avg_attendance"]
		)

		var revenue := float(
			row["revenue"]
		)

		var profit := float(
			row["profit"]
		)

		var cash := float(
			row["cash"]
		)

		var payroll := float(
			row["payroll"]
		)


		# -----------------------------------------
		# Set Tree values
		# -----------------------------------------

		item.set_text(
			0,
			team_name
		)

		item.set_text(
			1,
			format_number(
				roundi(avg_attendance)
			)
		)

		item.set_text(
			2,
			format_money(revenue)
		)

		item.set_text(
			3,
			format_money(profit)
		)

		item.set_text(
			4,
			format_money(cash)
		)

		item.set_text(
			5,
			format_money(payroll)
		)


# ---------------------------------------------------------
# FORMAT NUMBER
# ---------------------------------------------------------

func format_number(value: int) -> String:

	return "%s" % value


# ---------------------------------------------------------
# FORMAT MONEY
# ---------------------------------------------------------

func format_money(amount: float) -> String:

	var millions := amount / 1000000.0

	return "$%.2fM" % millions

func _on_game_id_pressed(id: int):
	match id:
		0:
			open_load_browser()
		1:
			open_save_browser()
		2:
			get_tree().change_scene_to_file("res://titlescreen.tscn")
		3:
			get_tree().quit()

func _on_team_id_pressed(id: int):

	match id:

		0:
			roster.popup()

		1:
			history.popup()


func _on_button_1_pressed():
	get_tree().change_scene_to_file("res://simulation/main.tscn")


func _on_playoffs_pressed():
	get_tree().change_scene_to_file("res://simulation/playoffs.tscn")


func _on_draft_pressed():
	get_tree().change_scene_to_file("res://simulation/draft.tscn")


func _on_free_agents_pressed():
	get_tree().change_scene_to_file("res://simulation/fa.tscn")


func _on_ratings_pressed():
	get_tree().change_scene_to_file("res://ratings.tscn")


func _on_player_stats_pressed():
	get_tree().change_scene_to_file("res://playerstats.tscn")


func _on_team_stats_pressed():
	get_tree().change_scene_to_file("res://teamstats.tscn")


func _on_game_log_pressed():
	get_tree().change_scene_to_file("res://gamelog.tscn")


func _on_button_pressed():
	get_tree().change_scene_to_file("res://leaguehis.tscn")

func open_load_browser():
	load_browser = load_scene.instantiate()
	add_child(load_browser)
	load_browser.title = "Load League"
	load_browser.load_selected.connect(_load_league)
	load_browser.cancelled.connect(func():
		load_browser.queue_free()
	)
	load_browser.popup_centered()
	
func _load_league(save_name):
	db.import_from_json("res://data/savefiles/%s.json" % save_name)
	var file = FileAccess.open(
		"res://data/savefiles/%s.json" % save_name,
		FileAccess.READ
	)
	var state = JSON.parse_string(file.get_as_text())
	file.close()
	Global.load_save_state(state)
	get_tree().reload_current_scene()

func open_save_browser():
	save_browser = save_scene.instantiate()
	add_child(save_browser)
	save_browser.title = "Save League"
	save_browser.save_selected.connect(_save_league)
	save_browser.cancelled.connect(func():
		save_browser.queue_free()
	)
	save_browser.popup_centered()
	
func _save_league(save_name):
	db.export_to_json("res://data/savefiles/%s.json" % save_name)
	var save_state = Global.get_save_state()
	var file = FileAccess.open(
		"res://data/savefiles/%s.state.json" % save_name,
		FileAccess.WRITE
	)
	file.store_string(JSON.stringify(save_state))
	file.close()
	print("Database and game state saved as ", save_name)
	save_browser.queue_free()

func _on_help_id_pressed(id):
	match id:
		0:
			manual.popup()


func _on_players_id_pressed(id):
	match id:
		0:
			trade.popup()
		1:
			draft_history.popup()

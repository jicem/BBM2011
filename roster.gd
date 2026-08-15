extends Control

@onready var title = %Title
@onready var roster_tree = $Tree
@onready var roster_info = %RosterInfo
@onready var release_dialog = $ReleaseDialog
@onready var release_text = %ReleaseText
@onready var buyout_dialog = $BuyoutDialog
@onready var buyout_message = %BuyoutText
@onready var player_info = $PlayerInfo

var db: SQLite
var pending_release_player = -1
var pending_buyout_player = -1
var pending_buyout_cost = 0.0

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
		title.text = "%s Roster" % db.query_result[0]["region"]
	else:
		title.text = "Roster"

	roster_tree.columns = 10

	roster_tree.set_column_title(0, "Name")
	roster_tree.set_column_title(1, "Pos")
	roster_tree.set_column_title(2, "Age")
	roster_tree.set_column_title(3, "Ovr")
	roster_tree.set_column_title(4, "Pot")
	roster_tree.set_column_title(5, "Contract")
	roster_tree.set_column_title(6, "Min")
	roster_tree.set_column_title(7, "Pts")
	roster_tree.set_column_title(8, "Reb")
	roster_tree.set_column_title(9, "Ast")

	# Make Name and Contract stretch
	roster_tree.set_column_expand(0, true)
	roster_tree.set_column_expand(5, true)

	# Don't let the others expand
	roster_tree.set_column_expand(1, false)
	roster_tree.set_column_expand(2, false)
	roster_tree.set_column_expand(3, false)
	roster_tree.set_column_expand(4, false)
	roster_tree.set_column_expand(6, false)
	roster_tree.set_column_expand(7, false)
	roster_tree.set_column_expand(8, false)
	roster_tree.set_column_expand(9, false)

	# Minimum widths
	roster_tree.set_column_custom_minimum_width(0, 180) # Name
	roster_tree.set_column_custom_minimum_width(1, 50)  # Pos
	roster_tree.set_column_custom_minimum_width(2, 50)  # Age
	roster_tree.set_column_custom_minimum_width(3, 55)  # Ovr
	roster_tree.set_column_custom_minimum_width(4, 55)  # Pot
	roster_tree.set_column_custom_minimum_width(5, 190) # Contract
	roster_tree.set_column_custom_minimum_width(6, 60)  # Min
	roster_tree.set_column_custom_minimum_width(7, 60)  # Points
	roster_tree.set_column_custom_minimum_width(8, 60)  # Rebs
	roster_tree.set_column_custom_minimum_width(9, 60)  # Asts

	update_roster()
	
func _process(delta):
	if(Global.player_signed):
		update_roster()
		
	if(Global.player_traded):
		update_roster()
		Global.player_traded = false

func update_roster():

	roster_tree.clear()

	var root = roster_tree.create_item()

	var sql = """
	SELECT
	    pa.player_id,
	    pa.name,
	    pa.position,
	    %d - pa.born_date AS age,
	    pr.overall,
	    pr.potential,
	    pa.contract_amount,
	    pa.contract_expiration,
	    pr.roster_position,

	    COALESCE(AVG(ps.minutes),0) AS minutes,
	    COALESCE(AVG(ps.points),0) AS points,
	    COALESCE(AVG(ps.offensive_rebounds + ps.defensive_rebounds),0) AS rebounds,
	    COALESCE(AVG(ps.assists),0) AS assists

	FROM player_attributes pa

	JOIN player_ratings pr
	ON pa.player_id = pr.player_id

	LEFT JOIN player_stats ps
	ON pa.player_id = ps.player_id
	AND ps.season = %d

	WHERE pa.team_id = %d

	GROUP BY
	    pa.player_id,
	    pa.name,
	    pa.position,
	    pa.born_date,
	    pr.overall,
	    pr.potential,
	    pa.contract_amount,
	    pa.contract_expiration,
	    pr.roster_position

	ORDER BY pr.roster_position
	""" % [
		Global.season + 2011,
		Global.season + 2011,
		Global.team
	]

	db.query(sql)

	var rows = db.query_result

	for row in rows:

		var item = roster_tree.create_item(root)
		var millions = float(row["contract_amount"]) / 1000000.0

		item.set_metadata(0, row["player_id"])

		item.set_text(0, row["name"])
		item.set_text(1, row["position"])
		item.set_text(2, str(row["age"]))
		item.set_text(3, str(row["overall"]))
		item.set_text(4, str(row["potential"]))

		item.set_text(
			5,
			"$%.1fM thru %d" % [
				millions,
				int(row["contract_expiration"])
			]
		)

		item.set_text(6, "%.1f" % float(row["minutes"]))
		item.set_text(7, "%.1f" % float(row["points"]))
		item.set_text(8, "%.1f" % float(row["rebounds"]))
		item.set_text(9, "%.1f" % float(row["assists"]))

	update_roster_info()
	
func update_roster_info():

	var rows = db.select_rows(
		"player_attributes",
		"team_id=%d" % Global.team,
		["COUNT(*) AS count"]
	)

	var players = int(rows[0]["count"])
	var empty = 15 - players

	roster_info.text = "Empty roster spots: %d" % empty
	
func get_selected_item() -> TreeItem:
	return roster_tree.get_selected()
	
func get_selected_player_id() -> int:
	var item = get_selected_item()

	if item == null:
		return -1

	return int(item.get_metadata(0))

func _on_auto_sort_pressed():

	var sql = """
	SELECT pa.player_id
	FROM player_attributes pa
	JOIN player_ratings pr
	ON pa.player_id = pr.player_id
	WHERE pa.team_id = %d
	ORDER BY pr.overall DESC,
	         pr.potential DESC
	""" % Global.team

	db.query(sql)

	var rows = db.query_result

	var pos = 1

	for row in rows:

		db.query("""
		UPDATE player_ratings
		SET roster_position=%d
		WHERE player_id=%d
		""" % [pos, row["player_id"]])

		pos += 1

	update_roster()

func _on_up_pressed():

	var item = get_selected_item()

	if item == null:
		return

	var previous = item.get_prev()

	if previous == null:
		return

	var a = int(item.get_metadata(0))
	var b = int(previous.get_metadata(0))

	swap_roster_positions(a, b)

	update_roster()
	
func swap_roster_positions(player1:int, player2:int):

	var sql = """
	SELECT player_id, roster_position
	FROM player_ratings
	WHERE player_id IN (%d,%d)
	""" % [player1, player2]

	db.query(sql)

	var rows = db.query_result

	var pos1
	var pos2

	for row in rows:

		if row["player_id"] == player1:
			pos1 = row["roster_position"]
		else:
			pos2 = row["roster_position"]

	db.query("""
	UPDATE player_ratings
	SET roster_position=%d
	WHERE player_id=%d
	""" % [pos2, player1])

	db.query("""
	UPDATE player_ratings
	SET roster_position=%d
	WHERE player_id=%d
	""" % [pos1, player2])
	
func release_player(id: int) -> void:

	var rows = db.select_rows(
		"player_attributes",
		"player_id = %d" % id,
		[
			"team_id",
			"contract_amount",
			"contract_expiration"
		]
	)

	if rows.is_empty():
		return

	var player = rows[0]

	var old_team_id: int = int(player["team_id"])
	var contract_amount: int = int(player["contract_amount"])
	var contract_expiration: int = int(player["contract_expiration"])

	# Keep track of the player's old contract.
	db.insert_row(
		"released_players_salaries",
		{
			"player_id": id,
			"team_id": old_team_id,
			"contract_amount": contract_amount,
			"contract_expiration": contract_expiration
		}
	)

	# Move player to free agency.
	db.query("""
		UPDATE player_attributes
		SET
			team_id = -1,
			free_agent_times_asked = 0
		WHERE player_id = %d
	""" % id)

func _on_down_pressed():

	var item = get_selected_item()

	if item == null:
		return

	var next = item.get_next()

	if next == null:
		return

	swap_roster_positions(
		int(item.get_metadata(0)),
		int(next.get_metadata(0))
	)

	update_roster()


func _on_info_pressed():

	var player_id = Global.current_player

	if player_id == -1:
		return
	
	Global.setup_player_trees = true

	player_info.popup_centered()


func _on_buy_out_pressed():

	var id = get_selected_player_id()

	if id == -1:
		return

	# Player contract
	db.query("""
	SELECT
		contract_amount,
		contract_expiration,
		name
	FROM player_attributes
	WHERE player_id=%d
	""" % id)

	if db.query_result.is_empty():
		return

	var player = db.query_result[0]

	var amount = float(player["contract_amount"])
	var expiration = int(player["contract_expiration"])
	var player_name = player["name"]

	# Team cash
	db.query("""
	SELECT cash
	FROM team_attributes
	WHERE team_id=%d
	AND season=%d
	""" % [Global.team, Global.season + 2011])

	if db.query_result.is_empty():
		return

	var cash = float(db.query_result[0]["cash"])

	# Games played (regular season only)
	db.query("""
	SELECT COUNT(*) AS games
	FROM team_stats
	WHERE team_id=%d
	AND season=%d
	AND is_playoffs=0
	""" % [Global.team, Global.season + 2011])

	var games = int(db.query_result[0]["games"])

	# Remaining contract owed
	var remaining = (
		(expiration - (Global.season + 2011) + 1) * amount
		- (games / 82.0) * amount
	) * 1000.0

	if cash < remaining:

		buyout_message.text = "%s cannot be bought out.\n\nYou need $%.2fM but only have $%.2fM." % [
			player_name,
			remaining / 1000000.0,
			cash / 1000000.0
		]

		buyout_dialog.ok_button_text = "OK"
		buyout_dialog.get_cancel_button().hide()

		buyout_dialog.popup_centered()

		return

	pending_buyout_player = id
	pending_buyout_cost = remaining

	buyout_message.text = (
		"Buy out %s?\n\nThis will cost $%.2fM.\nThe player will become a free agent."
	) % [
		player_name,
		remaining / 1000000.0
	]

	buyout_dialog.ok_button_text = "Buy Out"
	buyout_dialog.get_cancel_button().show()

	buyout_dialog.popup_centered()

func _on_buyout_dialog_confirmed():

	if pending_buyout_player == -1:
		return

	# Deduct cash
	db.query("""
	UPDATE team_attributes
	SET cash = cash - %f
	WHERE team_id=%d
	AND season=%d
	""" % [
		pending_buyout_cost,
		Global.team,
		Global.season + 2011
	])

	# Make player a free agent
	db.query("""
	UPDATE player_attributes
	SET team_id = -1
	WHERE player_id=%d
	""" % pending_buyout_player)

	pending_buyout_player = -1
	pending_buyout_cost = 0.0

	update_roster()
	
func _on_release_pressed() -> void:

	var id := get_selected_player_id()

	if id == -1:
		return

	db.query("""
		SELECT
			name,
			contract_amount,
			contract_expiration
		FROM player_attributes
		WHERE player_id = %d
	""" % id)

	if db.query_result.is_empty():
		return

	var player = db.query_result[0]

	var player_name := str(player["name"])
	var contract_amount := float(player["contract_amount"])
	var contract_expiration := int(player["contract_expiration"])
	var current_year := Global.season + 2011

	# Number of seasons remaining on the contract.
	var seasons_remaining = max(0,contract_expiration - current_year + 1)

	var remaining_salary = contract_amount * seasons_remaining

	pending_release_player = id

	release_text.text = (
		"Release %s?\n\nHe'll become a free agent, but you'll have to pay his salary through %d.\n\nRemaining salary obligation: $%.2fM"
	) % [
		player_name,
		contract_expiration,
		remaining_salary / 1000000.0
	]

	release_dialog.popup_centered()

func _on_tree_item_selected():
	Global.current_player = get_selected_player_id()


func _on_release_dialog_confirmed() -> void:

	if pending_release_player == -1:
		return

	release_player(pending_release_player)

	pending_release_player = -1

	update_roster()

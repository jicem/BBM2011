extends Control

@onready var team_roster = $TeamRoster
@onready var cpu_roster = $TradeRoster

@onready var dropdown = $TeamDropdown
@onready var accept_dialog = $AcceptDialog
@onready var reject_dialog = $RejectDialog
@onready var roster_refusal = $RosterRefusal

@onready var team_name = %TeamName
@onready var team_abbrev = %TeamAbbrev
@onready var partner_abbrev = %PartnerAbbrev
@onready var team_out = %TeamOut
@onready var team_in = %TeamIn
@onready var partner_out = %PartnerOut
@onready var partner_in = %PartnerIn
@onready var team_out_value = %TeamTradeValue
@onready var team_in_value = %TeamReturnValue
@onready var cpu_out_value = %PartnerTradeValue
@onready var cpu_in_value = %PartnerReturnValue
@onready var team_payroll = %TeamPayroll
@onready var partner_payroll = %PartnerPayroll

var trade : Trade
var db : SQLite
var season = 2011 + Global.season

func _ready():
	db=SQLite.new()
	db.path="res://data/bball.db"
	db.open_db()

	trade=Trade.new(db,0)
	
	setup_tree(team_roster)
	setup_tree(cpu_roster)
	
	load_team_roster(Global.team, team_roster)
	if(Global.team == 0):
		trade.new_team(1)
		load_team_roster(1, cpu_roster)
	else:
		trade.new_team(0)
		load_team_roster(0, cpu_roster)

	refresh_summary()
	load_dropdown()

func setup_tree(tree: Tree):
	tree.set_column_title(0, "")
	tree.set_column_title(1, "Player")
	tree.set_column_title(2, "Pos")
	tree.set_column_title(3, "Age")
	tree.set_column_title(4, "Ovr")
	tree.set_column_title(5, "Pot")
	tree.set_column_title(6, "Salary")

	tree.set_column_expand(0, false)
	tree.set_column_custom_minimum_width(0, 30)

	tree.set_column_expand(2, false)
	tree.set_column_custom_minimum_width(2, 60)

	tree.set_column_expand(3, false)
	tree.set_column_custom_minimum_width(3, 45)

	tree.set_column_expand(4, false)
	tree.set_column_custom_minimum_width(4, 45)

	tree.set_column_expand(5, false)
	tree.set_column_custom_minimum_width(5, 45)

	tree.set_column_expand(6, false)
	tree.set_column_custom_minimum_width(6, 90)

func load_dropdown():
	db.query("""
	SELECT team_id,region,name
	FROM team_attributes
	WHERE season=%d
	ORDER BY region
	""" % season)

	dropdown.clear()

	for row in db.query_result:

		if row.team_id==Global.team:
			continue

		dropdown.add_item(
			row.region+" "+row.name,
			row.team_id
		)
		
func _on_team_dropdown_item_selected(index):

	var id = dropdown.get_item_id(index)

	trade.new_team(id)

	load_team_roster(id, cpu_roster)

	refresh_summary()
	
func refresh_summary():
	trade.update()

	# Team names
	team_name.text = trade.team_names[0]
	team_abbrev.text = get_team_abbrev(Global.team)
	partner_abbrev.text = get_team_abbrev(trade.team_id)
	
	# Updating trade text
	team_out.text = "$%.2fM total" % (trade.total[0] / 1000000.0)

	team_in.text = "$%.2fM total" % (trade.total[1] / 1000000.0)

	team_out_value.text = "Value: " + add_commas(trade.value[0])
	
	team_in_value.text = "Value: " + add_commas(trade.value[1])

	team_payroll.text = "Payroll After: $%.2fM" % (trade.payroll_after_trade[0] / 1000000.0)

	partner_out.text = "$%.2fM total" % (trade.total[1] / 1000000.0)

	partner_in.text = "$%.2fM total" % (trade.total[0] / 1000000.0)

	cpu_out_value.text = "Value: " + add_commas(trade.value[1])
		
	cpu_in_value.text = "Value: " + add_commas(trade.value[0])

	partner_payroll.text = "Payroll After: $%.2fM" % (trade.payroll_after_trade[1] / 1000000.0)

	var normal = Color.WHITE
	var warning = Color.LIGHT_CORAL

	team_payroll.modulate = warning if trade.over_cap[0] else normal
	partner_payroll.modulate = warning if trade.over_cap[1] else normal

	# Indicate roster-limit violations
	if trade.over_roster_limit[0]:
		team_payroll.text += "\n(Over roster limit)"

	if trade.over_roster_limit[1]:
		partner_payroll.text += "\n(Over roster limit)"
		
func add_commas(number: int) -> String:
	var str_num = str(number)
	var result = ""
	var count = 0
	
	for i in range(str_num.length() - 1, -1, -1):
		result = str_num[i] + result
		count += 1
		
		if count % 3 == 0 and i != 0:
			result = "," + result
	
	return result

func get_team_abbrev(
	team_id: int
) -> String:

	db.query("""
		SELECT abbreviation
		FROM team_attributes
		WHERE team_id = %d
	""" % [
		team_id
	])

	if db.query_result.is_empty():
		return "Unknown"

	return str(
		db.query_result[0]["abbreviation"]
	)

func load_team_roster(team_id:int, tree:Tree):
	tree.clear()

	var root = tree.create_item()

	db.query("""
	SELECT
		pa.player_id,
		pa.name,
		pa.position,
		pa.height,
		pa.weight,
		pa.born_date,
		pa.contract_amount,
		pa.contract_expiration,
		pa.draft_year,
		pa.draft_round,
		pa.draft_pick,
		pr.overall,
		pr.potential
	FROM player_attributes pa
	INNER JOIN player_ratings pr
		ON pa.player_id = pr.player_id
	WHERE pa.team_id = %d
	ORDER BY pr.overall DESC, pr.potential DESC
	""" % team_id)

	for row in db.query_result:

		var item = tree.create_item(root)

		item.set_cell_mode(0, TreeItem.CELL_MODE_CHECK)
		item.set_editable(0, true)

		var age = season - int(row["born_date"])

		item.set_text(1, row["name"])
		item.set_text(2, row["position"])
		item.set_text(3, str(age))
		item.set_text(4, str(row["overall"]))
		item.set_text(5, str(row["potential"]))
		item.set_text(6, "$%.2fM" % (float(row["contract_amount"]) / 1000000.0))

		item.set_metadata(0, row)
		
func update_offer(side:int, tree:Tree):
	trade.offer[side].clear()

	var item = tree.get_root().get_first_child()

	while item:

		if item.is_checked(0):

			var p = item.get_metadata(0)

			trade.add_player(side, {
				"player_id": p["player_id"],
				"team_id": Global.team if side==0 else trade.team_id,
				"name": p["name"],
				"position": p["position"],
				"age": season - int(p["born_date"]),
				"overall": p["overall"],
				"potential": p["potential"],
				"height": p["height"],
				"weight": p["weight"],
				"contract": p["contract_amount"],
				"contract_expiration": p["contract_expiration"],
				"draft_year": p["draft_year"],
				"draft_round": p["draft_round"],
				"draft_pick": p["draft_pick"]
			})

		item = item.get_next()

	trade.update()
	refresh_summary()

func refresh_both_rosters():
	# Reload the player's roster
	load_team_roster(Global.team, team_roster)

	# Reload the CPU team's roster
	load_team_roster(trade.team_id, cpu_roster)

	# Clear any checked boxes/offers
	trade.clear_offer()

	# Update the summary panel
	refresh_summary()
		
func clear_checks(tree):
	var item = tree.get_root().get_first_child()

	while item:

		item.set_checked(0,false)

		item = item.get_next()

func _on_propose_button_pressed():
	trade.update()

	# Check roster limits first
	if trade.over_roster_limit[0] or trade.over_roster_limit[1]:
		roster_refusal.popup()
		return

	# Evaluate the trade
	var result = trade.propose()

	if result[0]:
		accept_dialog.popup()

		trade.process()
		
		Global.player_traded = true

		refresh_both_rosters()

		print(result[1])
	else:
		reject_dialog.popup()
		print(result[1])

func _on_clear_button_pressed():
	trade.clear_offer()
	clear_checks(team_roster)
	clear_checks(cpu_roster)
	refresh_summary()
	
func _on_team_roster_item_edited():
	update_offer(0, team_roster)

func _on_trade_roster_item_edited():
	update_offer(1, cpu_roster)

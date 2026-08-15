extends Control

@onready var team_name_label = %TeamName
@onready var payroll_label = %Payroll
@onready var years_box = %YearsBox
@onready var amount_box = %AmountBox

@onready var player_name_label = %PlayerName
@onready var overall_label = %Overall
@onready var potential_label = %Potential

@onready var contract_label = %ProposedContract

@onready var player_info = $PlayerInfo

var db: SQLite

var team_id: int
var player_id: int

var player_amount: float = 0.0
var player_years: int = 1

var steps: int = 0
var max_steps: int = 1

const MIN_SALARY := 500000
const MAX_SALARY := 20000000

func _ready():
	# Amount is displayed in millions.
	amount_box.min_value = MIN_SALARY / 1000000.0
	amount_box.max_value = MAX_SALARY / 1000000.0

	years_box.min_value = 1
	years_box.max_value = 5

	setup_db()

	team_id = Global.team
	player_id = Global.current_player

	load_negotiation_data()

func setup_db():

	db = SQLite.new()
	db.path = "res://data/bball.db"
	db.open_db()


func load_negotiation_data():

	load_team_info()
	load_player_info()
	
func load_team_info():

	# Get team name
	var team_rows = db.select_rows(
		"team_attributes",
		"team_id = %d AND season = %d" % [
			team_id,
			2011 + Global.season
		],
		["region", "name"]
	)

	if team_rows.is_empty():
		return

	var team = team_rows[0]

	team_name_label.text = "[b]" + team["region"] + " " + team["name"] + "[/b]"

	# Calculate team payroll
	db.query("""
		SELECT
			COALESCE(SUM(contract_amount), 0) AS payroll
		FROM player_attributes
		WHERE team_id = %d
	""" % team_id)

	if db.query_result.is_empty():
		payroll_label.text = "Payroll: $0.00M"
		return

	var payroll = float(
		db.query_result[0]["payroll"]
	)

	# Convert dollars to millions.
	var payroll_millions = payroll / 1000000.0

	payroll_label.text = "Payroll: $%.2fM" % payroll_millions
	
func load_player_info():

	db.query("""
		SELECT
			pa.name,
			pr.overall,
			pr.potential,
			pa.contract_amount,
			pa.contract_expiration
		FROM player_attributes pa
		INNER JOIN player_ratings pr
			ON pa.player_id = pr.player_id
		WHERE pa.player_id = %d
	""" % player_id)

	if db.query_result.is_empty():
		return

	var player = db.query_result[0]

	var overall := int(player["overall"])
	var potential := int(player["potential"])

	player_name_label.text = "[b]" + player["name"] + "[/b]"

	overall_label.text = "Overall: %d" % overall

	potential_label.text = "Potential: %d" % potential
	
	player_amount = int(player["contract_amount"])
	player_years = int(player["contract_expiration"]) - Global.season
	
	amount_box.value = player_amount / 1000000.0
	years_box.value = int(player["contract_expiration"]) - Global.season
	
	update_player_proposal()

func update_player_proposal():

	# Make sure salary stays within league limits.
	player_amount = clamp(
		player_amount,
		MIN_SALARY,
		MAX_SALARY
	)

	# Make sure years stay within allowed range.
	player_years = clampi(
		player_years,
		1,
		5
	)

	var salary_millions := player_amount / 1000000.0

	contract_label.text = "$%.2fM for %d years" % [
		salary_millions,
		player_years
	]

func calculate_offer(
	overall: int,
	potential: int
) -> Array:

	# Determine contract length
	var years := 1

	if overall >= 80:
		years = randi_range(4, 5)

	elif overall >= 70:
		years = randi_range(3, 5)

	elif overall >= 60:
		years = randi_range(2, 4)

	else:
		years = randi_range(1, 2)

	# Calculate expected salary
	var salary := ((2.0 * float(overall) + float(potential)) * 0.85 - 120.0) / 90

	# Apply salary variation
	salary *= randf_range(0.90, 1.10)

	# Enforce league salary limits
	salary = clamp(
		salary,
		MIN_SALARY,
		MAX_SALARY
	)
	
	salary = 50000.0 * round(salary / 50000.0)

	return [salary, years]

func _on_info_pressed():
	Global.setup_player_trees = true

	player_info.popup_centered()


func _on_release_pressed():
	# Release player.
	db.query("""
		UPDATE player_attributes
		SET
			team_id = -1,
			free_agent_times_asked = 1
		WHERE player_id = %d
	""" % player_id)


	# Move to the next expiring player.
	move_to_next_expiring_player()

func move_to_next_expiring_player():
	# Remove the player we just negotiated with.
	var index = Global.expirings.find(player_id)

	if index != -1:
		Global.expirings.remove_at(index)

	# Check if there are more players to negotiate with.
	if Global.expirings.is_empty():
		Global.negotiating = false
		queue_free()
		return

	# Get the next player.
	Global.current_player = Global.expirings[0]
	player_id = Global.current_player

	# Reset negotiation state.
	steps = 0
	max_steps = randi_range(1, 5)

	load_negotiation_data()

func _on_submit_offer_pressed():

	var team_amount := float(amount_box.value) * 1000000.0
	var team_years := int(years_box.value)

	steps += 1

	# Negotiation step

	if steps <= max_steps:

		# Contract length negotiation

		if team_years < player_years:

			# Team wants fewer years.
			# Player responds by reducing requested years
			# but increasing salary.
			player_years -= 1
			player_amount *= 1.2

		elif team_years > player_years:

			# Team offers more years.
			# Player accepts longer contract but asks
			# for more money.
			player_years += 1
			player_amount *= 1.2


		# Salary negotiation

		if (
			team_amount < player_amount
			and team_amount > 0.7 * player_amount
		):

			# Team offer is reasonably close.
			# Player compromises toward the offer.
			player_amount = (
				0.75 * player_amount
				+ 0.25 * team_amount
			)

		elif team_amount < player_amount:

			# Team offer is too low.
			# Player raises their demand.
			player_amount *= 1.1

		elif team_amount > player_amount:

			# Team offers more than the player requested.
			player_amount = team_amount


	else:

		# Negotiations have gone on too long.
		# Player becomes more demanding.
		player_amount *= 1.05


	update_player_proposal()


func _on_accept_offer_pressed():
	# Accept the player's current proposal.
	var offered_salary := roundi(player_amount)
	var offered_years := player_years

	# Calculate contract expiration

	var current_season := 2011 + Global.season

	var contract_expiration := (
		current_season + offered_years
	)


	# Sign player

	db.query("""
		UPDATE player_attributes
		SET
			team_id = %d,
			contract_amount = %d,
			contract_expiration = %d
		WHERE player_id = %d
	""" % [
		team_id,
		offered_salary,
		contract_expiration,
		player_id
	])
	
	Global.player_signed = true

	move_to_next_expiring_player()

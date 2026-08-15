extends Control
@onready var title = %Title
@onready var mvp = %MVP
@onready var mvp_stats = %MVPStats
@onready var dpoy = %DPOY
@onready var dpoy_stats = %DPOYStats
@onready var smoty = %SMOTY
@onready var smoty_stats = %SMOTYStats
@onready var roty = %ROTY
@onready var roty_stats = %ROTYStats
@onready var east_winner = %EastWinner
@onready var west_winner = %WestWinner
@onready var all_nba = [
	%AllNBA1,
	%AllNBA2,
	%AllNBA3,
	%AllNBA4,
	%AllNBA5,
	%AllNBA6,
	%AllNBA7,
	%AllNBA8,
	%AllNBA9,
	%AllNBA10,
	%AllNBA11,
	%AllNBA12,
	%AllNBA13,
	%AllNBA14,
	%AllNBA15
]

@onready var all_defensive = [
	%AllDefensive1,
	%AllDefensive2,
	%AllDefensive3,
	%AllDefensive4,
	%AllDefensive5,
	%AllDefensive6,
	%AllDefensive7,
	%AllDefensive8,
	%AllDefensive9,
	%AllDefensive10,
	%AllDefensive11,
	%AllDefensive12,
	%AllDefensive13,
	%AllDefensive14,
	%AllDefensive15
]
@onready var ppg = %PPG
@onready var rpg = %RPG
@onready var apg = %APG
@onready var spg = %SPG
@onready var bpg = %BPG
@onready var topg = %TOPG
@onready var mpg = %MPG

var season
var db: SQLite

func _ready():
	season = Global.awards_season
	
	db = SQLite.new()
	db.path = "res://data/bball.db"
	db.open_db()

	title.text = "%d Season Awards" % season

	build_awards_cache()
	load_best_record()
	load_major_awards()
	load_all_nba()
	load_all_defensive()
	load_leaders()
	
func _process(delta):
	if(Global.changed_season):
		season = Global.awards_season
		print(season)
		
		title.text = "%d Season Awards" % season

		build_awards_cache()
		load_best_record()
		load_major_awards()
		load_all_nba()
		load_all_defensive()
		load_leaders()
		
		Global.changed_season = false
	
func build_awards_cache() -> void:
	db.query("DROP TABLE IF EXISTS awards_cache")

	db.query("""
	CREATE TEMP TABLE awards_cache AS
	SELECT
		pa.player_id,
		pa.name,
		pa.team_id,
		pa.draft_year,

		ta.abbreviation,

		COUNT(*) AS games,

		SUM(ps.starter) AS starts,

		AVG(ps.minutes) AS minutes,

		AVG(ps.points) AS points,

		AVG(ps.assists) AS assists,

		AVG(ps.offensive_rebounds) AS offensive_rebounds,
		AVG(ps.defensive_rebounds) AS defensive_rebounds,

		AVG(ps.offensive_rebounds + ps.defensive_rebounds) AS rebounds,

		AVG(ps.steals) AS steals,

		AVG(ps.blocks) AS blocks,

		AVG(ps.turnovers) AS turnovers

	FROM player_stats ps

	INNER JOIN player_attributes pa
		ON pa.player_id = ps.player_id

	INNER JOIN team_attributes ta
		ON ta.team_id = ps.team_id
		AND ta.season = ps.season

	WHERE
		ps.season = %d
		AND ps.is_playoffs = 0

	GROUP BY
		pa.player_id
	""" % season)
	
func load_best_record():
	var east = db.select_rows(
		"team_attributes",
		"season=%d AND division_id<3" % season,
		["region","abbreviation","won","lost"]
	)

	east.sort_custom(func(a, b):
		return (
			float(a["won"]) / (a["won"] + a["lost"])
			>
			float(b["won"]) / (b["won"] + b["lost"])
		)
	)

	var west = db.select_rows(
		"team_attributes",
		"season=%d AND division_id>=3" % season,
		["region","abbreviation","won","lost"]
	)

	west.sort_custom(func(a, b):
		return (
			float(a["won"]) / (a["won"] + a["lost"])
			>
			float(b["won"]) / (b["won"] + b["lost"])
		)
	)

	east_winner.text = "East: %s (%d-%d)" % [
		east[0]["abbreviation"],
		east[0]["won"],
		east[0]["lost"]
	]

	west_winner.text = "West: %s (%d-%d)" % [
		west[0]["abbreviation"],
		west[0]["won"],
		west[0]["lost"]
	]
	
func load_major_awards():
	var p

	# MVP-
	db.query("""
		SELECT *
		FROM awards_cache
		ORDER BY
			(0.75 * points + rebounds + assists - turnovers * 0.5) DESC
		LIMIT 1
	""")

	if db.query_result.size() > 0:
		p = db.query_result[0]

		mvp.text = "%s (%s)" % [
			p["name"],
			p["abbreviation"]
		]

		mvp_stats.text = "%.1f pts, %.1f rebs, %.1f asts" % [
			p["points"],
			p["rebounds"],
			p["assists"]
		]

	# DPOY
	db.query("""
		SELECT *
		FROM awards_cache
		ORDER BY
			(rebounds + steals * 5 + blocks * 5) DESC
		LIMIT 1
	""")
	
	if db.query_result.size() > 0:

		p = db.query_result[0]

		dpoy.text = "%s (%s)" % [
			p["name"],
			p["abbreviation"]
		]

		dpoy_stats.text = "%.1f rebs, %.1f stls, %.1f blks" % [
			p["rebounds"],
			p["steals"],
			p["blocks"]
		]

	# SMOTY
	db.query("""
		SELECT *
		FROM awards_cache
		WHERE starts < 42 AND minutes < 28
		ORDER BY
			(0.75 * points + rebounds + assists) DESC
		LIMIT 1
	""")

	if db.query_result.size() > 0:
		p = db.query_result[0]

		smoty.text = "%s (%s)" % [
			p["name"],
			p["abbreviation"]
		]

		smoty_stats.text = "%.1f pts, %.1f rebs, %.1f asts" % [
			p["points"],
			p["rebounds"],
			p["assists"]
		]

	# ROTY
	db.query("""
		SELECT *
		FROM awards_cache
		WHERE draft_year = %d
		ORDER BY
			(0.75 * points + rebounds + assists) DESC
		LIMIT 1
	""" % (season - 1))

	if db.query_result.size() > 0:
		p = db.query_result[0]

		roty.text = "%s (%s)" % [
			p["name"],
			p["abbreviation"]
		]

		roty_stats.text = "%.1f pts, %.1f rebs, %.1f asts" % [
			p["points"],
			p["rebounds"],
			p["assists"]
		]
		
func load_all_nba():

	db.query("""
		SELECT *
		FROM awards_cache
		ORDER BY
			(
				points * 0.75 +
				rebounds +
				assists -
				turnovers * 0.5
			) DESC
		LIMIT 15
	""")

	for i in range(min(15, db.query_result.size())):

		var p = db.query_result[i]

		all_nba[i].text = "%s (%s)" % [
			p["name"],
			p["abbreviation"]
		]
		
func load_all_defensive():

	db.query("""
		SELECT *
		FROM awards_cache
		ORDER BY
			(
				rebounds +
				steals * 5 +
				blocks * 5
			) DESC
		LIMIT 15
	""")

	for i in range(min(15, db.query_result.size())):

		var p = db.query_result[i]

		all_defensive[i].text = "%s (%s)" % [
			p["name"],
			p["abbreviation"]
		]

func load_leaders():

	load_leader("points", ppg, "ppg")
	load_leader("rebounds", rpg, "rpg")
	load_leader("assists", apg, "apg")
	load_leader("steals", spg, "spg")
	load_leader("blocks", bpg, "bpg")
	load_leader("turnovers", topg, "topg")
	load_leader("minutes", mpg, "mpg")
	
func load_leader(column:String, label:Label, suffix:String):

	db.query("""
		SELECT *
		FROM awards_cache
		ORDER BY %s DESC
		LIMIT 1
	""" % column)

	if db.query_result.is_empty():
		return

	var p = db.query_result[0]

	label.text = "%s (%.1f %s)" % [
		p["name"],
		float(p[column]),
		suffix
	]

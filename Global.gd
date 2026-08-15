extends Node
var team : int
var season : int
var schedule1complete : bool
var schedule2complete : bool
var schedule3complete : bool
var schedule4complete : bool
var schedule5complete : bool
var schedule6complete : bool
var schedule7complete : bool
var schedule8complete : bool
var schedule9complete : bool
var schedule10complete : bool
var schedule11complete : bool
var ccschedulecomplete : bool
var bowlschedulecomplete : bool
var semischedulecomplete : bool
var finalschedulecomplete : bool
var sweet16schedulecomplete
var elite8schedulecomplete
var final4schedulecomplete
var final2schedulecomplete
var postseasonIds : Array
var pgsneeded : int
var sgsneeded : int
var sfsneeded : int
var pfsneeded : int
var csneeded : int
var admood : int
var gamestarted
var seconds
var minutes
var hours
var playmins
var playhrs
var nba_players
var schedule: Array
var teams: Array
var phase
var game_count
var games_played
var playoff_day
var playoff_round
var current_player
var awards_season
var changed_season
var setup_player_trees
var expirings
var negotiating
var changed_player
var player_signed
var player_traded
var rng := RandomNumberGenerator.new()

# Called when the node enters the scene tree for the first time.
func _ready():
	team = 0
	season = 0
	admood = 3
	seconds = 0
	minutes = 0
	hours = 0
	playmins = 0
	playhrs = 0
	schedule1complete = false
	schedule2complete = false
	schedule3complete = false
	schedule4complete = false
	schedule5complete = false
	schedule6complete = false
	schedule7complete = false
	schedule8complete = false
	schedule9complete = false
	schedule10complete = false
	schedule11complete = false
	ccschedulecomplete = false
	bowlschedulecomplete = false
	semischedulecomplete = false
	finalschedulecomplete = false
	sweet16schedulecomplete = false
	elite8schedulecomplete = false
	final4schedulecomplete = false
	final2schedulecomplete = false
	postseasonIds = []
	gamestarted = false
	nba_players = false
	schedule = []
	teams = []
	phase = 0
	game_count = 0
	games_played = 0
	playoff_day = 1
	playoff_round = 1
	current_player = -1
	awards_season = 2011
	changed_season = false
	setup_player_trees = false
	expirings = []
	negotiating = false
	changed_player = false
	player_signed = false
	player_traded = false

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	if gamestarted:
		seconds += 1
		if seconds >= 60:
			seconds = 0
			minutes += 1
			if minutes >= 60:
				minutes = 0
				hours += 1
				playmins += 1
				if hours >= 24:
					hours = 0
		if playmins >= 60:
			playmins = 0
			playhrs += 1

func gaussian(mean:float, sigma:float) -> float:
	var u1 = max(rng.randf(), 0.000001)
	var u2 = rng.randf()
	var z = sqrt(-2.0 * log(u1)) * cos(TAU * u2)
	return mean + sigma * z

func get_save_state() -> Dictionary:
	return {
		"nba_players": nba_players,
		"schedule": schedule,
		"season": season,
		"team": team,
		"teams": teams,
		"phase": phase,
		"game_count": game_count,
		"games_played": games_played,
		"playoff_day": playoff_day,
		"playoff_round": playoff_round,
		"current_player": current_player,
		"awards_season": awards_season,
		"changed_season": changed_season,
		"setup_player_trees": setup_player_trees,
		"expirings": expirings,
		"negotiating": negotiating
	}
	
func load_save_state(state: Dictionary):
	nba_players = state.get("nba_players", false)
	schedule = state.get("schedule", [])
	season = state.get("season", 0)
	team = state.get("team", 0)
	teams = state.get("teams", [])
	phase = state.get("phase", 0)
	game_count = state.get("game_count", 0)
	games_played = state.get("games_played", 0)
	playoff_day = state.get("playoff_day", 1)
	playoff_round = state.get("playoff_round", 1)
	current_player = state.get("current_player", -1)
	awards_season = state.get("awards_season", 2011)
	changed_season = state.get("changed_season", false)
	setup_player_trees = state.get("setup_player_trees", false)
	expirings = state.get("expirings", [])
	negotiating = state.get("negotiating", false)

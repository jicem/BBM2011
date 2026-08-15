extends RefCounted
class_name Trade

var db : SQLite
var team_id : int

# 0 = player team
# 1 = cpu team
var offer = [{}, {}]

var payroll_after_trade = [0.0, 0.0]
var total = [0.0, 0.0]
var value = [0.0, 0.0]
var over_cap = [false, false]
var over_roster_limit = [false, false]
var ratios = [1.0, 1.0]
var team_names = ["", ""]

const SALARY_CAP = 90000000

func _init(database : SQLite, cpu_team : int):
	db = database
	team_id = cpu_team
	
func update():

	for team in [Global.team, team_id]:

		var i = 0
		var j = 1

		if team != Global.team:
			i = 1
			j = 0
		
		db.query("""
		SELECT
		    region || ' ' || ta.name AS team_name,
		    SUM(pa.contract_amount) AS payroll
		FROM team_attributes ta
		JOIN player_attributes pa
		    ON ta.team_id = pa.team_id
		WHERE
		    ta.team_id = %d
		    AND ta.season = %d
		    AND pa.contract_expiration >= %d
		""" % [team, Global.season + 2011, Global.season + 2011])

		var row = db.query_result[0]
		
		team_names[i] = row["team_name"]

		var payroll = float(row["payroll"])

		db.query("SELECT COUNT(*) cnt FROM player_attributes WHERE team_id=%d" % team)

		var roster_size = int(db.query_result[0]["cnt"])

		total[i]=0
		value[i]=0

		for player in offer[i].values():

			total[i]+=player.contract

			value[i]+=pow(
				10.0,
				player.potential/10.0
				+player.overall/20.0
				-player.age/10.0
				-player.contract/10000000.0
			)

		total[j]=0

		for player in offer[j].values():
			total[j]+=player.contract

		payroll_after_trade[i]=payroll-total[i]+total[j]

		over_cap[i]=payroll_after_trade[i]>SALARY_CAP

		over_roster_limit[i]=(
			roster_size
			-offer[i].size()
			+offer[j].size()
		)>15

		if total[i]>0:
			ratios[i]=(100.0*total[j])/total[i]
		elif total[j]>0:
			ratios[i]=INF
		else:
			ratios[i]=1

func add_player(side:int, player:Dictionary):

	offer[side][player.player_id]=player

func remove_player(side:int,id:int):

	offer[side].erase(id)

func clear_offer():

	offer=[{},{}]

func new_team(id):

	team_id=id
	offer[1]={}

func propose():

	if value[0] > value[1]*0.9:
		return [true,"Nice doing business with you!"]

	return [false,"What, are you crazy?"]

func process():

	for player in offer[0].values():

		db.query("""
        UPDATE player_attributes
        SET team_id=%d
        WHERE player_id=%d
		""" % [team_id,player.player_id])

	for player in offer[1].values():

		db.query("""
        UPDATE player_attributes
        SET team_id=%d
        WHERE player_id=%d
		""" % [Global.team,player.player_id])

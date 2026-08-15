SELECT
    pa.team_id,
    ta.name,
    AVG(pr.overall) AS average_overall
FROM player_attributes pa
INNER JOIN player_ratings pr
    ON pa.player_id = pr.player_id
INNER JOIN team_attributes ta
    ON pa.team_id = ta.team_id
WHERE pr.roster_position BETWEEN 0 AND 9
GROUP BY
    pa.team_id,
    ta.name
ORDER BY
    average_overall DESC;
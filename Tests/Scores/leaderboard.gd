extends Control

func _ready() -> void:
	LoudWolf.configure_api_key("CsCNpHfeeI4Tvt3u8y8Du6z1PzrWwkak6Y6YyWxY")
	LoudWolf.configure_game_id("examplegame1")
	await LoudWolf.Scores.get_scores()
	await LoudWolf.Scores.get_all_scores()
	await LoudWolf.Scores.get_scores_by_player("Angelator312")
	await LoudWolf.Scores.get_score_position(312)
	await LoudWolf.Scores.get_top_score_by_player("Angelator312")

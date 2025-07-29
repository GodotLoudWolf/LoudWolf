extends Node
class_name LoudWolfURLs

#URLs:
var api_url:="https://api.silentwolf.com/"

#Auth:
var create_new_player:=api_url+"create_new_player"
var confirm_verification_code:=api_url+"confirm_verif_code"
var resend_confirmation_code:=api_url+"resend_conf_code"
var login_player:=api_url+"login_player"
var request_player_password_reset:=api_url+"request_player_password_reset"
var reset_player_password:=api_url+"reset_player_password"
var get_player_details:=api_url+"get_player_details"
var validate_remember_me:=api_url+"validate_remember_me"

#Players:
var push_player_data:=api_url+"push_player_data"
var get_player_data:=api_url+"get_player_data"
var remove_player_data:=api_url+"remove_player_data"

#Scores:
var save_score:=api_url+"save_score"
var _get_scores:=api_url+"get_scores"
var get_scores_by_player:=api_url+ "get_scores_by_player"
var get_top_score_by_player:=api_url+"get_top_score_by_player"
var get_score_position:=api_url+"get_score_position"
var get_scores_around:=api_url+"get_scores_around"
var delete_score:=api_url+"delete_score"
var wipe_leadeboard:=api_url+"wipe_leaderboard"

func get_scores(maximum:int,ldboard_name:String,period_offset:int):
	return LoudWolf.URLs._get_scores+"/" + str(LoudWolf.config.game_id) + "?max=" + str(maximum)  + "&ldboard_name=" + str(ldboard_name) + "&period_offset=" + str(period_offset)

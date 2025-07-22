extends Node
class_name LoudWolfAutoload

const version := "0.0.1"
var godot_version :String= Engine.get_version_info().string
#Paths:
const plugin_path:="res://addons/loud_wolf/"
const modules_path:=plugin_path+"modules/"
const utils_path:=modules_path+"Utils/"
const scores_path:=modules_path+"Scores/"
const auth_path:=modules_path+"Auth/"
const examples_path:=plugin_path+"examples/"

#Example paths
const custom_leaderboards_example_path:=examples_path+"CustomLeaderboards/"

const SWUtils := preload(LoudWolf.utils_path+"SWUtils.gd")
const SWHashing := preload(LoudWolf.utils_path+"SWHashing.gd")
const SWLogger := preload(LoudWolf.utils_path+"SWLogger.gd")

@onready var Auth := LoudWolfAuth.new()
@onready var Scores := LoudWolfScores.new()
@onready var PlayerData := LoudWolfPlayerData.new()
@onready var Multiplayer := LoudWolfMultiplayer.new()

#
# LoudWolf config: THE CONFIG VARIABLES BELOW WILL BE OVERRIDED THE 
# NEXT TIME YOU UPDATE YOUR PLUGIN!
#
# As a best practice, use LoudWolf.configure functions from your game's code instead to set the LoudWolf configuration.
#
# See https://loudwolf.angelator312.top/docs/game_config for more details
#
var config := IGameConfig.new()

class IGameConfig:
	var api_key:="FmKF4gtm0Z2RbUAEU62kZ2OZoYLj4PYOURAPIKEY"
	var game_id:="YOURGAMEID"
	var version:="0.0.1"
	var log_level:=LogLevels.Info


var scores_config :IScoresConfig= IScoresConfig.new("res://scenes/Splash.tscn")

class IScoresConfig:
	var open_scene_on_close:String
	func _init(o_s_on_c:String):
		open_scene_on_close=o_s_on_c


var auth_config := IAuthConfig.new()

class IAuthConfig:
	var redirect_to_scene:= "res://scenes/Splash.tscn"
	var login_scene:= auth_path+"Login.tscn"
	var email_confirmation_scene:= auth_path+"ConfirmEmail.tscn"
	var reset_password_scene:= auth_path+"ResetPassword.tscn"
	var session_duration_seconds:= 0
	var saved_session_expiration_days:= 30


func _init():
	print("SW Init timestamp: " + str(SWUtils.get_timestamp()))


func _ready():
	# The following line would keep LoudWolf working even if the game tree is paused.
	#pause_mode = Node.PAUSE_MODE_PROCESS
	print("SW ready start timestamp: " + str(SWUtils.get_timestamp()))
	add_child(Auth)
	add_child(Scores)
	add_child(PlayerData)
	#add_child(Multiplayer)
	print("SW ready end timestamp: " + str(SWUtils.get_timestamp()))

## @deprecated use configure_api_key, configure_game_id, configure_log_level
func configure(json_config:IGameConfig):
	config = json_config


func configure_api_key(api_key:String):
	config.apiKey = api_key


func configure_game_id(game_id:String):
	config.game_id = game_id


func configure_game_version(game_version:String):
	config.game_version = game_version


##################################################################
# Log levels:
##################################################################
enum LogLevels{
	## only log errors
	Error=0,
	# log errors and the main actions taken by the LoudWolf plugin - default setting
	Info=1,
	# detailed logs, including the above and much more, to be used when investigating a problem. This shouldn't be the default setting in production.
	Debug=2
}
func configure_log_level(log_level:LogLevels):
	config.log_level = log_level


func configure_scores(json_scores_config:IScoresConfig):
	scores_config = json_scores_config


func configure_scores_open_scene_on_close(scene:String):
	scores_config.open_scene_on_close = scene

## @deprecated use configure_auth_ functions
func configure_auth(json_auth_config:IAuthConfig):
	auth_config = json_auth_config


func configure_auth_redirect_to_scene(scene):
	auth_config.open_scene_on_close = scene


func configure_auth_session_duration(duration):
	auth_config.session_duration = duration


func free_request(weak_ref, object):
	if (weak_ref.get_ref()):
		object.queue_free()


class IPrepareHTTPRequest:
	var request:HTTPRequest
	var weakref
	func _init(r:HTTPRequest,wr):
		request=r
		weakref=wr

func prepare_http_request() -> IPrepareHTTPRequest:
	var request := HTTPRequest.new()
	var weakref := weakref(request)
	if OS.get_name() != "Web":
		request.set_use_threads(true)
	request.process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().get_root().call_deferred("add_child", request)
	var return_dict = IPrepareHTTPRequest.new(request, weakref)
	return return_dict


func send_get_request(http_node: HTTPRequest, request_url: String)->void:
	var headers:Array[String] = [
		"x-api-key: " + LoudWolf.config.api_key, 
		"x-sw-game-id: " + LoudWolf.config.game_id,
		"x-sw-plugin-version: " + LoudWolf.version,
		"x-sw-godot-version: " + godot_version 
	]
	headers = add_jwt_token_headers(headers)
	print("GET headers: " + str(headers))
	if !http_node.is_inside_tree():
		await get_tree().create_timer(0.01).timeout
	SWLogger.debug("Method: GET")
	SWLogger.debug("request_url: " + str(request_url))
	SWLogger.debug("headers: " + str(headers))
	http_node.request(request_url, headers) 


func send_post_request(http_node:HTTPRequest, request_url:String, payload) -> void:
	## Declare HTTP Headers, every element is stringified header 
	var headers :Array[String]= [
		"Content-Type: application/json", 
		"x-api-key: " + LoudWolf.config.api_key, 
		"x-sw-game-id: " + LoudWolf.config.game_id,
		"x-sw-plugin-version: " + LoudWolf.version,
		"x-sw-godot-version: " + godot_version 
	]
	headers = add_jwt_token_headers(headers)
	print("POST headers: " + str(headers))
	# TODO: This should in fact be the case for all POST requests, make the following code more generic
	#var post_request_paths: Array[String] = ["post_new_score", "push_player_data"]
	var paths_with_values_to_hash: Dictionary = {
		"save_score": ["player_name", "score"],
		"push_player_data": ["player_name", "player_data"]
	}
	## Made headers
	for path in paths_with_values_to_hash:
		var values_to_hash = []
		if check_string_in_url(path, request_url):
			SWLogger.debug("Computing hash for " + str(path))
			var fields_to_hash = paths_with_values_to_hash[path]
			for field in fields_to_hash:
				var value = payload[field]
				# if the data is a dictionary (e.g. player data, stringify it before hashing)
				if typeof(payload[field]) == TYPE_DICTIONARY:
					value = JSON.stringify(payload[field])
				values_to_hash.append_array([value])
			var timestamp = SWUtils.get_timestamp()
			values_to_hash = values_to_hash + [timestamp]
			SWLogger.debug(str(path) + " to_be_hashed: " + str(values_to_hash))
			var hashed = SWHashing.hash_values(values_to_hash)
			SWLogger.debug("hash value: " + str(hashed))
			headers.append("x-sw-act-tmst: " + str(timestamp))
			headers.append("x-sw-act-dig: " + hashed)
			break
	var use_ssl = true
	if !http_node.is_inside_tree():
		await get_tree().create_timer(0.01).timeout
	var query = JSON.stringify(payload)
	SWLogger.debug("Method: POST")
	SWLogger.debug("request_url: " + str(request_url))
	SWLogger.debug("headers: " + str(headers))
	SWLogger.debug("query: " + str(query))
	## Send to request_url the headers and query
	http_node.request(request_url, headers, HTTPClient.METHOD_POST, query)

## Appends headers for Auth.sw_id_token and Auth.sw_access_token
func add_jwt_token_headers(headers: Array[String]) -> Array[String]:
	if Auth.sw_id_token != null:
		headers.append("x-sw-id-token: " + Auth.sw_id_token)
	if Auth.sw_access_token != null:
		headers.append("x-sw-access-token: " + Auth.sw_access_token)
	return headers

## Check is the @param test_string in @param url
func check_string_in_url(test_string: String, url: String) -> bool:
	return test_string in url


func build_result(body: Dictionary) -> IBuildResult:
	var res=IBuildResult.new()
	if "error" in body:
		res.error = body.error
	if "success" in body:
		res.success = body.success
	return res

class IBuildResult:
	var error
	var success


## Awaits for Auth to exist 
func check_auth_ready():
	if !Auth:
		await get_tree().create_timer(0.01).timeout


func check_scores_ready():
	if !Scores:
		await get_tree().create_timer(0.01).timeout


func check_player_data_ready():
	if !PlayerData:
		await get_tree().create_timer(0.01).timeout


func check_multiplayer_ready():
	if !Multiplayer:
		await get_tree().create_timer(0.01).timeout


## Awaits for all modules to exist 
func check_sw_ready():
	if !Auth or !Scores or !PlayerData or !Multiplayer:
		await get_tree().create_timer(0.01).timeout

extends Node
class_name LoudWolfAutoload

const version := "0.0.1"
var godot_version :String= Engine.get_version_info().string
#Paths:
const plugin_path:="res://addons/loud_wolf/"
const modules_path:=plugin_path+"modules/"
const utils_path:=plugin_path+"utils/"
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
@onready var Players := LoudWolfPlayers.new()
@onready var Multiplayer := LoudWolfMultiplayer.new()

#
# LoudWolf CONFIG: THE CONFIG VARIABLES BELOW WILL BE OVERRIDED THE 
# NEXT TIME YOU UPDATE YOUR PLUGIN!
#
# As a best practice, use LoudWolf.configure from your game's
# code instead to set the LoudWolf configuration.
#
# See https://loudwolf.angelator312.top for more details
#
var config = {
	"api_key": "FmKF4gtm0Z2RbUAEU62kZ2OZoYLj4PYOURAPIKEY",
	"game_id": "YOURGAMEID",
	"log_level": 0
}

var scores_config :Dictionary= {
	"open_scene_on_close": "res://scenes/Splash.tscn"
}

var auth_config = {
	"redirect_to_scene": "res://scenes/Splash.tscn",
	"login_scene": auth_path+"Login.tscn",
	"email_confirmation_scene": auth_path+"ConfirmEmail.tscn",
	"reset_password_scene": auth_path+"ResetPassword.tscn",
	"session_duration_seconds": 0,
	"saved_session_expiration_days": 30
}


func _init():
	print("SW Init timestamp: " + str(SWUtils.get_timestamp()))


func _ready():
	# The following line would keep LoudWolf working even if the game tree is paused.
	#pause_mode = Node.PAUSE_MODE_PROCESS
	print("SW ready start timestamp: " + str(SWUtils.get_timestamp()))
	add_child(Auth)
	add_child(Scores)
	add_child(Players)
	#Multiplayer.set_script(multiplayer_script)
	#add_child(Multiplayer)
	print("SW ready end timestamp: " + str(SWUtils.get_timestamp()))


func configure(json_config):
	config = json_config


func configure_api_key(api_key):
	config.apiKey = api_key


func configure_game_id(game_id):
	config.game_id = game_id


func configure_game_version(game_version):
	config.game_version = game_version


##################################################################
# Log levels:
# 0 - error (only log errors)
# 1 - info (log errors and the main actions taken by the LoudWolf plugin) - default setting
# 2 - debug (detailed logs, including the above and much more, to be used when investigating a problem). This shouldn't be the default setting in production.
##################################################################
func configure_log_level(log_level):
	config.log_level = log_level


func configure_scores(json_scores_config):
	scores_config = json_scores_config


func configure_scores_open_scene_on_close(scene):
	scores_config.open_scene_on_close = scene


func configure_auth(json_auth_config):
	auth_config = json_auth_config


func configure_auth_redirect_to_scene(scene):
	auth_config.open_scene_on_close = scene


func configure_auth_session_duration(duration):
	auth_config.session_duration = duration


func free_request(weak_ref, object):
	if (weak_ref.get_ref()):
		object.queue_free()


func prepare_http_request() -> Dictionary:
	var request = HTTPRequest.new()
	var weakref = weakref(request)
	if OS.get_name() != "Web":
		request.set_use_threads(true)
	request.process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().get_root().call_deferred("add_child", request)
	var return_dict = {
		"request": request, 
		"weakref": weakref
	}
	return return_dict


func send_get_request(http_node: HTTPRequest, request_url: String):
	var headers = [
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


func send_post_request(http_node, request_url, payload):
	var headers = [
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
				values_to_hash = values_to_hash + [value]
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
	http_node.request(request_url, headers, HTTPClient.METHOD_POST, query)


func add_jwt_token_headers(headers: Array) -> Array:
	if Auth.sw_id_token != null:
		headers.append("x-sw-id-token: " + Auth.sw_id_token)
	if Auth.sw_access_token != null:
		headers.append("x-sw-access-token: " + Auth.sw_access_token)
	return headers


func check_string_in_url(test_string: String, url: String) -> bool:
	return test_string in url


func build_result(body: Dictionary) -> Dictionary:
	var error = null
	var success = false
	if "error" in body:
		error = body.error
	if "success" in body:
		success = body.success
	return {
		"success": success,
		"error": error
	}


func check_auth_ready():
	if !Auth:
		await get_tree().create_timer(0.01).timeout


func check_scores_ready():
	if !Scores:
		await get_tree().create_timer(0.01).timeout


func check_players_ready():
	if !Players:
		await get_tree().create_timer(0.01).timeout


func check_multiplayer_ready():
	if !Multiplayer:
		await get_tree().create_timer(0.01).timeout


func check_sw_ready():
	if !Auth or !Scores or !Players or !Multiplayer:
		await get_tree().create_timer(0.01).timeout

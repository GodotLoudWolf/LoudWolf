extends Node
class_name LoudWolfAuth

const SWLocalFileStorage = preload(LoudWolf.utils_path+"SWLocalFileStorage.gd")
const SWUtils = preload(LoudWolf.utils_path+"SWUtils.gd")
const SWLogger = preload(LoudWolf.utils_path+"SWLogger.gd")
const UUID = preload(LoudWolf.utils_path+"UUID.gd")

signal sw_login_complete
signal sw_logout_complete
signal sw_registration_complete
signal sw_registration_user_pwd_complete
signal sw_email_verif_complete
signal sw_resend_conf_code_complete
signal sw_session_check_complete
signal sw_request_password_reset_complete
signal sw_reset_password_complete
signal sw_get_player_details_complete

var tmp_username = null
var logged_in_player = null
var logged_in_player_email = null
var logged_in_anon = false
var sw_access_token = null
var sw_id_token = null

#HTTP Request Nodes:
var RegisterPlayer:HTTPRequest = null
var VerifyEmail:HTTPRequest = null
var ResendConfCode:HTTPRequest = null
var LoginPlayer :HTTPRequest= null
var ValidateSession:HTTPRequest = null
var RequestPasswordReset:HTTPRequest = null
var ResetPassword:HTTPRequest = null
var GetPlayerDetails:HTTPRequest = null

# wekrefs
var wrRegisterPlayer = null
var wrVerifyEmail = null
var wrResendConfCode = null
var wrLoginPlayer = null
var wrValidateSession = null
var wrRequestPasswordReset = null
var wrResetPassword = null
var wrGetPlayerDetails = null

var login_timeout = 0
var login_timer = null

var complete_session_check_wait_timer


func register_player_anon(player_name = null) -> Node:
	var user_local_id: String = get_anon_user_id()
	var prepared_http_req = LoudWolf.prepare_http_request()
	RegisterPlayer = prepared_http_req.request
	wrRegisterPlayer = prepared_http_req.weakref
	RegisterPlayer.request_completed.connect(_on_RegisterPlayer_request_completed)
	SWLogger.info("Calling LoudWolf to register an anonymous player")
	var payload = { "game_id": LoudWolf.config.game_id, "anon": true, "player_name": player_name, "user_local_id": user_local_id }
	var request_url =  LoudWolf.URLs.create_new_player
	LoudWolf.send_post_request(RegisterPlayer, request_url, payload)
	return self


func register_player(player_name: String, email: String, password: String, confirm_password: String) -> Node:
	tmp_username = player_name
	var prepared_http_req = LoudWolf.prepare_http_request()
	RegisterPlayer = prepared_http_req.request
	wrRegisterPlayer = prepared_http_req.weakref
	RegisterPlayer.request_completed.connect(_on_RegisterPlayer_request_completed)
	SWLogger.info("Calling LoudWolf to register a player")
	var payload = { "game_id": LoudWolf.config.game_id, "anon": false, "player_name": player_name, "email":  email, "password": password, "confirm_password": confirm_password }
	var request_url =  LoudWolf.URLs.create_new_player
	LoudWolf.send_post_request(RegisterPlayer, request_url, payload)
	return self


func _on_RegisterPlayer_request_completed(result, response_code, headers, body) -> void:
	var status_check = SWUtils.check_http_response(response_code, headers, body)
	LoudWolf.free_request(wrRegisterPlayer, RegisterPlayer)
	
	if status_check:
		var json_body = JSON.parse_string(body.get_string_from_utf8())
		# also get a JWT token here, when available in backend
		# send a different signal depending on registration success or failure
		var sw_result: LoudWolf.IBuildResult = LoudWolf.build_result(json_body)
		if json_body.success:
			SWLogger.info("LoudWolf register player success, player_name: " + str(json_body.player_name))
			#sw_token = json_body.swtoken
			var anon = json_body.anon
			if anon:
				SWLogger.info("Anonymous Player registration succeeded")
				logged_in_anon = true
				if 'player_name' in json_body:
					logged_in_player = json_body.player_name
				elif 'player_local_id' in json_body: 
					logged_in_player = str("anon##" + json_body.player_local_id)
				else:
					logged_in_player = "anon##unknown"
				SWLogger.info("Anonymous registration, logged in player: " + str(logged_in_player))
			else: 
				# if email confirmation is enabled for the game, we can't log in the player just yet
				var email_conf_enabled = json_body.email_conf_enabled
				if email_conf_enabled:
					SWLogger.info("Player registration succeeded, but player still needs to verify email address")
				else:
					SWLogger.info("Player registration succeeded, email verification is disabled")
					logged_in_player = tmp_username
		else:
			SWLogger.error("LoudWolf player registration failure: " + str(json_body.error))
		sw_registration_complete.emit(sw_result)


func register_player_user_password(player_name: String, password: String, confirm_password: String) -> Node:
	var prepared_http_req = LoudWolf.prepare_http_request()
	RegisterPlayer = prepared_http_req.request
	wrRegisterPlayer = prepared_http_req.weakref
	RegisterPlayer.request_completed.connect(_on_RegisterPlayerUserPassword_request_completed)
	SWLogger.info("Calling LoudWolf to register a player")
	var payload = { "game_id": LoudWolf.config.game_id, "player_name": player_name, "password": password, "confirm_password": confirm_password }
	var request_url =  LoudWolf.URLs.create_new_player
	LoudWolf.send_post_request(RegisterPlayer, request_url, payload)
	return self


func _on_RegisterPlayerUserPassword_request_completed(result, response_code, headers, body) -> void:
	var status_check = SWUtils.check_http_response(response_code, headers, body)
	#RegisterPlayer.queue_free()
	LoudWolf.free_request(wrRegisterPlayer, RegisterPlayer)
	
	if status_check:
		var json_body = JSON.parse_string(body.get_string_from_utf8())
		# also get a JWT token here
		# send a different signal depending on registration success or failure
		var sw_result: LoudWolf.IBuildResult = LoudWolf.build_result(json_body)
		if json_body.success:
			# if email confirmation is enabled for the game, we can't log in the player just yet
			var email_conf_enabled = json_body.email_conf_enabled
			SWLogger.info("Player registration with username/password succeeded, player account autoconfirmed.")
			logged_in_player = tmp_username
		else:
			SWLogger.error("LoudWolf username/password player registration failure: " + str(json_body.error))
		sw_registration_user_pwd_complete.emit(sw_result)


func verify_email(player_name: String, code: String) -> Node:
	var prepared_http_req = LoudWolf.prepare_http_request()
	VerifyEmail = prepared_http_req.request
	wrVerifyEmail = prepared_http_req.weakref
	VerifyEmail.request_completed.connect(_on_VerifyEmail_request_completed)
	SWLogger.info("Calling LoudWolf to verify email address for: " + str(player_name))
	var payload = { "game_id": LoudWolf.config.game_id, "username":  player_name, "code": code }
	var request_url = LoudWolf.URLs.confirm_verification_code
	LoudWolf.send_post_request(VerifyEmail, request_url, payload)
	return self


func _on_VerifyEmail_request_completed(result, response_code, headers, body) -> void:
	var status_check = SWUtils.check_http_response(response_code, headers, body)
	LoudWolf.free_request(wrVerifyEmail, VerifyEmail)
	
	if status_check:
		var json_body = JSON.parse_string(body.get_string_from_utf8())
		SWLogger.info("LoudWolf verify email success? : " + str(json_body.success))
		# also get a JWT token here
		# send a different signal depending on registration success or failure
		var sw_result: LoudWolf.IBuildResult = LoudWolf.build_result(json_body)
		if json_body.success:
			SWLogger.info("LoudWolf email verification success.")
			logged_in_player  = tmp_username
		else:
			SWLogger.error("LoudWolf email verification failure: " + str(json_body.error))
		sw_email_verif_complete.emit(sw_result)


func resend_conf_code(player_name: String) -> Node:
	var prepared_http_req = LoudWolf.prepare_http_request()
	ResendConfCode = prepared_http_req.request
	wrResendConfCode = prepared_http_req.weakref
	ResendConfCode.request_completed.connect(_on_ResendConfCode_request_completed)
	SWLogger.info("Calling LoudWolf to resend confirmation code for: " + str(player_name))
	var payload = { "game_id": LoudWolf.config.game_id, "username": player_name }
	var request_url = LoudWolf.URLs.resend_confirmation_code
	LoudWolf.send_post_request(ResendConfCode, request_url, payload)
	return self


func _on_ResendConfCode_request_completed(result, response_code, headers, body) -> void:
	SWLogger.info("ResendConfCode request completed")
	var status_check = SWUtils.check_http_response(response_code, headers, body)
	LoudWolf.free_request(wrResendConfCode, ResendConfCode)
	
	if status_check:
		var json_body = JSON.parse_string(body.get_string_from_utf8())
		# also get a JWT token here
		# send a different signal depending on registration success or failure
		var sw_result: LoudWolf.IBuildResult = LoudWolf.build_result(json_body)
		if json_body.success:
			SWLogger.info("LoudWolf resend conf code success.")
		else:
			SWLogger.error("LoudWolf resend conf code failure: " + str(json_body.error))
		sw_resend_conf_code_complete.emit(sw_result)


func login_player(username: String, password: String, remember_me:bool=false) -> Node:
	tmp_username = username
	var prepared_http_req = LoudWolf.prepare_http_request()
	LoginPlayer = prepared_http_req.request
	wrLoginPlayer = prepared_http_req.weakref
	LoginPlayer.request_completed.connect(_on_LoginPlayer_request_completed)
	SWLogger.info("Calling LoudWolf to log in a player")
	var payload = { "game_id": LoudWolf.config.game_id, "username": username, "password": password, "remember_me": str(remember_me) }
	if LoudWolf.auth_config.has("saved_session_expiration_days") and typeof(LoudWolf.auth_config.saved_session_expiration_days) == 2:
		payload["remember_me_expires_in"] = str(LoudWolf.auth_config.saved_session_expiration_days)
	var payload_for_logging = payload
	var obfuscated_password = SWUtils.obfuscate_string(payload["password"])
	print("obfuscated password: " + str(obfuscated_password))
	payload_for_logging["password"] = obfuscated_password
	SWLogger.debug("LoudWolf login player payload: " + str(payload_for_logging))
	var request_url = LoudWolf.URLs.login_player
	LoudWolf.send_post_request(LoginPlayer, request_url, payload)
	return self


func _on_LoginPlayer_request_completed(result, response_code, headers, body) -> void:
	var status_check = SWUtils.check_http_response(response_code, headers, body)
	LoudWolf.free_request(wrLoginPlayer, LoginPlayer)
	
	if status_check:
		var json_body = JSON.parse_string(body.get_string_from_utf8())
		if "lookup" in json_body.keys():
			SWLogger.debug("remember me lookup: " + str(json_body.lookup))
			save_session(json_body.lookup, json_body.validator)
		if "validator" in json_body.keys():
			SWLogger.debug("remember me validator: " + str(json_body.validator))
		# send a different signal depending on login success or failure
		var sw_result: LoudWolf.IBuildResult = LoudWolf.build_result(json_body)
		if json_body.success:
			SWLogger.info("LoudWolf resend conf code success.")
			sw_access_token = json_body.swtoken
			sw_id_token = json_body.swidtoken
			set_player_logged_in(tmp_username)
		else:
			SWLogger.error("LoudWolf login player failure: " + str(json_body.error))
		sw_login_complete.emit(sw_result)


func logout_player() -> void:
	logged_in_player = null
	# remove any player data if present
	LoudWolf.Players.clear_player_data()
	# remove stored session if any
	var delete_success = remove_stored_session()
	print("delete_success: " + str(delete_success))
	sw_access_token = null
	sw_id_token = null
	sw_logout_complete.emit(true, "")


func request_player_password_reset(player_name: String) -> Node:
	var prepared_http_req = LoudWolf.prepare_http_request()
	RequestPasswordReset = prepared_http_req.request
	wrRequestPasswordReset = prepared_http_req.weakref
	RequestPasswordReset.request_completed.connect(_on_RequestPasswordReset_request_completed)
	SWLogger.info("Calling LoudWolf to request a password reset for: " + str(player_name))
	var payload = { "game_id": LoudWolf.config.game_id, "player_name": player_name }
	SWLogger.debug("LoudWolf request player password reset payload: " + str(payload))
	var request_url = LoudWolf.URLs.request_player_password_reset
	LoudWolf.send_post_request(RequestPasswordReset, request_url, payload)
	return self


func _on_RequestPasswordReset_request_completed(result, response_code, headers, body) -> void:
	SWLogger.info("RequestPasswordReset request completed")
	var status_check = SWUtils.check_http_response(response_code, headers, body)
	LoudWolf.free_request(wrRequestPasswordReset, RequestPasswordReset)
	
	if status_check:
		var json_body = JSON.parse_string(body.get_string_from_utf8())
		var sw_result: LoudWolf.IBuildResult = LoudWolf.build_result(json_body)
		if json_body.success:
			SWLogger.info("LoudWolf request player password reset success.")
		else:
			SWLogger.error("LoudWolf request password reset failure: " + str(json_body.error))
		sw_request_password_reset_complete.emit(sw_result)


func reset_player_password(player_name: String, conf_code: String, new_password: String, confirm_password: String) -> Node:
	var prepared_http_req = LoudWolf.prepare_http_request()
	ResetPassword = prepared_http_req.request
	wrResetPassword = prepared_http_req.weakref
	ResetPassword.request_completed.connect(_on_ResetPassword_completed)
	SWLogger.info("Calling LoudWolf to reset password for: " + str(player_name))
	var payload = { "game_id": LoudWolf.config.game_id, "player_name": player_name, "conf_code": conf_code, "password": new_password, "confirm_password": confirm_password }
	SWLogger.debug("LoudWolf request player password reset payload: " + str(payload))
	var request_url = LoudWolf.URLs.reset_player_password
	LoudWolf.send_post_request(ResetPassword, request_url, payload)
	return self


func _on_ResetPassword_completed(result, response_code, headers, body) -> void:
	var status_check = SWUtils.check_http_response(response_code, headers, body)
	LoudWolf.free_request(wrResetPassword, ResetPassword)

	if status_check:
		var json_body = JSON.parse_string(body.get_string_from_utf8())
		var sw_result: LoudWolf.IBuildResult = LoudWolf.build_result(json_body)
		if json_body.success:
			SWLogger.info("LoudWolf reset player password success.")
		else:
			SWLogger.error("LoudWolf reset password failure: " + str(json_body.error))
		sw_reset_password_complete.emit(sw_result)


func get_player_details(player_name: String) -> Node:
	var prepared_http_req = LoudWolf.prepare_http_request()
	GetPlayerDetails = prepared_http_req.request
	wrGetPlayerDetails = prepared_http_req.weakref
	GetPlayerDetails.request_completed.connect(_on_GetPlayerDetails_request_completed)
	SWLogger.info("Calling LoudWolf to get player details")
	var payload = { "game_id": LoudWolf.config.game_id, "player_name": player_name }
	var request_url =LoudWolf.URLs.get_player_details
	LoudWolf.send_post_request(GetPlayerDetails, request_url, payload)
	return self


func _on_GetPlayerDetails_request_completed(result, response_code, headers, body) -> void:
	var status_check = SWUtils.check_http_response(response_code, headers, body)
	LoudWolf.free_request(wrGetPlayerDetails, GetPlayerDetails)
	
	if status_check:
		var json_body = JSON.parse_string(body.get_string_from_utf8())
		var sw_result: LoudWolf.IBuildResult = LoudWolf.build_result(json_body)
		if json_body.success:
			SWLogger.info("LoudWolf get player details success: " + str(json_body.player_details))
			sw_result["player_details"] = json_body.player_details
		else:
			SWLogger.error("LoudWolf get player details failure: " + str(json_body.error))
		sw_get_player_details_complete.emit(sw_result)


func validate_player_session(lookup: String, validator: String, scene: Node=get_tree().get_current_scene()) -> Node:
	var prepared_http_req = LoudWolf.prepare_http_request()
	ValidateSession = prepared_http_req.request
	wrValidateSession = prepared_http_req.weakref
	ValidateSession.request_completed.connect(_on_ValidateSession_request_completed)
	SWLogger.info("Calling LoudWolf to validate an existing player session")
	var payload = { "game_id": LoudWolf.config.game_id, "lookup": lookup, "validator": validator }
	SWLogger.debug("Validate session payload: " + str(payload))
	var request_url = LoudWolf.URLs.validate_remember_me
	LoudWolf.send_post_request(ValidateSession, request_url, payload)
	return self


func _on_ValidateSession_request_completed(result, response_code, headers, body) -> void:
	var status_check = SWUtils.check_http_response(response_code, headers, body)
	LoudWolf.free_request(wrValidateSession, ValidateSession)
	
	if status_check:
		var json_body = JSON.parse_string(body.get_string_from_utf8())
		var sw_result: LoudWolf.IBuildResult = LoudWolf.build_result(json_body)
		if json_body.success:
			SWLogger.info("LoudWolf validate session success.")	
			set_player_logged_in(json_body.player_name)
			sw_result["logged_in_player"] = logged_in_player
		else:
			SWLogger.error("LoudWolf validate session failure: " + str(json_body.error))
		complete_session_check(sw_result)


func auto_login_player() -> Node:
	var sw_session_data = load_session()
	SWLogger.debug("SW session data " + str(sw_session_data))
	if sw_session_data:
		SWLogger.debug("Found saved LoudWolf session data, attempting autologin...")
		var lookup = sw_session_data.lookup
		var validator = sw_session_data.validator
		# whether successful or not, in the end the "sw_session_check_complete" signal will be emitted
		validate_player_session(lookup, validator)
	else:
		SWLogger.debug("No saved LoudWolf session data, so no autologin will be performed")
		# the following is needed to delay the emission of the signal just a little bit, otherwise the signal is never received!
		setup_complete_session_check_wait_timer()
		complete_session_check_wait_timer.start()
	return self


func set_player_logged_in(player_name: String) -> void:
	logged_in_player  = player_name
	SWLogger.info("LoudWolf - player logged in as " + str(player_name))
	if LoudWolf.auth_config.has("session_duration_seconds") and typeof(LoudWolf.auth_config.session_duration_seconds) == 2:
		login_timeout = LoudWolf.auth_config.session_duration_seconds
	else:
		login_timeout = 0
	SWLogger.info("LoudWolf login timeout: " + str(login_timeout))
	if login_timeout != 0:
		setup_login_timer()


func get_anon_user_id() -> String:
	var anon_user_id = OS.get_unique_id()
	if anon_user_id == '':
		anon_user_id = UUID.generate_uuid_v4()
	print("anon_user_id: " + str(anon_user_id))
	return anon_user_id


func remove_stored_session() -> bool:
	var path = "user://swsession.save"
	var delete_success = SWLocalFileStorage.remove_data(path, "Removing LoudWolf session if any: " )
	return delete_success


# Signal can't be emitted directly from auto_login_player() function
# otherwise it won't connect back to calling script
func complete_session_check(sw_result=null) -> void:
	SWLogger.debug("LoudWolf: completing session check")
	sw_session_check_complete.emit(sw_result)


func setup_complete_session_check_wait_timer() -> void:
	complete_session_check_wait_timer = Timer.new()
	complete_session_check_wait_timer.set_one_shot(true)
	complete_session_check_wait_timer.set_wait_time(0.01)
	complete_session_check_wait_timer.timeout.connect(complete_session_check)
	add_child(complete_session_check_wait_timer)


func setup_login_timer() -> void:
	login_timer = Timer.new()
	login_timer.set_one_shot(true)
	login_timer.set_wait_time(login_timeout)
	login_timer.timeout.connect(on_login_timeout_complete)
	add_child(login_timer)


func on_login_timeout_complete() -> void:
	logout_player()


# store lookup (not logged in player name) and validator in local file
func save_session(lookup: String, validator: String) -> void:
	SWLogger.debug("Saving session, lookup: " + str(lookup) + ", validator: " + str(validator))
	var path = "user://swsession.save"
	var session_data: Dictionary = {
		"lookup": lookup,
		"validator": validator
	}
	SWLocalFileStorage.save_data("user://swsession.save", session_data, "Saving LoudWolf session: ")


# reload lookup and validator and send them back to the server to auto-login user
func load_session() -> Dictionary:
	var sw_session_data = null
	var path = "user://swsession.save"
	sw_session_data = SWLocalFileStorage.get_data(path)
	if sw_session_data == null:
		SWLogger.debug("No local LoudWolf session stored, or session data stored in incorrect format")
	SWLogger.info("Found session data: " + str(sw_session_data))
	return sw_session_data

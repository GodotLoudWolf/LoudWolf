extends TextureRect

const SWLogger = preload("../utils/SWLogger.gd")


func _ready():
	LoudWolf.Auth.sw_email_verif_complete.connect(_on_confirmation_complete)
	LoudWolf.Auth.sw_resend_conf_code_complete.connect(_on_resend_code_complete)


func _on_confirmation_complete(sw_result: Dictionary) -> void:
	if sw_result.success:
		confirmation_success()
	else:
		confirmation_failure(sw_result.error)


func confirmation_success() -> void:
	SWLogger.info("email verification succeeded: " + str(LoudWolf.Auth.logged_in_player))
	# redirect to configured scene (user is logged in after registration)
	var scene_name = LoudWolf.auth_config.redirect_to_scene
	get_tree().change_scene_to_file(scene_name)


func confirmation_failure(error: String) -> void:
	hide_processing_label()
	SWLogger.info("email verification failed: " + str(error))
	$"FormContainer/ErrorMessage".text = error
	$"FormContainer/ErrorMssage".show()
	

func _on_resend_code_complete(sw_result: Dictionary) -> void:
	if sw_result.success:
		resend_code_success()
	else:
		resend_code_failure()


func resend_code_success() -> void:
	SWLogger.info("Code resend succeeded for player: " + str(LoudWolf.Auth.tmp_username))
	$"FormContainer/ErrorMessage".text = "Confirmation code was resent to your email address. Please check your inbox (and your spam)."
	$"FormContainer/ErrorMessage".show()


func resend_code_failure() -> void:
	SWLogger.info("Code resend failed for player: " + str(LoudWolf.Auth.tmp_username))
	$"FormContainer/ErrorMessage".text = "Confirmation code could not be resent"
	$"FormContainer/ErrorMessage".show()


func show_processing_label() -> void:
	$"FormContainer/ProcessingLabel".show()


func hide_processing_label() -> void:
	$"FormContainer/ProcessingLabel".hide()


func _on_ConfirmButton_pressed() -> void:
	var username = LoudWolf.Auth.tmp_username
	var code = $"FormContainer/CodeContainer/VerifCode".text
	SWLogger.debug("Email verification form submitted, code: " + str(code))
	LoudWolf.Auth.verify_email(username, code)
	show_processing_label()


func _on_ResendConfCodeButton_pressed() -> void:
	var username = LoudWolf.Auth.tmp_username
	SWLogger.debug("Requesting confirmation code resend")
	LoudWolf.Auth.resend_conf_code(username)
	show_processing_label()

extends Node

const SWUtils = preload(LoudWolf.utils_path+"SWUtils.gd")
	
static func error(text):
	printerr(str(text))
	push_error(str(text))

static func info(text):
	if LoudWolf.log_level > 0:
		print(str(text))
	
static func debug(text):
	if LoudWolf.log_level > 1:
		print(str(text))
		
static func log_time(log_text, log_level='INFO'):
	var timestamp = SWUtils.get_timestamp()
	if log_level == 'ERROR':
		error(log_text + ": " + str(timestamp))
	elif log_level == 'INFO':
		info(log_text + ": " + str(timestamp))
	else:
		debug(log_text + ": " + str(timestamp))

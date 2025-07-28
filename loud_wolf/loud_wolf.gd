@tool
extends EditorPlugin

func _enter_tree():
	add_autoload_singleton("LoudWolf", "LoudWolf.gd")

func _exit_tree():
	remove_autoload_singleton("LoudWolf")

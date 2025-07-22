extends Control

const SCORE_ITEM = preload("res://docsExamples/tutorials/GetStarted/AddLeaderboard/score_item.tscn")
@onready var container: VBoxContainer = $M/Container
@onready var player_name: LineEdit = %PlayerName
@onready var score: LineEdit = %Score

func _ready() -> void:
	LoudWolf.configure_api_key("CsCNpHfeeI4Tvt3u8y8Du6z1PzrWwkak6Y6YyWxY")
	LoudWolf.configure_game_id("examplegame1")
	make_scores()

func make_scores():
	await LoudWolf.Scores.get_scores(0).sw_get_scores_complete
	var i:=0
	for score in LoudWolf.Scores.scores:
		add_item(score,i)
		i+=1

func add_item(score,i:int):
	var e:=SCORE_ITEM.instantiate()
	e.order_idx=i
	e.player_name=score.player_name
	e.score=score.score
	container.add_child(e)
	container.move_child(e,-2)

func delete_scores():
	for e in container.get_children():
		if e.name!="ContainerForAdd":
			e.queue_free()

func _on_add_score_pressed() -> void:
	await LoudWolf.Scores.save_score(player_name.text,score.text).sw_save_score_complete
	delete_scores()
	make_scores()

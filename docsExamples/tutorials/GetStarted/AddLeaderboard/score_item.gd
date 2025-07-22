extends Control
@export var order_idx:int:
	set(e):
		order_idx=e
		$Order.text=str(e)+"."
@export var player_name:String:
	set(e):
		player_name=e
		$Name.text=e
@export var score:float:
	set(e):
		score=e
		$Score.text=str(e)

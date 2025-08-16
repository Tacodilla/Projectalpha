extends CanvasLayer

@onready var hp_label: Label = $HBoxContainer/PlayerHPLabel
@onready var enemy_label: Label = $HBoxContainer/EnemyCountLabel

var player: Node = null

func _ready():
	player = get_tree().get_first_node_in_group("player")
	_update_labels()

func _process(_delta):
	_update_labels()

func _update_labels():
	if is_instance_valid(player):
		# Your player script defines `health` and `max_health`, so just read them.
		hp_label.text = "HP: %d/%d" % [int(player.health), int(player.max_health)]
	else:
		hp_label.text = "HP: ?/?"

	var enemies := get_tree().get_nodes_in_group("enemy").size()
	enemy_label.text = "Enemies: %d" % enemies

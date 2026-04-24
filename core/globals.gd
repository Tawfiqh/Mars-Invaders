extends Node

var points := 0
var lives := 3

const NAME_POOL: Array[String] = [
	"Orion", "Vega", "Sirius", "Rigel", "Altair",
	"Cygnus", "Draco", "Nova", "Pulsar", "Quasar",
]

func _pick_random_names() -> String:
	const names = Globals.NAME_POOL
	var order: Array = range(names.size())
	order.shuffle()
	return names[order[0]] + " " + names[order[1]]


func change_points(diff: int):
	points += diff
	Events.points_changed.emit(points)
	
func change_lives(diff: int):
	lives += diff
	Events.lives_changed.emit(lives)

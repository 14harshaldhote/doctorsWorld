class_name AvatarSheet
extends Node3D
## A group photo showing the range of the avatar creator, used for screenshots
## and as a quick visual check of every hair style. The back row stands on a
## step so every face is visible.

const COLUMNS := 6
const LOOKS := {
	"hair_colour": [0, 1, 2, 3, 4, 0, 7, 1, 2, 6, 8, 9],
	"skin": [1, 4, 6, 8, 2, 9, 5, 0, 7, 3, 5, 7],
	"facial_hair": [0, 2, 0, 5, 0, 4, 0, 0, 1, 0, 0, 5],
	"glasses": [0, 0, 1, 0, 2, 0, 5, 0, 0, 3, 0, 0],
	"face": [0, 2, 1, 5, 3, 4, 1, 0, 2, 3, 1, 5],
}
const MOODS := [1, 0, 1, 3, 1, 0, 2, 1, 0, 1, 1, 3]


func _ready() -> void:
	StageLighting.add_to(self, Color("#E3ECEE"), Vector3(-38, 22, 0))
	LowPoly.put(self, LowPoly.box(Vector3(14, 0.1, 8), Color("#B9C9CC")), Vector3(0, -0.05, -1.5))
	LowPoly.put(self, LowPoly.box(Vector3(5.6, 0.3, 0.9), Color("#9FB3B8")), Vector3(0, 0.15, -1.0))
	var rng := SeededRandom.new(2026)
	for index in 12:
		var look := AvatarConfig.random(rng)
		look.hair_style = index
		for field: String in LOOKS:
			look.set(field, LOOKS[field][index])
		var rig := AvatarRig.new(look)
		rig.blink_every = 0.0
		rig.mood = MOODS[index]
		rig.name = "Avatar%d" % index
		var column := index % COLUMNS
		var row := index / COLUMNS
		var x := (column - (COLUMNS - 1) / 2.0) * 0.86 + row * 0.43 - 0.2
		rig.position = Vector3(x, row * 0.3, -row * 1.0)
		rig.rotation.y = -x * 0.06
		add_child(rig)
		rig.set_process(false)
	var camera := Camera3D.new()
	camera.name = "Camera"
	camera.fov = 30
	add_child(camera)
	camera.look_at_from_position(Vector3(0, 1.85, 6.2), Vector3(0, 1.08, -0.5))

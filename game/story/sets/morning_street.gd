class_name MorningStreet
extends StorySet
## The first morning: Riverside City Hospital in daylight, an ambulance
## pulling in with its siren going, and the new doctor walking up to the
## doors with the letter in hand.

var front: HospitalFront


func _ready() -> void:
	front = HospitalFront.new(true, false)
	front.name = "HospitalFront"
	front.manual_time = true
	add_child(front)
	marks = {
		"path_start": Vector3(-1.4, 0, 3.4),
		"path_mid": Vector3(2.7, 0, 2.35),
		"doors": Vector3(4.5, 0, 0.55),
		"sign": Vector3(4.85, 6.45, -0.4),
	}
	var you := add_player(marks["path_start"], PI / 2 - 0.3, "doctor")
	you.hold("letter")
	you.set_mood(AvatarConfig.Mood.CALM)
	shots = {
		"street": {"from": Vector3(-4.8, 1.7, 9.6), "at": Vector3(1.8, 1.9, 1.6), "to_from": Vector3(-3.6, 1.65, 8.4),
			"time": 9.0, "fov": 40.0},
		"look_up": {"from": Vector3(0.2, 0.6, 5.2), "at": Vector3(4.0, 3.4, 0.0), "to_from": Vector3(0.5, 0.65, 4.8),
			"time": 5.0, "fov": 55.0},
	}


func tick(delta: float) -> void:
	front.tick(delta)


func cue(cue_name: String) -> float:
	if cue_name == "ambulance":
		Sfx.play(self, "siren", -6.0)
		front.drive_in()
		var you: AvatarRig = actors["you"]
		you.look_at_point(Vector3(0, 1.2, 5.2))
		return 2.2
	return 0.0

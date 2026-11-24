class_name CastLooks
extends RefCounted
## How the cast looks: one table that every place they appear builds them
## from (Ward 4, and the canteen, the hostel and the parties of an evening),
## so a colleague looks the same everywhere. Each entry is [look, mood,
## outfit]; the look holds AvatarConfig fields. The player's family looks
## like the player (StorySet.family_looks), so they are not here.

const LOOKS := {
	"iyer": [{"skin": 3, "face": 1, "height": 3, "hair_style": 7, "hair_colour": 5, "brows": 0, "glasses": 4,
		"scrubs": 1, "watch": true}, AvatarConfig.Mood.FOCUSED, "doctor"],
	"grace": [{"skin": 7, "face": 0, "hair_style": 6, "hair_colour": 0, "scrubs": 4, "coat": false,
		"stethoscope": false, "watch": true, "brows": 2}, AvatarConfig.Mood.HAPPY, "doctor"],
	"priya": [{"skin": 6, "face": 3, "hair_style": 8, "hair_colour": 0, "eyes": 7, "scrubs": 2, "coat": false,
		"stethoscope": false, "watch": true}, AvatarConfig.Mood.CALM, "doctor"],
	"sethi": [{"skin": 4, "face": 2, "height": 4, "hair_style": 2, "hair_colour": 1, "facial_hair": 4,
		"scrubs": 6, "brows": 2}, AvatarConfig.Mood.TIRED, "doctor"],
	"rao": [{"skin": 5, "face": 5, "height": 2, "body": 2, "hair_style": 1, "hair_colour": 6, "glasses": 2,
		"facial_hair": 2, "scrubs": 1, "brows": 5}, AvatarConfig.Mood.CALM, "doctor"],
	"malhotra": [{"skin": 2, "face": 4, "height": 3, "hair_style": 2, "hair_colour": 5, "glasses": 3,
		"scrubs": 6, "coat": false, "stethoscope": false, "watch": true, "brows": 3},
		AvatarConfig.Mood.FOCUSED, "casual"],
	"rohit": [{"skin": 6, "face": 4, "body": 0, "height": 3, "hair_style": 3, "hair_colour": 0, "brows": 2,
		"coat": false, "stethoscope": false}, AvatarConfig.Mood.TIRED, "patient"],
	"sunita": [{"skin": 6, "face": 0, "body": 1, "height": 1, "hair_style": 8, "hair_colour": 1, "brows": 4,
		"scrubs": 4, "coat": false, "stethoscope": false}, AvatarConfig.Mood.WORRIED, "kurta"],
	"lakshmi": [{"skin": 7, "face": 5, "body": 2, "height": 1, "hair_style": 7, "hair_colour": 5, "brows": 4,
		"glasses": 1, "coat": false, "stethoscope": false}, AvatarConfig.Mood.WORRIED, "patient"],
	"kunal": [{"skin": 3, "face": 2, "body": 1, "height": 3, "hair_style": 2, "hair_colour": 3, "facial_hair": 1,
		"scrubs": 7, "coat": false, "stethoscope": false, "watch": true}, AvatarConfig.Mood.ANGRY, "casual"],
	"banerjee": [{"skin": 2, "face": 0, "body": 0, "height": 0, "hair_style": 7, "hair_colour": 6, "brows": 3,
		"glasses": 5, "coat": false, "stethoscope": false}, AvatarConfig.Mood.TIRED, "patient"],
	"salim": [{"skin": 6, "face": 4, "body": 0, "height": 2, "hair_style": 0, "hair_colour": 0, "facial_hair": 4,
		"brows": 2, "coat": false, "stethoscope": false}, AvatarConfig.Mood.TIRED, "patient"],
	"joseph": [{"skin": 4, "face": 4, "body": 0, "height": 2, "hair_style": 1, "hair_colour": 6, "glasses": 4,
		"facial_hair": 2, "brows": 3, "coat": false, "stethoscope": false}, AvatarConfig.Mood.CALM, "patient"],
	"maria": [{"skin": 4, "face": 1, "body": 1, "height": 2, "hair_style": 9, "hair_colour": 1, "brows": 1,
		"scrubs": 5, "coat": false, "stethoscope": false}, AvatarConfig.Mood.WORRIED, "kurta"],
	"peter": [{"skin": 4, "face": 2, "body": 2, "height": 3, "hair_style": 0, "hair_colour": 2, "facial_hair": 1,
		"scrubs": 1, "coat": false, "stethoscope": false}, AvatarConfig.Mood.ANGRY, "casual"],
	"leela": [{"skin": 4, "face": 3, "hair_style": 5, "hair_colour": 1, "eyes": 2, "scrubs": 2, "coat": false,
		"stethoscope": false}, AvatarConfig.Mood.WORRIED, "kurta"],
	"aarav": [{"skin": 4, "face": 0, "eyes": 4, "hair_style": 3, "hair_colour": 0, "scrubs": 7, "coat": false,
		"stethoscope": false}, AvatarConfig.Mood.HAPPY, "casual"],
	"tom": [{"skin": 3, "face": 2, "hair_style": 2, "hair_colour": 0, "facial_hair": 1, "scrubs": 1,
		"coat": false, "stethoscope": false, "height": 3}, AvatarConfig.Mood.HAPPY, "doctor"],
	"khan": [{"skin": 4, "face": 4, "hair_style": 10, "hair_colour": 0, "brows": 1, "scrubs": 3, "coat": false,
		"height": 2}, AvatarConfig.Mood.FOCUSED, "doctor"],
	# Eight months later: the Junior Resident's patients.
	"deepa": [{"skin": 5, "face": 3, "body": 1, "height": 2, "hair_style": 8, "hair_colour": 0, "brows": 2,
		"scrubs": 2, "coat": false, "stethoscope": false}, AvatarConfig.Mood.WORRIED, "kurta"],
	"bansal": [{"skin": 3, "face": 5, "body": 2, "height": 2, "hair_style": 1, "hair_colour": 6, "glasses": 3,
		"facial_hair": 2, "brows": 4, "coat": false, "stethoscope": false}, AvatarConfig.Mood.TIRED, "patient"],
	"farida": [{"skin": 4, "face": 1, "body": 1, "height": 1, "hair_style": 9, "hair_colour": 1, "brows": 1,
		"glasses": 1, "coat": false, "stethoscope": false}, AvatarConfig.Mood.CALM, "patient"],
	"raju": [{"skin": 7, "face": 2, "body": 1, "height": 3, "hair_style": 0, "hair_colour": 0, "facial_hair": 4,
		"brows": 3, "coat": false, "stethoscope": false}, AvatarConfig.Mood.WORRIED, "patient"],
	"mehra": [{"skin": 2, "face": 0, "body": 2, "height": 1, "hair_style": 7, "hair_colour": 6, "brows": 4,
		"glasses": 5, "scrubs": 5, "coat": false, "stethoscope": false, "watch": true},
		AvatarConfig.Mood.ANGRY, "kurta"],
	# A year later: the Senior Resident's intern, patients and colleagues.
	"zoya": [{"skin": 3, "face": 3, "height": 1, "hair_style": 6, "hair_colour": 1, "eyes": 7, "brows": 1,
		"scrubs": 2, "watch": true}, AvatarConfig.Mood.WORRIED, "doctor"],
	"bhatt": [{"skin": 5, "face": 2, "body": 2, "height": 4, "hair_style": 1, "hair_colour": 0, "facial_hair": 4,
		"brows": 2, "scrubs": 3}, AvatarConfig.Mood.HAPPY, "doctor"],
	"gomes": [{"skin": 4, "face": 5, "body": 0, "height": 0, "hair_style": 7, "hair_colour": 6, "brows": 4,
		"glasses": 5, "coat": false, "stethoscope": false}, AvatarConfig.Mood.CALM, "patient"],
	"francis": [{"skin": 4, "face": 2, "body": 2, "height": 3, "hair_style": 2, "hair_colour": 5,
		"facial_hair": 2, "brows": 3, "scrubs": 1, "coat": false, "stethoscope": false, "watch": true},
		AvatarConfig.Mood.WORRIED, "casual"],
	"nanda": [{"skin": 3, "face": 5, "body": 2, "height": 2, "hair_style": 0, "hair_colour": 5, "facial_hair": 2,
		"glasses": 2, "brows": 3, "coat": false, "stethoscope": false}, AvatarConfig.Mood.TIRED, "patient"],
	"imran": [{"skin": 6, "face": 4, "body": 0, "height": 3, "hair_style": 3, "hair_colour": 0, "facial_hair": 1,
		"brows": 2, "coat": false, "stethoscope": false}, AvatarConfig.Mood.WORRIED, "patient"],
	"rubina": [{"skin": 6, "face": 1, "height": 1, "hair_style": 10, "hair_colour": 0, "eyes": 1, "brows": 1,
		"scrubs": 4, "coat": false, "stethoscope": false}, AvatarConfig.Mood.WORRIED, "kurta"],
	# Three months a surgeon: the first patient on your own list, your own
	# theatre team, and the chair of the board.
	"kurup": [{"skin": 6, "face": 5, "body": 2, "height": 1, "hair_style": 7, "hair_colour": 6, "brows": 4,
		"glasses": 1, "coat": false, "stethoscope": false}, AvatarConfig.Mood.TIRED, "patient"],
	"venu": [{"skin": 6, "face": 4, "body": 1, "height": 2, "hair_style": 1, "hair_colour": 6, "facial_hair": 2,
		"glasses": 3, "brows": 3, "scrubs": 5, "coat": false, "stethoscope": false},
		AvatarConfig.Mood.WORRIED, "casual"],
	"neha": [{"skin": 3, "face": 1, "height": 2, "hair_style": 10, "hair_colour": 0, "eyes": 3, "brows": 1,
		"scrubs": 2, "coat": false, "stethoscope": false}, AvatarConfig.Mood.FOCUSED, "doctor"],
	"bose": [{"skin": 4, "face": 2, "body": 1, "height": 3, "hair_style": 2, "hair_colour": 1, "facial_hair": 3,
		"glasses": 2, "brows": 2, "scrubs": 3, "coat": false}, AvatarConfig.Mood.HAPPY, "doctor"],
	"rajan": [{"skin": 5, "face": 0, "body": 1, "height": 2, "hair_style": 7, "hair_colour": 6, "brows": 3,
		"glasses": 4, "scrubs": 6, "coat": false, "stethoscope": false, "watch": true},
		AvatarConfig.Mood.CALM, "kurta"],
	# Six months a head of department: the day case that came back, the
	# rival for Chief of Medicine, the Dean, and a new intern of your own.
	"sinha": [{"skin": 4, "face": 1, "body": 1, "height": 2, "hair_style": 9, "hair_colour": 5, "brows": 3,
		"glasses": 1, "coat": false, "stethoscope": false}, AvatarConfig.Mood.TIRED, "patient"],
	"kapoor": [{"skin": 3, "face": 2, "body": 1, "height": 4, "hair_style": 2, "hair_colour": 0,
		"facial_hair": 3, "brows": 2, "scrubs": 1, "coat": false, "stethoscope": false, "watch": true},
		AvatarConfig.Mood.HAPPY, "casual"],
	"dean": [{"skin": 4, "face": 5, "body": 2, "height": 2, "hair_style": 1, "hair_colour": 6, "facial_hair": 4,
		"glasses": 1, "brows": 4, "scrubs": 5, "coat": false, "stethoscope": false}, AvatarConfig.Mood.CALM, "kurta"],
	"saxena": [{"skin": 5, "face": 3, "height": 1, "hair_style": 6, "hair_colour": 0, "eyes": 5, "brows": 1,
		"scrubs": 1}, AvatarConfig.Mood.WORRIED, "doctor"],
	# The Chief's days: Mr. Malhotra's son, a CarePlus day case, and three
	# families at the complaints desk.
	"dev": [{"skin": 2, "face": 0, "body": 0, "height": 2, "hair_style": 3, "hair_colour": 0, "brows": 2,
		"coat": false, "stethoscope": false}, AvatarConfig.Mood.WORRIED, "patient"],
	"verghese": [{"skin": 5, "face": 1, "body": 1, "height": 2, "hair_style": 8, "hair_colour": 1, "brows": 1,
		"glasses": 2, "coat": false, "stethoscope": false}, AvatarConfig.Mood.ANGRY, "patient"],
	"relative_a": [{"skin": 5, "face": 2, "body": 2, "height": 3, "hair_style": 0, "hair_colour": 5,
		"facial_hair": 3, "brows": 3, "scrubs": 5, "coat": false, "stethoscope": false, "watch": true},
		AvatarConfig.Mood.ANGRY, "casual"],
	"relative_b": [{"skin": 3, "face": 3, "body": 1, "height": 1, "hair_style": 9, "hair_colour": 6, "brows": 4,
		"glasses": 3, "scrubs": 4, "coat": false, "stethoscope": false}, AvatarConfig.Mood.ANGRY, "kurta"],
	"relative_c": [{"skin": 6, "face": 1, "body": 0, "height": 2, "hair_style": 5, "hair_colour": 0, "eyes": 6,
		"brows": 1, "scrubs": 7, "coat": false, "stethoscope": false}, AvatarConfig.Mood.WORRIED, "kurta"],
	# The walk-ins of the endless days.
	"arif": [{"skin": 4, "face": 0, "body": 0, "height": 3, "hair_style": 3, "hair_colour": 0, "brows": 2,
		"glasses": 2, "coat": false, "stethoscope": false}, AvatarConfig.Mood.WORRIED, "patient"],
	"mohan": [{"skin": 6, "face": 2, "body": 2, "height": 2, "hair_style": 1, "hair_colour": 5, "facial_hair": 3,
		"brows": 3, "coat": false, "stethoscope": false}, AvatarConfig.Mood.TIRED, "patient"],
	"savitri": [{"skin": 6, "face": 1, "body": 1, "height": 1, "hair_style": 7, "hair_colour": 6, "brows": 4,
		"scrubs": 6, "coat": false, "stethoscope": false}, AvatarConfig.Mood.HAPPY, "kurta"],
	"usha": [{"skin": 5, "face": 3, "body": 1, "height": 2, "hair_style": 7, "hair_colour": 5, "brows": 3,
		"glasses": 4, "coat": false, "stethoscope": false}, AvatarConfig.Mood.CALM, "patient"],
	"rosy": [{"skin": 2, "face": 5, "body": 1, "height": 0, "hair_style": 9, "hair_colour": 6, "brows": 4,
		"glasses": 1, "coat": false, "stethoscope": false}, AvatarConfig.Mood.CALM, "patient"],
	"gurdeep": [{"skin": 3, "face": 4, "body": 2, "height": 4, "hair_style": 0, "hair_colour": 0,
		"facial_hair": 5, "brows": 3, "coat": false, "stethoscope": false}, AvatarConfig.Mood.WORRIED, "patient"],
	"anwar": [{"skin": 5, "face": 5, "body": 1, "height": 2, "hair_style": 1, "hair_colour": 6, "facial_hair": 5,
		"glasses": 3, "brows": 4, "coat": false, "stethoscope": false}, AvatarConfig.Mood.TIRED, "patient"],
	"kavita": [{"skin": 4, "face": 2, "body": 1, "height": 2, "hair_style": 6, "hair_colour": 0, "eyes": 4,
		"brows": 1, "coat": false, "stethoscope": false}, AvatarConfig.Mood.TIRED, "patient"],
	"saroja": [{"skin": 5, "face": 1, "body": 1, "height": 0, "hair_style": 7, "hair_colour": 6, "brows": 3,
		"glasses": 2, "coat": false, "stethoscope": false}, AvatarConfig.Mood.TIRED, "patient"],
	"venkat": [{"skin": 5, "face": 3, "body": 1, "height": 3, "hair_style": 0, "hair_colour": 1,
		"facial_hair": 1, "glasses": 1, "brows": 2, "coat": false, "stethoscope": false},
		AvatarConfig.Mood.WORRIED, "casual"],
	# Patients who sleep through the week, so the ward is full.
	"bg1": [{"skin": 8, "face": 5, "body": 2, "hair_style": 1, "hair_colour": 5, "facial_hair": 5, "coat": false,
		"stethoscope": false}, AvatarConfig.Mood.TIRED, "patient"],
	"bg2": [{"skin": 1, "face": 1, "hair_style": 9, "hair_colour": 2, "coat": false, "stethoscope": false},
		AvatarConfig.Mood.CALM, "patient"],
	"bg3": [{"skin": 5, "face": 3, "body": 1, "hair_style": 0, "hair_colour": 0, "facial_hair": 2, "coat": false,
		"stethoscope": false}, AvatarConfig.Mood.TIRED, "patient"],
	# Dr. Varun Khanna, the batchmate at CarePlus, in person at last (stage 27):
	# sharp hair, stubble, a watch that costs a nurse's month.
	"varun": [{"skin": 3, "face": 2, "body": 1, "height": 3, "hair_style": 2, "hair_colour": 1, "facial_hair": 1,
		"brows": 2, "eyes": 1, "scrubs": 6, "coat": false, "stethoscope": false, "watch": true},
		AvatarConfig.Mood.HAPPY, "casual"],
	# Mani, who runs the canteen: grey moustache, the sleeves rolled up for
	# the chai, here since before the lifts worked.
	"mani": [{"skin": 6, "face": 5, "body": 2, "height": 2, "hair_style": 1, "hair_colour": 6, "facial_hair": 2,
		"brows": 4, "scrubs": 5, "coat": false, "stethoscope": false}, AvatarConfig.Mood.HAPPY, "kurta"],
}
## Children and a teenager are smaller.
const SCALES := {"aarav": 0.64, "dev": 0.9}
## People who never set foot on Ward 4.
const OFF_THE_WARD := ["varun", "mani"]


static func has(id: String) -> bool:
	return LOOKS.has(id)


## A fresh copy of someone's look (Dr. Iyer's if they are unknown).
static func config(id: String) -> AvatarConfig:
	var look: Dictionary = (LOOKS.get(id, LOOKS["iyer"]) as Array)[0]
	var made := AvatarConfig.new()
	for key: String in look:
		made.set(key, look[key])
	return made


static func mood(id: String) -> int:
	return int((LOOKS.get(id, LOOKS["iyer"]) as Array)[1])


static func outfit(id: String) -> String:
	return str((LOOKS.get(id, LOOKS["iyer"]) as Array)[2])


static func scale(id: String) -> float:
	return float(SCALES.get(id, 1.0))

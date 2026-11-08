class_name AvatarConfig
extends RefCounted
## Everything that describes how a character looks. The player's doctor and
## every other character in the game use the same parts, so the cast matches.
##
## Choices are stored as indexes into the catalogues below. from_dict()
## repairs anything out of range, so a damaged or older save never breaks
## the creator.

const SKIN_TONES := [
	Color("#F6D7C3"), Color("#EEC4A3"), Color("#E2AE88"), Color("#CF9670"), Color("#BC8059"),
	Color("#A56A45"), Color("#8C5636"), Color("#72432A"), Color("#5A3320"), Color("#432617"),
]
const BODIES := ["Slim", "Average", "Broad"]
const HEIGHTS := ["Shortest", "Short", "Medium", "Tall", "Tallest"]
const FACE_SHAPES := ["Round", "Oval", "Square", "Heart", "Long", "Wide"]
const EYE_SHAPES := ["Round", "Almond", "Wide-set", "Close-set", "Big", "Small", "Sleepy", "Bright"]
const BROW_STYLES := ["Straight", "Arched", "Thick", "Thin", "Soft", "Bold"]
const NOSE_STYLES := ["Button", "Straight", "Wide", "Long", "Small"]
const HAIR_STYLES := [
	"Short", "Buzz cut", "Side part", "Curly", "Afro", "Long",
	"Ponytail", "Bun", "Braid", "Bob", "Headscarf", "Turban",
]
const HAIR_COLOURS := [
	Color("#1B1411"), Color("#3B2417"), Color("#6B4226"), Color("#A0652E"), Color("#C9A15A"),
	Color("#8E8E8E"), Color("#E6E1D6"), Color("#2E4A8C"), Color("#6E2338"), Color("#1F6F6F"),
]
const HAIR_COLOUR_NAMES := [
	"Black", "Dark brown", "Brown", "Auburn", "Blonde", "Grey", "White", "Navy", "Burgundy", "Teal",
]
const FACIAL_HAIR := ["None", "Stubble", "Moustache", "Goatee", "Short beard", "Full beard"]
const GLASSES := ["None", "Round", "Square", "Wide", "Half-rim", "Big round"]
const SCRUBS := [
	Color("#1F8A8A"), Color("#24427A"), Color("#5E9FD0"), Color("#3E8E5A"),
	Color("#8C2F4B"), Color("#6A4C9C"), Color("#2B2F33"), Color("#C0603E"),
]
const SCRUB_NAMES := ["Teal", "Navy", "Ceil blue", "Green", "Wine", "Purple", "Charcoal", "Rust"]
const EXPRESSIONS := ["Calm", "Happy", "Worried", "Focused", "Tired", "Angry", "Shocked"]
enum Mood { CALM, HAPPY, WORRIED, FOCUSED, TIRED, ANGRY, SHOCKED }

## The fields stored as an index into a catalogue (see catalogue()).
const FIELDS := [
	"skin", "body", "height", "face", "eyes", "brows", "nose",
	"hair_style", "hair_colour", "facial_hair", "glasses", "scrubs",
]
const TOGGLES := ["coat", "stethoscope", "watch"]

var skin := 5
var body := 1
var height := 2
var face := 1
var eyes := 1
var brows := 4
var nose := 1
var hair_style := 7
var hair_colour := 0
var facial_hair := 0
var glasses := 0
var scrubs := 0
var coat := true
var stethoscope := true
var watch := false


## How many choices a field has.
static func choice_count(field: String) -> int:
	return catalogue(field).size()


## The list of choices behind an index field.
static func catalogue(field: String) -> Array:
	match field:
		"skin":
			return SKIN_TONES
		"body":
			return BODIES
		"height":
			return HEIGHTS
		"face":
			return FACE_SHAPES
		"eyes":
			return EYE_SHAPES
		"brows":
			return BROW_STYLES
		"nose":
			return NOSE_STYLES
		"hair_style":
			return HAIR_STYLES
		"hair_colour":
			return HAIR_COLOURS
		"facial_hair":
			return FACIAL_HAIR
		"glasses":
			return GLASSES
		"scrubs":
			return SCRUBS
	push_error("Unknown avatar field: " + field)
	return []


func skin_colour() -> Color:
	return SKIN_TONES[skin]


func hair_colour_value() -> Color:
	return HAIR_COLOURS[hair_colour]


## Beards and eyebrows stay a natural colour under a headscarf or turban,
## and with dyed hair (navy, burgundy, teal).
func facial_hair_colour() -> Color:
	if covers_hair() or hair_colour >= 7:
		return Color("#2A2220")
	return HAIR_COLOURS[hair_colour]


func scrubs_colour() -> Color:
	return SCRUBS[scrubs]


## Headscarf and turban cover the hair, so they hide hair-only details.
func covers_hair() -> bool:
	return HAIR_STYLES[hair_style] == "Headscarf" or HAIR_STYLES[hair_style] == "Turban"


func to_dict() -> Dictionary:
	var data := {}
	for field in FIELDS:
		data[field] = get(field)
	for toggle in TOGGLES:
		data[toggle] = get(toggle)
	return data


## Reads a saved look. Missing or invalid values fall back to the defaults.
static func from_dict(data: Variant) -> AvatarConfig:
	var config := AvatarConfig.new()
	if typeof(data) != TYPE_DICTIONARY:
		return config
	for field in FIELDS:
		var value: Variant = data.get(field)
		if (typeof(value) == TYPE_INT or typeof(value) == TYPE_FLOAT) and float(value) == floorf(float(value)):
			var index := int(value)
			if index >= 0 and index < choice_count(field):
				config.set(field, index)
	for toggle in TOGGLES:
		var flag: Variant = data.get(toggle)
		if typeof(flag) == TYPE_BOOL:
			config.set(toggle, flag)
	return config


## A random but complete look, fully determined by the generator.
static func random(rng: SeededRandom) -> AvatarConfig:
	var config := AvatarConfig.new()
	for field in FIELDS:
		config.set(field, rng.next_int(choice_count(field)))
	# Glasses and facial hair are less common than not.
	if rng.chance(0.6):
		config.glasses = 0
	if rng.chance(0.55):
		config.facial_hair = 0
	config.coat = rng.chance(0.7)
	config.stethoscope = rng.chance(0.8)
	config.watch = rng.chance(0.4)
	return config


func copy() -> AvatarConfig:
	return AvatarConfig.from_dict(to_dict())


func equals(other: AvatarConfig) -> bool:
	return other != null and to_dict() == other.to_dict()

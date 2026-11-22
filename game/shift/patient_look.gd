class_name PatientLook
extends RefCounted
## How a stranger in casualty looks, from who they are: a woman's hair, a
## man's beard, grey hair with age, a turban or a headscarf where the family
## would wear one, home clothes or a kurta. Never a doctor's coat. The same
## patient always looks the same (their look_seed).

## Hair styles by index in AvatarConfig.HAIR_STYLES.
const MEN_HAIR := [0, 1, 2, 3]
const WOMEN_HAIR := [5, 6, 7, 8, 9]
const HEADSCARF := 10
const TURBAN := 11
## Natural hair colours only: black, dark brown, brown; grey and white come
## with age.
const YOUNG_COLOURS := [0, 0, 0, 1, 1, 2]
const GREY := 5
const WHITE := 6
## Skin tones by index in AvatarConfig.SKIN_TONES: the town's range.
const SKIN := [2, 3, 4, 5, 6, 7, 8]
## How many different looks there are: a look seed is read modulo this.
const SEEDS := 1000003


## {"config": AvatarConfig, "outfit": String, "mood": AvatarConfig.Mood}
static func make(person: Dictionary, age: int, look_seed: int, triage: String = "green") -> Dictionary:
	var rng := SeededRandom.new(absi(look_seed) % SEEDS + 1)
	var config := AvatarConfig.random(rng)
	var woman := str(person.get("sex", "m")) == "f"
	var community := str(person.get("community", ""))
	config.skin = int(rng.pick(SKIN))
	config.coat = false
	config.stethoscope = false
	config.scrubs = rng.next_int(AvatarConfig.SCRUBS.size())
	config.watch = age >= 25 and rng.chance(0.4)
	if woman:
		config.facial_hair = 0
		config.hair_style = int(rng.pick(WOMEN_HAIR))
		if community == "muslim" and rng.chance(0.6):
			config.hair_style = HEADSCARF
	else:
		config.hair_style = int(rng.pick(MEN_HAIR))
		config.facial_hair = 0 if age < 18 or rng.chance(0.45) else 1 + rng.next_int(5)
		if community == "punjabi" and rng.chance(0.5):
			config.hair_style = TURBAN
			config.facial_hair = 5
	config.hair_colour = int(rng.pick(YOUNG_COLOURS))
	if age >= 70 or (age >= 50 and rng.chance(0.6)):
		config.hair_colour = WHITE if age >= 70 and rng.chance(0.6) else GREY
	config.glasses = (1 + rng.next_int(5)) if age >= 45 and rng.chance(0.55) else 0
	if age < 16:
		config.height = rng.next_int(2)
	var outfit := "kurta" if rng.chance(0.35 if woman else 0.25) else "casual"
	return {"config": config, "outfit": outfit, "mood": mood_for(triage)}


## How they look to be feeling: the sick look worried, the rest tired.
static func mood_for(triage: String) -> int:
	match triage:
		"red":
			return AvatarConfig.Mood.SHOCKED
		"yellow":
			return AvatarConfig.Mood.WORRIED
	return AvatarConfig.Mood.TIRED

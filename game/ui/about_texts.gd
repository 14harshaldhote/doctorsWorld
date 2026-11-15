class_name AboutTexts
extends RefCounted
## The words behind Settings > About: the privacy policy, and the
## acknowledgements (thanks, the free software the game is made with, and
## every licence that comes with it). The privacy policy is also in
## docs/PRIVACY.md, word for word, for the App Store; a test keeps the two
## the same.

const PRIVACY_TITLE := "Privacy policy"
const PRIVACY_UPDATED := "Last updated 15 November 2026. This policy covers Doctors World on iPhone and iPad."
const CONTACT := "github.com/14harshaldhote/doctorsWorld/issues"
## [heading, [paragraphs]]
const PRIVACY := [
	["The short version", [
		"Doctors World collects nothing about you. There are no accounts, no ads, no analytics and no tracking, " \
			+ "and the game never sends anything over the internet. What the game knows stays on your device."]],
	["What stays on your device", [
		"Your doctor's name and look, your progress through the story, your choices, scores and records, and your " \
			+ "settings. The game keeps them in its own storage on your device so you can carry on where you left off.",
		"If your device is backed up (to iCloud or to a computer), the save goes with the backup, under your own " \
			+ "account. Deleting the game deletes all of it."]],
	["Voices, microphone and camera", [
		"Every voice you hear was recorded for the game and comes inside it. If a line has no recording, your " \
			+ "device's own built-in voice may read it aloud, on the device. The game never uses the microphone, the " \
			+ "camera, your contacts, your photos or your location."]],
	["Reminders", [
		"Reminders are off until you say yes. If you turn them on, the game works out what to say from your " \
			+ "progress (for example, which patient is waiting) and asks your device to show it later. Your device's " \
			+ "own notification centre does the rest. Nothing goes to a server, and nobody else can see or send them.",
		"You can turn them off in the game's Settings, or for Doctors World in your device's Settings app."]],
	["Nobody else", [
		"The game contains no advertising, analytics or social media code from other companies, and it shares " \
			+ "nothing with anyone. It has nothing to share."]],
	["Children", [
		"The game collects no personal information from anyone, children included."]],
	["If this changes", [
		"If the game ever needs to handle your information differently, this policy will change first, with a new " \
			+ "date at the top."]],
	["Questions", [
		"Ask on the game's page: " + CONTACT]],
]

const THANKS_TITLE := "Acknowledgements"
## [heading, [paragraphs]]
const THANKS := [
	["For the night shift", [
		"Doctors World is for everyone who works nights in a hospital, and for the families waiting in the " \
			+ "corridor outside."]],
	["Everything in it is made up", [
		"Every patient, doctor, illness and hospital in the game is invented, and any likeness to real people is " \
			+ "a coincidence. It's a game, not medical advice. If you're unwell, see a real doctor."]],
	["Made with free and open software", [
		"Godot Engine runs the whole game. Copyright (c) 2014-present Godot Engine contributors, and (c) 2007-2014 " \
			+ "Juan Linietsky and Ariel Manzur. MIT licence, below. The parts Godot is built from, and their " \
			+ "licences, are on the next two pages.",
		"The voices were recorded for this game with Kokoro, an open voice model by hexgrad (Apache License 2.0), " \
			+ "run with kokoro-onnx by thewh1teagle (MIT licence).",
		"The fonts are Fredoka, copyright 2016 The Fredoka Project Authors, and Nunito, copyright 2014 The Nunito " \
			+ "Project Authors, both under the SIL Open Font License 1.1 (on the licence page).",
		"The music, sound effects, characters, rooms and story were made for Doctors World."]],
]
## The pages of the acknowledgements, in order.
const THANKS_PAGES := ["Thanks", "Godot's parts", "Licence texts"]
## Licences the game's own credits name, shown even if Godot's list leaves
## them out.
const NAMED_LICENCES := ["Apache-2.0", "OFL-1.1", "Expat"]


## A paragraph or heading made safe for a RichTextLabel.
static func escape(text: String) -> String:
	return text.replace("[", "[lb]")


static func _sections(sections: Array) -> String:
	var parts := PackedStringArray()
	for section: Array in sections:
		var paragraphs := PackedStringArray()
		for paragraph: String in section[1]:
			paragraphs.append(escape(paragraph))
		parts.append("[font_size=%d][b]%s[/b][/font_size]\n%s" % [UiKit.scaled_text(19), escape(str(section[0])),
			"\n\n".join(paragraphs)])
	return "\n\n".join(parts)


static func privacy() -> String:
	return "[color=#B8D6D2]%s[/color]\n\n%s" % [escape(PRIVACY_UPDATED), _sections(PRIVACY)]


## One page of the acknowledgements, by index into THANKS_PAGES.
static func thanks_page(index: int) -> String:
	match index:
		1:
			return godot_parts()
		2:
			return licence_texts()
	return "%s\n\n[font_size=%d][b]Godot Engine licence[/b][/font_size]\n\n%s" % [_sections(THANKS),
		UiKit.scaled_text(19), escape(Engine.get_license_text())]


## Every part of Godot Engine with its copyright holders and licence.
static func godot_parts() -> String:
	var parts := PackedStringArray(["Godot Engine is built from these parts, each under its own licence."])
	for component: Dictionary in Engine.get_copyright_info():
		var holders := PackedStringArray()
		var licences := PackedStringArray()
		for part: Dictionary in component.get("parts", []):
			for holder: String in part.get("copyright", []):
				if not holders.has(holder):
					holders.append(holder)
			var licence := str(part.get("license", ""))
			if not licence.is_empty() and not licences.has(licence):
				licences.append(licence)
		var lines := PackedStringArray(["[b]%s[/b]" % escape(str(component.get("name", "")))])
		for holder: String in holders:
			lines.append("Copyright (c) " + escape(holder))
		lines.append("Licence: " + escape(", ".join(licences)))
		parts.append("\n".join(lines))
	return "\n\n".join(parts)


## The full text of every licence named on the other pages.
static func licence_texts() -> String:
	var texts := Engine.get_license_info()
	var names: Array = texts.keys()
	for named: String in NAMED_LICENCES:
		if not names.has(named):
			push_warning("Godot's licence list has no %s" % named)
	names.sort()
	var parts := PackedStringArray()
	for licence: String in names:
		parts.append("[font_size=%d][b]%s[/b][/font_size]\n\n%s" % [UiKit.scaled_text(19), escape(licence),
			escape(str(texts[licence]).strip_edges())])
	return "\n\n".join(parts)

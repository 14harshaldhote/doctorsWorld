class_name FrameBudget
extends RefCounted
## How many frames a second the game asks for, so it never works harder than
## the screen needs: the player's setting (60, or 30 on Battery saver), 30
## on a still screen (the title, the career map, settings), and 5 while the
## game isn't in front (another window over it on the Mac, Control Centre
## pulled down on the phone). While it's away the hospital's clock waits too.

const MENU_FPS := 30
const AWAY_FPS := 5

## The player's own rate (GameSettings.apply_display sets it).
static var base := 60
## True while the game isn't the app in front.
static var away := false
## How many still screens are open (each adds one while it's showing).
static var _calm := 0


static func set_base(fps: int) -> void:
	base = fps
	apply()


static func set_away(value: bool) -> void:
	away = value
	apply()


## A still screen opening (true) or closing (false).
static func calm(on: bool) -> void:
	_calm = maxi(0, _calm + (1 if on else -1))
	apply()


static func calm_screens() -> int:
	return _calm


static func target() -> int:
	if away:
		return AWAY_FPS
	return mini(base, MENU_FPS) if _calm > 0 else base


static func apply() -> void:
	Engine.max_fps = target()


## Back to the start (for tests).
static func reset() -> void:
	base = 60
	away = false
	_calm = 0
	apply()

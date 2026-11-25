class_name FitCamera
extends Camera3D
## The game's 3D camera. Shots are framed on a wide phone; a screen that is
## narrower for its height (a Mac window, an iPad, an iPhone SE) would cut
## the sides off, so there the field of view opens up to show as much across
## as the phone does. A wide phone sees exactly the shot as designed. Scenes
## set designed_fov, never fov.

## The screen shape shots are framed for: an iPhone on its side (19.5 by 9).
const WIDE_ASPECT := 2.16
## Never wider than this, however narrow the screen.
const WIDEST := 75.0

## The field of view the shot was framed with (on a wide phone).
var designed_fov := 42.0:
	set(value):
		designed_fov = value
		_fit()


## The field of view that shows what designed shows on a wide phone, on a
## screen of this size: the same above WIDE_ASPECT, wider below it.
static func fitted(designed: float, screen: Vector2) -> float:
	var aspect := screen.x / maxf(screen.y, 1.0)
	if aspect >= WIDE_ASPECT:
		return designed
	var across := tan(deg_to_rad(designed / 2.0)) * WIDE_ASPECT / aspect
	return minf(rad_to_deg(2.0 * atan(across)), maxf(designed, WIDEST))


func _enter_tree() -> void:
	var view := get_viewport()
	if not view.size_changed.is_connected(_fit):
		view.size_changed.connect(_fit)
	_fit()


func _exit_tree() -> void:
	var view := get_viewport()
	if view.size_changed.is_connected(_fit):
		view.size_changed.disconnect(_fit)


func _fit() -> void:
	fov = fitted(designed_fov, get_viewport().get_visible_rect().size) if is_inside_tree() else designed_fov

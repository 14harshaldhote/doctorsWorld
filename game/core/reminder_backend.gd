class_name ReminderBackend
extends RefCounted
## Hands the reminder plan to the phone. On iOS a small piece of native code
## (addons/dw_reminders, added to the Xcode project on export) reads it from
## an environment variable every two seconds and schedules it with the
## phone's own notification centre, then writes back whether the player
## allowed reminders. Nothing leaves the device. Elsewhere there is nothing
## to send to. Tests swap in a fake (see Reminders.backend).

const PAYLOAD := "DW_REMINDERS"
const STATUS := "DW_REMINDERS_STATUS"

## The last plan handed over, for tests and for not repeating ourselves.
var last_sent := ""


func supported() -> bool:
	return OS.get_name() == "iOS"


## "granted", "denied", "undetermined", "unsupported", or "unknown" before
## the phone has said.
func status() -> String:
	var said := OS.get_environment(STATUS)
	return said if not said.is_empty() else "unknown"


func send(payload: String) -> void:
	if payload == last_sent:
		return
	last_sent = payload
	if supported():
		OS.set_environment(PAYLOAD, payload)

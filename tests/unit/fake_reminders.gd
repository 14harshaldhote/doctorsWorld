extends ReminderBackend
## Stands in for the phone's notification centre in tests: it can send,
## keeps every plan handed to it, and says whatever status a test sets.

var can_send := true
var said := "undetermined"
var sent: PackedStringArray = []


func supported() -> bool:
	return can_send


func status() -> String:
	return said


func send(payload: String) -> void:
	if payload == last_sent:
		return
	last_sent = payload
	sent.append(payload)

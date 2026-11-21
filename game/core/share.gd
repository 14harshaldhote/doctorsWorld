class_name Share
extends RefCounted
## Showing off to friends. WhatsApp opens with the message already typed
## (a wa.me link opens the app on any phone that has it, and WhatsApp Web
## on one that doesn't), and the same text goes on the clipboard, for
## anyone who'd rather paste it into the family group themselves.

## Who opens a link and who fills the clipboard. Empty means the phone's
## own; tests put recorders here so nothing really opens.
static var opener := Callable()
static var copier := Callable()
static var paster := Callable()


static func whatsapp_url(text: String) -> String:
	return "https://wa.me/?text=" + text.uri_encode()


## Opens WhatsApp with the text ready to send, and copies it too.
static func whatsapp(text: String) -> void:
	if text.is_empty():
		return
	copy(text)
	var url := whatsapp_url(text)
	if opener.is_valid():
		opener.call(url)
	else:
		OS.shell_open(url)


static func copy(text: String) -> void:
	if text.is_empty():
		return
	if copier.is_valid():
		copier.call(text)
	else:
		DisplayServer.clipboard_set(text)


## What's on the clipboard (a friend's result, pasted in to check).
static func paste() -> String:
	if paster.is_valid():
		return str(paster.call())
	return DisplayServer.clipboard_get()

// Doctors World reminders, iOS side.
//
// Added to the exported Xcode project's generated C++ file by
// addons/dw_reminders/export_plugin.gd. It schedules the game's reminders
// with the phone's own notification centre. Nothing is sent anywhere.
//
// The game and this code share two environment variables, so no engine
// headers are needed (the game sets and reads them with OS.set_environment
// and OS.get_environment, on the main thread, where this code also runs):
//
//   DW_REMINDERS         written by the game, read here every two seconds:
//                          DW1
//                          ask                           (optional: ask for permission)
//                          R <tab> id <tab> unix time <tab> title <tab> body
//                        Every new value replaces all pending reminders.
//   DW_REMINDERS_STATUS  written here: "undetermined", "denied", "granted"
//                        or "unsupported".
//
// It is plain C++ (the generated file is not Objective-C), so it talks to
// UserNotifications through the Objective-C runtime and Core Foundation.

#include <CoreFoundation/CoreFoundation.h>
#include <dispatch/dispatch.h>
#include <dlfcn.h>
#include <objc/message.h>
#include <objc/objc.h>
#include <objc/runtime.h>
#include <stdlib.h>
#include <time.h>

#include <string>
#include <vector>

namespace dw_reminders {

static std::string last_payload;
static unsigned long ticks = 0;
static dispatch_source_t timer = nullptr;

static id class_named(const char *name) {
	return (id)objc_getClass(name);
}

static SEL selector(const char *name) {
	return sel_registerName(name);
}

static id message(id target, const char *name) {
	return ((id(*)(id, SEL))objc_msgSend)(target, selector(name));
}

static void message_void(id target, const char *name) {
	((void (*)(id, SEL))objc_msgSend)(target, selector(name));
}

static void message_object(id target, const char *name, id value) {
	((void (*)(id, SEL, id))objc_msgSend)(target, selector(name), value);
}

static void set_status(const char *value) {
	setenv("DW_REMINDERS_STATUS", value, 1);
}

static id notification_center() {
	id center_class = class_named("UNUserNotificationCenter");
	if (center_class == nullptr) {
		dlopen("/System/Library/Frameworks/UserNotifications.framework/UserNotifications", RTLD_LAZY);
		center_class = class_named("UNUserNotificationCenter");
	}
	if (center_class == nullptr) {
		return nullptr;
	}
	return message(center_class, "currentNotificationCenter");
}

static std::vector<std::string> split(const std::string &text, char separator) {
	std::vector<std::string> parts;
	std::string::size_type start = 0;
	while (true) {
		std::string::size_type end = text.find(separator, start);
		if (end == std::string::npos) {
			parts.push_back(text.substr(start));
			break;
		}
		parts.push_back(text.substr(start, end - start));
		start = end + 1;
	}
	return parts;
}

static id make_string(const std::string &text) {
	return (id)CFStringCreateWithCString(kCFAllocatorDefault, text.c_str(), kCFStringEncodingUTF8);
}

static void release_string(id text) {
	if (text != nullptr) {
		CFRelease((CFTypeRef)text);
	}
}

// Asks the notification centre how the player answered, for the game's
// settings screen.
static void read_status() {
	id center = notification_center();
	if (center == nullptr) {
		set_status("unsupported");
		return;
	}
	((void (*)(id, SEL, void (^)(id)))objc_msgSend)(center, selector("getNotificationSettingsWithCompletionHandler:"),
			^(id settings) {
				long status = settings == nullptr ? 0 : ((long (*)(id, SEL))objc_msgSend)(settings, selector("authorizationStatus"));
				dispatch_async(dispatch_get_main_queue(), ^{
					// 0 not determined, 1 denied, 2 authorised, 3 provisional, 4 ephemeral.
					set_status(status == 0 ? "undetermined" : (status == 1 ? "denied" : "granted"));
				});
			});
}

static void schedule(id center, const std::string &identifier, double seconds, const std::string &title,
		const std::string &body) {
	id content_class = class_named("UNMutableNotificationContent");
	id trigger_class = class_named("UNTimeIntervalNotificationTrigger");
	id request_class = class_named("UNNotificationRequest");
	id sound_class = class_named("UNNotificationSound");
	if (content_class == nullptr || trigger_class == nullptr || request_class == nullptr) {
		return;
	}
	id identifier_text = make_string(identifier);
	id title_text = make_string(title);
	id body_text = make_string(body);
	if (identifier_text != nullptr && title_text != nullptr && body_text != nullptr) {
		id content = message(message(content_class, "alloc"), "init");
		message_object(content, "setTitle:", title_text);
		message_object(content, "setBody:", body_text);
		if (sound_class != nullptr) {
			message_object(content, "setSound:", message(sound_class, "defaultSound"));
		}
		id trigger = ((id(*)(id, SEL, double, BOOL))objc_msgSend)(trigger_class,
				selector("triggerWithTimeInterval:repeats:"), seconds, (BOOL) false);
		id request = ((id(*)(id, SEL, id, id, id))objc_msgSend)(request_class,
				selector("requestWithIdentifier:content:trigger:"), identifier_text, content, trigger);
		((void (*)(id, SEL, id, id))objc_msgSend)(center, selector("addNotificationRequest:withCompletionHandler:"),
				request, nullptr);
		message_void(content, "release");
	}
	release_string(identifier_text);
	release_string(title_text);
	release_string(body_text);
}

static void apply_plan(const std::string &payload, bool allow_ask);

// Shows the phone's own permission prompt (only the first time; after
// that it answers at once), then schedules the plan if the player agreed.
static void ask(id center) {
	unsigned long options = (1UL << 1) | (1UL << 2); // sound, alert
	((void (*)(id, SEL, unsigned long, void (^)(BOOL, id)))objc_msgSend)(center,
			selector("requestAuthorizationWithOptions:completionHandler:"), options, ^(BOOL granted, id error) {
				(void)error;
				dispatch_async(dispatch_get_main_queue(), ^{
					set_status(granted ? "granted" : "denied");
					if (granted) {
						apply_plan(last_payload, false);
					}
				});
			});
}

static void apply_plan(const std::string &payload, bool allow_ask) {
	std::vector<std::string> lines = split(payload, '\n');
	if (lines.empty() || lines[0] != "DW1") {
		return;
	}
	id center = notification_center();
	if (center == nullptr) {
		set_status("unsupported");
		return;
	}
	message_void(center, "removeAllPendingNotificationRequests");
	message_void(center, "removeAllDeliveredNotifications");
	double now = (double)time(nullptr);
	bool asking = false;
	for (size_t index = 1; index < lines.size(); index++) {
		std::vector<std::string> fields = split(lines[index], '\t');
		if (fields.size() == 1 && fields[0] == "ask") {
			asking = allow_ask;
		} else if (fields.size() == 5 && fields[0] == "R") {
			double seconds = strtod(fields[2].c_str(), nullptr) - now;
			if (seconds >= 60.0) {
				schedule(center, fields[1], seconds, fields[3], fields[4]);
			}
		}
	}
	if (asking) {
		ask(center);
	} else {
		read_status();
	}
}

static void tick() {
	const char *raw = getenv("DW_REMINDERS");
	std::string payload = raw == nullptr ? std::string() : std::string(raw);
	if (payload != last_payload) {
		last_payload = payload;
		if (!payload.empty()) {
			apply_plan(payload, true);
		}
	} else if (ticks % 30 == 0) {
		// Once a minute, in case the player changed it in the Settings app.
		read_status();
	}
	ticks++;
}

__attribute__((constructor)) static void start() {
	dispatch_async(dispatch_get_main_queue(), ^{
		timer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, dispatch_get_main_queue());
		if (timer == nullptr) {
			return;
		}
		dispatch_source_set_timer(timer, dispatch_time(DISPATCH_TIME_NOW, (int64_t)NSEC_PER_SEC), 2 * NSEC_PER_SEC,
				NSEC_PER_SEC / 4);
		dispatch_source_set_event_handler(timer, ^{
			tick();
		});
		dispatch_resume(timer);
	});
}

} // namespace dw_reminders

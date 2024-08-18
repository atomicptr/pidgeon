package pidgeon

import "base:runtime"
import "core:container/queue"
import "core:fmt"

strict_mode :: #config(PIDGEON_STRICT_MODE, false)

Message :: struct($T: typeid, $D: typeid) {
	type: T,
	data: D,
}

Listener :: struct($T: typeid, $D: typeid) {
	listener:   rawptr,
	on_message: proc(listener: rawptr, type: T, data: D) -> bool,
	loc:        runtime.Source_Code_Location,
}

Broker :: struct($T: typeid, $D: typeid) {
	listeners: map[T][dynamic]Listener(T, D),
	messages:  queue.Queue(Message(T, D)),
}

create :: proc($T: typeid, $D: typeid) -> ^Broker(T, D) {
	broker := new(Broker(T, D))
	return broker
}

register :: proc(
	using self: ^Broker($T, $D),
	type: T,
	who: rawptr,
	listener_func: proc(listener: rawptr, type: T, data: D) -> bool,
	loc := #caller_location,
) {
	l := listeners[type]
	append(&l, Listener(T, D){who, listener_func, loc})
	listeners[type] = l

	when ODIN_DEBUG {
		fmt.printfln("DEBUG: Pidgeon: Registered message listener for '%v' at %s", type, loc)
	}
}

unregister :: proc(using self: ^Broker($T, $D), who: rawptr) {
	for message_type in listeners {
		items_to_remove: [dynamic]int

		for listener, index in listeners[message_type] {
			if listener.listener == who {
				append(&items_to_remove, int(index))
			}
		}

		for index in items_to_remove {
			unordered_remove(&listeners[message_type], index)
		}

		delete(items_to_remove)
	}
}

process_messages :: proc(using self: ^Broker($T, $D)) {
	for queue.len(messages) > 0 {
		message := queue.pop_front(&messages)

		message_listeners, ok := listeners[message.type]
		if !ok {
			continue
		}

		for l in message_listeners {
			processed := l.on_message(l.listener, message.type, message.data)

			when strict_mode {
				assert(
					processed,
					fmt.tprintf(
						"ERROR: Pidgeon: Listener (%s) has not processed registered message: %v",
						l.loc,
						message.type,
					),
				)
			} else {
				if !processed {
					fmt.printfln(
						"WARN: Pidgeon: Listener (%s) has not processed registered message: %v",
						l.loc,
						message.type,
					)
				}
			}
		}
	}
}

post :: proc(using self: ^Broker($T, $D), type: T, data: D, loc := #caller_location) {
	queue.push_back(&messages, Message(T, D){type, data})

	when ODIN_DEBUG {
		fmt.printfln(
			"DEBUG: Pidgeon: Broker received message '%v' with data '%v' at %s",
			type,
			data,
			loc,
		)
	}
}

destroy :: proc(using self: ^Broker($T, $D)) {
	for message_type in listeners {
		delete(listeners[message_type])
	}
	delete(listeners)
	queue.destroy(&messages)
	free(self)
}


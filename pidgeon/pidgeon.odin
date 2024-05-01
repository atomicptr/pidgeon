package pidgeon

import "core:container/queue"
import "core:fmt"

Message :: struct($T: typeid, $D: typeid) {
	type: T,
	data: D,
}

Listener :: struct($T: typeid, $D: typeid) {
	listener:   rawptr,
	on_message: proc(listener: rawptr, type: T, data: D),
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
	listener_func: proc(listener: rawptr, type: T, data: D),
) {
	l := listeners[type]
	append(&l, Listener(T, D){who, listener_func})
	listeners[type] = l
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
			l.on_message(l.listener, message.type, message.data)
		}
	}
}

post :: proc(using self: ^Broker($T, $D), type: T, data: D) {
	queue.push_back(&messages, Message(T, D){type, data})
}

destroy :: proc(using self: ^Broker($T, $D)) {
	for message_type in listeners {
		delete(listeners[message_type])
	}
	delete(listeners)
	free(self)
}

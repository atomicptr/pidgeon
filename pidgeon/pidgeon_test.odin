package pidgeon

import "core:testing"

@(test)
test_message_passing :: proc(t: ^testing.T) {
	Test :: struct {
		t:            ^testing.T,
		message_send: ^bool,
	}

	b := create(string, Test)
	defer destroy(b)

	message_send := false

	register(b, "test", nil, proc(receiver: rawptr, msg: string, data: Test) -> bool {
		testing.expect_value(data.t, msg, "test")
		data.message_send^ = true
		return true
	})

	post(b, "test", Test{t, &message_send})

	process_messages(b)

	testing.expect(t, message_send)
}

@(test)
test_message_passing_enum_keys_multiple :: proc(t: ^testing.T) {
	Key :: enum u8 {
		A,
		B,
		C,
	}

	Test :: struct {
		t:    ^testing.T,
		send: [Key]^i32,
	}

	b := create(Key, Test)
	defer destroy(b)

	a_send: i32 = 0
	b_send: i32 = 0
	c_send: i32 = 0

	func :: proc(receiver: rawptr, msg: Key, data: Test) -> bool {
		data.send[msg]^ += 1
		return true
	}

	register(b, Key.A, nil, func)
	register(b, Key.B, nil, func)
	register(b, Key.C, nil, func)

	post(b, Key.A, Test{t, {.A = &a_send, .B = &b_send, .C = &c_send}})
	post(b, Key.A, Test{t, {.A = &a_send, .B = &b_send, .C = &c_send}})
	post(b, Key.B, Test{t, {.A = &a_send, .B = &b_send, .C = &c_send}})

	process_messages(b)

	testing.expect_value(t, a_send, 2)
	testing.expect_value(t, b_send, 1)
	testing.expect_value(t, c_send, 0)
}

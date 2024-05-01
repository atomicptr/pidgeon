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

	register(b, "test", nil, proc(receiver: rawptr, msg: string, data: Test) {
		testing.expect_value(data.t, msg, "test")
		data.message_send^ = true
	})

	post(b, "test", Test{t, &message_send})

	process_messages(b)

	testing.expect(t, message_send)
}

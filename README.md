# pidgeon

A simple messaging system for games written in [Odin](https://odin-lang.org).

## Usage

Pidgeon utilizes broker to whom you send pre defined messages with data, which you put into
a queue and then you process them all at once.

First we need to define our message and data types:

```odin
package game

import "pidgeon"

// In this example we will update our UI via messages, so when these values
// change we will send out a message
Message :: enum u8 {
  PlayerHPUpdated,
  PlayerManaUpdated,
}

// for this example we will only pass new values so a number is sufficient
// i usually use a union here though
MessageData :: u16

// we define one global broker
broker: ^pidgeon.Broker(Message, MessageData)
```

Next we need to initialize the broker somewhere, for this example I just decided to do
this in the main loop

```odin
package game

// ...

main :: proc() {
  // ...

  broker = pidgoen.create(Message, MessageData)
  defer pidgeon.destroy(broker)

  // ...
}
```

Now at various locations we can post messages:

```odin
package game

// ...

cast_spell :: proc(using self: ^Player, spell: Spell) {
  mana_amount -= spell.cost
  pidgeon.post(broker, Message.PlayerManaUpdated, mana_amount)

  spawn_spell(spell, position, direction)
}
```

And lastly we need to register to receive messages, which we can do like this:

```odin
package game

// ...

ui_create :: proc() {
  self := new(UIManager)
  // ...

  // first we register the events
  pidgeon.register(broker, Message.PlayerHPUpdated, rawptr(self), ui_on_message)
  pidgeon.register(broker, Message.PlayerManaUpdated, rawptr(self), ui_on_message)
}

ui_on_message :: proc(receiver: rawptr, message: Message, data: MessageData) {
  self := cast(^UIManager)receiver

  // next we handle the messages we care about
  #partial switch message {
  case Message.PlayerHPUpdated:
    value := data.(u16) // we know this can only be u16 here, depending on what you do check this
    ui_set_label(self.hp_label, fmt.cptrintf("HP: %d", value))
  case Message.PlayerManaUpdated:
    value := data.(u16)
    ui_set_label(self.mana_label, fmt.cptrintf("Mana: %d", value))
  }
}
```

And that is how you use pidgeon

## License

MIT

##[
Deser is a library for serializing and deserializing Nim data structures efficiently and generically. Just like [Serde](https://serde.rs/).

# Quickstart
First, install Deser via `nimble install deser`.

Deser is not a parser library. You need to install some parser from [Supported formats](#supported-formats).

We use [deser_json](https://github.com/gabbhack/deser_json/) for example - `nimble install deser_json`.

Let's say we have an API with `Message` type that has this output:
```js
{
  "id": 1,
  "text": "Hello!",
  "created": 1660848266
}
```

Let's try to map it to the Nim object.
Use [makeSerializable](deser/ser/make.html#makeSerializable.m,varargs[typedesc],static[bool])
and
[makeDeserializable](deser/des/make.html#makeDeserializable.m,varargs[typedesc],static[bool])
to generate `serialize` and `deserialize` procedures for your type.
```nim
import
  deser,
  deser_json

type
  Message = object
    id: int
    text: string
    created: int

makeSerializable(Message)
makeDeserializable(Message)
```

# Supported std-types

# Supported formats
[How to make bindings](#how-to-make-bindings)

# Customize serialization process

# How to make bindings
]##

import deser/[
  pragmas,
  des,
  ser
]

export
  pragmas,
  des,
  ser

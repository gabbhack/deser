##[
Deser is a library for serializing and deserializing Nim data structures efficiently and generically. Just like [Serde](https://serde.rs/).

# Explore
First, install Deser via `nimble install deser`.

Deser is not a parser library. You need to install some parser from [Supported formats](#supported-formats).

We use [deser_json](https://github.com/gabbhack/deser_json/) for example - `nimble install deser_json`.

Let's say we have an API with `Message` type that has this output:
```nim
const json = """
{
  "id": 1,
  "text": "Hello!",
  "created": 1660848266
}
"""
```

Let's try to map it to the Nim object.
Use [makeSerializable](deser/ser/make.html#makeSerializable.m,varargs[typedesc],static[bool])
and
[makeDeserializable](deser/des/make.html#makeDeserializable.m,varargs[typedesc],static[bool])
to generate `serialize` and `deserialize` procedures for your type.

.. Note:: This is a mandatory step. The generated procedures will then be used by parsers.

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

Use `toJson` and `fromJson` procedures from deser_json to serialize and deserialize to/from JSON:

```nim
let chat = Message.fromJson(json)
echo chat.toJson()
```

`created` field is the time in unix format, it is not convenient to work with it as `int`. But if we try to just use [Time](https://nim-lang.org/docs/times.html#Time), we get an error:

```nim
Error: type mismatch: got <typedesc[Time], Deserializer>
but expected one of: ...
```

.. Note:: Out of the box, deser supports serialization of [many types](#supported-stdminustypes) from the standard library. However, some types, such as `Time`, cannot be unambiguously serialized. Therefore, the user must explicitly specify how to serialize such types.

To fix this error, we need to use the [serializeWith](deser/pragmas.html#serializeWith.t%2Ctyped) and [deserializeWith](deser/pragmas.html#deserializeWith.t,typed) pragmas.

Full code:

```nim
import std/times

import
  deser,
  deser_json

proc toTimestamp(self: Time, serializer: var auto) =
  serializer.serializeInt64(self.toUnix())

proc fromTimestamp(deserializer: var auto): Time =
  fromUnix(deserialize(int64, deserializer))

type
  Message = object
    id: int
    text: string
    created {.serializeWith(toTimestamp), deserializeWith(fromTimestamp).}: Time

makeSerializable(Message)
makeDeserializable(Message)

const json = """
{
  "id": 1,
  "text": "Hello!",
  "created": 1660848266
}
"""
let chat = Message.fromJson(json)
echo chat.toJson()
```

# Supported std-types
- [bool](https://nim-lang.org/docs/system.html#bool)
- [int8-64](https://nim-lang.org/docs/system.html#SomeSignedInt) (int serializaed as int64)
- [uint8-64](https://nim-lang.org/docs/system.html#SomeUnsignedInt) (uint serialized as uint64)
- [float32-64](https://nim-lang.org/docs/system.html#SomeFloat) (float serializaed as float64)
- [char](https://nim-lang.org/docs/system.html#char)
- [string](https://nim-lang.org/docs/system.html#string)
- [seq](https://nim-lang.org/docs/system.html#seq)
- [array](https://nim-lang.org/docs/system.html#array)
- enum (serialized as the parser decides)
- tuple (serialized as array)
- [set](https://nim-lang.org/docs/system.html#set)
- [range](https://nim-lang.org/docs/system.html#range)
- [Option](https://nim-lang.org/docs/options.html#Option)
- [HashSet](https://nim-lang.org/docs/sets.html#HashSet)
- [OrderedSet](https://nim-lang.org/docs/sets.html#OrderedSet)
- [Table](https://nim-lang.org/docs/tables.html#Table)
- [OrderedTable](https://nim-lang.org/docs/tables.html#OrderedTable)

# Supported formats
[How to make bindings](#how-to-make-bindings)
- JSON - [deser_json](https://github.com/gabbhack/deser_json)

# Customize serialization process
Deser allows you to customize the serialization process, and the configuration will be applied to any parser.

Configuration is done with pragmas that are applied at compile time. [View available pragmas](deser/pragmas.html).

# How to make bindings
Check example at [deser_json](https://github.com/gabbhack/deser_json).

Check helpers templates for [serialization](deser/ser/helpers.html) and [deserialization](deser/des/helpers.html).

.. Note:: This section of the documentation is being supplemented.

# Write `serialize` and `deserialize` by hand
.. Note:: This section of the documentation is being supplemented.
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

import std/times

import deser


when defined(release):
  {.push inline.}

type UnixTimeFormat* = object ##[
Deserialize and serialize [Time](https://nim-lang.org/docs/times.html#Time) as unix timestamp integer.

**Example:**
```nim
import deser

type
  User = object
    created {.deserWith(UnixTimeFormat).}: Time

makeSerializable(User)
makeDeserializable(User)

let user = User(created: fromUnix(123))

assert user == User.fromJson("""{"created": 123}""")
assert user.toJson() == """{"created":123}"""
```
]##

proc deserialize*(self: typedesc[UnixTimeFormat], deserializer: var auto): Time =
  mixin deserialize

  fromUnix(deserialize(int64, deserializer))

proc serialize*(self: typedesc[UnixTimeFormat], field: Time, serializer: var auto) =
  mixin serialize

  serializer.serializeInt64(field.toUnix())


type DateTimeWith* = object ##[
Deserialize and serialize [DateTime](https://nim-lang.org/docs/times.html#DateTime) as string of your format.

**Example:**
```nim
type User = object
  created {.deserWith(DateTimeWith(format: "yyyy-MM-dd")).}: DateTime
```
]##
  format*: string

proc deserialize*(self: DateTimeWith, deserializer: var auto): DateTime =
  mixin deserialize

  parse(deserialize(string, deserializer), self.format)

proc serialize*(self: DateTimeWith, field: DateTime, serializer: var auto) =
  mixin serialize

  serializer.serializeString(field.format(self.format))

when defined(release):
  {.pop.}

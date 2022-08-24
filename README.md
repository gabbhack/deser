# Deser [![nim-version-img]][nim-version]

[nim-version]: https://nim-lang.org/blog/2021/10/19/version-160-released.html
[nim-version-img]: https://img.shields.io/badge/Nim_-v1.6.0%2B-blue

**Serde-like de/serialization library for Nim.**

`nimble install deser`

[Documentation](https://deser.nim.town)

---

## Motivation

Many serializers have already been written for Nim. You can probably find at least two serializers for each format. 

The problem is that each library's API and customization options are different. I can't declare an object with renamed or skipped fields once and change the data format with one line.

Attempts to generalize the serializer were also made. However, I found only one library that is actively under development - [nim-serialization](https://github.com/status-im/nim-serialization). When installing the library downloaded a quarter of all libraries for Nim, so I did not try it.

Thus, there was no library for Nim that standardized the serialization process, so I wrote **deser**.

Also read:
- [Standards](https://xkcd.com/927/)
- [Not invented here](https://en.wikipedia.org/wiki/Not_invented_here)


## Supported formats
 - JSON - [deser_json](https://github.com/gabbhack/deser_json)

Also read:
- [How to make bindings](https://deser.nim.town/deser.html#how-to-make-bindings)


## Example
```nim
import std/[
  options,
  times
]

import
  deser,
  deser_json

proc fromTimestamp(deserializer: var auto): Time =
  fromUnix(deserialize(int64, deserializer))

proc toTimestamp(self: Time, serializer: var auto) =
  serializer.serializeInt64(self.toUnix())

type
  ChatType = enum
    Private = "private"
    Group = "group"

  Chat {.renameAll(SnakeCase).} = object
    id: int64
    username: Option[string]
    created {.serializeWith(toTimestamp), deserializeWith(fromTimestamp).}: Time

    case kind {.renamed("type").}: ChatType
    of Private:
      firstName: string
      lastName {.skipSerializeIf(isNone).}: Option[string]
      bio {.skipSerializeIf(isNone).}: Option[String]
    of Group:
      title: string

# Use public to export deserialize or serialize procedures
# false by default
makeSerializable(Chat, public=true)
makeDeserializable(Chat, public=true)

const
  json = """
  {
    "id": 123,
    "username": "gabbhack",
    "created": 1234567890,
    "type": "private",
    "first_name": "Gabben"
  }
  """
  chat = Chat(
    id: 123,
    username: some "gabbhack",
    created: fromUnix(1234567890),
    kind: Private,
    firstName: "Gabben"
  )

echo Chat.fromJson(json)
echo chat.toJson()
```

Also read:
- [Customize serialization process](https://deser.nim.town/deser.html#customize-serialization-process)

## License
Licensed under <a href="LICENSE">MIT license</a>.

Deser uses third-party libraries or other resources that may be
distributed under licenses different than the deser.

<a href="THIRD-PARTY-NOTICES.TXT">THIRD-PARTY-NOTICES.TXT</a>


## Acknowledgements
- [serde.rs](https://serde.rs), for all the ideas I stole
- [patty](https://github.com/andreaferretti/patty), for making it easier to work with object variants

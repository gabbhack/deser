# Deser

**Deser is a serialization and deserialization library for Nim**

[Deser documentation](https://deser.nim.town/)

## Installation

```
nimble install deser
```

or

```nim
requires "nim >= 1.4.2, deser"
```

## Features

- **Efficient**: `deser` does not use reflection or type information at runtime. Read more about [overhead](https://deser.nim.town/deser.html#manual-overhead).
- **Easy to use**: [simple](https://deser.nim.town/deser.html#design-easy-to-use) API for users and data formats developers.
- **Functional**: use pragmas to [manage](https://deser.nim.town/deser.html#design-functional) the serialization and deserialization process.
- **Universal**: `deser` is [not limited](https://deser.nim.town/deser.html#design-universal) to any data format.

## Usage

```nim
import times
import deser, deser_json

type
  Foo {.des, ser, renameAll(rkSnakeCase), skipSerializeIf(isNone).} = object
    id: int
    someOption: Option[int]
    test {.skip.}: int
    date {.serializeWith(toUnix), deserializeWith(fromUnix).}: Time

const js = """
  {
    "id": 123,
    "some_option": 321,
    "date": 1214092800
  }
"""

var f = Foo.fromJson(js)

assert f.someOption.get == 321

f.someOption = none(int)

assert f.toJson() == """{"id":123,"date":1214092800}"""

```

## Contributing
1. Fork the Project
2. Create your Feature Branch (`git checkout -b feature/AmazingFeature`)
3. Format the code (`nimble pretty`)
4. Check tests (`nimble test`)
5. Commit your Changes (`git commit -m 'Add some AmazingFeature'`)
6. Push to the Branch (`git push origin feature/AmazingFeature`)
7. Open a Pull Request

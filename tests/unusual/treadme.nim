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

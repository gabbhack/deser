# Actually testing `break` statement inside forDesFields

import macros, options, times
import deser, deser_json

type
  Foo {.skipSerializeIf(isNone), renameAll(rkSnakeCase).} = object
    id: int
    someOption: Option[int]
    date {.serializeWith(toUnix), deserializeWith(fromUnix).}: Time

const js = """
  {
    "id": 123,
    "some_option": 321,
    "date": 1214092800
  }
"""

var f = js.parse().to(Foo)

f.someOption = none(int)

assert f.dumps() == """{"id":123,"date":1214092800}"""

discard """
  output: '''
id int
msg_text string
TiMe Time
SOME_FOO string
  '''
"""
import macros, options, times
import deser

type
  Foo {.renameAll(rkUpperSnakeCase).} = object
    someOption: Option[string]
    someFoo: string
  Test {.renameAll(rkSnakeCase), skipSerializeIf(isNone).} = object
    id: int
    msgText: string
    photo: Option[string]
    time {.serializeWith(fromUnix), rename("TiMe").}: int64
    foo {.flat.}: Foo

let t = Test()

forSerFields key, value, t:
  echo key, " ", value.type

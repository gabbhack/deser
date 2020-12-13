discard """
  output: '''
msg_text string
TiMe int64
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
    id {.skip.}: int
    anotherSkip {.skipSerializing.}: int
    msgText: string
    photo: Option[string]
    time {.serializeWith(toUnix), rename("TiMe").}: Time
    foo {.flat.}: Foo

let t = Test()

forSerFields key, value, t:
  echo key, " ", value.type
discard """
  output: '''
msg_text string
TiMe int64
SOME_OPTION Option[system.string]
SOME_FOO string
  '''
"""
import options, times
import deser

type
  Foo {.ser, renameAll(rkUpperSnakeCase).} = object
    someOption: Option[string]
    someFoo: string
  Test {.ser, renameAll(rkSnakeCase), skipSerializeIf(isNone).} = object
    id {.skip.}: int
    anotherSkip {.skipSerializing.}: int
    msgText: string
    photo: Option[string]
    time {.serializeWith(toUnix), rename("TiMe").}: Time
    foo {.flat.}: Foo

let t = Test()

forSer key, value, t:
  echo key, " ", value.type

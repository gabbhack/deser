discard """
  output: '''
id Option[system.int]
msg_text Option[system.string]
photo Option[system.string]
TiMe Option[system.int64]
SOME_OPTION Option[system.string]
SOME_FOO Option[system.string]
  '''
"""
import
  times,
  deser

type
  Foo {.des, renameAll(rkUpperSnakeCase).} = object
    someOption: Option[string]
    someFoo: string
  Test {.des, renameAll(rkSnakeCase).} = object
    id: int
    msgText: string
    photo: Option[string]
    time {.deserializeWith(fromUnix), rename("TiMe").}: Time
    foo {.flat.}: Foo

var t = Test()

startDes t:
  forDes key, value, t:
    echo key, " ", value.type
    finish:
      value = some(default(value.get.type))

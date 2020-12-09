discard """
  output: '''
id int
msg_text string
photo Option[system.string]
TiMe int64
SOME_OPTION Option[system.string]
SOME_FOO string
  '''
"""
import macros, options, times
import deser

type
  Foo {.renameAll(rkUpperSnakeCase).} = object
    someOption: Option[string]
    someFoo: string
  Test {.renameAll(rkSnakeCase).} = object
    id: int
    msgText: string
    photo: Option[string]
    time {.deserializeWith(fromUnix), rename("TiMe").}: Time
    foo {.flat.}: Foo

var t = Test()

forDesFields key, value, t:
  echo key, " ", value.type

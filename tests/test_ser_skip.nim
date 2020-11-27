discard """
  output: '''
foo int 0

fooInt int 0
kek int 0
  '''
"""
import macros, options
import deser

proc skipFloat(x: float): bool = true
proc skipInt(x: int): bool = true

type
  Test = object
    id {.skip.}: int
    text {.skipSerializing.}: string
    foo {.skipDeserializing.}: int
    bar {.skipSerializeIf(skipFloat).}: float
  
  Bar {.skipSerializeIf(isNone).} = object
    id {.skipSerializeIf(skipInt).}: int
    barFloat: float
    text: Option[string]
    kek: int

let t = Test()

forSerFields key, value, t:
  echo key, " ", value.type, " ", value

echo ""

type
  Foo {.skipSerializeIf(skipFloat).} = object
    fooInt: int
    bar {.flat.}: Bar
    fooFloat: float

let f = Foo()

forSerFields key, value, f:
  echo key, " ", value.type, " ", value

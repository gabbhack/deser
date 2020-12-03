discard """
  output: '''
someFloat
kek
  '''
"""
import macros, options
import deser

proc skipInt(x: int): bool = true

type
  Test {.skipSerializeIf(isNone).} = object
    id {.skipSerializeIf(skipInt).}: int
    someFloat: float
    text: Option[string]
    kek: int

let t = Test()

forSerFields key, value, t:
  echo key

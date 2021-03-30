discard """
  output: '''
someFloat
kek
  '''
"""
import options
import deser

proc skipInt(x: int): bool = true

type
  Test {.ser, skipSerializeIf(isNone).} = object
    id {.skipSerializeIf(skipInt).}: int
    someFloat: float
    text: Option[string]
    kek: int

let t = Test()

forSer key, value, t:
  echo key

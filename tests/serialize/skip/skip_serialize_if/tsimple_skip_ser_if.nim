discard """
  output: '''
id
  '''
"""

import deser

proc skipFloat(x: float): bool = true
proc skipInt(x: int): bool = true

type
  Test {.ser.} = object
    id: int
    uselessFloat {.skipSerializeIf(skipFloat).}: float
    uselessInt {.skipSerializeIf(skipInt).}: int

let t = Test()

forSer(k, v, t):
  echo k

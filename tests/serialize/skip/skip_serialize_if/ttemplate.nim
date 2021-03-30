discard """
  output: '''
id
  '''
"""

import deser

template skipFloat(x: float): bool = true
template skipInt(x: int): bool = true

type
  Test {.ser.} = object
    id: int
    uselessFloat {.skipSerializeIf(skipFloat).}: float
    uselessInt {.skipSerializeIf(skipInt).}: int

let t = Test()

forSer(k, v, t):
  echo k

discard """
  output: '''
id
  '''
"""
import macros
import deser

proc skipFloat(x: float): bool = true
proc skipInt(x: int): bool = true

type
  Test = object
    id: int
    uselessFloat {.skipSerializeIf(skipFloat).}: float
    uselessInt {.skipSerializeIf(skipInt).}: int

let t = Test()

forSerFields(k, v, t):
  echo k

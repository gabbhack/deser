discard """
  output: '''
id
  '''
"""
import options
import deser

type
  Test {.ser.} = object
    id: int
    someOption {.skipSerializeIf(isNone).}: Option[int]

let t = Test()

forSer(k, v, t):
  echo k

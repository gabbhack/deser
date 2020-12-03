discard """
  output: '''
id
  '''
"""
import macros, options
import deser

type
  Test = object
    id: int
    someOption {.skipSerializeIf(isNone).}: Option[int]

let t = Test()

forSerFields(k, v, t):
  echo k

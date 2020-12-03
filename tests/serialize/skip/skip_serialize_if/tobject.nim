discard """
  output: '''
id
text
  '''
"""
import macros, options
import deser

type
  Test {.skipSerializeIf(isNone).} = object
    id: int
    text: string
    someOption: Option[int]

let t = Test()

forSerFields key, value, t:
  echo key

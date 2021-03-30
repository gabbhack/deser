discard """
  output: '''
id
text
  '''
"""
import options
import deser

type
  Test {.ser, skipSerializeIf(isNone).} = object
    id: int
    text: string
    someOption: Option[int]

let t = Test()

forSer key, value, t:
  echo key

discard """
  output: '''
id
text
  '''
"""
import macros
import deser

type
  Test = object
    id: int
    text: string
    useless {.skipSerializing.}: string

let t = Test()

forSerFields(k, v, t):
  echo k

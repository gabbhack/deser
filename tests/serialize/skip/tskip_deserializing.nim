discard """
  output: '''
id
text
usefull
  '''
"""
import macros
import deser

type
  Test = object
    id: int
    text: string
    usefull {.skipDeserializing.}: string

let t = Test()

forSerFields(k, v, t):
  echo k

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
    usefull {.skipSerializing.}: string

var t = Test()

forDesFields(k, v, t):
  echo k

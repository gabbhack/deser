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
    useless {.skipDeserializing.}: string

var t = Test()

forDesFields(k, v, t):
  echo k

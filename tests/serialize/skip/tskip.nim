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
    useless {.skip.}: string

let t = Test()

forSerFields(k, v, t):
  echo k

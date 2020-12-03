discard """
  output: '''
camelCase
anotherCamelCase
  '''
"""
import macros
import deser

type
  TestToKebabCase {.renameAll(rkNothing).} = object
    camelCase: int
    anotherCamelCase: int

let tkc = TestToKebabCase()

forSerFields key, value, tkc:
  echo key

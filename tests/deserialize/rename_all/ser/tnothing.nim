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

var tkc = TestToKebabCase()

forDesFields key, value, tkc:
  echo key

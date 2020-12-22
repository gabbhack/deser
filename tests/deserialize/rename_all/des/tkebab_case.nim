discard """
  output: '''
camel-case
another-camel-case
  '''
"""
import macros
import deser

type
  TestToKebabCase {.renameAll(des = rkKebabCase).} = object
    camelCase: int
    anotherCamelCase: int

var tkc = TestToKebabCase()

forDesFields key, value, tkc:
  echo key

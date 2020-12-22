discard """
  output: '''
CAMEL-CASE
ANOTHER-CAMEL-CASE
  '''
"""
import macros
import deser

type
  TestToUpperKebabCase {.renameAll(des = rkUpperKebabCase).} = object
    camelCase: int
    anotherCamelCase: int

var tukc = TestToUpperKebabCase()

forDesFields key, value, tukc:
  echo key

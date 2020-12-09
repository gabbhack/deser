discard """
  output: '''
CAMEL_CASE
ANOTHER_CAMEL_CASE
  '''
"""
import macros
import deser

type
  TestToUpperSnakeCase {.renameAll(rkUpperSnakeCase).} = object
    camelCase: int
    anotherCamelCase: int

var tusc = TestToUpperSnakeCase()

forDesFields key, value, tusc:
  echo key

discard """
  output: '''
camel_case
another_camel_case
  '''
"""
import macros
import deser

type
  TestToSnakeCase {.renameAll(des = rkSnakeCase).} = object
    camelCase: int
    anotherCamelCase: int

var tsc = TestToSnakeCase()

forDesFields key, value, tsc:
  echo key

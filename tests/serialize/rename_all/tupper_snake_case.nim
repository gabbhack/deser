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

let tusc = TestToUpperSnakeCase()

forSerFields key, value, tusc:
  echo key

discard """
  output: '''
camel_case
another_camel_case
  '''
"""
import macros
import deser

type
  TestToSnakeCase {.renameAll(rkSnakeCase).} = object
    camelCase: int
    anotherCamelCase: int

let tsc = TestToSnakeCase()

forSerFields key, value, tsc:
  echo key

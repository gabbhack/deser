discard """
  output: '''
CAMEL-CASE
ANOTHER-CAMEL-CASE
  '''
"""
import macros
import deser

type
  TestToUpperKebabCase {.renameAll(rkUpperKebabCase).} = object
    camelCase: int
    anotherCamelCase: int

let tukc = TestToUpperKebabCase()

forSerFields key, value, tukc:
  echo key

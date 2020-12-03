discard """
  output: '''
camel-case
another-camel-case
  '''
"""
import macros
import deser

type
  TestToKebabCase {.renameAll(rkKebabCase).} = object
    camelCase: int
    anotherCamelCase: int

let tkc = TestToKebabCase()

forSerFields key, value, tkc:
  echo key

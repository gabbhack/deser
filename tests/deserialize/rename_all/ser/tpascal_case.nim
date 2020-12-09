discard """
  output: '''
CamelCase
AnotherCamelCase
  '''
"""
import macros
import deser

type
  TestToPascalCase {.renameAll(rkPascalCase).} = object
    camelCase: int
    anotherCamelCase: int

var tpc = TestToPascalCase()

forDesFields key, value, tpc:
  echo key

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

let tpc = TestToPascalCase()

forSerFields key, value, tpc:
  echo key

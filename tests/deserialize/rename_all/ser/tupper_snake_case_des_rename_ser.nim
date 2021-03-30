discard """
  output: '''
CAMEL_CASE
ANOTHER_CAMEL_CASE
  '''
"""

import deser

type
  TestToUpperSnakeCase {.des, renameAll(rkUpperSnakeCase).} = object
    camelCase: int
    anotherCamelCase: int

var t = TestToUpperSnakeCase()

startDes(t):
  forDes(k, v, t):
    echo k
    finish:
      v = some(default(v.get.type))

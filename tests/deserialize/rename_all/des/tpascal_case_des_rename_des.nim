discard """
  output: '''
CamelCase
AnotherCamelCase
  '''
"""

import deser

type
  TestToPascalCase {.des, renameAll(des = rkPascalCase).} = object
    camelCase: int
    anotherCamelCase: int

var t = TestToPascalCase()

startDes(t):
  forDes(k, v, t):
    echo k
    finish:
      v = some(default(v.get.type))
